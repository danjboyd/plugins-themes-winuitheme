/*
   Copyright (C) 2026 Daniel Boyd

   This file is part of the GNUstep WinUI theme.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <https://www.gnu.org/licenses/>.
*/

#import "WinUIThemeDrawing.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

/* The menu bar in a window, from the keyboard (#78) and when it's too
   narrow for its titles (#77).

   Keyboard: Alt pressed and released alone, or F10, selects the bar's first
   title and underlines each title's access key; Left and Right move along
   the bar, Down, Enter or the access key opens a menu, Up and Down move in
   it, Right opens a submenu and Left closes it, Enter picks an item, Esc
   closes a menu and then leaves the bar. Alt+letter opens the menu whose
   title starts with that letter, unless a menu item has Alt+letter as its
   key equivalent. GNUstep menus have no access keys, so a title's first
   letter is its access key, as most Windows apps choose.

   Overflow: the titles that don't fit fold into a "..." button at the
   bar's end (CommandBar's "See more"), whose menu holds them. Every
   window's bar shows the same main menu, so the menu is left as it is (key
   equivalents and validation keep working): a folded title gets an empty
   rect, which nothing draws or hits, and the overflow menu is a copy made
   each time it opens. From the Adwaita theme (its #25).

   libs-gui's menu tracking follows only the pointer, so a session of the
   theme's own runs the menus opened from the keyboard or the overflow
   button: it opens and highlights them with NSMenuView's own methods and
   takes the keys, presses and pointer moves -[NSApplication sendEvent:]
   gets while it lasts (WinUIThemeFocus.m calls in). It runs no event loop
   of its own. */

typedef struct
{
  NSInteger folded;   /* The first folded title, or NSNotFound. */
  NSRect overflow;    /* The overflow button; empty when nothing folds. */
} WinUIThemeMenuBarFold;

/* WinUI's AppBarButton is 40px wide in a CommandBar's compact row. */
static const CGFloat WinUIThemeOverflowButtonWidth = 40.0;

@interface NSMenu (WinUIThemeMenuBarKeyboardPrivate)
- (BOOL) _ownedByPopUp;
@end

