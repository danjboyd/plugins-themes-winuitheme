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

/* NSColorWell as WinUI's colour button (#26), the swatch button of the
   ColorPicker flyout and of Settings: the theme's button (4px corners,
   rest, hover, pressed and disabled) holding a rounded swatch with a faint
   inner border. While the colour panel is attached, the well is checked,
   as a ToggleButton: accent chrome. libs-gui drew NeXT's bevelled well. */

/* The swatch's inset from the button's edge. */
static const CGFloat WinUIThemeColorWellInsetX = 6.0;
static const CGFloat WinUIThemeColorWellInsetY = 5.0;

@implementation WinUITheme (ColorWell)

- (NSRect) drawColorWellBorder: (NSColorWell *)well
                    withBounds: (NSRect)bounds
                      withClip: (NSRect)clipRect
{
  BOOL enabled = [well isEnabled];
  BOOL pressed = [[well cell] isHighlighted];
  BOOL hover = NO;

  (void)clipRect;
  if ([well isBordered] == NO)
    {
      return bounds;
    }
  if (enabled)
    {
      WinUIThemeTrackHover(well);
      hover = WinUIThemeViewIsHovered(well);
    }
  WinUIThemeDrawButtonChrome(self, bounds, well, enabled, enabled && [well isActive], pressed, hover);
  return NSInsetRect(bounds,
                     MIN(WinUIThemeColorWellInsetX, floor(NSWidth(bounds) / 4.0)),
                     MIN(WinUIThemeColorWellInsetY, floor(NSHeight(bounds) / 4.0)));
}

/* The swatch: rounded, with a faint inner border so a colour close to the
   button's still shows its edge, and faded when the well is disabled. */
- (void) _overrideNSColorWellMethod_drawWellInside: (NSRect)insideRect
{
  NSColorWell *well = (NSColorWell *)self;
  GSTheme *active = [GSTheme theme];
  WinUITheme *theme = [active isKindOfClass: [WinUITheme class]] ? (WinUITheme *)active : nil;
  BOOL dark = [[theme settings] prefersDarkAppearance];
  CGFloat radius = MIN(2.0, floor(MIN(NSWidth(insideRect), NSHeight(insideRect)) / 2.0));
  NSBezierPath *path = nil;
  NSBezierPath *edge = nil;

  if (NSIsEmptyRect(insideRect))
    {
      return;
    }
  if (theme == nil || [well isBordered] == NO)
    {
      [[well color] drawSwatchInRect: insideRect];
      return;
    }

  path = WinUIThemeRoundedPath(insideRect, radius);
  edge = WinUIThemeRoundedPath(NSInsetRect(insideRect, 0.5, 0.5), MAX(0.0, radius - 0.5));
  [NSGraphicsContext saveGraphicsState];
  [path addClip];
  [[well color] drawSwatchInRect: insideRect];
  if ([well isEnabled] == NO)
    {
      [WinUIThemeColorWithAlpha(WinUIThemeColorFromTheme(theme, @"windowBackgroundColor",
                                                         [NSColor windowBackgroundColor]), 0.55) set];
      NSRectFillUsingOperation(insideRect, NSCompositeSourceOver);
    }
  [NSGraphicsContext restoreGraphicsState];

  /* ControlStrokeColorDefault's weight, in black or white. */
  if ([[theme settings] highContrastEnabled])
    {
      [WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]) set];
    }
  else
    {
      [WinUIThemeColorWithAlpha(dark ? [NSColor whiteColor] : [NSColor blackColor], dark ? 0.16 : 0.14) set];
    }
  [edge setLineWidth: 1.0];
  [edge stroke];
}

@end
