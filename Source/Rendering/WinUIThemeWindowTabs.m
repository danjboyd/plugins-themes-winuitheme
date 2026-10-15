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
#import "../Settings/WinUIThemeSettings.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>

#import "GSWindowTabbing.h"
#import "../Native/WinUIThemeCaption.h"
#import "../Native/WinUIThemeWindowIntegration.h"

/* Window tabs (#72) as WinUI's TabView draws them (Notepad, Terminal),
   over the shared gnustep-window-tabbing code, which lays the bar out and
   handles the mouse.

   When the theme draws the caption (the carried libs-back), the bar sits
   in the title bar, as Windows 11's own apps have it (#83,
   WinUIThemeCaption.m lays it out); otherwise Windows draws the title bar
   and the bar takes its own row above the content.

   From WinUI 3's TabView resources (generic.xaml):
   - the strip: 8px above 32px tabs (TabViewHeaderPadding,
     TabViewItemMinHeight), tabs 100-240px wide and touching, 4px in from
     each end;
   - the selected tab: SolidBackgroundFillColorTertiary, 8px top corners
     and 4px flares into the line along the strip's foot, a
     CardStrokeColorDefault outline, semibold text; it has no line under
     it, so it runs into the content. Here it is the window background,
     which the content shows (Tertiary itself in the light theme), and the
     strip is a step darker, as Mica is under WinUI's tab;
   - other tabs: transparent, LayerOnMicaBaseAltFillColorSecondary under
     the pointer, TextFillColorSecondary text, a 1px
     DividerStrokeColorDefault separator 8px from the top and bottom,
     hidden beside the selected, hovered or pressed tab;
   - titles at 12px (TabViewItemHeaderFontSize) times Windows' text size,
     8px from the leading edge;
   - the close button: 32x24 with 4px corners, 4px from the trailing edge,
     a 12px cross (E711), SubtleFillColorSecondary under the pointer and
     Tertiary pressed. WinUI's CloseButtonOverlayMode Auto means Always,
     so every tab has one. A tab whose window has unsaved changes shows a
     dot there instead until the pointer is over it, as Notepad does;
   - the "+" (AddTabButton): 32x24, 3px after the last tab;
   - high contrast: ButtonFace strip, Window for the selected tab with a
     Hilight outline and Hilight text, Hilight with HilightText under the
     pointer, WindowText separators. */

/* One tab (#133). The shared code's group shows its bar from the second
   tab, as macOS does; Notepad and Terminal open with theirs, one tab and
   a "+". While a group's bar is automatic (not shown or hidden with
   -toggleTabBar:), a window on its own shows it when it can be a tab
   (titled, not a panel, its tabbing mode not Disallowed) and something
   answers -newWindowForTab: for it, so the "+" has something to do. The
   shared code builds a window's bar only when its group changes; a
   window on its own gets it as it first becomes key. The rule belongs in
   the shared code (a theme's say over the automatic state); until then
   the theme replaces -[NSWindowTabGroup isTabBarVisible]. */

@interface NSWindow (WinUIThemeSingleTabPrivate)
- (BOOL) _canBeTabbed;
- (void) _updateTabBar;
- (NSWindowTabGroup *) _tabbingGroup;
- (id) _tabBarView;
@end

static BOOL (*WinUIThemeOriginalIsTabBarVisible)(id, SEL) = NULL;
static ptrdiff_t WinUIThemeBarStateOffset = -1;

static BOOL
WinUIThemeWindowShowsSingleTab(NSWindow *window)
{
  return window != nil
    && [[GSTheme theme] isKindOfClass: [WinUITheme class]]
    && [window respondsToSelector: @selector(_canBeTabbed)]
    && [window _canBeTabbed]
    && [NSApp targetForAction: @selector(newWindowForTab:) to: nil from: window] != nil;
}

/* What the automatic state shows: the bar from two tabs, or one tab
   that can have company. */
static BOOL
WinUIThemeTabGroupShowsAutomatically(NSWindowTabGroup *group)
{
  NSArray *windows = [group windows];

  return [windows count] > 1
    || ([windows count] == 1 && WinUIThemeWindowShowsSingleTab([windows objectAtIndex: 0]));
}

static BOOL
WinUIThemeTabGroupIsTabBarVisible(id group, SEL _cmd)
{
  if (WinUIThemeBarStateOffset >= 0
      && *(int *)((char *)group + WinUIThemeBarStateOffset) != 0)
    {
      /* Shown or hidden with -toggleTabBar:. */
      return WinUIThemeOriginalIsTabBarVisible(group, _cmd);
    }
  return WinUIThemeTabGroupShowsAutomatically(group);
}

@interface NSWindowTabGroup (WinUIThemeSingleTabPrivate)
- (void) _windowsDidChangeAlso: (id)extra;
@end