static BOOL
WinUIThemeIsWindowMenuBar(NSMenuView *view)
{
  NSWindow *window = [view window];

  return (view != nil && [view isHorizontal] && window != nil
          && [window menu] == [view menu]
          && NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", view) == NSWindows95InterfaceStyle);
}

static WinUIThemeMenuBarFold
WinUIThemeMenuBarFolding(NSMenuView *bar)
{
  typedef NSRect (*RectIMP)(id, SEL, NSInteger);
  SEL selector = @selector(rectOfItemAtIndex:);
  RectIMP originalIMP = (RectIMP)WinUIThemeOriginalMethod(selector, bar, [NSMenuView class]);
  WinUIThemeMenuBarFold fold = { NSNotFound, NSZeroRect };
  NSInteger count = [[bar menu] numberOfItems];
  NSRect visible;
  NSRect first;
  CGFloat start;
  NSInteger index;

  if (originalIMP == NULL || count == 0 || WinUIThemeIsWindowMenuBar(bar) == NO)
    {
      return fold;
    }
  /* The window clips a bar wider than itself. */
  visible = [bar visibleRect];
  if (NSWidth(visible) <= 0.0)
    {
      return fold;
    }
  first = originalIMP(bar, selector, 0);
  if (NSMaxX(originalIMP(bar, selector, count - 1)) <= NSMaxX(visible))
    {
      return fold;
    }
  /* At the bar's end, as far in as the first title is. */
  start = MAX(NSMinX(first), NSMaxX(visible) - MAX(0.0, NSMinX(first)) - WinUIThemeOverflowButtonWidth);
  fold.overflow = NSMakeRect(start, NSMinY(first), WinUIThemeOverflowButtonWidth, NSHeight(first));
  for (index = 0; index < count; index++)
    {
      if (NSMaxX(originalIMP(bar, selector, index)) > NSMinX(fold.overflow))
        {
          fold.folded = index;
          break;
        }
    }
  return fold;
}

/* The bar's titles shown, then the overflow button when there is one:
   the session's index space. */
static NSInteger
WinUIThemeMenuBarShownCount(NSMenuView *bar, WinUIThemeMenuBarFold fold)
{
  return (fold.folded == NSNotFound) ? [[bar menu] numberOfItems] : fold.folded;
}

static NSInteger
WinUIThemeMenuBarStopCount(NSMenuView *bar, WinUIThemeMenuBarFold fold)
{
  return WinUIThemeMenuBarShownCount(bar, fold) + ((fold.folded == NSNotFound) ? 0 : 1);
}

/* The window's menu bar, if it has one. */
static NSMenuView *
WinUIThemeFindMenuBar(NSView *view, NSUInteger depth)
{
  NSEnumerator *enumerator = nil;
  NSView *subview = nil;

  if ([view isKindOfClass: [NSMenuView class]] && WinUIThemeIsWindowMenuBar((NSMenuView *)view))
    {
      return (NSMenuView *)view;
    }
  if (depth == 0)
    {
      return nil;
    }
  enumerator = [[view subviews] objectEnumerator];
  while ((subview = [enumerator nextObject]) != nil)
    {
      NSMenuView *found = WinUIThemeFindMenuBar(subview, depth - 1);

      if (found != nil)
        {
          return found;
        }
    }
  return nil;
}

static NSMenuView *
WinUIThemeMenuBarOfWindow(NSWindow *window)
{
  NSView *frameView = [[window contentView] superview];

  if (window == nil || [window menu] == nil || frameView == nil)
    {
      return nil;
    }
  return WinUIThemeFindMenuBar(frameView, 3);
}

/* A menu title's or item's access key: its first letter or digit,
   lowercased; 0 when it has none. */
static unichar
WinUIThemeAccessKey(NSString *title)
{
  NSCharacterSet *alphanumerics = [NSCharacterSet alphanumericCharacterSet];
  NSUInteger index;

  for (index = 0; index < [title length]; index++)
    {
      unichar c = [title characterAtIndex: index];

      if ([alphanumerics characterIsMember: c])
        {
          return [[[NSString stringWithCharacters: &c length: 1] lowercaseString] characterAtIndex: 0];
        }
    }
  return 0;
}

NSRange
WinUIThemeMenuAccessKeyRange(NSString *title)
{
  NSCharacterSet *alphanumerics = [NSCharacterSet alphanumericCharacterSet];
  NSUInteger index;

  for (index = 0; index < [title length]; index++)
    {
      if ([alphanumerics characterIsMember: [title characterAtIndex: index]])
        {
          return [title rangeOfComposedCharacterSequenceAtIndex: index];
        }
    }
  return NSMakeRange(NSNotFound, 0);
}

/* Whether a menu item in `menu` or its submenus has Alt+`key` as its key
   equivalent; the app's shortcut then wins over the access key. */
static BOOL
WinUIThemeMenuHasAltKeyEquivalent(NSMenu *menu, NSString *key)
{
  NSEnumerator *enumerator = [[menu itemArray] objectEnumerator];
  NSMenuItem *item = nil;
  NSUInteger modifiers = NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask;

  while ((item = [enumerator nextObject]) != nil)
    {
      if (([item keyEquivalentModifierMask] & modifiers) == NSAlternateKeyMask
          && [[item keyEquivalent] caseInsensitiveCompare: key] == NSOrderedSame)
        {
          return YES;
        }
      if ([item hasSubmenu] && WinUIThemeMenuHasAltKeyEquivalent([item submenu], key))
        {
          return YES;
        }
    }
  return NO;
}

static BOOL
WinUIThemeMenuItemIsStop(NSMenu *menu, NSInteger index)
{
  NSMenuItem *item = (NSMenuItem *)[menu itemAtIndex: index];

  return ([item isSeparatorItem] == NO && [[item title] length] > 0);
}

/* The session. */
static NSMenuView *WinUIThemeSessionBar = nil;
static BOOL WinUIThemeSessionAccessKeys = NO;
/* The selected title in the bar's stops (WinUIThemeMenuBarStopCount). */
static NSInteger WinUIThemeSessionIndex = -1;
/* The menus open, outermost first. */
static NSMutableArray *WinUIThemeSessionMenus = nil;
/* The overflow menu while it's open (also the first of the menus). */
static NSMenu *WinUIThemeSessionOverflow = nil;
static NSMenu *WinUIThemeOverflowHolder = nil;
/* The item a press in an open menu started on, picked by its release. */
static NSMenu *WinUIThemeSessionPressMenu = nil;
static NSInteger WinUIThemeSessionPressIndex = -1;
static BOOL WinUIThemeSessionBarTracksMoves = NO;

/* Alt down with nothing else pressed since; Alt down at all. */
static BOOL WinUIThemeAltAlone = NO;
static BOOL WinUIThemeAltHeld = NO;
static NSMenuView *WinUIThemeAltBar = nil;

static void WinUIThemeEndMenuBarSession(void);

@interface WinUIThemeMenuBarSessionObserver : NSObject
+ (void) windowWillLeave: (NSNotification *)notification;
@end

@implementation WinUIThemeMenuBarSessionObserver
+ (void) windowWillLeave: (NSNotification *)notification
{
  if ([notification object] == [WinUIThemeSessionBar window])
    {
      WinUIThemeEndMenuBarSession();
    }
}
@end

BOOL
WinUIThemeMenuAccessKeysVisible(void)
{
  return ((WinUIThemeSessionBar != nil && WinUIThemeSessionAccessKeys)
          || (WinUIThemeAltHeld && WinUIThemeAltBar != nil));
}

NSRect
WinUIThemeMenuBarOverflowRect(NSMenuView *bar)
{
  return WinUIThemeMenuBarFolding(bar).overflow;
}

BOOL
WinUIThemeMenuBarOverflowSelected(NSMenuView *bar)
{
  WinUIThemeMenuBarFold fold;

  if (bar == nil || bar != WinUIThemeSessionBar)
    {
      return NO;
    }
  fold = WinUIThemeMenuBarFolding(bar);
  return (fold.folded != NSNotFound
          && WinUIThemeSessionIndex == WinUIThemeMenuBarShownCount(bar, fold));
}

/* Closes the open menus from `level` in; the item whose submenu closed
   stays highlighted, and so does the bar's title. */
static void
WinUIThemeCloseSessionMenus(NSUInteger level)
{
  NSMenuView *bar = WinUIThemeSessionBar;

  if (level >= [WinUIThemeSessionMenus count])
    {
      return;
    }
  if (level > 0)
    {
      NSMenuView *parentView = [[WinUIThemeSessionMenus objectAtIndex: level - 1] menuRepresentation];
      NSInteger highlighted = [parentView highlightedItemIndex];

      [parentView detachSubmenu];
      [parentView setHighlightedItemIndex: highlighted];
    }
  else if (WinUIThemeSessionOverflow != nil)
    {
      [[WinUIThemeSessionOverflow menuRepresentation] detachSubmenu];
      [WinUIThemeSessionOverflow close];
      DESTROY(WinUIThemeSessionOverflow);
      [bar setNeedsDisplay: YES];
    }
  else
    {
      [bar detachSubmenu];
    }
  [WinUIThemeSessionMenus removeObjectsInRange:
    NSMakeRange(level, [WinUIThemeSessionMenus count] - level)];
  if (level == 0 && bar != nil)
    {
      WinUIThemeMenuBarFold fold = WinUIThemeMenuBarFolding(bar);

      [bar setHighlightedItemIndex: (WinUIThemeSessionIndex < WinUIThemeMenuBarShownCount(bar, fold))
                                     ? WinUIThemeSessionIndex : -1];
    }
}

static void
WinUIThemeEndMenuBarSession(void)
{
  NSMenuView *bar = WinUIThemeSessionBar;

  if (bar == nil)
    {
      return;
    }
  WinUIThemeCloseSessionMenus(0);
  [bar setHighlightedItemIndex: -1];
  if (WinUIThemeSessionBarTracksMoves == NO)
    {
      [[bar window] setAcceptsMouseMovedEvents: NO];
    }
  [[NSNotificationCenter defaultCenter] removeObserver: [WinUIThemeMenuBarSessionObserver class]];
  WinUIThemeSessionBar = nil;
  WinUIThemeSessionIndex = -1;
  WinUIThemeSessionPressMenu = nil;
  WinUIThemeSessionPressIndex = -1;
  WinUIThemeSessionAccessKeys = NO;
  [bar setNeedsDisplay: YES];
  RELEASE(bar);
}

static void
WinUIThemeBeginMenuBarSession(NSMenuView *bar, BOOL accessKeys)
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  NSWindow *window = [bar window];

  WinUIThemeEndMenuBarSession();
  if (WinUIThemeSessionMenus == nil)
    {
      WinUIThemeSessionMenus = [NSMutableArray new];
    }
  WinUIThemeSessionBar = RETAIN(bar);
  WinUIThemeSessionAccessKeys = accessKeys;
  WinUIThemeSessionIndex = -1;
  /* The pointer moving onto another title or item follows it. */
  WinUIThemeSessionBarTracksMoves = [window acceptsMouseMovedEvents];
  [window setAcceptsMouseMovedEvents: YES];
  [center addObserver: [WinUIThemeMenuBarSessionObserver class]
             selector: @selector(windowWillLeave:)
                 name: NSWindowDidResignKeyNotification
               object: window];
  [center addObserver: [WinUIThemeMenuBarSessionObserver class]
             selector: @selector(windowWillLeave:)
                 name: NSWindowWillCloseNotification
               object: window];
  [bar setNeedsDisplay: YES];
}

