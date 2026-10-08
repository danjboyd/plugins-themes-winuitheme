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

/* NSBrowser as WinUI draws lists side by side (#58), after the reference
   app's More Surfaces page: each column a ListView on a card (the card
   colour inside a hairline stroke, 4pt corners, 8pt apart), rows at least
   32pt with the text 12pt in from the item, the selection ListView's
   subtle fill with its 3x16pt accent pill, and a chevron in the secondary
   text colour on branch rows. libs-gui drew bezelled columns, a saturated
   full-width selection with white text, its own arrows, and a heavy
   horizontal scroller under the columns even when they all fit. Now that
   scroller shows only while there are columns to scroll to, as WinUI's
   thin bar (#29); the columns' own scroll bars are already the theme's. */

static const CGFloat WinUIThemeBrowserRowHeight = 32.0;
static const CGFloat WinUIThemeBrowserColumnGap = 8.0;
static const CGFloat WinUIThemeBrowserTextInset = 12.0;
/* A column title's text at its rows' text edge: the row's 4pt item inset
   and 12pt text inset, plus the column scroll view's 2pt bezel border,
   less the 3pt that NSCell's -titleRectForBounds: adds for a bezelled cell
   (title cells call themselves bezelled). */
static const CGFloat WinUIThemeBrowserTitleInset = 4.0 + 12.0 + 2.0 - 3.0;

@interface NSCell (WinUIThemeBrowserPrivate)
- (BOOL) _inEditing;
@end


/* YES when every loaded column is on view, so there's nothing to scroll
   to. */
static BOOL
WinUIThemeBrowserColumnsFit(NSBrowser *browser)
{
  return [browser firstVisibleColumn] == 0 && [browser lastColumn] < [browser numberOfVisibleColumns];
}

static WinUITheme *
WinUIThemeBrowserTheme(void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [WinUITheme class]] ? (WinUITheme *)theme : nil;
}

/* CardBackgroundFillColorDefault over the window: white at 70% (5% in
   the dark palette). High contrast keeps the window colour. */
NSColor *
WinUIThemeBrowserCardColor(WinUITheme *theme)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *window = WinUIThemeColorFromTheme(theme, @"windowBackgroundColor", [NSColor windowBackgroundColor]);

  if ([[theme settings] highContrastEnabled])
    {
      return window;
    }
  return WinUIThemeBlendColor(window, [NSColor whiteColor], dark ? 0.05 : 0.70);
}

/* CardStrokeColorDefault, made visible against a white page. */
NSColor *
WinUIThemeCardStrokeColor(WinUITheme *theme)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];

  if ([[theme settings] highContrastEnabled])
    {
      return WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
    }
  return WinUIThemeBlendColor(WinUIThemeBrowserCardColor(theme),
                              dark ? [NSColor whiteColor] : [NSColor blackColor], dark ? 0.10 : 0.09);
}

/* YES for one of a browser's column scroll views. */
BOOL
WinUIThemeIsBrowserColumn(NSView *view)
{
  return [view isKindOfClass: [NSScrollView class]] && [[view superview] isKindOfClass: [NSBrowser class]];
}

/* A column's card, in its border. */
void
WinUIThemeDrawBrowserColumnCard(WinUITheme *theme, NSRect frame)
{
  WinUIThemeFillAndStrokeRoundedRect(NSInsetRect(NSIntegralRect(frame), 0.5, 0.5),
                                     WinUIThemeControlCornerRadius(theme),
                                     WinUIThemeBrowserCardColor(theme),
                                     WinUIThemeCardStrokeColor(theme), 1.0);
}

static NSScroller *
WinUIThemeBrowserScroller(NSBrowser *browser)
{
  Ivar ivar = class_getInstanceVariable([NSBrowser class], "_horizontalScroller");

  return (ivar != NULL) ? (NSScroller *)object_getIvar(browser, ivar) : nil;
}

/* A right-pointing chevron, 4x8pt, centred on `centre`. */
static void
WinUIThemeDrawBranchChevron(NSPoint centre, NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];

  [path moveToPoint: NSMakePoint(centre.x - 2.0, centre.y - 4.0)];
  [path lineToPoint: NSMakePoint(centre.x + 2.0, centre.y)];
  [path lineToPoint: NSMakePoint(centre.x - 2.0, centre.y + 4.0)];
  [path setLineWidth: 1.3];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [color set];
  [path stroke];
}