@interface NSWindow (WinUIThemeTabSwitchPrivate)
- (void) _tabbingShowWithFrame: (NSRect)frame makeKey: (BOOL)makeKey;
- (void) _tabbingHide;
@end

static ptrdiff_t WinUIThemeSelectedWindowOffset = -1;

/* Set on a tab's window once the switch has shown it. */
static char WinUIThemeTabShownKey;

static NSArray *
WinUIThemeTabModes(void)
{
  return [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSModalPanelRunLoopMode,
                  NSEventTrackingRunLoopMode, nil];
}

/* The old tab's window ordered out once the new one has drawn over it,
   unless it has been selected again since; a new tab's window, set up
   behind the old one, brought forward. */
@interface WinUIThemeTabHider : NSObject
+ (void) hide: (NSArray *)groupAndWindow;
+ (void) reveal: (NSArray *)groupWindowPreviousKey;
@end

@implementation WinUIThemeTabHider
+ (void) hide: (NSArray *)groupAndWindow
{
  NSWindowTabGroup *group = [groupAndWindow objectAtIndex: 0];
  NSWindow *window = [groupAndWindow objectAtIndex: 1];

  if ([group selectedWindow] != window && [window isVisible])
    {
      [window _tabbingHide];
    }
}

+ (void) reveal: (NSArray *)groupWindowPreviousKey
{
  NSWindowTabGroup *group = [groupWindowPreviousKey objectAtIndex: 0];
  NSWindow *window = [groupWindowPreviousKey objectAtIndex: 1];
  NSWindow *previous = [groupWindowPreviousKey objectAtIndex: 2];
  BOOL key = [[groupWindowPreviousKey objectAtIndex: 3] boolValue];

  if ([group selectedWindow] != window)
    {
      return;
    }
  WinUIThemeWindowIntegrationSuspendTransitions(window, previous);
  [window _tabbingShowWithFrame: [previous frame] makeKey: (key || [previous isKeyWindow])];
  [window display];
  [window flushWindow];
  [self performSelector: @selector(hide:)
             withObject: [NSArray arrayWithObjects: group, previous, nil]
             afterDelay: 0.05
                inModes: WinUIThemeTabModes()];
}
@end

/* Selecting a tab (a click, the "+", Ctrl+Tab): the shared code hid the
   old tab's window, then showed the new one in its place, so for a moment
   neither was on the screen and the window seemed to vanish. The new one
   comes on screen first, at the group's frame, then the old one goes. The
   selected window isn't retained, as in the shared code. */