/* Highlights the first item after (or before) the highlighted one,
   wrapping, that isn't a separator. */
static void
WinUIThemeMoveInMenu(NSMenu *menu, NSInteger step)
{
  NSMenuView *view = [menu menuRepresentation];
  NSInteger count = [menu numberOfItems];
  NSInteger index = [view highlightedItemIndex];
  NSInteger tries;

  if (count == 0)
    {
      return;
    }
  if (index < 0)
    {
      index = (step > 0) ? -1 : count;
    }
  for (tries = 0; tries < count; tries++)
    {
      index = (index + step + count) % count;
      if (WinUIThemeMenuItemIsStop(menu, index))
        {
          [view setHighlightedItemIndex: index];
          return;
        }
    }
}

static void
WinUIThemeHighlightFirst(NSMenu *menu)
{
  [[menu menuRepresentation] setHighlightedItemIndex: -1];
  WinUIThemeMoveInMenu(menu, 1);
}

/* Selects the bar's stop `index` and, with `open`, opens its menu. */
static void
WinUIThemeSelectBarStop(NSInteger index, BOOL open, BOOL highlightFirst)
{
  NSMenuView *bar = WinUIThemeSessionBar;
  NSMenu *barMenu = [bar menu];
  WinUIThemeMenuBarFold fold = WinUIThemeMenuBarFolding(bar);
  NSInteger shown = WinUIThemeMenuBarShownCount(bar, fold);

  WinUIThemeCloseSessionMenus(0);
  WinUIThemeSessionIndex = index;
  if (index >= shown)
    {
      [bar setHighlightedItemIndex: -1];
      [bar setNeedsDisplayInRect: fold.overflow];
      if (open && fold.folded != NSNotFound)
        {
          NSMenu *overflow = [[NSMenu alloc] initWithTitle: @""];
          NSMenuView *overflowView = nil;
          NSWindow *overflowWindow = nil;
          NSRect button = [bar convertRect: fold.overflow toView: nil];
          NSPoint corner;
          NSRect frame;
          NSInteger item;

          for (item = fold.folded; item < [barMenu numberOfItems]; item++)
            {
              NSMenuItem *copy = [(NSMenuItem *)[barMenu itemAtIndex: item] copy];

              [overflow addItem: copy];
              RELEASE(copy);
            }
          WinUIThemeSessionOverflow = overflow;
          /* In Windows 95 style libs-gui shows no menu without a supermenu
             (it takes it for the main menu), so the copy gets one, never
             shown. */
          if (WinUIThemeOverflowHolder == nil)
            {
              WinUIThemeOverflowHolder = [[NSMenu alloc] initWithTitle: @""];
            }
          [overflow setSupermenu: WinUIThemeOverflowHolder];
          [overflow update];
          [overflow sizeToFit];
          overflowView = [overflow menuRepresentation];
          overflowWindow = [overflowView window];
          /* Under the button, right edges aligned, as CommandBar's. */
          corner = [[bar window] convertBaseToScreen: NSMakePoint(NSMaxX(button), NSMinY(button))];
          frame = [overflowWindow frame];
          [overflowWindow setFrameOrigin: NSMakePoint(corner.x - NSWidth(frame), corner.y - NSHeight(frame))];
          [overflowWindow setAcceptsMouseMovedEvents: YES];
          [overflowWindow orderFrontRegardless];
          [WinUIThemeSessionMenus addObject: overflow];
          if (highlightFirst)
            {
              WinUIThemeHighlightFirst(overflow);
            }
        }
      return;
    }

  [bar setHighlightedItemIndex: index];
  if (fold.folded != NSNotFound)
    {
      [bar setNeedsDisplayInRect: fold.overflow];
    }
  if (open && [(NSMenuItem *)[barMenu itemAtIndex: index] hasSubmenu])
    {
      NSMenu *submenu = [(NSMenuItem *)[barMenu itemAtIndex: index] submenu];

      [bar attachSubmenuForItemAtIndex: index];
      [[[submenu menuRepresentation] window] setAcceptsMouseMovedEvents: YES];
      [WinUIThemeSessionMenus addObject: submenu];
      if (highlightFirst)
        {
          WinUIThemeHighlightFirst(submenu);
        }
    }
}

