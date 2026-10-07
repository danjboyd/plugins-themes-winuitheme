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

/* NSLevelIndicator as WinUI draws levels (#57). libs-gui fills a square
   white well with green, yellow or red; with the warning and critical
   values left at 0, as most apps leave them, every level is red. */

typedef enum
{
  WinUIThemeLevelNormal,
  WinUIThemeLevelCaution,
  WinUIThemeLevelCritical
} WinUIThemeLevelState;

/* The bar's depth and the gap between discrete segments. */
static const CGFloat WinUIThemeLevelThickness = 3.0;
static const CGFloat WinUIThemeLevelSegmentGap = 2.0;
/* Room for tick marks, on their side of the bar. */
static const CGFloat WinUIThemeLevelTickSpace = 6.0;
/* RatingControl's 16px stars, 8px apart. */
static const CGFloat WinUIThemeRatingStarSize = 16.0;
static const CGFloat WinUIThemeRatingSpacing = 8.0;

/* A threshold left at 0 is unset. When both are set and the warning is
   above the critical value, low levels are the bad ones, as in AppKit. */
static WinUIThemeLevelState
WinUIThemeLevelStateFor(double value, double warning, double critical)
{
  BOOL hasWarning = (warning != 0.0);
  BOOL hasCritical = (critical != 0.0);

  if (hasWarning && hasCritical && warning > critical)
    {
      if (value <= critical)
        {
          return WinUIThemeLevelCritical;
        }
      return (value <= warning) ? WinUIThemeLevelCaution : WinUIThemeLevelNormal;
    }
  if (hasCritical && value >= critical)
    {
      return WinUIThemeLevelCritical;
    }
  if (hasWarning && value >= warning)
    {
      return WinUIThemeLevelCaution;
    }
  return WinUIThemeLevelNormal;
}

/* SystemFillColorCaution and SystemFillColorCritical. High contrast keeps
   the highlight colour, as its ProgressBar does. */
static NSColor *
WinUIThemeLevelColor(WinUITheme *theme, WinUIThemeLevelState state, BOOL enabled, NSColor *value)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];

  if (state == WinUIThemeLevelNormal || enabled == NO || [[theme settings] highContrastEnabled])
    {
      return value;
    }
  if (state == WinUIThemeLevelCaution)
    {
      return dark ? [NSColor colorWithCalibratedRed: 0xFC / 255.0 green: 0xE1 / 255.0 blue: 0x00 / 255.0 alpha: 1.0]
                  : [NSColor colorWithCalibratedRed: 0x9D / 255.0 green: 0x5D / 255.0 blue: 0x00 / 255.0 alpha: 1.0];
    }
  return dark ? [NSColor colorWithCalibratedRed: 0xFF / 255.0 green: 0x99 / 255.0 blue: 0xA4 / 255.0 alpha: 1.0]
              : [NSColor colorWithCalibratedRed: 0xC4 / 255.0 green: 0x2B / 255.0 blue: 0x1C / 255.0 alpha: 1.0];
}

/* `length` of `area` along the bar, from its start: the left, or the
   bottom of a vertical bar. */
static NSRect
WinUIThemeLevelPart(NSRect area, BOOL vertical, BOOL flipped, CGFloat start, CGFloat length)
{
  if (vertical)
    {
      area.origin.y = flipped ? NSMaxY(area) - start - length : NSMinY(area) + start;
      area.size.height = length;
    }
  else
    {
      area.origin.x += start;
      area.size.width = length;
    }
  return area;
}

/* A five-pointed star filling `rect`, point up. */
static NSBezierPath *
WinUIThemeStarPath(NSRect rect, BOOL flipped)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat outer = MIN(NSWidth(rect), NSHeight(rect)) / 2.0;
  CGFloat inner = outer * 0.48;
  /* The star's points span 1.81 outer radii from top to bottom: centre it. */
  NSPoint centre = NSMakePoint(NSMidX(rect), NSMidY(rect) + (flipped ? 1.0 : -1.0) * outer * 0.095);
  NSInteger index;

  for (index = 0; index < 10; index++)
    {
      CGFloat radius = (index % 2 == 0) ? outer : inner;
      CGFloat angle = M_PI / 2.0 + index * M_PI / 5.0;
      NSPoint point = NSMakePoint(centre.x + radius * cos(angle),
                                  centre.y + (flipped ? -1.0 : 1.0) * radius * sin(angle));

      if (index == 0)
        {
          [path moveToPoint: point];
        }
      else
        {
          [path lineToPoint: point];
        }
    }
  [path closePath];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  return path;
}

