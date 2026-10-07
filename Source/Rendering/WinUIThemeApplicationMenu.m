#import "WinUIThemeDrawing.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

/* Windows menu conventions. Windows apps have no menu named after the app:
   Exit ends the File menu, About ends the Help menu, and there's nothing
   to hide. GSTheme's -organizeMenu:isHorizontal: gathers a horizontal main
   menu's loose items, Info and Services into a first menu titled with the
   app's name; the theme hands each item to its Windows home and drops that
   menu. The original items move, so actions, validation and key
   equivalents keep working. */

/* The title GSTheme gives the application menu. */
static NSString *
WinUIThemeApplicationMenuTitle(void)
{
  NSString *title = [[[NSBundle mainBundle] localizedInfoDictionary]
                      objectForKey: @"ApplicationName"];

  return (title != nil) ? title : [[NSProcessInfo processInfo] processName];
}

/* `string` as libs-gui translates it (Services, Info, ...), else itself. */
static NSString *
WinUIThemeGUIString(NSString *string)
{
  return [[NSBundle bundleForClass: [NSApplication class]]
           localizedStringForKey: string value: string table: nil];
}

/* The menu the app passed to -[NSApplication setAppleMenu:], which GNUstep
   itself ignores. */
static NSMenu *WinUIThemeAppleMenu = nil;

static BOOL
WinUIThemeActionIs(NSMenuItem *item, SEL selector)
{
  SEL action = [item action];

  return (action != NULL && sel_isEqual(action, selector));
}

/* Whether `menu` holds items only a Cocoa application menu has. */
static BOOL
WinUIThemeMenuHasCocoaApplicationItems(NSMenu *menu)
{
  NSEnumerator *enumerator = [[menu itemArray] objectEnumerator];
  NSMenuItem *item = nil;

  while ((item = [enumerator nextObject]) != nil)
    {
      if (WinUIThemeActionIs(item, @selector(orderFrontStandardAboutPanel:))
          || WinUIThemeActionIs(item, @selector(hide:))
          || WinUIThemeActionIs(item, @selector(hideOtherApplications:))
          || WinUIThemeActionIs(item, @selector(unhideAllApplications:)))
        {
          return YES;
        }
    }
  return NO;
}

/* Cocoa treats the main menu's first item as the application menu,
   whatever its title: menus built in code usually leave it untitled, and
   nibs often say "NewApplication". GSTheme only recognises an item titled
   with the app's name. Recognise it the way Cocoa apps mark it (untitled,
   passed to -setAppleMenu:, a nib's _NSAppleMenu, or holding About or
   Hide) and give it the app's name, so it's handled like GNUstep's. A
   GNUstep-style first menu (Info, File, ...) has none of these marks.
   From the Adwaita theme. */
static void
WinUIThemeAdoptCocoaApplicationMenu(NSMenu *menu)
{
  NSString *appTitle = WinUIThemeApplicationMenuTitle();
  NSMenuItem *first = nil;
  NSMenu *submenu = nil;
  BOOL cocoa = NO;

  if ([menu numberOfItems] == 0 || [menu itemWithTitle: appTitle] != nil)
    {
      return;
    }
  first = (NSMenuItem *)[menu itemAtIndex: 0];
  submenu = [first submenu];
  if (submenu == nil)
    {
      return;
    }
  cocoa = ([[first title] length] == 0
           || submenu == WinUIThemeAppleMenu
           || ([submenu respondsToSelector: @selector(_name)]
               && [[submenu performSelector: @selector(_name)] isEqualToString: @"_NSAppleMenu"])
           || WinUIThemeMenuHasCocoaApplicationItems(submenu));
  if (cocoa)
    {
      [first setTitle: appTitle];
      [submenu setTitle: appTitle];
    }
}

/* The main menu's submenu titled `title` (or its translation), made at
   `index` (NSNotFound: at the end) when there isn't one. */