/* Opens the submenu of item `index` in the open menu at `level`. */
static void
WinUIThemeOpenSessionSubmenu(NSUInteger level, NSInteger index, BOOL highlightFirst)
{
  NSMenu *menu = [WinUIThemeSessionMenus objectAtIndex: level];
  NSMenuView *view = [menu menuRepresentation];
  NSMenu *submenu = [(NSMenuItem *)[menu itemAtIndex: index] submenu];

  WinUIThemeCloseSessionMenus(level + 1);
  [view setHighlightedItemIndex: index];
  if (submenu == nil)
    {
      return;
    }
  [view attachSubmenuForItemAtIndex: index];
  [[[submenu menuRepresentation] window] setAcceptsMouseMovedEvents: YES];
  [WinUIThemeSessionMenus addObject: submenu];
  if (highlightFirst)
    {
      WinUIThemeHighlightFirst(submenu);
    }
}

/* Picks item `index` of the open menu at `level`: opens its submenu, or
   closes the menus and runs it. */
static void
WinUIThemeActivateSessionItem(NSUInteger level, NSInteger index, BOOL highlightFirst)
{
  NSMenu *menu = [WinUIThemeSessionMenus objectAtIndex: level];
  NSMenuItem *item = (NSMenuItem *)[menu itemAtIndex: index];

  if ([item hasSubmenu])
    {
      WinUIThemeOpenSessionSubmenu(level, index, highlightFirst);
      return;
    }
  if ([item isEnabled] == NO || WinUIThemeMenuItemIsStop(menu, index) == NO)
    {
      return;
    }
  RETAIN(menu);
  WinUIThemeEndMenuBarSession();
  [menu performActionForItemAtIndex: index];
  RELEASE(menu);
}

/* The stop whose title has access key `key`, or -1. A folded title's is
   the overflow button's, with the menu's index in it in `*folded`. */
