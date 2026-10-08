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

#import "GSWindowTabbing.h"

/* Window tabs (#72) as WinUI's TabView draws them (Notepad, Terminal),
   over the shared gnustep-window-tabbing code, which lays the bar out and
   handles the mouse.

   libs-back's Windows server leaves the title bar to Windows, so the bar
   takes its own row above the content (GSWindowTabBarAboveContent) rather
   than sitting in the title bar, as Windows 11's own apps have it.

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

- (GSWindowTabBarPlacement) windowTabBarPlacementForWindow: (NSWindow *)window
{
  return GSWindowTabBarAboveContent;
}

- (CGFloat) windowTabMinimumWidthForWindow: (NSWindow *)window
{
  return round(100.0 * WinUIThemeTabsDensity(self));
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
  [WinUIThemeTabsStripColor(self) set];
  NSRectFill(rect);
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