/* Body Strong, smaller only where Windows' text size would otherwise
   overflow NSBrowser's fixed 21pt title height. */
static NSFont *
WinUIThemeBrowserTitleFont(WinUITheme *theme, NSFont *font, CGFloat height)
{
  NSFont *body = WinUIThemePreferredControlFont(theme, font, NO);
  CGFloat size = [body pointSize];
  NSFont *strong = WinUIThemeSemiboldFont(body, size);

  while (strong != nil && size > 9.0 && ceil([strong defaultLineHeightForFont]) > height)
    {
      size -= 1.0;
      strong = WinUIThemeSemiboldFont(body, size);
    }
  return (strong != nil) ? strong : font;
}

@implementation WinUITheme (Browser)

- (CGFloat) browserColumnSeparation
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  if ([defaults objectForKey: @"GSBrowserColumnSeparation"] != nil)
    {
      return [defaults floatForKey: @"GSBrowserColumnSeparation"];
    }
  return WinUIThemeBrowserColumnGap;
}

/* Titles only: no bezel round the horizontal scroller, no column
   borders; the columns' scroll views draw their cards. */
- (void) drawBrowserRect: (NSRect)rect
                  inView: (NSView *)view
        withScrollerRect: (NSRect)scrollerRect
              columnSize: (NSSize)columnSize
{
  NSBrowser *browser = (NSBrowser *)view;
  NSInteger column;

  (void)scrollerRect;
  (void)columnSize;
  if ([browser isLoaded] == NO)
    {
      [browser loadColumnZero];
    }
  if ([browser isTitled] == NO)
    {
      return;
    }
  for (column = [browser firstVisibleColumn]; column <= [browser lastVisibleColumn]; column++)
    {
      NSRect titleRect = [browser titleFrameOfColumn: column];

      if (NSIntersectsRect(titleRect, rect))
        {
          [browser drawTitleOfColumn: column inRect: titleRect];
        }
    }
}

/* Column titles (#74), and the font panel's "Size" label, which uses the
   same cell: WinUI has no titled list column, so they're drawn as its
   section labels, Body Strong in the secondary text colour on the
   window, no bezel, at the rows' text edge. libs-gui drew its grey bezel
   behind them (the theme has no GSBrowserHeader tiles). */
- (NSColor *) browserHeaderTextColor
{
  return WinUIThemeColorFromTheme(self, @"secondaryLabelColor", [NSColor controlTextColor]);
}

/* Nothing behind the title. The cell is shared by every browser and set
   up once (the font panel's label by the panel), so its colour, font and
   alignment follow the theme here, before its text is drawn. */
- (void) drawBrowserHeaderCell: (NSTableHeaderCell *)cell
                     withFrame: (NSRect)rect
                        inView: (NSView *)view
{
  NSColor *color = [self browserHeaderTextColor];
  NSFont *font = WinUIThemeBrowserTitleFont(self, [cell font], NSHeight(rect));

  (void)view;
  if ([cell alignment] == WinUIThemeCenterTextAlignment())
    {
      [cell setAlignment: NSLeftTextAlignment];
    }
  if ([[cell textColor] isEqual: color] == NO)
    {
      [cell setTextColor: color];
    }
  if (font != nil && [[cell font] isEqual: font] == NO)
    {
      [cell setFont: font];
    }
}

/* The title's full height, its text at the rows' text edge. */
- (NSRect) browserHeaderDrawingRectForCell: (NSTableHeaderCell *)cell
                                 withFrame: (NSRect)rect
{
  (void)cell;
  rect.origin.x += WinUIThemeBrowserTitleInset;
  rect.size.width = MAX(0.0, NSWidth(rect) - WinUIThemeBrowserTitleInset);
  return rect;
}

/* A row: the selection (subtle fill and accent pill), the cell's image,
   its title from 12pt in, and a chevron on a branch. */