static void
WinUIThemeTabGroupSwitchToWindow(id group, SEL _cmd, id window)
{
  id *selected = (id *)((char *)group + WinUIThemeSelectedWindowOffset);
  id previous = *selected;
  NSRect frame;
  BOOL key;

  if (window == previous)
    {
      return;
    }
  *selected = window;
  if (previous == nil)
    {
      return;
    }
  frame = [previous frame];
  key = [previous isKeyWindow];
  if (objc_getAssociatedObject(window, &WinUIThemeTabShownKey) == nil
      && [window isVisible] == NO)
    {
      /* A tab's window never on screen (the "+" or the app's new tab):
         Windows would show it first with its own title bar and the app's
         content not laid out yet. It's set up behind the old one, at the
         group's frame, and brought forward once the app has returned to
         the run loop and it has drawn. */
      objc_setAssociatedObject(window, &WinUIThemeTabShownKey,
                               [NSNumber numberWithBool: YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      WinUIThemeWindowIntegrationSuspendTransitions(window, previous);
      [window setFrame: frame display: NO];
      [window orderWindow: NSWindowBelow relativeTo: [previous windowNumber]];
      [WinUIThemeTabHider performSelector: @selector(reveal:)
                               withObject: [NSArray arrayWithObjects: group, window, previous,
                                                    [NSNumber numberWithBool: key], nil]
                               afterDelay: 0.1
                                  inModes: WinUIThemeTabModes()];
      return;
    }
  objc_setAssociatedObject(window, &WinUIThemeTabShownKey,
                           [NSNumber numberWithBool: YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  /* Without Windows' show and hide animations, which would fade the old
     window out as the new one fades in. */
  WinUIThemeWindowIntegrationSuspendTransitions(window, previous);
  [window _tabbingShowWithFrame: frame makeKey: key];
  /* A tab shown before keeps its contents while ordered out (libs-back's
     windows are layered, and show nothing until flushed); drawn and
     flushed again, it covers the old one, which goes at once, as the
     shared code and apps expect. */
  [window display];
  [window flushWindow];
  [previous _tabbingHide];
}

/* -toggleTabBar: as the shared code has it, against the automatic state
   above: back to automatic when that's what automatic would show, else
   shown (1) or hidden (2). */
static void
WinUIThemeTabGroupToggleTabBar(id group, SEL _cmd)
{
  BOOL show = ([(NSWindowTabGroup *)group isTabBarVisible] == NO);
  int *state = (int *)((char *)group + WinUIThemeBarStateOffset);

  *state = (show == WinUIThemeTabGroupShowsAutomatically(group)) ? 0 : (show ? 1 : 2);
  [(NSWindowTabGroup *)group _windowsDidChangeAlso: nil];
}

void
WinUIThemeWindowTabsInstallSingleTabBar(void)
{
  Class groupClass = NSClassFromString(@"NSWindowTabGroup");
  Method method = NULL;
  Method toggle = NULL;
  Ivar state = NULL;

  if (WinUIThemeOriginalIsTabBarVisible != NULL || groupClass == Nil)
    {
      return;
    }
  method = class_getInstanceMethod(groupClass, @selector(isTabBarVisible));
  toggle = class_getInstanceMethod(groupClass, NSSelectorFromString(@"_toggleTabBar"));
  state = class_getInstanceVariable(groupClass, "_barState");
  if (method == NULL || toggle == NULL || state == NULL
      || [groupClass instancesRespondToSelector: @selector(_windowsDidChangeAlso:)] == NO)
    {
      return;
    }
  WinUIThemeBarStateOffset = ivar_getOffset(state);
  WinUIThemeOriginalIsTabBarVisible = (BOOL (*)(id, SEL))method_getImplementation(method);
  method_setImplementation(method, (IMP)WinUIThemeTabGroupIsTabBarVisible);
  method_setImplementation(toggle, (IMP)WinUIThemeTabGroupToggleTabBar);

  {
    Method switchMethod = class_getInstanceMethod(groupClass, NSSelectorFromString(@"_switchToWindow:"));
    Ivar selected = class_getInstanceVariable(groupClass, "_selectedWindow");

    if (switchMethod != NULL && selected != NULL
        && [NSWindow instancesRespondToSelector: @selector(_tabbingShowWithFrame:makeKey:)]
        && [NSWindow instancesRespondToSelector: @selector(_tabbingHide)])
      {
        WinUIThemeSelectedWindowOffset = ivar_getOffset(selected);
        method_setImplementation(switchMethod, (IMP)WinUIThemeTabGroupSwitchToWindow);
      }
  }
}

void
WinUIThemeWindowTabsWindowBecameKey(NSWindow *window)
{
  NSWindowTabGroup *group = nil;

  if (WinUIThemeOriginalIsTabBarVisible == NULL
      || [window respondsToSelector: @selector(_updateTabBar)] == NO
      || WinUIThemeWindowShowsSingleTab(window) == NO)
    {
      return;
    }
  group = [window tabGroup];
  if ([[group windows] count] == 1 && [group isTabBarVisible]
      && [window _tabBarView] == nil)
    {
      [window _updateTabBar];
    }
}

static CGFloat
WinUIThemeTabsDensity(WinUITheme *theme)
{
  CGFloat scale = [[theme settings] desktopScaleFactor];

  return (scale > 0.0) ? scale : 1.0;
}

static BOOL
WinUIThemeTabsHighContrast(WinUITheme *theme)
{
  return [[theme settings] highContrastEnabled];
}

static BOOL
WinUIThemeTabsDark(WinUITheme *theme)
{
  return WinUIThemeTabsHighContrast(theme) == NO && [[theme settings] prefersDarkAppearance];
}

static NSColor *
WinUIThemeTabsContrast(WinUITheme *theme, NSString *name, NSColor *fallback)
{
  NSColor *color = [[theme settings] contrastColor: name];

  return (color != nil) ? color : fallback;
}

static NSColor *
WinUIThemeTabsWindowColor(WinUITheme *theme)
{
  return WinUIThemeColorFromTheme(theme, @"windowBackgroundColor", [NSColor windowBackgroundColor]);
}

static NSColor *
WinUIThemeTabsTextColor(WinUITheme *theme)
{
  return WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
}

/* Black (white in the dark theme) at `light` (`dark`) opacity over `color`. */
static NSColor *
WinUIThemeTabsLayer(WinUITheme *theme, NSColor *color, CGFloat light, CGFloat dark)
{
  BOOL isDark = WinUIThemeTabsDark(theme);

  return WinUIThemeBlendColor(color, isDark ? [NSColor whiteColor] : [NSColor blackColor],
                              isDark ? dark : light);
}

/* The strip behind the tabs: a step below the window background, as Mica
   is below the selected tab's SolidBackgroundFillColorTertiary (243 under
   the light theme's 249, 26 under the dark theme's 32). */
static NSColor *
WinUIThemeTabsStripColor(WinUITheme *theme)
{
  if (WinUIThemeTabsHighContrast(theme))
    {
      return WinUIThemeTabsContrast(theme, @"ButtonFace", WinUIThemeTabsWindowColor(theme));
    }
  return WinUIThemeBlendColor(WinUIThemeTabsWindowColor(theme), [NSColor blackColor],
                              WinUIThemeTabsDark(theme) ? 0.19 : 0.025);
}

/* The selected tab: the window background, which the content shows, so
   the tab runs into it. */
static NSColor *
WinUIThemeTabsSelectedColor(WinUITheme *theme)
{
  if (WinUIThemeTabsHighContrast(theme))
    {
      return WinUIThemeTabsContrast(theme, @"Window", WinUIThemeTabsWindowColor(theme));
    }
  return WinUIThemeTabsWindowColor(theme);
}

/* CardStrokeColorDefault (TabViewBorderBrush): the selected tab's outline
   and the line along the strip's foot. */
static NSColor *
WinUIThemeTabsBorderColor(WinUITheme *theme)
{
  if (WinUIThemeTabsHighContrast(theme))
    {
      return WinUIThemeTabsContrast(theme, @"Hilight", WinUIThemeTabsTextColor(theme));
    }
  return WinUIThemeBlendColor(WinUIThemeTabsStripColor(theme), [NSColor blackColor],
                              WinUIThemeTabsDark(theme) ? 0.10 : 0.06);
}

NSColor *
WinUIThemeWindowTabStripColor(void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [WinUITheme class]]
    ? WinUIThemeTabsStripColor((WinUITheme *)theme) : [NSColor controlColor];
}

NSColor *
WinUIThemeWindowTabFootColor(void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [WinUITheme class]]
    ? WinUIThemeTabsBorderColor((WinUITheme *)theme) : [NSColor controlShadowColor];
}

/* DividerStrokeColorDefault between unselected tabs. */
static NSColor *
WinUIThemeTabsSeparatorColor(WinUITheme *theme)
{
  if (WinUIThemeTabsHighContrast(theme))
    {
      return WinUIThemeTabsContrast(theme, @"WindowText", WinUIThemeTabsTextColor(theme));
    }
  return WinUIThemeTabsLayer(theme, WinUIThemeTabsStripColor(theme), 0.06, 0.08);
}

/* A tab under the pointer (LayerOnMicaBaseAltFillColorSecondary) or
   pressed (LayerOnMicaBaseAltFillColorDefault). */
static NSColor *
WinUIThemeTabsHoverColor(WinUITheme *theme, BOOL pressed)
{
  NSColor *strip = WinUIThemeTabsStripColor(theme);

  if (WinUIThemeTabsHighContrast(theme))
    {
      return WinUIThemeTabsContrast(theme, @"Hilight", WinUIThemeTabsTextColor(theme));
    }
  if (pressed)
    {
      return WinUIThemeTabsDark(theme)
        ? WinUIThemeBlendColor(strip, [NSColor colorWithCalibratedWhite: 58.0 / 255.0 alpha: 1.0], 0.45)
        : WinUIThemeBlendColor(strip, [NSColor whiteColor], 0.70);
    }
  return WinUIThemeTabsLayer(theme, strip, 0.04, 0.06);
}

/* A tab's title: TextFillColorPrimary selected, Secondary otherwise. */
static NSColor *
WinUIThemeTabsTitleColor(WinUITheme *theme, GSWindowTabState state)
{
  NSColor *text = WinUIThemeTabsTextColor(theme);

  if (WinUIThemeTabsHighContrast(theme))
    {
      if (state & GSWindowTabSelected)
        {
          return WinUIThemeTabsContrast(theme, @"Hilight", text);
        }
      if (state & (GSWindowTabHovered | GSWindowTabPressed))
        {
          return WinUIThemeTabsContrast(theme, @"HilightText", text);
        }
      return WinUIThemeTabsContrast(theme, @"WindowText", text);
    }
  if (state & GSWindowTabSelected)
    {
      return text;
    }
  return WinUIThemeBlendColor(WinUIThemeTabsStripColor(theme), text,
                              WinUIThemeTabsDark(theme) ? 0.77 : 0.62);
}

/* The 32px tab itself: the bar's lower part, under its 8px top padding. */
static NSRect
WinUIThemeTabsBody(WinUITheme *theme, NSRect rect)
{
  CGFloat height = MIN(NSHeight(rect), round(32.0 * WinUIThemeTabsDensity(theme)));

  return NSMakeRect(NSMinX(rect), NSMinY(rect), NSWidth(rect), height);
}

/* A 32x24 button (the close button, the "+"), 4px from the body's foot. */
static NSRect
WinUIThemeTabsButtonRect(WinUITheme *theme, CGFloat x, NSRect body)
{
  CGFloat d = WinUIThemeTabsDensity(theme);
  CGFloat height = round(24.0 * d);

  return NSMakeRect(x, NSMinY(body) + floor((NSHeight(body) - height) / 2.0),
                    round(32.0 * d), height);
}

/* The selected tab's shape: top corners of 8px, sides down to flares of
   4px that turn out into the strip's foot. `outline` gives the open path
   along its edge, half a pixel in, for a 1px stroke. */
static NSBezierPath *
WinUIThemeTabsSelectedPath(WinUITheme *theme, NSRect body, BOOL outline)
{
  CGFloat d = WinUIThemeTabsDensity(theme);
  CGFloat radius = MIN(WinUIThemeOverlayCornerRadius(theme), NSWidth(body) / 2.0);
  CGFloat flare = round(4.0 * d);
  CGFloat inset = outline ? 0.5 : 0.0;
  CGFloat left = NSMinX(body) + inset;
  CGFloat right = NSMaxX(body) - inset;
  CGFloat bottom = NSMinY(body) + inset;
  CGFloat top = NSMaxY(body) - inset;
  NSBezierPath *path = [NSBezierPath bezierPath];

  [path moveToPoint: NSMakePoint(left - flare, bottom)];
  [path appendBezierPathWithArcWithCenter: NSMakePoint(left - flare, bottom + flare)
                                   radius: flare
                               startAngle: 270.0
                                 endAngle: 360.0
                                clockwise: NO];
  [path lineToPoint: NSMakePoint(left, top - radius)];
  [path appendBezierPathWithArcWithCenter: NSMakePoint(left + radius, top - radius)
                                   radius: radius
                               startAngle: 180.0
                                 endAngle: 90.0
                                clockwise: YES];
  [path lineToPoint: NSMakePoint(right - radius, top)];
  [path appendBezierPathWithArcWithCenter: NSMakePoint(right - radius, top - radius)
                                   radius: radius
                               startAngle: 90.0
                                 endAngle: 0.0
                                clockwise: YES];
  [path lineToPoint: NSMakePoint(right, bottom + flare)];
  [path appendBezierPathWithArcWithCenter: NSMakePoint(right + flare, bottom + flare)
                                   radius: flare
                               startAngle: 180.0
                                 endAngle: 270.0
                                clockwise: NO];
  if (outline == NO)
    {
      [path closePath];
    }
  return path;
}

static void
WinUIThemeTabsDrawSelected(WinUITheme *theme, NSRect body)
{
  NSBezierPath *outline = WinUIThemeTabsSelectedPath(theme, body, YES);

  [WinUIThemeTabsSelectedColor(theme) set];
  [WinUIThemeTabsSelectedPath(theme, body, NO) fill];
  [outline setLineWidth: 1.0];
  [WinUIThemeTabsBorderColor(theme) set];
  [outline stroke];
}

/* Where `tab` is in the bar's group, and where the selected tab is. */
static void
WinUIThemeTabsIndexes(NSWindowTab *tab, NSWindow *window,
                      NSInteger *index, NSInteger *selected, NSUInteger *count)
{
  NSWindowTabGroup *group = [window tabGroup];
  NSArray *windows = [group windows];
  NSUInteger i;

  *index = -1;
  *selected = -1;
  *count = [windows count];
  for (i = 0; i < [windows count]; i++)
    {
      NSWindow *other = [windows objectAtIndex: i];

      if ([other tab] == tab)
        {
          *index = i;
        }
      if (other == [group selectedWindow])
        {
          *selected = i;
        }
    }
}

static NSFont *
WinUIThemeTabsFont(WinUITheme *theme, BOOL selected)
{
  NSFont *base = [[theme settings] interfaceFont];
  CGFloat size = round(12.0 * MAX(1.0, [[theme settings] textScaleFactor]));
  NSFont *font = (base != nil) ? [NSFont fontWithName: [base fontName] size: size] : nil;

  if (font == nil)
    {
      font = [NSFont systemFontOfSize: size];
    }
  return selected ? WinUIThemeSemiboldFont(font, size) : font;
}

/* The title already marks unsaved changes (a bullet, U+2022, as ObjcMarkdown
   titles its windows). */
static BOOL
WinUIThemeTabsTitleShowsEdited(NSString *title)
{
  return [title length] > 0 && [title characterAtIndex: 0] == 0x2022;
}

/* Whether the tab drawn last shows unsaved changes in its title: the bar
   draws a tab's close button right after the tab. */
static BOOL WinUIThemeTabsLastTitleShowsEdited = NO;

@implementation WinUITheme (WindowTabs)

- (CGFloat) windowTabBarHeightForWindow: (NSWindow *)window
{
  return round(40.0 * WinUIThemeTabsDensity(self));
}

/* In the title bar (#83), as Windows 11's tabbed apps have it, when the
   theme draws the window's caption (the carried libs-back); above the
   content otherwise. */
- (GSWindowTabBarPlacement) windowTabBarPlacementForWindow: (NSWindow *)window
{
  return WinUIThemeDrawsCaptionForStyle([window styleMask])
    ? GSWindowTabBarInTitleBar : GSWindowTabBarAboveContent;
}

/* WinUI's 100px; in the title bar, where the caption buttons and the
   room to drag by limit the bar, tabs narrow to fit, down to 40px, rather
   than run past it (#83). */
- (CGFloat) windowTabMinimumWidthForWindow: (NSWindow *)window
{
  CGFloat d = WinUIThemeTabsDensity(self);
  CGFloat minimum = round(100.0 * d);

  if ([self windowTabBarPlacementForWindow: window] == GSWindowTabBarInTitleBar)
    {
      NSView *bar = GSWindowTabBarViewForWindow(window);
      NSUInteger count = [[[window tabGroup] windows] count];
      CGFloat newTab = ([NSApp targetForAction: @selector(newWindowForTab:) to: nil from: window] != nil)
        ? round(40.0 * d) : 0.0;

      if (bar != nil && count > 0)
        {
          CGFloat fit = floor((NSWidth([bar bounds]) - 2.0 * [self windowTabBarMarginForWindow: window]
                               - newTab) / count);

          minimum = MIN(minimum, MAX(round(40.0 * d), fit));
        }
    }
  return minimum;
}

- (CGFloat) windowTabMaximumWidthForWindow: (NSWindow *)window
{
  return round(240.0 * WinUIThemeTabsDensity(self));
}

/* 4px at each end: WinUI's strip starts its tabs 2px in (LeftContentColumn's
   MinWidth), and the selected tab's flares reach 4px past it, so the first
   tab's flare shows whole. */
- (CGFloat) windowTabBarMarginForWindow: (NSWindow *)window
{
  return round(4.0 * WinUIThemeTabsDensity(self));
}

/* TabView's tabs touch, with a divider between them. */
- (CGFloat) windowTabSpacingForWindow: (NSWindow *)window
{
  return 0.0;
}

/* The "+" follows the last tab, as WinUI's AddTabButton does. The shared
   bar puts the button at its end (inside the margin) and gives the tabs
   what is left, so the button's width is what the tabs leave: the rect
   then starts where the tabs end, and the button is drawn at its start.
   Tabs share the width as GSWindowTabWidth() does (floor of the share,
   between the limits). */
- (CGFloat) windowTabNewTabButtonWidthForWindow: (NSWindow *)window
{
  CGFloat d = WinUIThemeTabsDensity(self);
  CGFloat button = round(40.0 * d);
  NSView *bar = GSWindowTabBarViewForWindow(window);
  NSUInteger count = [[[window tabGroup] windows] count];
  CGFloat width = NSWidth([bar bounds]) - 2.0 * [self windowTabBarMarginForWindow: window];
  CGFloat minimum = [self windowTabMinimumWidthForWindow: window];
  CGFloat maximum = [self windowTabMaximumWidthForWindow: window];
  CGFloat each;
  CGFloat rest;

  if (bar == nil || count == 0 || width <= button)
    {
      return button;
    }
  each = WinUIThemeClamp(floor((width - button) / count), minimum, maximum);
  /* Half a point less, so that floor() of the tabs' share is `each`. */
  rest = width - each * count - 0.5;
  return MAX(button, rest);
}

- (NSRect) windowTabCloseButtonRectForTabRect: (NSRect)tabRect
                                        state: (GSWindowTabState)state
                                       window: (NSWindow *)window
{
  NSRect body = WinUIThemeTabsBody(self, tabRect);
  CGFloat d = WinUIThemeTabsDensity(self);
  CGFloat width = round(32.0 * d);

  return WinUIThemeTabsButtonRect(self, NSMaxX(body) - round(4.0 * d) - width, body);
}

- (void) drawWindowTabBarBackgroundInRect: (NSRect)rect
                                   window: (NSWindow *)window
{
  if (WinUIThemeWindowShowsMica(window)
      && [self windowTabBarPlacementForWindow: window] == GSWindowTabBarInTitleBar)
    {
      /* The title bar's Mica shows behind the tabs (#47). */
      NSRectFillUsingOperation(rect, NSCompositeClear);
    }
  else
    {
      [WinUIThemeTabsStripColor(self) set];
      NSRectFill(rect);
    }
  /* The line along the foot; the selected tab covers it. */
  [WinUIThemeTabsBorderColor(self) set];
  NSRectFill(NSMakeRect(NSMinX(rect), NSMinY(rect), NSWidth(rect), 1.0));
}

- (void) drawWindowTab: (NSWindowTab *)tab
                inRect: (NSRect)rect
                 state: (GSWindowTabState)state
                window: (NSWindow *)window
{
  CGFloat d = WinUIThemeTabsDensity(self);
  NSRect body = WinUIThemeTabsBody(self, rect);
  BOOL selected = (state & GSWindowTabSelected) != 0;
  BOOL hovered = (state & (GSWindowTabHovered | GSWindowTabPressed)) != 0;
  NSInteger index = -1;
  NSInteger selectedIndex = -1;
  NSUInteger count = 0;
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  NSString *title = [tab title];
  NSRect closeRect;
  CGFloat titleLeft;
  CGFloat titleRight;
  NSSize size;

  WinUIThemeTabsIndexes(tab, window, &index, &selectedIndex, &count);
  WinUIThemeTabsLastTitleShowsEdited = WinUIThemeTabsTitleShowsEdited(title);

  if (selected)
    {
      WinUIThemeTabsDrawSelected(self, body);
    }
  else
    {
      if (hovered)
        {
          CGFloat radius = MIN(WinUIThemeOverlayCornerRadius(self), NSWidth(body) / 2.0);
          NSRect fill = NSMakeRect(NSMinX(body), NSMinY(body) + 1.0,
                                   NSWidth(body), NSHeight(body) - 1.0);

          [WinUIThemeTabsHoverColor(self, (state & GSWindowTabPressed) != 0) set];
          /* Top corners only (TopCornerRadiusFilterConverter). */
          [WinUIThemeRoundedPath(fill, radius) fill];
          NSRectFill(NSMakeRect(NSMinX(fill), NSMinY(fill), NSWidth(fill), MIN(radius, NSHeight(fill))));
          /* The selected neighbour's flare turns into this tab: keep it
             over the fill. */
          if (selectedIndex >= 0 && index >= 0 && (index == selectedIndex - 1 || index == selectedIndex + 1))
            {
              NSRect neighbour = NSOffsetRect(body, (selectedIndex - index) * NSWidth(body), 0.0);

              [NSGraphicsContext saveGraphicsState];
              NSRectClip(body);
              WinUIThemeTabsDrawSelected(self, neighbour);
              [NSGraphicsContext restoreGraphicsState];
            }
        }
      /* The divider between two tabs that are neither selected, under the
         pointer nor pressed (GSWindowTabPreviousHighlighted): none before
         the first tab or after the last. */
      if (hovered == NO
          && (state & (GSWindowTabFirst | GSWindowTabPreviousHighlighted)) == 0)
        {
          CGFloat margin = round(8.0 * d);

          [WinUIThemeTabsSeparatorColor(self) set];
          NSRectFill(NSMakeRect(NSMinX(body), NSMinY(body) + margin,
                                1.0, NSHeight(body) - 2.0 * margin));
        }
    }

  closeRect = [self windowTabCloseButtonRectForTabRect: rect state: state window: window];
  titleLeft = NSMinX(body) + round(8.0 * d);
  titleRight = NSIsEmptyRect(closeRect) ? NSMaxX(body) - round(8.0 * d)
                                        : NSMinX(closeRect) - round(4.0 * d);
  [attributes setObject: WinUIThemeTabsFont(self, selected) forKey: NSFontAttributeName];
  [attributes setObject: WinUIThemeTabsTitleColor(self, state) forKey: NSForegroundColorAttributeName];
  title = GSWindowTabFittedTitle(title, attributes, MAX(0.0, titleRight - titleLeft));
  size = [title sizeWithAttributes: attributes];
  [title drawAtPoint: NSMakePoint(titleLeft, floor(NSMidY(body) - size.height / 2.0))
      withAttributes: attributes];
}

- (void) drawWindowTabCloseButtonInRect: (NSRect)rect
                                  state: (GSWindowTabState)state
                                 window: (NSWindow *)window
{
  CGFloat d = WinUIThemeTabsDensity(self);
  BOOL highContrast = WinUIThemeTabsHighContrast(self);
  BOOL selected = (state & GSWindowTabSelected) != 0;
  BOOL tabHovered = (state & (GSWindowTabHovered | GSWindowTabPressed)) != 0;
  BOOL hovered = (state & GSWindowTabCloseHovered) != 0;
  BOOL pressed = (state & GSWindowTabClosePressed) != 0;
  NSColor *text = WinUIThemeTabsTextColor(self);
  NSColor *under = selected ? WinUIThemeTabsSelectedColor(self)
                            : (tabHovered ? WinUIThemeTabsHoverColor(self, NO)
                                          : WinUIThemeTabsStripColor(self));
  NSColor *glyph = text;
  CGFloat radius = WinUIThemeControlCornerRadius(self);
  NSRect mark;

  if (highContrast)
    {
      /* ButtonText on ButtonFace, outlined in ButtonText under the
         pointer; Hilight on the selected tab, HilightText on a tab under
         the pointer. */
      glyph = WinUIThemeTabsContrast(self, @"ButtonText", text);
      if (selected)
        {
          glyph = WinUIThemeTabsContrast(self, @"Hilight", text);
        }
      else if (tabHovered)
        {
          glyph = WinUIThemeTabsContrast(self, @"HilightText", text);
        }
      if (hovered || pressed)
        {
          NSColor *face = WinUIThemeTabsContrast(self, @"ButtonFace", under);
          NSColor *buttonText = WinUIThemeTabsContrast(self, @"ButtonText", text);

          WinUIThemeFillAndStrokeRoundedRect(rect, radius, face, buttonText, 1.0);
          glyph = buttonText;
        }
    }
  else if (hovered || pressed)
    {
      /* SubtleFillColorSecondary, Tertiary pressed (with
         TextFillColorSecondary). */
      [WinUIThemeTabsLayer(self, under, pressed ? 0.024 : 0.035, pressed ? 0.04 : 0.06) set];
      [WinUIThemeRoundedPath(rect, radius) fill];
      if (pressed)
        {
          glyph = WinUIThemeBlendColor(under, text, WinUIThemeTabsDark(self) ? 0.77 : 0.62);
        }
    }

  /* Unsaved changes: a dot in the button's place until the pointer is
     over the tab (unless the title shows them already). */
  if ((state & GSWindowTabEdited) && tabHovered == NO
      && WinUIThemeTabsLastTitleShowsEdited == NO)
    {
      CGFloat size = round(8.0 * d);

      [glyph set];
      [[NSBezierPath bezierPathWithOvalInRect: WinUIThemeCenteredRect(rect, size, size)] fill];
      return;
    }

  mark = WinUIThemeCenteredRect(rect, round(8.0 * d), round(8.0 * d));
  WinUIThemeDrawCrossGlyph(mark, glyph);
}

- (void) drawWindowTabNewTabButtonInRect: (NSRect)rect
                                   state: (GSWindowTabState)state
                                  window: (NSWindow *)window
{
  CGFloat d = WinUIThemeTabsDensity(self);
  NSRect body = WinUIThemeTabsBody(self, rect);
  NSRect button = WinUIThemeTabsButtonRect(self, NSMinX(rect) + round(3.0 * d), body);
  BOOL hovered = (state & GSWindowTabHovered) != 0;
  BOOL pressed = (state & GSWindowTabPressed) != 0;
  NSColor *strip = WinUIThemeTabsStripColor(self);
  NSColor *text = WinUIThemeTabsTextColor(self);
  NSColor *glyph = text;
  CGFloat radius = WinUIThemeControlCornerRadius(self);
  CGFloat span = round(10.0 * d);
  NSRect mark;
  NSBezierPath *plus = [NSBezierPath bezierPath];

  if (WinUIThemeTabsHighContrast(self))
    {
      NSColor *buttonText = WinUIThemeTabsContrast(self, @"ButtonText", text);

      glyph = buttonText;
      if (hovered || pressed)
        {
          NSColor *highlight = WinUIThemeTabsContrast(self, @"Hilight", text);

          WinUIThemeFillAndStrokeRoundedRect(button, radius, highlight, highlight, 1.0);
          glyph = WinUIThemeTabsContrast(self, @"HilightText", text);
        }
      else
        {
          WinUIThemeFillAndStrokeRoundedRect(button, radius, strip, buttonText, 1.0);
        }
    }
  else if (hovered || pressed)
    {
      [WinUIThemeTabsLayer(self, strip, pressed ? 0.024 : 0.035, pressed ? 0.04 : 0.06) set];
      [WinUIThemeRoundedPath(button, radius) fill];
      if (pressed)
        {
          glyph = WinUIThemeBlendColor(strip, text, WinUIThemeTabsDark(self) ? 0.77 : 0.62);
        }
    }

  mark = WinUIThemeCenteredRect(button, span, span);
  [plus moveToPoint: NSMakePoint(NSMidX(mark), NSMinY(mark))];
  [plus lineToPoint: NSMakePoint(NSMidX(mark), NSMaxY(mark))];
  [plus moveToPoint: NSMakePoint(NSMinX(mark), NSMidY(mark))];
  [plus lineToPoint: NSMakePoint(NSMaxX(mark), NSMidY(mark))];
  [plus setLineWidth: 1.3];
  [plus setLineCapStyle: NSRoundLineCapStyle];
  [glyph set];
  [plus stroke];
}

@end
