#import "WinUITheme.h"

#import "Settings/WinUIThemeSettings.h"
#import "Settings/WinUIThemeMetrics.h"
#import "Rendering/WinUIThemePalette.h"
#import "Native/WinUIThemeShellDialogs.h"
#import "Native/WinUIThemeWindowIntegration.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

static NSString *WinUIThemeRuntimeDefaultsDomain = @"WinUIThemeRuntimeDomain";

@interface WinUITheme ()
- (void) applyRuntimeDefaults;
- (void) removeRuntimeDefaults;
- (void) refreshRuntimeDefaultsIfNeeded;
- (NSDictionary *) runtimeDefaultsDictionary;
- (BOOL) shouldUseWindowIntegration;
- (void) windowNeedsMainMenu: (NSNotification *)notification;
- (void) applicationDidFinishLaunching: (NSNotification *)notification;
- (void) addFont: (NSFont *)font
          forKey: (NSString *)key
     toDictionary: (NSMutableDictionary *)dictionary;
@end

IMP
WinUIThemeOriginalMethod(SEL selector, id receiver, Class baseClass)
{
  static NSMapTable *prototypes = nil;
  GSTheme *theme = [GSTheme theme];
  IMP imp = [theme overriddenMethod: selector for: receiver];
  id prototype;

  if (imp != NULL || baseClass == Nil)
    {
      return imp;
    }
  /* An instance of exactly `baseClass`, used only as a lookup key: it is never
     initialised, messaged, or freed. */
  if (prototypes == nil)
    {
      prototypes = [[NSMapTable alloc]
        initWithKeyOptions: NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
              valueOptions: NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality
                  capacity: 16];
    }
  prototype = (id)NSMapGet(prototypes, (void *)baseClass);
  if (prototype == nil)
    {
      prototype = class_createInstance(baseClass, 0);
      NSMapInsert(prototypes, (void *)baseClass, (void *)prototype);
    }
  return [theme overriddenMethod: selector for: prototype];
}

@implementation WinUITheme

+ (NSString *) themeName
{
  return @"WinUI";
}

- (id) initWithBundle: (NSBundle *)bundle
{
  self = [super initWithBundle: bundle];
  if (self != nil)
    {
      _settings = [WinUIThemeSettings new];
      _metrics = [WinUIThemeMetrics new];
      _runtimeDefaultsApplied = NO;
      [self reloadConfiguration];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_settings);
  RELEASE(_metrics);
  RELEASE(_palette);
  [super dealloc];
}

- (void) reloadConfiguration
{
  [_settings reload];
  [_metrics reloadFromSettings: _settings];
  DESTROY(_palette);
  [self refreshRuntimeDefaultsIfNeeded];
  if ([self shouldUseWindowIntegration])
    {
      WinUIThemeWindowIntegrationReloadTheme(self);
    }
  else
    {
      WinUIThemeWindowIntegrationDeactivate();
    }
}

- (void) systemSettingsDidChange
{
  [self reloadConfiguration];
  if ([GSTheme theme] == self)
    {
      /* NSColor keeps the palette it had at activation; this notification
         has it take the new one and recache every system colour. Window
         decorations, browsers and the interface style refresh too. */
      [[NSNotificationCenter defaultCenter]
        postNotificationName: GSThemeDidActivateNotification
                      object: self
                    userInfo: nil];
      if ([self shouldUseWindowIntegration])
        {
          WinUIThemeWindowIntegrationReloadTheme(self);
        }
    }
}

- (WinUIThemeSettings *) settings
{
  return _settings;
}

- (WinUIThemeMetrics *) metrics
{
  return _metrics;
}

- (void) activate
{
  [self reloadConfiguration];
  [self applyRuntimeDefaults];
  _runtimeDefaultsApplied = YES;
  [super activate];
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(windowNeedsMainMenu:)
                                               name: NSWindowDidBecomeKeyNotification
                                             object: nil];
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(windowNeedsMainMenu:)
                                               name: NSWindowDidBecomeMainNotification
                                             object: nil];
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(applicationDidFinishLaunching:)
                                               name: NSApplicationDidFinishLaunchingNotification
                                             object: nil];
  if ([self shouldUseWindowIntegration])
    {
      WinUIThemeWindowIntegrationActivate(self);
    }
  else
    {
      WinUIThemeWindowIntegrationDeactivate();
    }
}

