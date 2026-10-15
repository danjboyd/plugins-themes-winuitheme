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

#import "WinUIThemeToolbarInMenuBar.h"
#import "WinUIThemeWindowIntegration.h"
#import "../WinUITheme.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <GNUstepGUI/GSToolbarView.h>
#import <objc/runtime.h>

/* Single-row chrome (#91). A window with Windows-style menus and a
   toolbar has the title bar, the menu bar and the toolbar's 48pt row;
   Notepad and Paint have the title bar and one row, the menus at its
   start and the commands after them. With GSThemeToolbarInMenuBar the
   toolbar goes in the menu bar's row:

   - the menu titles keep the room they need, the toolbar takes the rest
     of the row, so a flexible space puts the items after it at the
     row's end;
   - its items are icon-only buttons at the row's height (32pt), as a
     CommandBar's compact AppBarButtons, their labels tool tips
     (WinUIThemeToolbar.m); a label-only toolbar keeps its text buttons;
   - with too little room the toolbar's items fold into libs-gui's ">>"
     first; the menus fold into their "..." (#77) only once the toolbar
     is down to that;
   - the content takes the toolbar's row back. A toolbar moving into or
     out of the row keeps the content's size, as libs-gui does when a
     toolbar is shown or hidden; a change of the default keeps the
     window's frame instead, as Adwaita's header-bar toolbar does;
   - a window without a menu bar (a panel) keeps the toolbar row, and a
     hidden toolbar leaves the menu bar alone. */

@interface NSToolbar (WinUIThemeToolbarInMenuBarPrivate)
- (GSToolbarView *) _toolbarView;
@end

@interface GSToolbarView (WinUIThemeToolbarInMenuBarPrivate)
- (void) _reload;
- (CGFloat) _heightFromLayout;
@end

@interface NSToolbarItem (WinUIThemeToolbarInMenuBarPrivate)
- (void) _layout;
@end

@interface GSWindowDecorationView (WinUIThemeToolbarInMenuBarPrivate)
- (void) addToolbarView: (GSToolbarView *)toolbarView;
- (void) removeToolbarView: (GSToolbarView *)toolbarView;
@end

/* On a decoration view: YES while its toolbar is in its menu bar's row.
   On a toolbar view: YES while its items are laid out for one. */
static char WinUIThemeHoldsToolbarKey;
static char WinUIThemeLaidOutInMenuBarKey;

/* The least the toolbar keeps beside the menus: one 32pt button and
   libs-gui's 28pt ">>" for the rest. */
static const CGFloat WinUIThemeToolbarInMenuBarMinWidth = 60.0;
/* Between the last menu title and the first command. */
static const CGFloat WinUIThemeToolbarInMenuBarGap = 4.0;
/* After the last command, before the window's edge: the menu bar's own
   inset before its first title, about. */
static const CGFloat WinUIThemeToolbarInMenuBarEndInset = 4.0;

/* NO while the theme isn't active: a theme switch puts toolbars back in
   rows of their own. */
static BOOL WinUIThemeToolbarInMenuBarActive = YES;

/* The key's value in one domain, or nil when it has none. */
static id
WinUIThemeToolbarInMenuBarValue(NSDictionary *values)
{
  id value = [values objectForKey: @"GSThemeToolbarInMenuBar"];

  return [value respondsToSelector: @selector(boolValue)] ? value : nil;
}

/* Asked in order: the user for this app (-GSThemeToolbarInMenuBar on
   the command line, then the app's own defaults); the app, when its
   Info.plist says NO; the user for all apps (NSGlobalDomain); the app's
   Info.plist; registered defaults. Other domains (GlobalDefaults, a
   theme's) aren't asked. Off otherwise: the toolbar has to suit the row
   (a few icons). As the Adwaita theme reads its
   GnomeThemeHeaderBarToolbar. */
BOOL
WinUIThemeToolbarInMenuBarEnabled(void)
{
  static BOOL declaredRead = NO;
  static id declared = nil;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id value = nil;

  if (WinUIThemeToolbarInMenuBarActive == NO)
    {
      return NO;
    }
  if (declaredRead == NO)
    {
      declared = RETAIN(WinUIThemeToolbarInMenuBarValue([[NSBundle mainBundle] infoDictionary]));
      declaredRead = YES;
    }
  value = WinUIThemeToolbarInMenuBarValue([defaults volatileDomainForName: NSArgumentDomain]);
  if (value == nil)
    {
      value = WinUIThemeToolbarInMenuBarValue(
        [defaults persistentDomainForName: [[NSProcessInfo processInfo] processName]]);
    }
  if (value != nil)
    {
      return [value boolValue];
    }
  if (declared != nil && [declared boolValue] == NO)
    {
      return NO;
    }
  value = WinUIThemeToolbarInMenuBarValue([defaults persistentDomainForName: NSGlobalDomain]);
  if (value != nil)
    {
      return [value boolValue];
    }
  if (declared != nil)
    {
      return YES;
    }
  value = WinUIThemeToolbarInMenuBarValue([defaults volatileDomainForName: NSRegistrationDomain]);
  return [value boolValue];
}