static NSMenu *
WinUIThemeTopLevelMenu(NSMenu *mainMenu, NSString *title, NSUInteger index)
{
  NSString *localized = WinUIThemeGUIString(title);
  NSEnumerator *enumerator = [[mainMenu itemArray] objectEnumerator];
  NSMenuItem *item = nil;
  NSMenu *submenu = nil;

  while ((item = [enumerator nextObject]) != nil)
    {
      if ([item hasSubmenu]
          && ([[item title] isEqualToString: title] || [[item title] isEqualToString: localized]))
        {
          return [item submenu];
        }
    }

  item = AUTORELEASE([[NSMenuItem alloc] initWithTitle: localized
                                                action: NULL
                                         keyEquivalent: @""]);
  submenu = AUTORELEASE([[NSMenu alloc] initWithTitle: localized]);
  [mainMenu insertItem: item
               atIndex: (index == NSNotFound) ? [mainMenu numberOfItems] : index];
  [mainMenu setSubmenu: submenu forItem: item];
  return submenu;
}

/* Appends `items` to `menu`, after a separator when the menu already has
   items and `separate` is set. */
static void
WinUIThemeAppendItems(NSMenu *menu, NSArray *items, BOOL separate)
{
  NSEnumerator *enumerator = nil;
  NSMenuItem *item = nil;

  if ([items count] == 0)
    {
      return;
    }
  if (separate && [menu numberOfItems] > 0
      && [(NSMenuItem *)[menu itemAtIndex: [menu numberOfItems] - 1] isSeparatorItem] == NO)
    {
      [menu addItem: [NSMenuItem separatorItem]];
    }
  enumerator = [items objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      [menu addItem: item];
    }
}

static BOOL
WinUIThemeItemIsPreferences(NSMenuItem *item)
{
  NSString *action = NSStringFromSelector([item action]);
  NSString *title = [[item title] lowercaseString];

  return ([action rangeOfString: @"reference"].location != NSNotFound
          || [action rangeOfString: @"Settings"].location != NSNotFound
          || [title hasPrefix: @"preferences"]
          || [title hasPrefix: @"settings"]
          || [title hasPrefix: @"options"]);
}

static BOOL
WinUIThemeItemIsAbout(NSMenuItem *item)
{
  return (WinUIThemeActionIs(item, @selector(orderFrontStandardAboutPanel:))
          || WinUIThemeActionIs(item, @selector(orderFrontStandardInfoPanel:))
          || [[[item title] lowercaseString] hasPrefix: @"about"]
          || [[[item title] lowercaseString] hasPrefix: @"info panel"]);
}

/* Sorts the application menu's items (and those of GNUstep's Info submenu
   in it) into their Windows homes. */
static void
WinUIThemeSortApplicationItems(NSMenu *appMenu,
                               NSMutableArray *fileItems,
                               NSMutableArray *preferenceItems,
                               NSMutableArray *helpItems,
                               NSMutableArray *aboutItems,
                               NSMutableArray *exitItems)
{
  NSArray *items = [NSArray arrayWithArray: [appMenu itemArray]];
  NSEnumerator *enumerator = [items objectEnumerator];
  NSMenuItem *item = nil;
  NSMenu *servicesMenu = [NSApp servicesMenu];

  while ((item = [enumerator nextObject]) != nil)
    {
      NSMenu *submenu = [item submenu];
      NSString *title = [item title];

      [appMenu removeItem: item];
      if ([item isSeparatorItem])
        {
          continue;
        }
      /* Windows has no hidden apps or Services menu. */
      if (WinUIThemeActionIs(item, @selector(hide:))
          || WinUIThemeActionIs(item, @selector(hideOtherApplications:))
          || WinUIThemeActionIs(item, @selector(unhideAllApplications:))
          || (submenu != nil && (submenu == servicesMenu
                                 || [title isEqualToString: @"Services"]
                                 || [title isEqualToString: WinUIThemeGUIString(@"Services")])))
        {
          continue;
        }
      /* GNUstep's Info submenu: Info Panel, Preferences, Help. */
      if (submenu != nil && ([title isEqualToString: @"Info"]
                             || [title isEqualToString: WinUIThemeGUIString(@"Info")]))
        {
          WinUIThemeSortApplicationItems(submenu, fileItems, preferenceItems,
                                         helpItems, aboutItems, exitItems);
          continue;
        }

      if (WinUIThemeActionIs(item, @selector(terminate:)))
        {
          [item setTitle: WinUIThemeGUIString(@"Exit")];
          [exitItems addObject: item];
        }
      else if (WinUIThemeItemIsAbout(item))
        {
          [item setTitle: [NSString stringWithFormat: WinUIThemeGUIString(@"About %@"),
                                                       WinUIThemeApplicationMenuTitle()]];
          [aboutItems addObject: item];
        }
      else if (WinUIThemeItemIsPreferences(item))
        {
          [preferenceItems addObject: item];
        }
      else if (WinUIThemeActionIs(item, @selector(showHelp:)))
        {
          [helpItems addObject: item];
        }
      else
        {
          [fileItems addObject: item];
        }
    }
}