- (void) drawBrowserInteriorWithFrame: (NSRect)cellFrame
                             withCell: (NSBrowserCell *)cell
                               inView: (NSView *)controlView
                            withImage: (NSImage *)theImage
                       alternateImage: (NSImage *)alternateImage
                        isHighlighted: (BOOL)isHighlighted
                                state: (int)state
                               isLeaf: (BOOL)isLeaf
{
  BOOL dark = [[self settings] prefersDarkAppearance];
  BOOL highContrast = [[self settings] highContrastEnabled];
  BOOL selected = (isHighlighted || state != 0);
  BOOL enabled = [cell isEnabled];
  BOOL active = ([controlView window] == nil || [[controlView window] isKeyWindow]);
  NSRect item = NSInsetRect(cellFrame, 4.0, NSHeight(cellFrame) > 20.0 ? 2.0 : 1.0);
  NSRect titleRect = item;
  NSImage *image = (selected && alternateImage != nil) ? alternateImage : theImage;
  NSColor *textColor = enabled
    ? WinUIThemeColorFromTheme(self, @"labelColor", [NSColor controlTextColor])
    : WinUIThemeColorFromTheme(self, @"disabledControlTextColor", [NSColor disabledControlTextColor]);
  NSColor *chevron = WinUIThemeColorFromTheme(self, @"secondaryLabelColor", textColor);
  NSMutableParagraphStyle *style = nil;
  NSDictionary *attributes = nil;
  NSString *title = nil;
  NSSize titleSize;

  if (selected)
    {
      if (highContrast)
        {
          [WinUIThemeColorFromTheme(self, @"selectedTextBackgroundColor", [NSColor selectedTextBackgroundColor]) set];
          NSRectFill(cellFrame);
          textColor = chevron = WinUIThemeColorFromTheme(self, @"selectedTextColor", [NSColor selectedTextColor]);
        }
      else
        {
          NSColor *fill = WinUIThemeBlendColor(WinUIThemeBrowserCardColor(self),
                                               dark ? [NSColor whiteColor] : [NSColor blackColor],
                                               dark ? 0.06 : 0.037);
          CGFloat pillHeight = MIN(16.0, MAX(6.0, NSHeight(item) - 8.0));
          NSRect pill = NSMakeRect(NSMinX(item), floor(NSMidY(item) - pillHeight / 2.0), 3.0, pillHeight);

          [fill set];
          [WinUIThemeRoundedPath(item, WinUIThemeControlCornerRadius(self)) fill];
          [(active ? WinUIThemeColorFromTheme(self, @"accentColor", [NSColor selectedControlColor])
                   : chevron) set];
          [WinUIThemeRoundedPath(pill, 1.5) fill];
        }
    }

  titleRect.origin.x += WinUIThemeBrowserTextInset;
  titleRect.size.width -= WinUIThemeBrowserTextInset;
  if (isLeaf == NO)
    {
      WinUIThemeDrawBranchChevron(NSMakePoint(NSMaxX(item) - 12.0, floor(NSMidY(item)) + 0.5), chevron);
      titleRect.size.width -= 24.0;
    }

  /* A file browser's icon: no taller than the row allows, before the
     title. */
  if (image != nil)
    {
      NSSize size = [image size];
      CGFloat side = MIN(20.0, NSHeight(item) - 4.0);
      CGFloat scale = (size.width > 0.0 && size.height > 0.0)
        ? MIN(1.0, MIN(side / size.width, side / size.height)) : 1.0;
      NSRect imageRect = NSMakeRect(NSMinX(titleRect), 0.0, floor(size.width * scale), floor(size.height * scale));

      imageRect.origin.y = floor(NSMidY(item) - NSHeight(imageRect) / 2.0);
      if (controlView != nil)
        {
          imageRect = [controlView centerScanRect: imageRect];
        }
      [image drawInRect: imageRect
               fromRect: NSZeroRect
              operation: NSCompositeSourceOver
               fraction: enabled ? 1.0 : 0.5
         respectFlipped: YES
                  hints: nil];
      titleRect.origin.x += NSWidth(imageRect) + 8.0;
      titleRect.size.width -= NSWidth(imageRect) + 8.0;
    }

  if ([cell _inEditing])
    {
      [self drawEditorForCell: cell withFrame: cellFrame inView: controlView];
      return;
    }
  title = [cell stringValue];
  if ([title length] == 0 || NSWidth(titleRect) <= 0.0)
    {
      return;
    }
  style = AUTORELEASE([[NSMutableParagraphStyle alloc] init]);
  [style setLineBreakMode: NSLineBreakByTruncatingTail];
  attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                               WinUIThemePreferredControlFont(self, [cell font], NO), NSFontAttributeName,
                               textColor, NSForegroundColorAttributeName,
                               style, NSParagraphStyleAttributeName, nil];
  titleSize = [title sizeWithAttributes: attributes];
  titleRect.origin.y = floor(NSMidY(item) - titleSize.height / 2.0);
  titleRect.size.height = titleSize.height;
  [title drawInRect: titleRect withAttributes: attributes];
}