/* RatingControl: accent stars up to the value (part of one for a
   fraction), outlines after. */
static void
WinUIThemeDrawRating(NSRect frame, BOOL flipped, NSInteger count, double rating,
                     NSColor *filled, NSColor *empty)
{
  CGFloat size = MIN(WinUIThemeRatingStarSize, NSHeight(frame) - 2.0);
  CGFloat step = size + WinUIThemeRatingSpacing;
  NSInteger index;

  if (count <= 0 || size <= 2.0)
    {
      return;
    }
  /* Squeeze the spacing, then the stars, into a narrow frame. */
  if (count * step - WinUIThemeRatingSpacing > NSWidth(frame))
    {
      step = NSWidth(frame) / count;
      size = MIN(size, step - 1.0);
    }
  for (index = 0; index < count; index++)
    {
      NSRect starRect = NSMakeRect(NSMinX(frame) + index * step,
                                   floor(NSMidY(frame) - size / 2.0), size, size);
      NSBezierPath *star = WinUIThemeStarPath(starRect, flipped);
      double part = WinUIThemeClamp(rating - index, 0.0, 1.0);

      if (part < 1.0)
        {
          [empty set];
          [star setLineWidth: 1.0];
          [star stroke];
        }
      if (part > 0.0)
        {
          [NSGraphicsContext saveGraphicsState];
          NSRectClip(NSMakeRect(NSMinX(starRect) - 1.0, NSMinY(starRect) - 1.0,
                                1.0 + NSWidth(starRect) * part, NSHeight(starRect) + 2.0));
          [filled set];
          [star fill];
          [NSGraphicsContext restoreGraphicsState];
        }
    }
}

@implementation WinUITheme (LevelIndicator)

- (void) _overrideNSLevelIndicatorCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                            inView: (NSView *)controlView
{
  typedef void (*DrawIMP)(id, SEL, NSRect, NSView *);
  DrawIMP originalIMP = (DrawIMP)WinUIThemeOriginalMethod(_cmd, self, [NSLevelIndicatorCell class]);
  NSLevelIndicatorCell *cell = (NSLevelIndicatorCell *)self;
  GSTheme *active = [GSTheme theme];
  WinUITheme *theme = [active isKindOfClass: [WinUITheme class]] ? (WinUITheme *)active : nil;
  NSLevelIndicatorStyle style = [cell style];
  BOOL enabled = [cell isEnabled];
  BOOL flipped = [controlView isFlipped];
  BOOL vertical = NSHeight(cellFrame) > NSWidth(cellFrame);
  double minimum = [cell minValue];
  double maximum = [cell maxValue];
  double value = [cell doubleValue];
  double fraction = (maximum > minimum) ? WinUIThemeClamp((value - minimum) / (maximum - minimum), 0.0, 1.0) : 0.0;
  NSInteger ticks = [cell numberOfTickMarks];
  Ivar frameIvar = class_getInstanceVariable([NSLevelIndicatorCell class], "_cellFrame");
  NSColor *track = nil;
  NSColor *accent = nil;
  NSColor *bar = nil;
  NSRect area = cellFrame;
  NSRect lane;
  CGFloat length;

  /* An app's own rating image is drawn as libs-gui draws it. */
  if (theme == nil || (style == NSRatingLevelIndicatorStyle && [cell image] != nil))
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }
  /* -rectOfTickMarkAtIndex: measures from the frame last drawn. */
  if (frameIvar != NULL)
    {
      *(NSRect *)((char *)self + ivar_getOffset(frameIvar)) = cellFrame;
    }

  WinUIThemeRangeColors(theme, enabled, &track, &accent, NULL, NULL, NULL);

  if (style == NSRatingLevelIndicatorStyle)
    {
      WinUIThemeDrawRating(cellFrame, flipped, (NSInteger)ceil(maximum - minimum),
                           value - minimum, accent, track);
      return;
    }

  /* Tick marks, 4pt long, beside the bar (libs-gui draws them only for a
     horizontal indicator, and so does this). */
  if (ticks > 0 && vertical == NO)
    {
      BOOL below = ([cell tickMarkPosition] == NSTickMarkBelow);
      BOOL atMaxY = (below == flipped);
      CGFloat tickY;
      NSInteger index;

      NSDivideRect(cellFrame, &lane, &area, WinUIThemeLevelTickSpace, atMaxY ? NSMaxYEdge : NSMinYEdge);
      tickY = NSMinY(lane) + 1.0;
      [track set];
      for (index = 0; index < ticks; index++)
        {
          CGFloat x = (ticks > 1)
            ? NSMinX(cellFrame) + floor(index * (NSWidth(cellFrame) - 1.0) / (ticks - 1))
            : floor(NSMidX(cellFrame));

          NSRectFill(NSMakeRect(x, tickY, 1.0, 4.0));
        }
    }

  /* The bar's lane, centred across what's left. */
  if (vertical)
    {
      lane = NSMakeRect(floor(NSMidX(area) - WinUIThemeLevelThickness / 2.0), NSMinY(area),
                        WinUIThemeLevelThickness, NSHeight(area));
      length = NSHeight(lane);
    }
  else
    {
      lane = NSMakeRect(NSMinX(area), floor(NSMidY(area) - WinUIThemeLevelThickness / 2.0),
                        NSWidth(area), WinUIThemeLevelThickness);
      length = NSWidth(lane);
    }

  if (style == NSRelevancyLevelIndicatorStyle)
    {
      NSRect fill = WinUIThemeLevelPart(lane, vertical, flipped, 0.0, floor(length * fraction));

      bar = enabled
        ? WinUIThemeColorFromTheme(theme, @"secondaryLabelColor", [NSColor darkGrayColor])
        : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor", [NSColor disabledControlTextColor]);
      if (NSWidth(fill) > 0.0 && NSHeight(fill) > 0.0)
        {
          WinUIThemeFillAndStrokeRoundedRect(fill, WinUIThemeLevelThickness / 2.0, bar, nil, 0.0);
        }
      return;
    }

  bar = WinUIThemeLevelColor(theme,
                             WinUIThemeLevelStateFor(value, [cell warningValue], [cell criticalValue]),
                             enabled, accent);

  if (style == NSDiscreteCapacityLevelIndicatorStyle)
    {
      NSInteger segments = (NSInteger)(maximum - minimum);
      CGFloat step = (segments > 0) ? (length + WinUIThemeLevelSegmentGap) / segments : 0.0;

      if (segments > 0 && step > WinUIThemeLevelSegmentGap + 1.0)
        {
          NSInteger filled = (NSInteger)(fraction * segments + 0.5);
          NSInteger index;

          for (index = 0; index < segments; index++)
            {
              CGFloat start = floor(index * step);
              CGFloat end = floor((index + 1) * step) - WinUIThemeLevelSegmentGap;
              NSRect segment = WinUIThemeLevelPart(lane, vertical, flipped, start, end - start);

              if (index < filled)
                {
                  WinUIThemeFillAndStrokeRoundedRect(segment, WinUIThemeLevelThickness / 2.0, bar, nil, 0.0);
                }
              else
                {
                  [track set];
                  NSRectFill(vertical ? NSInsetRect(segment, 1.0, 0.0) : NSInsetRect(segment, 0.0, 1.0));
                }
            }
          return;
        }
      /* Too many segments to tell apart: a continuous bar. */
    }

  /* ProgressBar: a 1pt track line through the lane, a 3pt rounded bar
     over it. */
  [track set];
  NSRectFill(vertical ? NSInsetRect(lane, 1.0, 0.0) : NSInsetRect(lane, 0.0, 1.0));
  lane = WinUIThemeLevelPart(lane, vertical, flipped, 0.0, floor(length * fraction));
  if (NSWidth(lane) > 0.0 && NSHeight(lane) > 0.0)
    {
      WinUIThemeFillAndStrokeRoundedRect(lane, WinUIThemeLevelThickness / 2.0, bar, nil, 0.0);
    }
}

@end