static NSInteger
WinUIThemeBarStopForAccessKey(NSMenuView *bar, unichar key, NSInteger *foldedIndex)
{
  NSMenu *menu = [bar menu];
  WinUIThemeMenuBarFold fold = WinUIThemeMenuBarFolding(bar);
  NSInteger shown = WinUIThemeMenuBarShownCount(bar, fold);
  NSInteger count = [menu numberOfItems];
  NSInteger index;

  *foldedIndex = -1;
  for (index = 0; index < count; index++)
    {
      if (WinUIThemeMenuItemIsStop(menu, index)
          && WinUIThemeAccessKey([(NSMenuItem *)[menu itemAtIndex: index] title]) == key)
        {
          if (index < shown)
            {
              return index;
            }
          *foldedIndex = index - fold.folded;
          return shown;
        }
    }
  return -1;
}

/* Opens the bar's menu with access key `key`; NO when there's none. */
static BOOL
WinUIThemeOpenBarMenuForAccessKey(unichar key)
{
  NSInteger folded = -1;
  NSInteger stop = WinUIThemeBarStopForAccessKey(WinUIThemeSessionBar, key, &folded);

  if (stop < 0)
    {
      return NO;
    }
  WinUIThemeSelectBarStop(stop, YES, folded < 0);
  if (folded >= 0 && [WinUIThemeSessionMenus count] > 0)
    {
      WinUIThemeActivateSessionItem(0, folded, YES);
    }
  return YES;
}

/* A letter or digit in the open menu at `level`: the one item with that
   access key is picked; with several, the next is highlighted. */
static void
WinUIThemeAccessKeyInMenu(NSUInteger level, unichar key)
{
  NSMenu *menu = [WinUIThemeSessionMenus objectAtIndex: level];
  NSMenuView *view = [menu menuRepresentation];
  NSInteger count = [menu numberOfItems];
  NSInteger highlighted = [view highlightedItemIndex];
  NSInteger matches = 0;
  NSInteger firstMatch = -1;
  NSInteger nextMatch = -1;
  NSInteger index;

  for (index = 0; index < count; index++)
    {
      if (WinUIThemeMenuItemIsStop(menu, index)
          && WinUIThemeAccessKey([(NSMenuItem *)[menu itemAtIndex: index] title]) == key)
        {
          matches++;
          if (firstMatch < 0)
            {
              firstMatch = index;
            }
          if (nextMatch < 0 && index > highlighted)
            {
              nextMatch = index;
            }
        }
    }
  if (matches == 1)
    {
      WinUIThemeActivateSessionItem(level, firstMatch, YES);
    }
  else if (matches > 1)
    {
      WinUIThemeCloseSessionMenus(level + 1);
      [view setHighlightedItemIndex: (nextMatch >= 0) ? nextMatch : firstMatch];
    }
}

static unichar
WinUIThemeEventKey(NSEvent *event)
{
  NSString *characters = [event charactersIgnoringModifiers];

  return ([characters length] > 0) ? [characters characterAtIndex: 0] : 0;
}

static NSUInteger
WinUIThemeEventModifiers(NSEvent *event)
{
  return [event modifierFlags]
    & (NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask);
}

static BOOL
WinUIThemeKeyIsAccessKey(unichar key)
{
  return (key < 0xF700 && key > ' '
          && [[NSCharacterSet alphanumericCharacterSet] characterIsMember: key]);
}

static unichar
WinUIThemeLowercaseKey(unichar key)
{
  return [[[NSString stringWithCharacters: &key length: 1] lowercaseString] characterAtIndex: 0];
}