/* The display form of a key equivalent libs-gui composed as control,
   alternate, shift and command prefixes, then the key ("#o"). Windows
   shows "Ctrl+O": on Windows GNUstep's Command is the left Ctrl key and
   Control the right one (libs-back's GSFirstCommandKey defaults). */
static NSString *
WinUIThemeModifierString(NSString *key, NSString *fallback)
{
  NSString *string = [[NSUserDefaults standardUserDefaults] stringForKey: key];

  return ([string length] > 0) ? string : fallback;
}

@implementation WinUITheme (ApplicationMenu)

- (void) organizeMenu: (NSMenu *)menu
         isHorizontal: (BOOL)horizontal
{
  BOOL mainMenu = (menu == [NSApp mainMenu]);
  NSMenuItem *first = nil;
  NSMenu *appMenu = nil;
  NSMutableArray *fileItems = nil;
  NSMutableArray *preferenceItems = nil;
  NSMutableArray *helpItems = nil;
  NSMutableArray *aboutItems = nil;
  NSMutableArray *exitItems = nil;

  if (horizontal && mainMenu)
    {
      WinUIThemeAdoptCocoaApplicationMenu(menu);
    }

  [super organizeMenu: menu isHorizontal: horizontal];

  if (horizontal == NO || mainMenu == NO || [menu numberOfItems] == 0)
    {
      return;
    }
  first = (NSMenuItem *)[menu itemAtIndex: 0];
  if ([first hasSubmenu] == NO
      || [[first title] isEqualToString: WinUIThemeApplicationMenuTitle()] == NO)
    {
      return;
    }

  appMenu = RETAIN([first submenu]);
  fileItems = [NSMutableArray array];
  preferenceItems = [NSMutableArray array];
  helpItems = [NSMutableArray array];
  aboutItems = [NSMutableArray array];
  exitItems = [NSMutableArray array];
  WinUIThemeSortApplicationItems(appMenu, fileItems, preferenceItems,
                                 helpItems, aboutItems, exitItems);
  [menu removeItemAtIndex: 0];
  RELEASE(appMenu);

  if ([fileItems count] > 0 || [exitItems count] > 0)
    {
      NSMenu *fileMenu = WinUIThemeTopLevelMenu(menu, @"File", 0);

      WinUIThemeAppendItems(fileMenu, fileItems, YES);
      if ([preferenceItems count] > 0
          && [menu itemWithTitle: @"Edit"] == nil
          && [menu itemWithTitle: WinUIThemeGUIString(@"Edit")] == nil)
        {
          WinUIThemeAppendItems(fileMenu, preferenceItems, YES);
          [preferenceItems removeAllObjects];
        }
      WinUIThemeAppendItems(fileMenu, exitItems, YES);
    }
  if ([preferenceItems count] > 0)
    {
      NSUInteger editIndex = ([menu numberOfItems] > 0) ? 1 : 0;

      WinUIThemeAppendItems(WinUIThemeTopLevelMenu(menu, @"Edit", editIndex),
                            preferenceItems, YES);
    }
  if ([helpItems count] > 0 || [aboutItems count] > 0)
    {
      NSMenu *helpMenu = WinUIThemeTopLevelMenu(menu, @"Help", NSNotFound);

      WinUIThemeAppendItems(helpMenu, helpItems, YES);
      WinUIThemeAppendItems(helpMenu, aboutItems, YES);
    }
}