/* Rows at least 32pt, as the theme's lists. */
- (NSSize) _overrideNSBrowserCellMethod_cellSize
{
  typedef NSSize (*SizeIMP)(id, SEL);
  SizeIMP originalIMP = (SizeIMP)WinUIThemeOriginalMethod(_cmd, self, [NSBrowserCell class]);
  NSSize size = (originalIMP != NULL) ? originalIMP(self, _cmd) : NSZeroSize;
  WinUITheme *theme = WinUIThemeBrowserTheme();

  if (theme != nil)
    {
      NSFont *font = WinUIThemePreferredControlFont(theme, [(NSCell *)self font], NO);

      size.height = MAX(size.height, MAX(WinUIThemeBrowserRowHeight,
                                         ceil([font defaultLineHeightForFont]) + 12.0));
    }
  return size;
}

/* A browser column's scroll view, as libs-gui places it (its -tile sets
   every visible column's frame). When every column fits, the horizontal
   scroller hides and the column takes its strip down to the browser's
   foot. These are scroll view methods, not NSBrowser's: overriding
   NSBrowser's would have GSTheme run +[NSBrowser initialize] as it loads
   the theme, and the title cell made there fixed the system font before
   the theme's fonts were set. */
- (void) _overrideNSScrollViewMethod_setFrame: (NSRect)frame
{
  typedef void (*FrameIMP)(id, SEL, NSRect);
  FrameIMP originalIMP = (FrameIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScrollView class]);
  NSView *superview = [(NSView *)self superview];

  if (WinUIThemeBrowserTheme() != nil && [superview isKindOfClass: [NSBrowser class]])
    {
      NSBrowser *browser = (NSBrowser *)superview;
      NSScroller *scroller = WinUIThemeBrowserScroller(browser);

      if (scroller != nil && [browser hasHorizontalScroller])
        {
          BOOL fits = WinUIThemeBrowserColumnsFit(browser);

          if ([scroller isHidden] != fits)
            {
              [scroller setHidden: fits];
              [browser setNeedsDisplay: YES];
            }
          if (fits)
            {
              if ([browser isFlipped])
                {
                  frame.size.height = NSHeight([browser bounds]) - NSMinY(frame);
                }
              else
                {
                  frame.size.height = NSMaxY(frame);
                  frame.origin.y = 0.0;
                }
            }
        }
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, frame);
    }
}

@end

/* A browser column's background, behind and below its rows: the card.
   libs-gui gives the column's matrix the browser's -backgroundColor,
   controlColor. Called from the scroll view's -tile, which follows its
   -setDocumentView:. */
void
WinUIThemeSyncBrowserColumn(NSScrollView *scrollView)
{
  WinUITheme *theme = WinUIThemeBrowserTheme();
  NSColor *card = nil;
  id documentView = nil;

  if (theme == nil || WinUIThemeIsBrowserColumn(scrollView) == NO)
    {
      return;
    }
  card = WinUIThemeBrowserCardColor(theme);
  if ([[scrollView backgroundColor] isEqual: card] == NO)
    {
      [scrollView setBackgroundColor: card];
    }
  if ([scrollView drawsBackground] == NO)
    {
      [scrollView setDrawsBackground: YES];
    }

  documentView = [scrollView documentView];
  if ([documentView isKindOfClass: [NSMatrix class]] && [[documentView backgroundColor] isEqual: card] == NO)
    {
      [documentView setBackgroundColor: card];
    }
}