/* A key while the session runs. */
static void
WinUIThemeMenuSessionKey(NSEvent *event)
{
  unichar key = WinUIThemeEventKey(event);
  NSUInteger modifiers = WinUIThemeEventModifiers(event);
  NSMenuView *bar = WinUIThemeSessionBar;
  WinUIThemeMenuBarFold fold = WinUIThemeMenuBarFolding(bar);
  NSInteger stops = WinUIThemeMenuBarStopCount(bar, fold);
  NSInteger level = (NSInteger)[WinUIThemeSessionMenus count] - 1;
  NSMenu *innermost = (level >= 0) ? [WinUIThemeSessionMenus objectAtIndex: level] : nil;
  NSInteger highlighted = [[innermost menuRepresentation] highlightedItemIndex];

  switch (key)
    {
      case 0x1b:
        if (level >= 0)
          {
            WinUIThemeCloseSessionMenus(level);
          }
        else
          {
            WinUIThemeEndMenuBarSession();
          }
        return;
      case NSF10FunctionKey:
        WinUIThemeEndMenuBarSession();
        return;
      case NSLeftArrowFunctionKey:
        if (level >= 1)
          {
            WinUIThemeCloseSessionMenus(level);
          }
        else if (stops > 0)
          {
            WinUIThemeSelectBarStop((WinUIThemeSessionIndex - 1 + stops) % stops, level == 0, YES);
          }
        return;
      case NSRightArrowFunctionKey:
        if (level >= 0 && highlighted >= 0
            && [(NSMenuItem *)[innermost itemAtIndex: highlighted] hasSubmenu])
          {
            WinUIThemeOpenSessionSubmenu(level, highlighted, YES);
          }
        else if (stops > 0)
          {
            WinUIThemeSelectBarStop((WinUIThemeSessionIndex + 1) % stops, level >= 0, YES);
          }
        return;
      case NSDownArrowFunctionKey:
      case NSUpArrowFunctionKey:
        if (level < 0)
          {
            WinUIThemeSelectBarStop(WinUIThemeSessionIndex, YES, YES);
            if (key == NSUpArrowFunctionKey && [WinUIThemeSessionMenus count] > 0)
              {
                NSMenu *opened = [WinUIThemeSessionMenus objectAtIndex: 0];

                [[opened menuRepresentation] setHighlightedItemIndex: -1];
                WinUIThemeMoveInMenu(opened, -1);
              }
          }
        else
          {
            WinUIThemeCloseSessionMenus(level + 1);
            WinUIThemeMoveInMenu(innermost, (key == NSDownArrowFunctionKey) ? 1 : -1);
          }
        return;
      case '\r':
      case '\n':
      case 0x03:
      case ' ':
        if (level < 0)
          {
            WinUIThemeSelectBarStop(WinUIThemeSessionIndex, YES, YES);
          }
        else if (highlighted >= 0)
          {
            WinUIThemeActivateSessionItem(level, highlighted, YES);
          }
        return;
      default:
        break;
    }

  if (WinUIThemeKeyIsAccessKey(key) == NO)
    {
      return;
    }
  key = WinUIThemeLowercaseKey(key);
  /* Alt+letter goes to the bar, as does a letter with no menu open. */
  if (level < 0 || (modifiers & NSAlternateKeyMask))
    {
      WinUIThemeOpenBarMenuForAccessKey(key);
    }
  else if ((modifiers & (NSControlKeyMask | NSCommandKeyMask)) == 0)
    {
      WinUIThemeAccessKeyInMenu(level, key);
    }
}

/* The level of the open menu shown in `window`, or -1. */
static NSInteger
WinUIThemeSessionLevelOfWindow(NSWindow *window)
{
  NSUInteger level;

  for (level = 0; window != nil && level < [WinUIThemeSessionMenus count]; level++)
    {
      if ([[[WinUIThemeSessionMenus objectAtIndex: level] menuRepresentation] window] == window)
        {
          return (NSInteger)level;
        }
    }
  return -1;
}

static NSInteger
WinUIThemeItemIndexForEvent(NSMenu *menu, NSEvent *event)
{
  NSMenuView *view = [menu menuRepresentation];

  return [view indexOfItemAtPoint: [view convertPoint: [event locationInWindow] fromView: nil]];
}

/* The bar's stop under an event in the bar's window, or -1. */
static NSInteger
WinUIThemeBarStopForEvent(NSEvent *event)
{
  NSMenuView *bar = WinUIThemeSessionBar;
  WinUIThemeMenuBarFold fold = WinUIThemeMenuBarFolding(bar);
  NSPoint point = [bar convertPoint: [event locationInWindow] fromView: nil];
  NSInteger index;

  if ([event window] != [bar window] || NSPointInRect(point, [bar bounds]) == NO)
    {
      return -1;
    }
  if (NSPointInRect(point, fold.overflow))
    {
      return WinUIThemeMenuBarShownCount(bar, fold);
    }
  index = [bar indexOfItemAtPoint: point];
  return (index >= 0 && index < WinUIThemeMenuBarShownCount(bar, fold)) ? index : -1;
}