- (void) deactivate
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  [center removeObserver: self name: NSWindowDidBecomeKeyNotification object: nil];
  [center removeObserver: self name: NSWindowDidBecomeMainNotification object: nil];
  [center removeObserver: self name: NSApplicationDidFinishLaunchingNotification object: nil];
  WinUIThemeWindowIntegrationDeactivate();
  [self removeRuntimeDefaults];
  _runtimeDefaultsApplied = NO;
  [super deactivate];
}

/* Once the app's own launch code has run (it may build its menus then). */
- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  [self performSelector: @selector(tidyMainMenu) withObject: nil afterDelay: 0.0];
}

/* With NSWindows95InterfaceStyle, GNUstep puts the main menu only into the
   windows that exist when the menu is first updated (-[NSMenu update] calls
   -updateAllWindowsWithMenu: once), so a window created after launch has no
   menu bar. Attach it when such a window becomes key or main. Windows given a
   menu of their own, and windows that can't become main (panels, menus), are
   left alone. */
- (void) windowNeedsMainMenu: (NSNotification *)notification
{
  NSWindow *window = [notification object];
  NSMenu *mainMenu = [NSApp mainMenu];

  [self tidyMainMenu];

  if (mainMenu == nil || [window isKindOfClass: [NSWindow class]] == NO)
    {
      return;
    }
  if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", nil) != NSWindows95InterfaceStyle)
    {
      return;
    }
  if ([window canBecomeMainWindow] == NO || [window menu] != nil)
    {
      return;
    }
  [self updateMenu: mainMenu forWindow: window];
}

- (NSColorList *) colors
{
  if (_palette == nil)
    {
      _palette = RETAIN([WinUIThemePalette colorListForSettings: _settings]);
    }
  return _palette;
}

- (NSColor *) colorNamed: (NSString *)aName
                   state: (GSThemeControlState)elementState
{
  NSColor *color = [super colorNamed: aName state: elementState];

  if (color == nil && [aName length] > 0)
    {
      color = [[self colors] colorWithKey: aName];
    }

  return color;
}

- (BOOL) menuShouldShowIcon
{
  return NO;
}

- (CGFloat) menuBarHeight
{
  return [_metrics menuBarHeight];
}

- (CGFloat) menuItemHeight
{
  return [_metrics menuItemHeight];
}

- (CGFloat) menuSeparatorHeight
{
  return [_metrics menuSeparatorHeight];
}

- (float) defaultScrollerWidth
{
  return [_metrics scrollerWidth];
}

- (CGFloat) tabHeightForType: (NSTabViewType)type
{
  CGFloat height = [super tabHeightForType: type];

  switch (type)
    {
      case NSTopTabsBezelBorder:
      case NSBottomTabsBezelBorder:
      case NSLeftTabsBezelBorder:
      case NSRightTabsBezelBorder:
        height = MAX(height, [_metrics minimumTabHeight]);
        break;

      default:
        break;
    }

  return height;
}

- (Class) openPanelClass
{
  return [WinUIThemeOpenPanel class];
}

- (Class) savePanelClass
{
  return [WinUIThemeSavePanel class];
}

- (Class) printPanelClass
{
  return [WinUIThemePrintPanel class];
}

- (Class) pageLayoutClass
{
  return [WinUIThemePageLayout class];
}

- (id<GSWindowDecorator>) windowDecorator
{
  if ([GSCurrentServer() handlesWindowDecorations])
    {
      return (id<GSWindowDecorator>)[WinUIThemeBackendWindowDecorationView class];
    }

  return (id<GSWindowDecorator>)[WinUIThemeStandardWindowDecorationView class];
}

- (void) addFont: (NSFont *)font
          forKey: (NSString *)key
     toDictionary: (NSMutableDictionary *)dictionary
{
  if (font == nil || key == nil || dictionary == nil)
    {
      return;
    }

  [dictionary setObject: [font fontName] forKey: key];
  [dictionary setObject: [NSNumber numberWithFloat: [font pointSize]]
                 forKey: [NSString stringWithFormat: @"%@Size", key]];
}