static BOOL
WinUIThemeDecorationHoldsToolbar(NSView *decoration)
{
  return decoration != nil
    && objc_getAssociatedObject(decoration, &WinUIThemeHoldsToolbarKey) != nil;
}

static void
WinUIThemeDecorationSetHoldsToolbar(NSView *decoration, BOOL holds)
{
  objc_setAssociatedObject(decoration, &WinUIThemeHoldsToolbarKey,
                           holds ? [NSNumber numberWithBool: YES] : nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

BOOL
WinUIThemeToolbarIsInMenuBar(NSToolbar *toolbar)
{
  NSView *toolbarView = nil;
  NSView *decoration = nil;

  if (toolbar == nil || [toolbar respondsToSelector: @selector(_toolbarView)] == NO)
    {
      return NO;
    }
  toolbarView = [toolbar _toolbarView];
  decoration = [toolbarView superview];
  return [decoration isKindOfClass: [GSWindowDecorationView class]]
    && WinUIThemeDecorationHoldsToolbar(decoration);
}

/* Lays every item out again, then the row: libs-gui lays an item out
   only when it's new or changed, and in the menu bar's row its button
   has no label and another size. */
static void
WinUIThemeToolbarViewRelayout(GSToolbarView *toolbarView)
{
  NSEnumerator *enumerator = [[[toolbarView toolbar] items] objectEnumerator];
  NSToolbarItem *item = nil;

  while ((item = [enumerator nextObject]) != nil)
    {
      if ([item respondsToSelector: @selector(_layout)])
        {
          [item _layout];
        }
    }
  [toolbarView _reload];
}

/* The toolbar laid out for the menu bar's row or a row of its own: its
   frame line (none in the menu bar's row, libs-gui's bottom line in its
   own, as libs-gui sets it from -showsBaselineSeparator), and its items
   laid out again when they move from one to the other. A toolbar that
   was never in the menu bar's row is left as libs-gui has it. */
static void
WinUIThemeToolbarViewSetInMenuBar(GSToolbarView *toolbarView, BOOL inBar)
{
  BOOL laidOutInBar = (objc_getAssociatedObject(toolbarView, &WinUIThemeLaidOutInMenuBarKey) != nil);
  unsigned int mask = 0;

  if (laidOutInBar == inBar)
    {
      /* The app may have asked for a baseline since (-setShowsBaselineSeparator:):
         none in the menu bar's row. */
      if (inBar && [toolbarView borderMask] != 0)
        {
          [toolbarView setBorderMask: 0];
          [toolbarView _reload];
        }
      return;
    }
  objc_setAssociatedObject(toolbarView, &WinUIThemeLaidOutInMenuBarKey,
                           inBar ? [NSNumber numberWithBool: YES] : nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if (inBar == NO && [[toolbarView toolbar] showsBaselineSeparator])
    {
      mask = GSToolbarViewBottomBorder;
    }
  if ([toolbarView borderMask] != mask)
    {
      [toolbarView setBorderMask: mask];
    }
  WinUIThemeToolbarViewRelayout(toolbarView);
}

static NSMenuView *
WinUIThemeDecorationMenuView(NSView *decoration)
{
  NSEnumerator *enumerator = [[decoration subviews] objectEnumerator];
  NSView *subview = nil;

  while ((subview = [enumerator nextObject]) != nil)
    {
      if ([subview isKindOfClass: [NSMenuView class]])
        {
          return (NSMenuView *)subview;
        }
    }
  return nil;
}

/* The width the menu titles need, from the bar's start: the last title's
   end as libs-gui lays the titles out, before the theme folds any. */
static CGFloat
WinUIThemeMenuTitlesWidth(NSMenuView *menuView)
{
  typedef NSRect (*RectIMP)(id, SEL, NSInteger);
  SEL selector = @selector(rectOfItemAtIndex:);
  RectIMP rectIMP = (RectIMP)WinUIThemeOriginalMethod(selector, menuView, [NSMenuView class]);
  NSInteger count = [[menuView menu] numberOfItems];

  if (count == 0)
    {
      return 0.0;
    }
  if (rectIMP == NULL)
    {
      rectIMP = (RectIMP)[menuView methodForSelector: selector];
    }
  return ceil(NSMaxX(rectIMP(menuView, selector, count - 1)));
}

/* Shares the menu bar's row out: the menu titles, then the toolbar. */
static void
WinUIThemeLayoutToolbarInMenuBar(GSWindowDecorationView *decoration, NSWindow *window)
{
  GSToolbarView *toolbarView = [[window toolbar] _toolbarView];
  NSMenuView *menuView = WinUIThemeDecorationMenuView(decoration);
  NSRect row;
  CGFloat menusWidth;
  CGFloat toolbarWidth;

  if (toolbarView == nil || menuView == nil || [toolbarView superview] != decoration)
    {
      return;
    }
  row = [menuView frame];
  /* The full row: libs-gui's -layout gave the bar all of it. */
  menusWidth = WinUIThemeMenuTitlesWidth(menuView);
  if (menusWidth > 0.0)
    {
      menusWidth += WinUIThemeToolbarInMenuBarGap;
    }
  toolbarWidth = MAX(NSWidth(row) - menusWidth - WinUIThemeToolbarInMenuBarEndInset,
                     MIN(NSWidth(row), WinUIThemeToolbarInMenuBarMinWidth));
  menusWidth = MAX(0.0, NSWidth(row) - toolbarWidth - WinUIThemeToolbarInMenuBarEndInset);
  [menuView setFrame: NSMakeRect(NSMinX(row), NSMinY(row), menusWidth, NSHeight(row))];
  WinUIThemeToolbarViewSetInMenuBar(toolbarView, YES);
  if (NSWidth([toolbarView frame]) != toolbarWidth || NSHeight([toolbarView frame]) != NSHeight(row))
    {
      /* libs-gui lays the items out again for a new size. */
      [toolbarView setFrameSize: NSMakeSize(toolbarWidth, NSHeight(row))];
      [toolbarView _reload];
    }
  [toolbarView setFrame: NSMakeRect(NSMinX(row) + menusWidth, NSMinY(row), toolbarWidth, NSHeight(row))];
  [menuView setNeedsDisplay: YES];
  [toolbarView setNeedsDisplay: YES];
}

@implementation GSWindowDecorationView (WinUIThemeToolbarInMenuBar)

- (BOOL) winUIThemeHoldsToolbarInMenuBar
{
  return WinUIThemeDecorationHoldsToolbar(self)
    && [[window toolbar] _toolbarView] != nil
    && [[[window toolbar] _toolbarView] superview] == self;
}

- (BOOL) winUIThemeAddToolbarViewToMenuBar: (GSToolbarView *)toolbarView
{
  if (hasMenu == NO || WinUIThemeToolbarInMenuBarEnabled() == NO)
    {
      WinUIThemeDecorationSetHoldsToolbar(self, NO);
      WinUIThemeToolbarViewSetInMenuBar(toolbarView, NO);
      return NO;
    }
  WinUIThemeDecorationSetHoldsToolbar(self, YES);
  hasToolbar = YES;
  [self addSubview: toolbarView];
  WinUIThemeToolbarViewSetInMenuBar(toolbarView, YES);
  [self layout];
  [self setNeedsDisplay: YES];
  return YES;
}

- (BOOL) winUIThemeRemoveToolbarViewFromMenuBar: (GSToolbarView *)toolbarView
{
  if (WinUIThemeDecorationHoldsToolbar(self) == NO || [toolbarView superview] != self)
    {
      return NO;
    }
  WinUIThemeDecorationSetHoldsToolbar(self, NO);
  hasToolbar = NO;
  [toolbarView removeFromSuperviewWithoutNeedingDisplay];
  [self layout];
  [self setNeedsDisplay: YES];
  return YES;
}

- (BOOL) winUIThemeAdjustToolbarViewInMenuBar: (GSToolbarView *)toolbarView
{
  if ([self winUIThemeHoldsToolbarInMenuBar] == NO)
    {
      return NO;
    }
  [self layout];
  return YES;
}

- (void) winUIThemeMenuViewAdded
{
  GSToolbarView *toolbarView = [[window toolbar] _toolbarView];
  CGFloat rowHeight;

  if (hasMenu == NO || hasToolbar == NO || WinUIThemeDecorationHoldsToolbar(self)
      || toolbarView == nil || [toolbarView superview] != self
      || WinUIThemeToolbarInMenuBarEnabled() == NO)
    {
      return;
    }
  rowHeight = NSHeight([toolbarView frame]);
  WinUIThemeDecorationSetHoldsToolbar(self, YES);
  WinUIThemeToolbarViewSetInMenuBar(toolbarView, YES);
  /* The content keeps its size: the window gives up the toolbar's row. */
  [self changeWindowHeight: -rowHeight];
  [self setNeedsDisplay: YES];
}

- (BOOL) winUIThemeMenuViewWillBeRemoved
{
  GSToolbarView *toolbarView = [[window toolbar] _toolbarView];

  if ([self winUIThemeHoldsToolbarInMenuBar] == NO)
    {
      return NO;
    }
  WinUIThemeDecorationSetHoldsToolbar(self, NO);
  WinUIThemeToolbarViewSetInMenuBar(toolbarView, NO);
  return YES;
}

- (void) winUIThemeMenuViewRemoved: (BOOL)heldToolbar
{
  GSToolbarView *toolbarView = [[window toolbar] _toolbarView];

  if (heldToolbar == NO || toolbarView == nil || [toolbarView superview] != self)
    {
      return;
    }
  /* The toolbar has its row again: the window grows by it. */
  [self changeWindowHeight: [toolbarView _heightFromLayout]];
}

- (BOOL) winUIThemeBeginLayout
{
  if ([self winUIThemeHoldsToolbarInMenuBar] == NO)
    {
      return NO;
    }
  /* libs-gui's -layout gives the toolbar a row above the content: in
     the menu bar's row it has none. */
  hasToolbar = NO;
  return YES;
}

- (void) winUIThemeEndLayout: (BOOL)heldToolbar
{
  if (heldToolbar == NO)
    {
      return;
    }
  hasToolbar = YES;
  WinUIThemeLayoutToolbarInMenuBar(self, window);
}

/* libs-gui takes a shown toolbar's height off the content: in the menu
   bar's row it takes none. (While a toolbar is being shown, it isn't
   visible yet and libs-gui takes nothing off.) */
- (NSRect) winUIThemeContentRect: (NSRect)content
{
  NSToolbar *toolbar = [window toolbar];

  if ([self winUIThemeHoldsToolbarInMenuBar] && [toolbar isVisible])
    {
      content.size.height += [[toolbar _toolbarView] _heightFromLayout];
    }
  return content;
}

- (NSRect) winUIThemeFrameRect: (NSRect)frame
{
  NSToolbar *toolbar = [window toolbar];

  if ([self winUIThemeHoldsToolbarInMenuBar] && [toolbar isVisible])
    {
      frame.size.height -= [[toolbar _toolbarView] _heightFromLayout];
    }
  return frame;
}

/* The default changed: the toolbar moves into or out of the menu bar's
   row, and the window keeps its frame (the content takes or gives up
   the toolbar's row). */
- (void) winUIThemePlaceToolbarForSetting
{
  NSToolbar *toolbar = [window toolbar];
  GSToolbarView *toolbarView = [toolbar _toolbarView];
  NSRect frame = [window frame];
  BOOL wanted = (hasMenu && WinUIThemeToolbarInMenuBarEnabled());

  if (toolbar == nil || [toolbar isVisible] == NO || [toolbarView superview] != self
      || WinUIThemeDecorationHoldsToolbar(self) == wanted)
    {
      return;
    }
  RETAIN(toolbarView);
  [self removeToolbarView: toolbarView];
  [self addToolbarView: toolbarView];
  RELEASE(toolbarView);
  [window setFrame: frame display: YES];
}

@end

/* Called whenever NSUserDefaults posts a change (on the main thread):
   only a change of the setting itself moves toolbars, and only in the
   theme's own decoration views, which carry them. */
void
WinUIThemeToolbarInMenuBarSettingChanged(void)
{
  static int enabled = -1;
  BOOL now = WinUIThemeToolbarInMenuBarEnabled();
  NSEnumerator *enumerator = nil;
  NSWindow *window = nil;

  if (enabled == (int)now)
    {
      return;
    }
  enabled = now;
  enumerator = [[NSApp windows] objectEnumerator];
  while ((window = [enumerator nextObject]) != nil)
    {
      NSView *decoration = [[window contentView] superview];

      if ([decoration isKindOfClass: [WinUIThemeBackendWindowDecorationView class]]
          || [decoration isKindOfClass: [WinUIThemeStandardWindowDecorationView class]])
        {
          [(GSWindowDecorationView *)decoration winUIThemePlaceToolbarForSetting];
        }
    }
}

void
WinUIThemeToolbarInMenuBarSetActive(BOOL active)
{
  WinUIThemeToolbarInMenuBarActive = active;
  WinUIThemeToolbarInMenuBarSettingChanged();
}