static BOOL
WinUIThemeMenuSessionPointer(NSEvent *event)
{
  NSEventType type = [event type];
  NSWindow *window = [event window];
  NSInteger level = WinUIThemeSessionLevelOfWindow(window);
  NSInteger stop = WinUIThemeBarStopForEvent(event);
  BOOL menuOpen = ([WinUIThemeSessionMenus count] > 0);

  switch (type)
    {
      case NSLeftMouseDown:
      case NSRightMouseDown:
      case NSOtherMouseDown:
        WinUIThemeSessionPressMenu = nil;
        WinUIThemeSessionPressIndex = -1;
        if (level >= 0)
          {
            NSMenu *menu = [WinUIThemeSessionMenus objectAtIndex: level];
            NSInteger index = WinUIThemeItemIndexForEvent(menu, event);

            if (index >= 0)
              {
                WinUIThemeSessionPressMenu = menu;
                WinUIThemeSessionPressIndex = index;
                if ([(NSMenuItem *)[menu itemAtIndex: index] hasSubmenu])
                  {
                    WinUIThemeOpenSessionSubmenu(level, index, NO);
                  }
                else
                  {
                    WinUIThemeCloseSessionMenus(level + 1);
                    [[menu menuRepresentation] setHighlightedItemIndex: index];
                  }
              }
            return YES;
          }
        if (stop >= 0)
          {
            if (menuOpen && stop == WinUIThemeSessionIndex)
              {
                WinUIThemeEndMenuBarSession();
              }
            else
              {
                WinUIThemeSelectBarStop(stop, YES, NO);
              }
            return YES;
          }
        /* A press elsewhere closes the menus and goes nowhere else, as a
           press outside menus libs-gui tracks does (WinUIThemeMenuTracking.m);
           with only the bar selected it goes on to its view. */
        WinUIThemeEndMenuBarSession();
        return menuOpen;

      case NSLeftMouseUp:
      case NSRightMouseUp:
      case NSOtherMouseUp:
        if (WinUIThemeSessionPressMenu != nil && level >= 0
            && [WinUIThemeSessionMenus objectAtIndex: level] == WinUIThemeSessionPressMenu
            && WinUIThemeItemIndexForEvent(WinUIThemeSessionPressMenu, event) == WinUIThemeSessionPressIndex)
          {
            NSInteger index = WinUIThemeSessionPressIndex;

            WinUIThemeSessionPressMenu = nil;
            WinUIThemeSessionPressIndex = -1;
            if ([(NSMenuItem *)[[WinUIThemeSessionMenus objectAtIndex: level] itemAtIndex: index] hasSubmenu] == NO)
              {
                WinUIThemeActivateSessionItem(level, index, NO);
              }
          }
        return YES;

      case NSMouseMoved:
      case NSLeftMouseDragged:
        if (level >= 0)
          {
            NSMenu *menu = [WinUIThemeSessionMenus objectAtIndex: level];
            NSInteger index = WinUIThemeItemIndexForEvent(menu, event);

            if (index >= 0 && index != [[menu menuRepresentation] highlightedItemIndex])
              {
                if ([(NSMenuItem *)[menu itemAtIndex: index] hasSubmenu])
                  {
                    WinUIThemeOpenSessionSubmenu(level, index, NO);
                  }
                else
                  {
                    WinUIThemeCloseSessionMenus(level + 1);
                    [[menu menuRepresentation] setHighlightedItemIndex: index];
                  }
              }
            return YES;
          }
        if (menuOpen && stop >= 0 && stop != WinUIThemeSessionIndex)
          {
            WinUIThemeSelectBarStop(stop, YES, NO);
            return YES;
          }
        return NO;

      default:
        return NO;
    }
}

/* Alt, F10 and Alt+letter with no session. */
static BOOL
WinUIThemeMenuBarIdleEvent(NSEvent *event)
{
  NSEventType type = [event type];
  NSUInteger modifiers = WinUIThemeEventModifiers(event);
  NSMenuView *bar = nil;

  if (type == NSFlagsChanged)
    {
      BOOL alt = ((modifiers & NSAlternateKeyMask) != 0);

      if (alt && modifiers == NSAlternateKeyMask)
        {
          if (WinUIThemeAltHeld == NO)
            {
              WinUIThemeAltHeld = YES;
              WinUIThemeAltAlone = YES;
              ASSIGN(WinUIThemeAltBar, WinUIThemeMenuBarOfWindow([NSApp keyWindow]));
              [WinUIThemeAltBar setNeedsDisplay: YES];
            }
        }
      else
        {
          BOOL enter = (alt == NO && WinUIThemeAltHeld && WinUIThemeAltAlone);

          if (alt == NO || modifiers != NSAlternateKeyMask)
            {
              WinUIThemeAltAlone = NO;
            }
          if (alt == NO)
            {
              WinUIThemeAltHeld = NO;
              [WinUIThemeAltBar setNeedsDisplay: YES];
              bar = AUTORELEASE(RETAIN(WinUIThemeAltBar));
              DESTROY(WinUIThemeAltBar);
              if (enter && bar != nil && bar == WinUIThemeMenuBarOfWindow([NSApp keyWindow]))
                {
                  WinUIThemeBeginMenuBarSession(bar, YES);
                  WinUIThemeSelectBarStop(0, NO, NO);
                }
            }
        }
      return NO;
    }
  if (type != NSKeyDown)
    {
      if (type == NSLeftMouseDown || type == NSRightMouseDown || type == NSOtherMouseDown)
        {
          WinUIThemeAltAlone = NO;
        }
      return NO;
    }

  WinUIThemeAltAlone = NO;
  bar = WinUIThemeMenuBarOfWindow([NSApp keyWindow]);
  if (bar == nil)
    {
      return NO;
    }
  if (WinUIThemeEventKey(event) == NSF10FunctionKey && modifiers == 0)
    {
      WinUIThemeBeginMenuBarSession(bar, YES);
      WinUIThemeSelectBarStop(0, NO, NO);
      return YES;
    }
  if (modifiers == NSAlternateKeyMask && WinUIThemeKeyIsAccessKey(WinUIThemeEventKey(event)))
    {
      unichar key = WinUIThemeLowercaseKey(WinUIThemeEventKey(event));
      NSInteger folded = -1;

      if (WinUIThemeMenuHasAltKeyEquivalent([bar menu], [NSString stringWithCharacters: &key length: 1])
          || WinUIThemeBarStopForAccessKey(bar, key, &folded) < 0)
        {
          return NO;
        }
      WinUIThemeBeginMenuBarSession(bar, YES);
      WinUIThemeOpenBarMenuForAccessKey(key);
      return YES;
    }
  return NO;
}