- (NSDictionary *) runtimeDefaultsDictionary
{
  NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
  NSFont *interfaceFont = [_settings interfaceFont];
  NSFont *menuFont = [_settings menuFont];
  NSFont *menuBarFont = [_settings menuBarFont];
  NSFont *fixedPitchFont = [_settings fixedPitchFont];
  CGFloat baseFontSize = [_settings interfaceFontSize];

  [self addFont: interfaceFont forKey: @"NSFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSUserFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSControlContentFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSLabelFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSMessageFont" toDictionary: dictionary];
  [self addFont: interfaceFont forKey: @"NSToolTipsFont" toDictionary: dictionary];
  /* Bold is WinUI's Semibold (#44): left unset, gui's bold system font
     wasn't Segoe at all. */
  [self addFont: [_settings semiboldInterfaceFontOfSize: [interfaceFont pointSize]]
         forKey: @"NSBoldFont"
   toDictionary: dictionary];
  [self addFont: menuFont forKey: @"NSMenuFont" toDictionary: dictionary];
  [self addFont: menuBarFont forKey: @"NSMenuBarFont" toDictionary: dictionary];
  [self addFont: fixedPitchFont forKey: @"NSUserFixedPitchFont" toDictionary: dictionary];

  [dictionary setObject: [NSNumber numberWithFloat: baseFontSize]
                 forKey: @"NSFontSize"];
  /* WinUI's Caption, 12px, and a size below it. */
  [dictionary setObject: [NSNumber numberWithFloat: MAX(9.0, baseFontSize - 2.0)]
                 forKey: @"NSSmallFontSize"];
  [dictionary setObject: [NSNumber numberWithFloat: MAX(8.0, baseFontSize - 3.0)]
                 forKey: @"NSMiniFontSize"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuBarHeight]]
                 forKey: @"GSMenuBarHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuItemHeight]]
                 forKey: @"GSMenuItemHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics menuSeparatorHeight]]
                 forKey: @"GSMenuSeparatorHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics scrollerWidth]]
                 forKey: @"GSScrollerDefaultWidth"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics minimumTabHeight]]
                 forKey: @"GSMinimumTabHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics maximumTabHeight]]
                 forKey: @"GSMaximumTabHeightPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics controlHeight]]
                 forKey: @"GSControlHeight"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics textFieldHeight]]
                 forKey: @"GSTextFieldHeightPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics popupControlHeight]]
                 forKey: @"GSPopupControlHeightPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics tableRowHeight]]
                 forKey: @"GSTableRowHeightPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics controlCornerRadius]]
                 forKey: @"GSControlCornerRadiusPrivate"];
  [dictionary setObject: [NSNumber numberWithFloat: [_metrics windowCornerRadius]]
                 forKey: @"GSWindowCornerRadiusPrivate"];

  return dictionary;
}

- (BOOL) shouldUseWindowIntegration
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id disabledValue = [defaults objectForKey: @"WinUIThemeDisableWindowIntegration"];

  return (disabledValue == nil || [disabledValue boolValue] == NO);
}

- (void) applyRuntimeDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *searchList = [[defaults searchList] mutableCopy];
  NSUInteger index = NSNotFound;

  [defaults setVolatileDomain: [self runtimeDefaultsDictionary]
                      forName: WinUIThemeRuntimeDefaultsDomain];

  if ([searchList containsObject: WinUIThemeRuntimeDefaultsDomain] == NO)
    {
      index = [searchList indexOfObject: @"GSThemeDomain"];
      if (index == NSNotFound)
        {
          index = [searchList indexOfObject: GSConfigDomain];
        }
      if (index == NSNotFound)
        {
          index = [searchList indexOfObject: NSRegistrationDomain];
        }
      if (index == NSNotFound)
        {
          index = [searchList count];
        }

      [searchList insertObject: WinUIThemeRuntimeDefaultsDomain atIndex: index];
      [defaults setSearchList: searchList];
    }

  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSUserDefaultsDidChangeNotification
                  object: defaults];
  RELEASE(searchList);
}

- (void) removeRuntimeDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *searchList = [[defaults searchList] mutableCopy];

  [searchList removeObject: WinUIThemeRuntimeDefaultsDomain];
  [defaults setSearchList: searchList];
  [defaults removeVolatileDomainForName: WinUIThemeRuntimeDefaultsDomain];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
    postNotificationName: NSUserDefaultsDidChangeNotification
                  object: defaults];

  RELEASE(searchList);
}

- (void) refreshRuntimeDefaultsIfNeeded
{
  if (_runtimeDefaultsApplied == NO)
    {
      return;
    }

  [self removeRuntimeDefaults];
  [self applyRuntimeDefaults];
}

@end