/* libs-gui organises the main menu when it's set (and when the app icon or
   interface style changes), but apps often set an empty main menu and fill
   it in afterwards (ScreenshotTool), leaving the application menu in the
   bar. The theme tidies the main menu again after launch and whenever a
   window becomes key or main; when there's no application menu this does
   nothing. */
- (void) tidyMainMenu
{
  NSMenu *mainMenu = [NSApp mainMenu];
  NSMenuItem *first = nil;

  if (mainMenu == nil || [mainMenu numberOfItems] == 0
      || NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      return;
    }
  WinUIThemeAdoptCocoaApplicationMenu(mainMenu);
  first = (NSMenuItem *)[mainMenu itemAtIndex: 0];
  if ([first hasSubmenu]
      && [[first title] isEqualToString: WinUIThemeApplicationMenuTitle()])
    {
      [self organizeMenu: mainMenu isHorizontal: YES];
    }
}

- (NSString *) keyForKeyEquivalent: (NSString *)aString
{
  NSString *control = WinUIThemeModifierString(@"GSControlKeyString", @"^");
  NSString *alternate = WinUIThemeModifierString(@"GSAlternateKeyString", @"+");
  NSString *shift = WinUIThemeModifierString(@"GSShiftKeyString", @"/");
  NSString *command = WinUIThemeModifierString(@"GSCommandKeyString", @"#");
  NSString *rest = aString;
  BOOL ctrl = NO;
  BOOL alt = NO;
  BOOL shifted = NO;
  NSMutableString *display = nil;

  /* The prefixes come in libs-gui's order; the key itself always
     remains, even when it's one of the prefix characters. */
  if ([rest length] > [control length] && [rest hasPrefix: control])
    {
      ctrl = YES;
      rest = [rest substringFromIndex: [control length]];
    }
  if ([rest length] > [alternate length] && [rest hasPrefix: alternate])
    {
      alt = YES;
      rest = [rest substringFromIndex: [alternate length]];
    }
  if ([rest length] > [shift length] && [rest hasPrefix: shift])
    {
      shifted = YES;
      rest = [rest substringFromIndex: [shift length]];
    }
  if ([rest length] > [command length] && [rest hasPrefix: command])
    {
      ctrl = YES;
      rest = [rest substringFromIndex: [command length]];
    }
  if (ctrl == NO && alt == NO && shifted == NO)
    {
      return aString;
    }

  /* An upper case letter means Shift, as in Cocoa. */
  if ([rest length] == 1
      && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember: [rest characterAtIndex: 0]])
    {
      shifted = YES;
    }
  if ([rest isEqualToString: @"RET"])
    {
      rest = @"Enter";
    }
  else if ([rest isEqualToString: @"ESC"])
    {
      rest = @"Esc";
    }
  else if ([rest isEqualToString: @"DEL"])
    {
      rest = @"Del";
    }
  else
    {
      rest = [rest uppercaseString];
    }

  display = [NSMutableString string];
  if (ctrl)
    {
      [display appendString: @"Ctrl+"];
    }
  if (alt)
    {
      [display appendString: @"Alt+"];
    }
  if (shifted)
    {
      [display appendString: @"Shift+"];
    }
  [display appendString: rest];
  return display;
}

- (void) _overrideNSApplicationMethod_setAppleMenu: (NSMenu *)aMenu
{
  typedef void (*SetMenuIMP)(id, SEL, NSMenu *);
  SetMenuIMP originalIMP = (SetMenuIMP)WinUIThemeOriginalMethod(_cmd, self, [NSApplication class]);

  ASSIGN(WinUIThemeAppleMenu, aMenu);
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, aMenu);
    }
}

@end