BOOL
WinUIThemeMenuBarHandleEvent(NSEvent *event)
{
  NSEventType type = [event type];

  if (WinUIThemeSessionBar == nil)
    {
      return WinUIThemeMenuBarIdleEvent(event);
    }
  if ([[WinUIThemeSessionBar window] isKeyWindow] == NO
      || [WinUIThemeSessionBar window] == nil)
    {
      WinUIThemeEndMenuBarSession();
      return WinUIThemeMenuBarIdleEvent(event);
    }

  switch (type)
    {
      case NSKeyDown:
        WinUIThemeAltAlone = NO;
        WinUIThemeMenuSessionKey(event);
        return YES;
      case NSKeyUp:
        return YES;
      case NSFlagsChanged:
        {
          NSUInteger modifiers = WinUIThemeEventModifiers(event);

          /* Alt pressed and released alone again leaves the bar. */
          if (modifiers == NSAlternateKeyMask)
            {
              WinUIThemeAltAlone = (WinUIThemeAltHeld == NO);
              WinUIThemeAltHeld = YES;
            }
          else
            {
              BOOL leave = (modifiers == 0 && WinUIThemeAltHeld && WinUIThemeAltAlone);

              WinUIThemeAltHeld = ((modifiers & NSAlternateKeyMask) != 0);
              WinUIThemeAltAlone = NO;
              if (WinUIThemeAltHeld == NO)
                {
                  DESTROY(WinUIThemeAltBar);
                }
              if (leave)
                {
                  WinUIThemeEndMenuBarSession();
                }
            }
          return YES;
        }
      default:
        return WinUIThemeMenuSessionPointer(event);
    }
}

/* For QuirkProbe: the overflow button, and whether this bar has the
   session with the menus it has open, outermost first (nil when it has
   none). */
@interface NSMenuView (WinUIThemeMenuBarProbe)
- (NSRect) winUIThemeOverflowRect;
- (NSArray *) winUIThemeSessionMenus;
@end

@implementation NSMenuView (WinUIThemeMenuBarProbe)
- (NSRect) winUIThemeOverflowRect
{
  return WinUIThemeMenuBarFolding(self).overflow;
}

- (NSArray *) winUIThemeSessionMenus
{
  return (WinUIThemeSessionBar == self) ? [NSArray arrayWithArray: WinUIThemeSessionMenus] : nil;
}
@end

/* A press on the overflow button opens its menu; NO for a press
   elsewhere. */
static BOOL
WinUIThemeMenuBarOverflowMouseDown(NSMenuView *bar, NSEvent *event)
{
  WinUIThemeMenuBarFold fold = WinUIThemeMenuBarFolding(bar);
  NSPoint point = [bar convertPoint: [event locationInWindow] fromView: nil];

  if (NSIsEmptyRect(fold.overflow) || NSPointInRect(point, fold.overflow) == NO)
    {
      return NO;
    }
  WinUIThemeBeginMenuBarSession(bar, NO);
  WinUIThemeSelectBarStop(WinUIThemeMenuBarShownCount(bar, fold), YES, NO);
  return YES;
}

@implementation WinUITheme (MenuBarKeyboard)

/* A folded title has no size, past the bar's end, so nothing draws or
   hits it. */
- (NSRect) _overrideNSMenuViewMethod_rectOfItemAtIndex: (NSInteger)index
{
  typedef NSRect (*RectIMP)(id, SEL, NSInteger);
  RectIMP originalIMP = (RectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuView class]);
  NSMenuView *menuView = (NSMenuView *)self;
  NSRect rect = (originalIMP != NULL) ? originalIMP(self, _cmd, index) : NSZeroRect;
  WinUIThemeMenuBarFold fold;

  if ([menuView isHorizontal] == NO)
    {
      return rect;
    }
  fold = WinUIThemeMenuBarFolding(menuView);
  if (fold.folded != NSNotFound && index >= fold.folded)
    {
      return NSMakeRect(NSMaxX([menuView bounds]), NSMinY(rect), 0.0, 0.0);
    }
  return rect;
}

- (void) _overrideNSMenuViewMethod_mouseDown: (NSEvent *)event
{
  typedef void (*MouseDownIMP)(id, SEL, NSEvent *);
  MouseDownIMP originalIMP = (MouseDownIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuView class]);

  if ([(NSMenuView *)self isHorizontal]
      && WinUIThemeMenuBarOverflowMouseDown((NSMenuView *)self, event))
    {
      return;
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, event);
    }
}

@end
