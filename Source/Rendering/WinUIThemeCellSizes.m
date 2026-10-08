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

/* -cellSize heights for the controls WinUI makes as tall as a Button
   (#86). A push button's -cellSize gives the theme's 32pt (its margins
   and a line of its font), but libs-gui sized a segmented control and a
   TextBox to their text and a slider to its track, so an app that lays
   out from -cellSize squashed them: the selected segment's pill and the
   slider's thumb were clipped, and a text field sat shorter than the
   button beside it. WinUI's Segmented, TextBox and Slider (its touch
   target, round a 4px rail and 20px thumb) are 32px at standard density;
   compact metrics (#31) get the compact button's height. */

static WinUITheme *
WinUIThemeCellSizesTheme(void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [WinUITheme class]] ? (WinUITheme *)theme : nil;
}

/* A push button's -cellSize height for one line of `font`: its margins
   and the line, as NSButtonCell measures it. */
static CGFloat
WinUIThemeButtonHeightForFont(WinUITheme *theme, NSFont *font)
{
  GSThemeMargins margins = [theme buttonMarginsForCell: nil
                                                 style: NSRoundedBezelStyle
                                                 state: GSThemeNormalState];
  NSDictionary *attributes = nil;

  if (font == nil)
    {
      font = [NSFont systemFontOfSize: 0.0];
    }
  attributes = [NSDictionary dictionaryWithObject: font forKey: NSFontAttributeName];
  return ceil([@"A" sizeWithAttributes: attributes].height + margins.top + margins.bottom);
}

@implementation WinUITheme (CellSizes)

- (NSSize) _overrideNSSegmentedCellMethod_cellSize
{
  typedef NSSize (*CellSizeIMP)(id, SEL);
  CellSizeIMP originalIMP = (CellSizeIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSegmentedCell class]);
  WinUITheme *theme = WinUIThemeCellSizesTheme();
  NSSize size = (originalIMP != NULL) ? originalIMP(self, _cmd) : NSZeroSize;

  if (theme != nil)
    {
      size.height = MAX(size.height, WinUIThemeButtonHeightForFont(theme, [(NSCell *)self font]));
    }
  return size;
}

/* The touch target: a push button's height across a horizontal slider,
   its width across a vertical one, and never less than the thumb. */
- (NSSize) _overrideNSSliderCellMethod_cellSize
{
  typedef NSSize (*CellSizeIMP)(id, SEL);
  CellSizeIMP originalIMP = (CellSizeIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSliderCell class]);
  WinUITheme *theme = WinUIThemeCellSizesTheme();
  NSSliderCell *cell = (NSSliderCell *)self;
  NSSize size = (originalIMP != NULL) ? originalIMP(self, _cmd) : NSZeroSize;
  CGFloat target;

  if (theme == nil || [cell sliderType] != NSLinearSlider)
    {
      return size;
    }
  target = MAX(WinUIThemeButtonHeightForFont(theme, nil),
               round(20.0 * MAX(1.0, [[theme settings] desktopScaleFactor])) + 4.0);
  if ([cell isVertical] == 1)
    {
      size.width = MAX(size.width, target);
    }
  else
    {
      size.height = MAX(size.height, target);
    }
  return size;
}

/* A TextBox (a bezelled or bordered field, editable or not): a push
   button's height for its font. Labels and table headers keep libs-gui's
   size. */
- (NSSize) _overrideNSTextFieldCellMethod_cellSize
{
  typedef NSSize (*CellSizeIMP)(id, SEL);
  CellSizeIMP originalIMP = (CellSizeIMP)WinUIThemeOriginalMethod(_cmd, self, [NSTextFieldCell class]);
  WinUITheme *theme = WinUIThemeCellSizesTheme();
  NSTextFieldCell *cell = (NSTextFieldCell *)self;
  NSSize size = (originalIMP != NULL) ? originalIMP(self, _cmd) : NSZeroSize;

  if (theme != nil && ([cell isBezeled] || [cell isBordered])
      && [cell isKindOfClass: [NSTableHeaderCell class]] == NO)
    {
      size.height = MAX(size.height, WinUIThemeButtonHeightForFont(theme, [cell font]));
    }
  return size;
}

@end
