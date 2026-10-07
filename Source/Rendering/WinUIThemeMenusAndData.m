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
#import "../Native/WinUIThemeWindowIntegration.h"

#import "../Settings/WinUIThemeMetrics.h"
#import "../Settings/WinUIThemeSettings.h"

#import <AppKit/NSBezierPath.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSMenuItemCell.h>
#import <AppKit/NSMenuView.h>
#import <AppKit/NSOutlineView.h>
#import <AppKit/NSParagraphStyle.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSTabView.h>
#import <AppKit/NSTabViewItem.h>
#import <AppKit/NSTableColumn.h>
#import <AppKit/NSTableHeaderCell.h>
#import <AppKit/NSTableHeaderView.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSWindow.h>

#import <math.h>
#import <objc/runtime.h>

static void
WinUIThemeMenuTrace(NSString *message)
{
  static NSUInteger traceCount = 0;
  NSString *path = nil;
  NSFileHandle *handle = nil;
  NSData *data = nil;

  if (message == nil || traceCount > 200)
    {
      return;
    }

  traceCount++;
  path = [NSTemporaryDirectory() stringByAppendingPathComponent: @"WinUITheme-menu-trace.log"];
  if ([[NSFileManager defaultManager] fileExistsAtPath: path] == NO)
    {
      [[NSData data] writeToFile: path atomically: YES];
    }

  handle = [NSFileHandle fileHandleForWritingAtPath: path];
  if (handle == nil)
    {
      return;
    }

  [handle seekToEndOfFile];
  data = [[message stringByAppendingString: @"\r\n"] dataUsingEncoding: NSUTF8StringEncoding];
  if (data != nil)
    {
      [handle writeData: data];
    }
  [handle closeFile];
}

@interface NSMenuItemCell (WinUIThemeMenuCellPrivate)
- (NSString *) _keyEquivalentString;
- (void) _drawAttributedText: (NSAttributedString *)string
                     inFrame: (NSRect)cellFrame;
- (void) _drawText: (NSString *)title
           inFrame: (NSRect)cellFrame;
@end

typedef enum
{
  WinUIThemeMenuChevronUp = 0,
  WinUIThemeMenuChevronDown,
  WinUIThemeMenuChevronLeft,
  WinUIThemeMenuChevronRight
} WinUIThemeMenuChevronDirection;

/* Space between a menu bar title and its item's edges, and the pad
   NSMenuView already puts there (its _horizontalEdgePad). */
static const CGFloat WinUIThemeMenuBarTitleInset = 8.0;
static const CGFloat WinUIThemeMenuViewHorizontalEdgePad = 4.0;
/* A flyout item's space between its text and accelerator, and after it. */
static const CGFloat WinUIThemeMenuKeyEquivalentGap = 24.0;
static const CGFloat WinUIThemeMenuKeyEquivalentTrailing = 8.0;

static CGFloat
WinUIThemeMinimumMenuFontSize(BOOL horizontal)
{
  return horizontal ? 13.0 : 13.0;
}

static NSFont *
WinUIThemeFontWithMinimumSize(NSFont *font, CGFloat minimumSize)
{
  NSFontManager *fontManager = nil;
  NSFont *resolvedFont = nil;
  NSString *fontName = nil;
  NSString *familyName = nil;
  CGFloat pointSize = 0.0;

  if (font == nil)
    {
      return nil;
    }

  pointSize = MAX(minimumSize, [font pointSize]);
  if (fabs(pointSize - [font pointSize]) < 0.01)
    {
      return font;
    }

  fontName = [font fontName];
  if ([fontName length] > 0)
    {
      resolvedFont = [NSFont fontWithName: fontName size: pointSize];
      if (resolvedFont != nil)
        {
          return resolvedFont;
        }
    }

  familyName = [font familyName];
  fontManager = [NSFontManager sharedFontManager];
  if (fontManager != nil && [familyName length] > 0)
    {
      resolvedFont = [fontManager fontWithFamily: familyName
                                          traits: 0
                                          weight: 5
                                            size: pointSize];
      if (resolvedFont != nil)
        {
          return resolvedFont;
        }
    }

  return [NSFont systemFontOfSize: pointSize];
}

static NSFont *
WinUIThemeResolvedMenuTextFont(WinUITheme *theme,
                               NSFont *font,
                               BOOL horizontal,
                               BOOL popupOwned)
{
  CGFloat minimumSize = WinUIThemeMinimumMenuFontSize(horizontal);

  if ((font == nil || [font pointSize] + 0.01 < minimumSize)
      && theme != nil
      && [theme isKindOfClass: [WinUITheme class]])
    {
      font = (popupOwned
              ? [[theme settings] interfaceFont]
              : (horizontal
                 ? [[theme settings] menuBarFont]
                 : [[theme settings] menuFont]));
    }
  if (font == nil)
    {
      font = [NSFont systemFontOfSize: MAX([NSFont systemFontSize], minimumSize)];
    }

  return WinUIThemeFontWithMinimumSize(font, minimumSize);
}

static NSDictionary *
WinUIThemeMenuTextAttributes(NSFont *font,
                             NSColor *textColor,
                             NSTextAlignment alignment)
{
  NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];

  [style setAlignment: alignment];
  [style setLineBreakMode: NSLineBreakByTruncatingTail];

  return [NSDictionary dictionaryWithObjectsAndKeys:
                         (font != nil ? font : [NSFont systemFontOfSize: [NSFont systemFontSize]]),
                         NSFontAttributeName,
                         (textColor != nil ? textColor : [NSColor controlTextColor]),
                         NSForegroundColorAttributeName,
                         style,
                         NSParagraphStyleAttributeName,
                         nil];
}

static BOOL
WinUIThemeViewIsActive(NSView *view)
{
  NSWindow *window = [view window];

  return (window != nil ? [window isKeyWindow] : NO);
}

static void
WinUIThemeDrawMenuChevron(NSRect rect,
                          WinUIThemeMenuChevronDirection direction,
                          NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
  CGFloat width = MAX(4.0, MIN(7.0, floor(MIN(rect.size.width, rect.size.height) * 0.45)));
  CGFloat height = MAX(3.0, width * 0.58);

  switch (direction)
    {
      case WinUIThemeMenuChevronUp:
        [path moveToPoint: NSMakePoint(center.x - (width / 2.0), center.y + (height / 2.0))];
        [path lineToPoint: NSMakePoint(center.x, center.y - (height / 2.0))];
        [path lineToPoint: NSMakePoint(center.x + (width / 2.0), center.y + (height / 2.0))];
        break;

      case WinUIThemeMenuChevronDown:
        [path moveToPoint: NSMakePoint(center.x - (width / 2.0), center.y - (height / 2.0))];
        [path lineToPoint: NSMakePoint(center.x, center.y + (height / 2.0))];
        [path lineToPoint: NSMakePoint(center.x + (width / 2.0), center.y - (height / 2.0))];
        break;

      case WinUIThemeMenuChevronLeft:
        [path moveToPoint: NSMakePoint(center.x + (height / 2.0), center.y - (width / 2.0))];
        [path lineToPoint: NSMakePoint(center.x - (height / 2.0), center.y)];
        [path lineToPoint: NSMakePoint(center.x + (height / 2.0), center.y + (width / 2.0))];
        break;

      case WinUIThemeMenuChevronRight:
      default:
        [path moveToPoint: NSMakePoint(center.x - (height / 2.0), center.y - (width / 2.0))];
        [path lineToPoint: NSMakePoint(center.x + (height / 2.0), center.y)];
        [path lineToPoint: NSMakePoint(center.x - (height / 2.0), center.y + (width / 2.0))];
        break;
    }

  [path setLineWidth: 1.5];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [color set];
  [path stroke];
}

static NSImage *
WinUIThemeCreateDisclosureImage(WinUITheme *theme,
                                WinUIThemeMenuChevronDirection direction,
                                BOOL emphasized)
{
  NSImage *image = [[[NSImage alloc] initWithSize: NSMakeSize(12.0, 12.0)] autorelease];
  NSColor *baseColor = nil;

  if (image == nil)
    {
      return nil;
    }

  baseColor = emphasized
    ? WinUIThemeColorFromTheme(theme, @"accentColor", [NSColor selectedControlColor])
    : WinUIThemeColorFromTheme(theme, @"secondaryLabelColor", [NSColor controlTextColor]);

  [image lockFocus];
  [[NSColor clearColor] set];
  NSRectFill(NSMakeRect(0.0, 0.0, 12.0, 12.0));
  WinUIThemeDrawMenuChevron(NSMakeRect(1.0, 1.0, 10.0, 10.0), direction, baseColor);
  [image unlockFocus];

  return image;
}

static void
WinUIThemeDrawSelectionFill(NSRect frame,
                            CGFloat radius,
                            NSColor *fillColor,
                            NSColor *borderColor)
{
  NSRect drawRect = NSInsetRect(NSIntegralRect(frame), 0.5, 0.5);
  NSBezierPath *path = WinUIThemeRoundedPath(drawRect, radius);

  [fillColor set];
  [path fill];

  if (borderColor != nil)
    {
      [borderColor set];
      [path setLineWidth: 1.0];
      [path stroke];
    }
}

static NSColor *
WinUIThemeDataViewBorderColor(WinUITheme *theme)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *separator = WinUIThemeColorFromTheme(theme,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);

  return WinUIThemeBlendColor(separator,
                              dark ? [NSColor whiteColor] : [NSColor blackColor],
                              dark ? 0.08 : 0.02);
}

static NSColor *
WinUIThemeDataViewRailColor(WinUITheme *theme)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *surface = WinUIThemeColorFromTheme(theme,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *window = WinUIThemeColorFromTheme(theme,
                                             @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);

  return WinUIThemeBlendColor(surface, window, dark ? 0.22 : 0.06);
}

static NSColor *
WinUIThemeSelectionBorderColor(WinUITheme *theme,
                               NSColor *fillColor,
                               BOOL active,
                               BOOL outline)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *separator = WinUIThemeColorFromTheme(theme,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSColor *accent = WinUIThemeColorFromTheme(theme,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);

  if (active)
    {
      return WinUIThemeBlendColor(fillColor,
                                  accent,
                                  outline ? (dark ? 0.34 : 0.38) : (dark ? 0.22 : 0.24));
    }

  return WinUIThemeBlendColor(fillColor,
                              separator,
                              dark ? 0.28 : 0.34);
}

static CGFloat
WinUIThemeMenuCornerRadius(WinUITheme *theme, BOOL horizontal)
{
  CGFloat baseRadius = [[theme metrics] controlCornerRadius];

  (void)baseRadius;
  return horizontal ? WinUIThemeControlCornerRadius(theme) : WinUIThemeOverlayCornerRadius(theme);
}

static CGFloat
WinUIThemeEffectiveMenuCornerRadius(WinUITheme *theme,
                                    BOOL horizontal,
                                    BOOL popupOwned)
{
#ifdef _WIN32
  if (horizontal == NO)
    {
      (void)popupOwned;
      return 0.0;
    }
#else
  (void)popupOwned;
#endif

  return WinUIThemeMenuCornerRadius(theme, horizontal);
}

/* SubtleFillColorSecondary over the flyout or menu bar: black at 3.7% in
   light mode, white at 6% in dark. */
static NSColor *
WinUIThemeMenuItemHoverColor(WinUITheme *theme, BOOL menuBar)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *background = WinUIThemeColorFromTheme(theme,
                                                 menuBar ? @"menuBarBackgroundColor" : @"menuBackgroundColor",
                                                 [NSColor controlBackgroundColor]);

  return WinUIThemeBlendColor(background,
                              dark ? [NSColor whiteColor] : [NSColor blackColor],
                              dark ? 0.06 : 0.037);
}

static BOOL
WinUIThemeMenuViewOwnedByPopup(NSMenuView *menuView)
{
  SEL selector = NSSelectorFromString(@"_ownedByPopUp");
  id menu = nil;
  IMP implementation = NULL;

  if (menuView == nil || [menuView respondsToSelector: @selector(menu)] == NO)
    {
      return NO;
    }

  menu = [menuView menu];
  if (menu == nil || [menu respondsToSelector: selector] == NO)
    {
      return NO;
    }

  implementation = [menu methodForSelector: selector];
  if (implementation == NULL)
    {
      return NO;
    }

  return ((BOOL (*)(id, SEL))implementation)(menu, selector);
}

static id
WinUIThemePopupOwningCellForMenuView(NSMenuView *menuView)
{
  SEL selector = NSSelectorFromString(@"_owningPopUp");
  id menu = nil;
  IMP implementation = NULL;

  if (menuView == nil || [menuView respondsToSelector: @selector(menu)] == NO)
    {
      return nil;
    }

  menu = [menuView menu];
  if (menu == nil || [menu respondsToSelector: selector] == NO)
    {
      return nil;
    }

  implementation = [menu methodForSelector: selector];
  if (implementation == NULL)
    {
      return nil;
    }

  return ((id (*)(id, SEL))implementation)(menu, selector);
}

static NSFont *
WinUIThemePopupMenuTextFont(WinUITheme *theme, NSView *controlView)
{
  NSMenuView *menuView = nil;
  id popupCell = nil;
  NSFont *font = nil;

  if ([controlView isKindOfClass: [NSMenuView class]] == NO)
    {
      return [[theme settings] interfaceFont];
    }

  menuView = (NSMenuView *)controlView;
  popupCell = WinUIThemePopupOwningCellForMenuView(menuView);
  if (popupCell != nil && [popupCell respondsToSelector: @selector(font)])
    {
      font = [popupCell font];
    }

  return WinUIThemeResolvedMenuTextFont(theme, font, NO, YES);
}

static BOOL
WinUIThemePopupMenuPullsDown(NSMenuView *menuView)
{
  id popupCell = WinUIThemePopupOwningCellForMenuView(menuView);

  if (popupCell == nil || [popupCell respondsToSelector: @selector(pullsDown)] == NO)
    {
      return NO;
    }

  return [(id)popupCell pullsDown];
}

static BOOL
WinUIThemeMenuItemCellOwnedByPopup(NSMenuItemCell *cell, NSView *controlView)
{
  if ([controlView isKindOfClass: [NSMenuView class]])
    {
      return WinUIThemeMenuViewOwnedByPopup((NSMenuView *)controlView);
    }

  (void)cell;
  return NO;
}

static inline BOOL
WinUIThemeUsesPopupButtonCellLayout(NSMenuItemCell *cell)
{
  NSMenuView *menuView = nil;

  if (cell == nil || [cell respondsToSelector: @selector(menuView)] == NO)
    {
      return NO;
    }

  menuView = [cell menuView];
  if (menuView == nil || [menuView isHorizontal])
    {
      return NO;
    }

  return WinUIThemeMenuViewOwnedByPopup(menuView);
}

static NSInteger
WinUIThemePopupMenuItemIndex(NSMenuItemCell *cell, NSView *controlView)
{
  NSMenuView *menuView = nil;
  NSInteger itemCount = 0;
  NSInteger index = 0;

  if (cell == nil
      || [controlView isKindOfClass: [NSMenuView class]] == NO
      || WinUIThemeMenuItemCellOwnedByPopup(cell, controlView) == NO)
    {
      return -1;
    }

  menuView = (NSMenuView *)controlView;
  itemCount = [[menuView menu] numberOfItems];
  for (index = 0; index < itemCount; index++)
    {
      if ([menuView menuItemCellForItemAtIndex: index] == cell)
        {
          return index;
        }
    }

  return -1;
}

static NSString *
WinUIThemePopupButtonDisplayString(NSMenuItemCell *cell)
{
  NSString *title = nil;
  NSInteger selectedIndex = -1;
  id item = nil;

  if (cell == nil || [cell respondsToSelector: @selector(indexOfSelectedItem)] == NO)
    {
      return @"";
    }

  if ([cell respondsToSelector: @selector(selectedItem)])
    {
      item = [(id)cell selectedItem];
      if ([item respondsToSelector: @selector(title)])
        {
          title = [item title];
        }
    }
  if ([title length] == 0 && [cell respondsToSelector: @selector(indexOfSelectedItem)])
    {
      selectedIndex = [(id)cell indexOfSelectedItem];
      if (selectedIndex >= 0 && [cell respondsToSelector: @selector(itemAtIndex:)])
        {
          item = [(id)cell itemAtIndex: selectedIndex];
          if ([item respondsToSelector: @selector(title)])
            {
              title = [item title];
            }
        }
    }
  if ([title length] == 0 && [cell menuItem] != nil)
    {
      title = [[cell menuItem] title];
    }

  return (title != nil) ? title : @"";
}

static NSInteger
WinUIThemePopupMenuHighlightedItemIndex(NSView *controlView)
{
  if ([controlView isKindOfClass: [NSMenuView class]] == NO
      || [controlView respondsToSelector: @selector(highlightedItemIndex)] == NO)
    {
      return -1;
    }

  return [(id)controlView highlightedItemIndex];
}

static BOOL
WinUIThemePopupMenuItemIsHovered(NSMenuItemCell *cell, NSView *controlView)
{
  NSInteger highlightedIndex = -1;
  NSInteger itemIndex = -1;

  if (WinUIThemeMenuItemCellOwnedByPopup(cell, controlView) == NO)
    {
      return NO;
    }

  highlightedIndex = WinUIThemePopupMenuHighlightedItemIndex(controlView);
  itemIndex = WinUIThemePopupMenuItemIndex(cell, controlView);
  return (itemIndex >= 0 && itemIndex == highlightedIndex);
}

static NSRect
WinUIThemePopupMenuAdjustedCellFrame(NSMenuItemCell *cell,
                                     NSView *controlView,
                                     NSRect cellFrame)
{
  NSMenuView *menuView = nil;
  NSInteger itemCount = 0;
  NSInteger itemIndex = -1;
  BOOL flipped = NO;
  CGFloat topInset = 2.0;
  CGFloat bottomInset = 2.0;
  NSRect adjusted = cellFrame;

  if (WinUIThemeMenuItemCellOwnedByPopup(cell, controlView) == NO
      || [controlView isKindOfClass: [NSMenuView class]] == NO)
    {
      return cellFrame;
    }

  menuView = (NSMenuView *)controlView;
  itemCount = [[menuView menu] numberOfItems];
  itemIndex = WinUIThemePopupMenuItemIndex(cell, controlView);
  flipped = [menuView isFlipped];

  adjusted = NSInsetRect(adjusted, 6.0, 0.0);
  if (itemCount > 1)
    {
      if (itemIndex == 0)
        {
          topInset = 3.0;
          bottomInset = 1.0;
        }
      else if (itemIndex == itemCount - 1)
        {
          topInset = 1.0;
          bottomInset = 3.0;
        }
    }

  adjusted.size.height = MAX(0.0, adjusted.size.height - topInset - bottomInset);
  if (flipped)
    {
      adjusted.origin.y += topInset;
    }
  else
    {
      adjusted.origin.y += bottomInset;
    }

  return adjusted;
}

static NSRect
WinUIThemePopupMenuTitleRect(NSMenuItemCell *cell,
                             NSView *controlView,
                             NSRect cellFrame)
{
  NSRect titleRect = WinUIThemePopupMenuAdjustedCellFrame(cell, controlView, cellFrame);
  CGFloat leadingInset = 8.0;
  CGFloat trailingInset = 8.0;

  if ([[cell menuItem] hasSubmenu])
    {
      trailingInset += 12.0;
    }

  titleRect.origin.x += leadingInset;
  titleRect.size.width = MAX(0.0, titleRect.size.width - leadingInset - trailingInset);
  return titleRect;
}

static NSColor *
WinUIThemeMenuSelectionBorderColor(WinUITheme *theme,
                                   NSColor *fillColor,
                                   BOOL horizontal)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *accent = WinUIThemeColorFromTheme(theme,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  NSColor *border = WinUIThemeColorFromTheme(theme,
                                             horizontal ? @"menuBarBorderColor" : @"menuBorderColor",
                                             [NSColor controlShadowColor]);

  return WinUIThemeBlendColor(fillColor,
                              WinUIThemeBlendColor(accent, border, horizontal ? 0.64 : 0.38),
                              horizontal ? (dark ? 0.20 : 0.16) : (dark ? 0.32 : 0.26));
}

static NSColor *
WinUIThemePopupMenuSelectionFillColor(WinUITheme *theme, BOOL enabled)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *background = WinUIThemeColorFromTheme(theme,
                                                 @"menuBackgroundColor",
                                                 [NSColor controlBackgroundColor]);
  NSColor *selection = WinUIThemeColorFromTheme(theme,
                                                @"selectedMenuItemColor",
                                                [NSColor selectedMenuItemColor]);

  if (enabled == NO)
    {
      return WinUIThemeBlendColor(selection, background, dark ? 0.42 : 0.34);
    }

  return selection;
}

static void
WinUIThemePreparePopupMenuTypography(WinUITheme *theme, NSMenuView *menuView)
{
  NSFont *popupFont = nil;
  NSInteger itemCount = 0;
  NSInteger index = 0;

  if (menuView == nil)
    {
      return;
    }

  popupFont = WinUIThemePopupMenuTextFont(theme, menuView);
  if (popupFont == nil)
    {
      return;
    }

  if ([menuView respondsToSelector: @selector(font)]
      && [[menuView font] isEqual: popupFont] == NO)
    {
      [menuView setFont: popupFont];
    }

  itemCount = [[menuView menu] numberOfItems];
  for (index = 0; index < itemCount; index++)
    {
      NSMenuItemCell *cell = [menuView menuItemCellForItemAtIndex: index];

      if (cell == nil)
        {
          continue;
        }

      if ([[cell font] isEqual: popupFont] == NO)
        {
          [cell setFont: popupFont];
        }
      if ([cell respondsToSelector: @selector(setNeedsSizing:)])
        {
          [cell setNeedsSizing: YES];
        }
    }

  if ([menuView respondsToSelector: @selector(setNeedsSizing:)])
    {
      [menuView setNeedsSizing: YES];
    }
}

static char WinUIThemeHoverRowKey;

/* The view whose tracking rect says whether the pointer is over a table:
   its scroll view. A tracking rect on the table itself, inside the clip
   view, saw no entering. */
static NSView *
WinUIThemeTableHoverView(NSTableView *tableView)
{
  NSScrollView *scrollView = [tableView enclosingScrollView];

  return (scrollView != nil) ? (NSView *)scrollView : (NSView *)tableView;
}

/* The row under the pointer, which -mouseMoved: records, or -1. */
static NSInteger
WinUIThemeTableHoverRow(NSTableView *tableView)
{
  NSNumber *row = objc_getAssociatedObject(tableView, &WinUIThemeHoverRowKey);

  return (row != nil && WinUIThemeViewIsHovered(WinUIThemeTableHoverView(tableView)))
    ? [row integerValue] : -1;
}

/* WinUI's list and tree rows under the pointer (#28, #43):
   SubtleFillColorSecondary, the selection's shape without its pill. A
   selected row keeps its selection. libs-gui tracks no row hover: the
   table's window gets mouse-moved events, which -mouseMoved: turns into
   the row, and the table's scroll view a tracking rect, whose exit clears
   it. High contrast has no hover fill. */
static void
WinUIThemeDrawTableHover(WinUITheme *theme, NSTableView *tableView, NSRect clipRect)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSInteger row;
  NSRect rowRect, itemRect;

  if ([tableView window] == nil || [[theme settings] highContrastEnabled])
    {
      return;
    }
  WinUIThemeTrackHover(WinUIThemeTableHoverView(tableView));
  if ([[tableView window] acceptsMouseMovedEvents] == NO)
    {
      [[tableView window] setAcceptsMouseMovedEvents: YES];
    }

  row = WinUIThemeTableHoverRow(tableView);
  if (row < 0 || row >= [tableView numberOfRows] || [tableView isRowSelected: row])
    {
      return;
    }
  rowRect = [tableView rectOfRow: row];
  if (NSIntersectsRect(rowRect, clipRect) == NO)
    {
      return;
    }
  itemRect = NSInsetRect(rowRect, 4.0, NSHeight(rowRect) > 20.0 ? 2.0 : 1.0);
  [NSGraphicsContext saveGraphicsState];
  NSRectClip(clipRect);
  [WinUIThemeBlendColor(WinUIThemeColorFromTheme(theme, @"rowBackgroundColor",
                                                 [NSColor controlBackgroundColor]),
                        dark ? [NSColor whiteColor] : [NSColor blackColor],
                        dark ? 0.06 : 0.037) set];
  [WinUIThemeRoundedPath(itemRect, WinUIThemeControlCornerRadius(theme)) fill];
  [NSGraphicsContext restoreGraphicsState];
}

@implementation WinUITheme (MenusAndData)

- (void) displayPopUpMenu: (NSMenuView *)menuView
            withCellFrame: (NSRect)cellFrame
        controlViewWindow: (NSWindow *)controlViewWindow
            preferredEdge: (NSRectEdge)edge
             selectedItem: (int)selectedItem
{
  BOOL popupOwned = WinUIThemeMenuViewOwnedByPopup(menuView);
  BOOL pullsDown = (popupOwned && WinUIThemePopupMenuPullsDown(menuView));
  int placementSelectedItem = selectedItem;

  if (popupOwned && pullsDown == NO)
    {
      WinUIThemePreparePopupMenuTypography(self, menuView);

      if ([menuView respondsToSelector: @selector(setHighlightedItemIndex:)]
          && selectedItem >= 0)
        {
          [menuView setHighlightedItemIndex: selectedItem];
        }

      placementSelectedItem = -1;
    }

  [super displayPopUpMenu: menuView
            withCellFrame: cellFrame
        controlViewWindow: controlViewWindow
            preferredEdge: edge
             selectedItem: placementSelectedItem];
}

- (void) drawBackgroundForMenuView: (NSMenuView *)menuView
                         withFrame: (NSRect)bounds
                         dirtyRect: (NSRect)dirtyRect
                        horizontal: (BOOL)horizontal
{
  WinUIThemeMenuTrace([NSString stringWithFormat: @"drawBackground horizontal=%d bounds=%@ dirty=%@ menuView=%@",
                                                 horizontal,
                                                 NSStringFromRect(bounds),
                                                 NSStringFromRect(dirtyRect),
                                                 menuView]);
  BOOL popupOwned = (horizontal == NO && WinUIThemeMenuViewOwnedByPopup(menuView));
  NSColor *background = WinUIThemeColorFromTheme(self,
                                                 horizontal ? @"menuBarBackgroundColor" : @"menuBackgroundColor",
                                                 [NSColor controlBackgroundColor]);
  NSColor *borderColor = WinUIThemeColorFromTheme(self,
                                                  horizontal ? @"menuBarBorderColor" : @"menuBorderColor",
                                                  [NSColor controlShadowColor]);
  NSRect drawRect = horizontal ? NSIntegralRect(bounds) : NSInsetRect(NSIntegralRect(bounds), 0.5, 0.5);

  if (horizontal && NSIsEmptyRect(NSIntersectionRect(bounds, dirtyRect)) == NO)
    {
      [background set];
      NSRectFill(NSIntersectionRect(bounds, dirtyRect));
    }

  if (horizontal)
    {
      NSRect edgeRect = NSMakeRect(bounds.origin.x,
                                   [menuView isFlipped] ? NSMaxY(bounds) - 1.0 : bounds.origin.y,
                                   bounds.size.width,
                                   1.0);

      [borderColor set];
      NSRectFill(NSIntersectionRect(edgeRect, dirtyRect));
      return;
    }

  /* WinUI's MenuFlyout (#39): a flat panel, without the Win32-classic
     icon gutter. On Windows DWM rounds the window to 8pt and shadows it
     where it can (Windows 11 with a GPU); a rounded fill would leave the
     opaque window's corners showing. */
  if (NSIsEmptyRect(NSIntersectionRect(bounds, dirtyRect)) == NO)
    {
      CGFloat radius = WinUIThemeEffectiveMenuCornerRadius(self, NO, popupOwned);
      NSBezierPath *panelPath = WinUIThemeRoundedPath(drawRect, radius);

      WinUIThemeWindowIntegrationRoundPopupWindow([menuView window], NO, borderColor);
      [background set];
      if (radius > 0.0)
        {
          [panelPath fill];
        }
      else
        {
          NSRectFill(NSIntersectionRect(bounds, dirtyRect));
        }
      [borderColor set];
      [panelPath setLineWidth: 1.0];
      [panelPath stroke];
    }
}

- (NSRect) drawMenuTitleBackground: (GSTitleView *)aTitleView
                         withBounds: (NSRect)bounds
                           withClip: (NSRect)clipRect
{
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *background = WinUIThemeColorFromTheme(self,
                                                 @"menuBarBackgroundColor",
                                                 [NSColor controlColor]);
  NSColor *border = WinUIThemeColorFromTheme(self,
                                             @"menuBarBorderColor",
                                             [NSColor controlShadowColor]);
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSRect drawRect = NSIntersectionRect(bounds, clipRect);

  (void)aTitleView;

  if (NSIsEmptyRect(drawRect))
    {
      return bounds;
    }

  [WinUIThemeBlendColor(background, surface, dark ? 0.08 : 0.12) set];
  NSRectFill(drawRect);

  [border set];
  NSRectFill(NSMakeRect(bounds.origin.x,
                        NSMaxY(bounds) - 1.0,
                        bounds.size.width,
                        1.0));
  NSRectFill(NSMakeRect(bounds.origin.x,
                        bounds.origin.y,
                        bounds.size.width,
                        1.0));

  return bounds;
}

- (void) drawBorderAndBackgroundForMenuItemCell: (NSMenuItemCell *)cell
                                      withFrame: (NSRect)cellFrame
                                         inView: (NSView *)controlView
                                          state: (GSThemeControlState)state
                                   isHorizontal: (BOOL)isHorizontal
{
  BOOL dark = [[self settings] prefersDarkAppearance];
  BOOL highlighted = WinUIThemeStateIsHighlighted(state);
  BOOL enabled = [cell isEnabled];
  BOOL popupOwned = (isHorizontal == NO
                     && WinUIThemeMenuItemCellOwnedByPopup(cell, controlView));
  BOOL popupHovered = (popupOwned
                       && WinUIThemePopupMenuItemIsHovered(cell, controlView));
  NSColor *selection = WinUIThemeColorFromTheme(self,
                                                @"selectedMenuItemColor",
                                                [NSColor selectedMenuItemColor]);
  NSColor *background = WinUIThemeColorFromTheme(self,
                                                 isHorizontal ? @"menuBarBackgroundColor" : @"menuBackgroundColor",
                                                 [NSColor controlBackgroundColor]);
  NSColor *borderColor = nil;
  NSRect drawRect = (popupOwned
                     ? WinUIThemePopupMenuAdjustedCellFrame(cell, controlView, cellFrame)
                     : NSInsetRect(cellFrame,
                                   isHorizontal ? 5.0 : 7.0,
                                   isHorizontal ? 4.0 : 1.5));
  CGFloat radius = WinUIThemeEffectiveMenuCornerRadius(self,
                                                       isHorizontal,
                                                       popupOwned);

  /* A ComboBox's drop-down (#40): the item under the pointer and the
     selected one get the flyout's subtle fill; the selected one also a
     3x16pt accent pill at its leading edge. */
  if (popupOwned && [[self settings] highContrastEnabled] == NO)
    {
      id owner = WinUIThemePopupOwningCellForMenuView((NSMenuView *)controlView);
      NSInteger index = WinUIThemePopupMenuItemIndex(cell, controlView);
      BOOL selectedItem = (index >= 0 && [owner respondsToSelector: @selector(indexOfSelectedItem)]
                           && [owner indexOfSelectedItem] == index);

      if (popupHovered || selectedItem)
        {
          [WinUIThemeMenuItemHoverColor(self, NO) set];
          [WinUIThemeRoundedPath(drawRect, WinUIThemeControlCornerRadius(self)) fill];
        }
      if (selectedItem)
        {
          NSRect pill = NSMakeRect(NSMinX(drawRect), floor(NSMidY(drawRect) - 8.0), 3.0, 16.0);

          [WinUIThemeColorFromTheme(self, @"accentColor", [NSColor selectedControlColor]) set];
          [WinUIThemeRoundedPath(pill, 1.5) fill];
        }
      return;
    }
  if (popupOwned)
    {
      highlighted = popupHovered;
      selection = WinUIThemePopupMenuSelectionFillColor(self, enabled);
    }

  if (highlighted == NO)
    {
      return;
    }

  /* A MenuFlyoutItem under the pointer (#39): SubtleFillColorSecondary,
     4pt corners, 4pt in from the flyout's sides and 2pt from its
     neighbours. An open MenuBarItem has the same fill. High contrast keeps
     the system highlight. */
  if (isHorizontal && [[self settings] highContrastEnabled] == NO)
    {
      [WinUIThemeMenuItemHoverColor(self, YES) set];
      [WinUIThemeRoundedPath(drawRect, radius) fill];
      return;
    }
  if (isHorizontal == NO && popupOwned == NO && [[self settings] highContrastEnabled] == NO)
    {
      NSRect itemRect = NSMakeRect(NSMinX(cellFrame) + 3.0,
                                   NSMinY(cellFrame) + 2.0,
                                   MAX(0.0, NSWidth(cellFrame) - 6.0),
                                   MAX(0.0, NSHeight(cellFrame) - 4.0));

      [WinUIThemeMenuItemHoverColor(self, NO) set];
      [WinUIThemeRoundedPath(itemRect, WinUIThemeControlCornerRadius(self)) fill];
      return;
    }

  if (enabled == NO)
    {
      selection = WinUIThemeBlendColor(selection,
                                       background,
                                       dark ? 0.48 : 0.34);
    }

  borderColor = WinUIThemeColorWithAlpha(WinUIThemeMenuSelectionBorderColor(self,
                                                                            selection,
                                                                            isHorizontal),
                                         isHorizontal ? (dark ? 0.34 : 0.30)
                                                      : (popupOwned ? (dark ? 0.50 : 0.42)
                                                                    : (dark ? 0.72 : 0.70)));
  WinUIThemeDrawSelectionFill(drawRect, radius, selection, borderColor);
}

- (void) drawTitleForMenuItemCell: (NSMenuItemCell *)cell
                        withFrame: (NSRect)cellFrame
                           inView: (NSView *)controlView
                            state: (GSThemeControlState)state
                     isHorizontal: (BOOL)isHorizontal
{
  BOOL popupButtonDisplay = ([controlView isKindOfClass: [NSMenuView class]] == NO
                             && [cell respondsToSelector: @selector(indexOfSelectedItem)]);
  NSString *title = popupButtonDisplay ? WinUIThemePopupButtonDisplayString(cell)
                                       : [[cell menuItem] title];
  BOOL popupOwned = (isHorizontal == NO
                     && WinUIThemeMenuItemCellOwnedByPopup(cell, controlView));
  BOOL popupHovered = (popupOwned && WinUIThemePopupMenuItemIsHovered(cell, controlView));
  BOOL highlighted = (popupOwned ? popupHovered
                                 : WinUIThemeStateIsHighlighted(state));
  NSRect popupCellFrame = (popupOwned
                           ? WinUIThemePopupMenuAdjustedCellFrame(cell, controlView, cellFrame)
                           : cellFrame);
  NSRect titleRect = (popupOwned
                      ? WinUIThemePopupMenuTitleRect(cell, controlView, cellFrame)
                      : [cell titleRectForBounds: cellFrame]);
  NSColor *textColor = nil;
  NSDictionary *attributes = nil;
  NSAttributedString *attributedTitle = nil;
  NSFont *font = (popupOwned
                  ? WinUIThemePopupMenuTextFont(self, controlView)
                  : [cell font]);
  NSSize titleSize = NSZeroSize;

  WinUIThemeMenuTrace([NSString stringWithFormat: @"drawTitle horizontal=%d title=%@ frame=%@ controlView=%@ titleRect=%@ state=%d",
                                                 isHorizontal,
                                                 title,
                                                 NSStringFromRect(cellFrame),
                                                 controlView,
                                                 NSStringFromRect(titleRect),
                                                 (int)state]);

  if ([title length] == 0)
    {
      return;
    }

  font = WinUIThemeResolvedMenuTextFont(self, font, isHorizontal, popupOwned);

  if ([cell isEnabled] == NO)
    {
      textColor = WinUIThemeColorFromTheme(self,
                                           @"disabledControlTextColor",
                                           [NSColor disabledControlTextColor]);
    }
  else if (highlighted)
    {
      BOOL systemHighlight = (popupOwned == NO && [[self settings] highContrastEnabled]);

      textColor = WinUIThemeColorFromTheme(self,
                                           systemHighlight ? @"selectedMenuItemTextColor" : @"controlTextColor",
                                           systemHighlight ? [NSColor selectedMenuItemTextColor]
                                                           : [NSColor controlTextColor]);
    }
  else
    {
      textColor = WinUIThemeColorFromTheme(self,
                                           isHorizontal ? @"labelColor" : @"controlTextColor",
                                           [NSColor controlTextColor]);
    }

  attributes = WinUIThemeMenuTextAttributes(font,
                                            textColor,
                                            isHorizontal ? WinUIThemeCenterTextAlignment() : NSLeftTextAlignment);
  attributedTitle = [[[NSAttributedString alloc] initWithString: title
                                                     attributes: attributes] autorelease];
  titleSize = [attributedTitle size];
  if (popupButtonDisplay)
    {
      NSRect drawRect = NSInsetRect(NSIntegralRect(cellFrame), 1.0, 1.0);
      BOOL enabled = [cell isEnabled];

      if (enabled)
        {
          attributes = WinUIThemeMenuTextAttributes(font,
                                                    WinUIThemeColorFromTheme(self, @"labelColor",
                                                                             [NSColor controlTextColor]),
                                                    NSLeftTextAlignment);
          attributedTitle = AUTORELEASE([[NSAttributedString alloc] initWithString: title
                                                                        attributes: attributes]);
        }
      titleRect = drawRect;
      titleRect.origin.x += 11.0;
      titleRect.size.width = MAX(0.0, titleRect.size.width - (WinUIThemeComboBoxGlyphInset + 23.0));
      titleRect.origin.y = floor(NSMidY(drawRect) - (titleSize.height / 2.0));
      titleRect.size.height = ceil(titleSize.height) + 1.0;
      [attributedTitle drawInRect: titleRect];
      WinUIThemeDrawComboBoxGlyph(self, cellFrame, enabled);
      return;
    }
  if (isHorizontal == NO && popupOwned == NO)
    {
      titleRect = NSInsetRect(titleRect, 2.0, 0.0);
      titleRect.size.width = MAX(0.0, titleRect.size.width - 4.0);
    }
  else if (isHorizontal)
    {
      titleRect = NSInsetRect(NSIntegralRect(cellFrame), WinUIThemeMenuBarTitleInset, 0.0);
      titleRect.origin.y = floor(NSMidY(cellFrame) - (titleSize.height / 2.0));
      titleRect.size.height = ceil(titleSize.height) + 1.0;
      [attributedTitle drawInRect: titleRect];
      return;
    }

  titleRect.origin.y = floor(NSMidY(popupOwned ? popupCellFrame : titleRect)
                             - (titleSize.height / 2.0)
                             - (popupOwned ? 1.0 : 0.0));
  titleRect.size.height = ceil(titleSize.height);
  [attributedTitle drawInRect: titleRect];
}

/* Menu bar items: NSMenuView makes each item its title's width plus a 4pt
   edge pad on each side, but -drawTitleForMenuItemCell:... draws the title
   WinUIThemeMenuBarTitleInset in from each edge, which clipped every title
   ("Fil", "Ed"). Widen the title by the difference. */
- (CGFloat) proposedTitleWidth: (CGFloat)proposedWidth
                   forMenuView: (NSMenuView *)aMenuView
{
  if ([aMenuView isHorizontal] == NO)
    {
      return proposedWidth;
    }

  return ceil(proposedWidth)
    + 2.0 * (WinUIThemeMenuBarTitleInset - WinUIThemeMenuViewHorizontalEdgePad);
}

- (void) drawSeparatorItemForMenuItemCell: (NSMenuItemCell *)cell
                                withFrame: (NSRect)cellFrame
                                   inView: (NSView *)controlView
                             isHorizontal: (BOOL)isHorizontal
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"menuSeparatorColor",
                                                [self menuSeparatorColor]);
  CGFloat leftInset = isHorizontal ? 10.0 : 0.0;
  CGFloat rightInset = isHorizontal ? 12.0 : 0.0;
  CGFloat y = floor(NSMidY(cellFrame)) + 0.5;

  (void)cell;
  (void)controlView;

  [separator set];
  [path setLineWidth: 1.0];
  [path moveToPoint: NSMakePoint(cellFrame.origin.x + leftInset, y)];
  [path lineToPoint: NSMakePoint(NSMaxX(cellFrame) - rightInset, y)];
  [path stroke];
}

- (CGFloat) menuSeparatorInset
{
  return 14.0;
}

- (NSColor *) tableHeaderTextColorForState: (GSThemeControlState)state
{
  NSColor *secondary = WinUIThemeColorFromTheme(self,
                                                @"secondaryLabelColor",
                                                [NSColor disabledControlTextColor]);

  if (WinUIThemeStateIsHighlighted(state))
    {
      return WinUIThemeBlendColor(secondary,
                                  WinUIThemeColorFromTheme(self,
                                                           @"labelColor",
                                                           [NSColor controlTextColor]),
                                  0.18);
    }

  return secondary;
}

- (void) drawTableCornerView: (NSView *)cornerView
                    withClip: (NSRect)aRect
{
  NSColor *background = WinUIThemeColorFromTheme(self,
                                                 @"headerBackgroundColor",
                                                 [NSColor controlColor]);
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"gridColor",
                                                [NSColor gridColor]);
  NSRect drawRect = NSIntersectionRect([cornerView bounds], aRect);
  BOOL dark = [[self settings] prefersDarkAppearance];

  if (NSIsEmptyRect(drawRect))
    {
      return;
    }

  background = WinUIThemeBlendColor(background, surface, dark ? 0.12 : 0.18);
  [background set];
  NSRectFill(drawRect);

  [separator set];
  NSRectFill(NSMakeRect(drawRect.origin.x,
                        [cornerView isFlipped] ? NSMaxY(drawRect) - 1.0 : drawRect.origin.y,
                        drawRect.size.width,
                        1.0));
}

/* The header's background and dividers only: NSTableHeaderCell draws its
   title afterwards with -drawInteriorWithFrame:inView:, in the colour
   -tableHeaderTextColorForState: gives it, inside
   -tableHeaderCellDrawingRectForBounds:. */
- (void) drawTableHeaderCell: (NSTableHeaderCell *)cell
                   withFrame: (NSRect)cellFrame
                      inView: (NSView *)controlView
                       state: (GSThemeControlState)state
{
  NSRect drawRect = NSIntegralRect(cellFrame);
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *background = WinUIThemeColorFromTheme(self,
                                                 @"headerBackgroundColor",
                                                 [NSColor controlColor]);
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"gridColor",
                                                [NSColor gridColor]);
  NSColor *accent = WinUIThemeColorFromTheme(self,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  CGFloat dividerY = [controlView isFlipped] ? NSMaxY(drawRect) - 1.0 : drawRect.origin.y;

  /* GNUstep centres header titles by default; WinUI (and Cocoa) start them
     at the leading edge. Titles an app aligned left or right keep that. */
  if ([cell alignment] == WinUIThemeCenterTextAlignment())
    {
      [cell setAlignment: NSLeftTextAlignment];
    }

  background = WinUIThemeBlendColor(background, surface, dark ? 0.12 : 0.18);
  if (WinUIThemeStateIsHighlighted(state))
    {
      background = WinUIThemeBlendColor(background, accent, dark ? 0.10 : 0.05);
    }

  [background set];
  NSRectFill(drawRect);

  [separator set];
  NSRectFill(NSMakeRect(drawRect.origin.x, dividerY, drawRect.size.width, 1.0));

  /* WinUI shows column dividers only while the pointer is over the
     header, where they can be dragged (#28). */
  WinUIThemeTrackHover(controlView);
  if (WinUIThemeViewIsHovered(controlView) || [[self settings] highContrastEnabled])
    {
      NSRectFill(NSMakeRect(NSMaxX(drawRect) - 1.0,
                            drawRect.origin.y + 4.0,
                            1.0,
                            MAX(0.0, drawRect.size.height - 8.0)));
    }
}

/* Titles 12pt in, as WinUI's column headers: NSCell's -titleRectForBounds:
   adds 3pt to this for a bezeled cell, which header cells are. */
- (NSRect) tableHeaderCellDrawingRectForBounds: (NSRect)theRect
{
  return NSInsetRect(theRect, 9.0, 1.0);
}

- (void) drawTabViewBezelRect: (NSRect)aRect
                  tabViewType: (NSTabViewType)type
                       inView: (NSView *)view
{
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *window = WinUIThemeColorFromTheme(self,
                                             @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSRect drawRect = NSInsetRect(NSIntegralRect(aRect), 0.5, 0.5);
  CGFloat radius = WinUIThemeOverlayCornerRadius(self);
  NSBezierPath *path = nil;

  if (type != NSTopTabsBezelBorder && type != NSNoTabsBezelBorder)
    {
      [super drawTabViewBezelRect: aRect tabViewType: type inView: view];
      return;
    }

  path = WinUIThemeRoundedPath(drawRect, radius);
  [WinUIThemeBlendColor(surface, window, dark ? 0.04 : 0.18) set];
  [path fill];

  [WinUIThemeBlendColor(separator,
                        dark ? [NSColor whiteColor] : [NSColor blackColor],
                        dark ? 0.10 : 0.04) set];
  [path setLineWidth: 1.0];
  [path stroke];
}

- (void) drawTabViewRect: (NSRect)rect
                  inView: (NSView *)view
               withItems: (NSArray *)items
            selectedItem: (NSTabViewItem *)selectedItem
{
  NSTabView *tabView = (NSTabView *)view;
  NSTabViewType type = [tabView tabViewType];
  NSRect bounds = [view bounds];
  NSRect contentRect = [self tabViewBackgroundRectForBounds: bounds tabViewType: type];
  NSRect stripRect = NSMakeRect(bounds.origin.x,
                                [view isFlipped] ? bounds.origin.y : NSMaxY(contentRect),
                                bounds.size.width,
                                [self tabHeightForType: type]);
  CGFloat x = bounds.origin.x + 10.0;
  NSUInteger index = 0;
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *window = WinUIThemeColorFromTheme(self,
                                             @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *border = WinUIThemeColorFromTheme(self,
                                             @"menuBarBorderColor",
                                             [NSColor controlShadowColor]);

  (void)rect;

  if (type != NSTopTabsBezelBorder)
    {
      [super drawTabViewRect: rect
                      inView: view
                   withItems: items
                selectedItem: selectedItem];
      return;
    }

  [window set];
  NSRectFill(stripRect);
  [self drawTabViewBezelRect: contentRect tabViewType: type inView: view];

  for (index = 0; index < [items count]; index++)
    {
      NSTabViewItem *item = [items objectAtIndex: index];
      NSString *title = [item label];
      BOOL selected = (item == selectedItem);
      NSColor *textColor = selected
        ? WinUIThemeColorFromTheme(self, @"labelColor", [NSColor controlTextColor])
        : WinUIThemeColorFromTheme(self, @"secondaryLabelColor", [NSColor disabledControlTextColor]);
      NSDictionary *attributes = WinUIThemeMenuTextAttributes([NSFont systemFontOfSize: [NSFont systemFontSize]],
                                                              textColor,
                                                              WinUIThemeCenterTextAlignment());
      NSSize labelSize = [title sizeWithAttributes: attributes];
      CGFloat tabWidth = MAX(78.0, ceil(labelSize.width + 28.0));
      NSRect tabRect = NSMakeRect(x,
                                  [view isFlipped] ? stripRect.origin.y + (selected ? 4.0 : 7.0) : stripRect.origin.y,
                                  tabWidth,
                                  stripRect.size.height - (selected ? 4.0 : 10.0));
      NSRect labelRect = NSInsetRect(tabRect, 12.0, 0.0);

      if (selected)
        {
          NSBezierPath *path = WinUIThemeRoundedPath(NSInsetRect(tabRect, 0.5, 0.5),
                                                     WinUIThemeOverlayCornerRadius(self));

          [surface set];
          [path fill];

          [WinUIThemeBlendColor(border,
                                dark ? [NSColor whiteColor] : [NSColor blackColor],
                                dark ? 0.10 : 0.02) set];
          [path setLineWidth: 1.0];
          [path stroke];

          [WinUIThemeColorFromTheme(self, @"accentColor", [NSColor selectedControlColor]) set];
          NSRectFill(NSMakeRect(labelRect.origin.x,
                                [view isFlipped] ? NSMaxY(tabRect) - 3.0 : tabRect.origin.y + 1.0,
                                labelRect.size.width,
                                2.0));
        }

      labelRect.origin.y = floor(NSMidY(labelRect) - (labelSize.height / 2.0));
      [title drawInRect: labelRect withAttributes: attributes];
      x += tabWidth + 8.0;
    }
}

- (void) drawScrollViewRect: (NSRect)rect
                     inView: (NSView *)view
{
  NSScrollView *scrollView = (NSScrollView *)view;
  NSBorderType borderType = [scrollView borderType];
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *borderColor = WinUIThemeDataViewBorderColor(self);
  NSColor *railColor = WinUIThemeDataViewRailColor(self);
  NSRect bounds = NSInsetRect(NSIntegralRect([view bounds]), 0.5, 0.5);
  CGFloat radius = WinUIThemeOverlayCornerRadius(self);
  NSBezierPath *path = nil;
  NSScroller *verticalScroller = [scrollView verticalScroller];
  NSScroller *horizontalScroller = [scrollView horizontalScroller];

  (void)rect;

  if (borderType == NSNoBorder)
    {
      return;
    }

  path = WinUIThemeRoundedPath(bounds, radius);
  [surface set];
  [path fill];

  [borderColor set];
  [path setLineWidth: 1.0];
  [path stroke];

  /* Scroll bars over the content have no rail (#29); always shown, they
     sit on one, as WinUI's do, without a dividing line. */
  if (WinUIThemeUsesOverlayScrollers())
    {
      return;
    }
  if ([scrollView hasVerticalScroller] && verticalScroller != nil)
    {
      [railColor set];
      NSRectFill([verticalScroller frame]);
    }
  if ([scrollView hasHorizontalScroller] && horizontalScroller != nil)
    {
      [railColor set];
      NSRectFill([horizontalScroller frame]);
    }
}

- (void) drawTableViewBackgroundInClipRect: (NSRect)clipRect
                                    inView: (NSView *)view
                       withBackgroundColor: (NSColor *)backgroundColor
{
  NSTableView *tableView = (NSTableView *)view;
  BOOL outline = [tableView isKindOfClass: [NSOutlineView class]];
  NSColor *rowBackground = WinUIThemeColorFromTheme(self,
                                                    @"rowBackgroundColor",
                                                    backgroundColor);
  NSColor *alternateRowBackground = WinUIThemeColorFromTheme(self,
                                                             @"alternateRowBackgroundColor",
                                                             rowBackground);
  CGFloat rowHeight = [tableView rowHeight];
  NSInteger startingRow = [tableView rowAtPoint: NSMakePoint(0.0, NSMinY(clipRect))];
  NSInteger endingRow = [tableView rowAtPoint: NSMakePoint(0.0, NSMaxY(clipRect))];
  NSInteger row = 0;

  [rowBackground set];
  NSRectFill(clipRect);
  WinUIThemeDrawTableHover(self, tableView, clipRect);

  if ([tableView usesAlternatingRowBackgroundColors] == NO || rowHeight <= 0.0)
    {
      return;
    }

  if (startingRow < 0)
    {
      startingRow = 0;
    }
  if (endingRow < 0)
    {
      endingRow = [tableView numberOfRows] - 1;
    }

  for (row = startingRow; row <= endingRow; row++)
    {
      NSRect rowRect = NSIntersectionRect([tableView rectOfRow: row], clipRect);

      if ((row % 2) == 1 && NSIsEmptyRect(rowRect) == NO)
        {
          if (outline)
            {
              WinUIThemeDrawSelectionFill(NSInsetRect(rowRect, 6.0, 0.0),
                                          8.0,
                                          alternateRowBackground,
                                          nil);
            }
          else
            {
              [alternateRowBackground set];
              NSRectFill(rowRect);
            }
        }
    }
}

- (void) drawTableViewGridInClipRect: (NSRect)aRect
                              inView: (NSView *)view
{
  NSTableView *tableView = (NSTableView *)view;
  BOOL outline = [tableView isKindOfClass: [NSOutlineView class]];
  NSInteger startingRow = [tableView rowAtPoint: NSMakePoint(0.0, NSMinY(aRect))];
  NSInteger endingRow = [tableView rowAtPoint: NSMakePoint(0.0, NSMaxY(aRect))];
  NSInteger row = 0;
  NSInteger column = 0;
  NSInteger columnCount = [tableView numberOfColumns];
  NSTableViewGridLineStyle mask = [tableView gridStyleMask];
  NSColor *gridColor = WinUIThemeColorWithAlpha(WinUIThemeColorFromTheme(self,
                                                                         @"gridColor",
                                                                         [tableView gridColor]),
                                                [[self settings] prefersDarkAppearance] ? 0.68 : 1.0);

  if (mask == NSTableViewGridNone)
    {
      return;
    }

  [gridColor set];

  if (startingRow < 0)
    {
      startingRow = 0;
    }
  if (endingRow < 0)
    {
      endingRow = [tableView numberOfRows] - 1;
    }

  if ((mask & NSTableViewSolidHorizontalGridLineMask) != 0)
    {
      for (row = startingRow; row <= endingRow; row++)
        {
          NSRect rowRect = NSIntersectionRect([tableView rectOfRow: row], aRect);

          if (NSIsEmptyRect(rowRect) == NO)
            {
              CGFloat leftInset = outline ? 14.0 : 0.0;
              CGFloat rightInset = outline ? 16.0 : 0.0;

              NSRectFill(NSMakeRect(rowRect.origin.x + leftInset,
                                    NSMaxY(rowRect) - 1.0,
                                    MAX(0.0, rowRect.size.width - leftInset - rightInset),
                                    1.0));
            }
        }
    }

  if (outline || (mask & NSTableViewSolidVerticalGridLineMask) == 0)
    {
      return;
    }

  for (column = 0; column < columnCount; column++)
    {
      NSRect columnRect = NSIntersectionRect([tableView rectOfColumn: column], aRect);

      if (NSIsEmptyRect(columnRect) == NO)
        {
          NSRectFill(NSMakeRect(NSMaxX(columnRect) - 1.0,
                                columnRect.origin.y,
                                1.0,
                                columnRect.size.height));
        }
    }
}

/* WinUI's ListView and TreeView selection (#43): a selected row gets
   SubtleFillColorSecondary, 4pt corners, 4pt in from the sides and 2pt from
   its neighbours, and a 3x16pt accent pill at its leading edge (in an
   inactive window, the secondary text colour). Its text stays the primary
   colour. High contrast keeps the system highlight. Column selection is
   unchanged. */
- (void) highlightTableViewSelectionInClipRect: (NSRect)clipRect
                                        inView: (NSView *)view
                              selectingColumns: (BOOL)selectingColumns
{
  NSTableView *tableView = (NSTableView *)view;
  BOOL active = WinUIThemeViewIsActive(view);
  BOOL outline = [tableView isKindOfClass: [NSOutlineView class]];
  BOOL highContrast = [[self settings] highContrastEnabled];
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSIndexSet *selectedIndexes = selectingColumns
    ? [tableView selectedColumnIndexes]
    : [tableView selectedRowIndexes];
  NSColor *fillColor = active
    ? WinUIThemeColorFromTheme(self,
                               @"highlightedTableRowBackgroundColor",
                               [NSColor selectedTextBackgroundColor])
    : WinUIThemeColorFromTheme(self,
                               @"selectedInactiveColor",
                               [NSColor secondarySelectedControlColor]);
  NSColor *pillColor = active
    ? WinUIThemeColorFromTheme(self, @"accentColor", [NSColor selectedControlColor])
    : WinUIThemeColorFromTheme(self, @"secondaryLabelColor", [NSColor controlTextColor]);
  NSUInteger index = [selectedIndexes firstIndex];

  if (selectingColumns == NO && highContrast == NO)
    {
      NSColor *rows = WinUIThemeColorFromTheme(self, @"rowBackgroundColor",
                                               [NSColor controlBackgroundColor]);

      fillColor = WinUIThemeBlendColor(rows, dark ? [NSColor whiteColor] : [NSColor blackColor],
                                       dark ? 0.06 : 0.037);
    }

  while (index != NSNotFound)
    {
      NSRect selectionRect = selectingColumns
        ? [tableView rectOfColumn: index]
        : [tableView rectOfRow: index];

      if (selectingColumns)
        {
          selectionRect = NSInsetRect(NSIntersectionRect(selectionRect, clipRect), 1.0, 2.0);
          if (NSIsEmptyRect(selectionRect) == NO)
            {
              WinUIThemeDrawSelectionFill(selectionRect,
                                          WinUIThemeControlCornerRadius(self),
                                          fillColor,
                                          WinUIThemeSelectionBorderColor(self, fillColor, active, outline));
            }
        }
      else if (highContrast)
        {
          selectionRect = NSIntersectionRect(selectionRect, clipRect);
          if (NSIsEmptyRect(selectionRect) == NO)
            {
              [fillColor set];
              NSRectFill(selectionRect);
            }
        }
      else if (NSIntersectsRect(selectionRect, clipRect))
        {
          NSRect itemRect = NSInsetRect(selectionRect, 4.0, NSHeight(selectionRect) > 20.0 ? 2.0 : 1.0);
          CGFloat pillHeight = MIN(16.0, MAX(6.0, NSHeight(itemRect) - 8.0));
          NSRect pill = NSMakeRect(NSMinX(itemRect),
                                   floor(NSMidY(itemRect) - pillHeight / 2.0),
                                   3.0, pillHeight);
          NSGraphicsContext *context = [NSGraphicsContext currentContext];

          [context saveGraphicsState];
          [[NSBezierPath bezierPathWithRect: clipRect] addClip];
          [fillColor set];
          [WinUIThemeRoundedPath(itemRect, WinUIThemeControlCornerRadius(self)) fill];
          [pillColor set];
          [WinUIThemeRoundedPath(pill, 1.5) fill];
          [context restoreGraphicsState];
        }

      index = [selectedIndexes indexGreaterThanIndex: index];
    }
}

- (NSRect) drawOutlineCell: (NSTableColumn *)tb
               outlineView: (NSOutlineView *)outlineView
                      item: (id)item
               drawingRect: (NSRect)inputRect
                  rowIndex: (NSInteger)rowIndex
{
  NSRect drawingRect = inputRect;
  NSInteger level = MAX(0, [outlineView levelForItem: item]);
  CGFloat indentation = [outlineView indentationPerLevel] * level;
  BOOL expandable = [outlineView isExpandable: item];
  BOOL expanded = expandable ? [outlineView isItemExpanded: item] : NO;
  BOOL selected = [[outlineView selectedRowIndexes] containsIndex: rowIndex];
  NSRect glyphRect = NSZeroRect;
  NSColor *glyphColor = nil;

  if (tb != [outlineView outlineTableColumn])
    {
      return inputRect;
    }

  /* WinUI's TreeView (#51): each level indented, the chevron in a 12pt
     slot before the title (empty on leaf rows, so titles line up). Both
     from the row's indented edge: -frameOfOutlineCellAtRow: already
     includes the indentation, and adding it again put a nested row's
     chevron over its title. */
  glyphRect = NSMakeRect(NSMinX(inputRect) + indentation + 3.0,
                         floor(NSMidY(inputRect) - 6.0),
                         12.0, 12.0);

  glyphColor = (selected && [[self settings] highContrastEnabled])
    ? WinUIThemeColorFromTheme(self,
                               @"selectedMenuItemTextColor",
                               [NSColor selectedMenuItemTextColor])
    : WinUIThemeColorFromTheme(self, @"secondaryLabelColor", [NSColor controlTextColor]);

  if (expandable)
    {
      WinUIThemeDrawMenuChevron(glyphRect,
                                expanded ? WinUIThemeMenuChevronDown : WinUIThemeMenuChevronRight,
                                glyphColor);
    }

  drawingRect.origin.x += indentation + 18.0;
  drawingRect.size.width = MAX(0.0, drawingRect.size.width - indentation - 18.0);
  return drawingRect;
}

- (NSImage *) branchImage
{
  return WinUIThemeCreateDisclosureImage(self, WinUIThemeMenuChevronRight, NO);
}

- (NSImage *) highlightedBranchImage
{
  return WinUIThemeCreateDisclosureImage(self, WinUIThemeMenuChevronDown, YES);
}

@end

@implementation WinUITheme (MenusAndDataOverrides)

/* Tool tips (#39): WinUI's ToolTip, the flyout's colours and border with
   4pt corners from DWM where it gives them (Windows 11), in place of
   libs-gui's black box around text in the system tool-tip colours. */
- (void) _overrideGSTTViewMethod_drawRect: (NSRect)dirtyRect
{
  typedef void (*DrawRectIMP)(id, SEL, NSRect);
  DrawRectIMP originalIMP = (DrawRectIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSTTView"));
  NSView *view = (NSView *)self;
  GSTheme *current = [GSTheme theme];
  WinUITheme *theme = [current isKindOfClass: [WinUITheme class]] ? (WinUITheme *)current : nil;
  NSAttributedString *text = nil;
  NSMutableAttributedString *colored = nil;
  NSColor *background = nil;
  NSColor *border = nil;
  NSRect bounds = [view bounds];

  if (theme == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, dirtyRect);
        }
      return;
    }

  background = WinUIThemeColorFromTheme(theme, @"menuBackgroundColor", [NSColor controlBackgroundColor]);
  border = WinUIThemeColorFromTheme(theme, @"menuBorderColor", [NSColor controlShadowColor]);
  WinUIThemeWindowIntegrationRoundPopupWindow([view window], YES, border);
  [background set];
  NSRectFill(bounds);
  [border set];
  NSFrameRect(bounds);

  text = [view valueForKey: @"text"];
  if ([text length] > 0)
    {
      colored = AUTORELEASE([text mutableCopy]);
      [colored addAttribute: NSForegroundColorAttributeName
                      value: WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor])
                      range: NSMakeRange(0, [colored length])];
      [colored drawInRect: NSInsetRect(bounds, 2.0, 2.0)];
    }
}

/* Items of a pop-up button's menu are laid out by the theme (title and
   check mark only), so they report no image, key equivalent or state image
   and draw none; other menu items keep libs-gui's layout. */
- (NSCellImagePosition) _overrideNSMenuItemCellMethod_imagePosition
{
  typedef NSCellImagePosition (*ImagePositionIMP)(id, SEL);
  ImagePositionIMP originalIMP = (ImagePositionIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);

  if (WinUIThemeUsesPopupButtonCellLayout((NSMenuItemCell *)self))
    {
      return NSNoImage;
    }

  return (originalIMP != NULL) ? originalIMP(self, _cmd) : NSNoImage;
}

- (CGFloat) _overrideNSMenuItemCellMethod_imageWidth
{
  typedef CGFloat (*ImageWidthIMP)(id, SEL);
  ImageWidthIMP originalIMP = (ImageWidthIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);

  if (WinUIThemeUsesPopupButtonCellLayout((NSMenuItemCell *)self))
    {
      return 0.0;
    }

  return (originalIMP != NULL) ? originalIMP(self, _cmd) : 0.0;
}

- (NSRect) _overrideNSMenuItemCellMethod_imageRectForBounds: (NSRect)cellFrame
{
  typedef NSRect (*ImageRectIMP)(id, SEL, NSRect);
  ImageRectIMP originalIMP = (ImageRectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);

  if (WinUIThemeUsesPopupButtonCellLayout((NSMenuItemCell *)self))
    {
      return NSZeroRect;
    }

  return (originalIMP != NULL) ? originalIMP(self, _cmd, cellFrame) : NSZeroRect;
}

- (NSRect) _overrideNSMenuItemCellMethod_keyEquivalentRectForBounds: (NSRect)cellFrame
{
  typedef NSRect (*KeyEquivalentRectIMP)(id, SEL, NSRect);
  KeyEquivalentRectIMP originalIMP = (KeyEquivalentRectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);

  if (WinUIThemeUsesPopupButtonCellLayout((NSMenuItemCell *)self))
    {
      return NSZeroRect;
    }

  return (originalIMP != NULL) ? originalIMP(self, _cmd, cellFrame) : NSZeroRect;
}

- (CGFloat) _overrideNSMenuItemCellMethod_stateImageWidth
{
  typedef CGFloat (*StateImageWidthIMP)(id, SEL);
  StateImageWidthIMP originalIMP = (StateImageWidthIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;

  if (WinUIThemeUsesPopupButtonCellLayout(cell))
    {
      return 0.0;
    }

  return (originalIMP != NULL) ? originalIMP(self, _cmd) : 0.0;
}

- (CGFloat) _overrideNSMenuItemCellMethod_keyEquivalentWidth
{
  typedef CGFloat (*KeyEquivalentWidthIMP)(id, SEL);
  KeyEquivalentWidthIMP originalIMP = (KeyEquivalentWidthIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;

  CGFloat width = 0.0;

  if (WinUIThemeUsesPopupButtonCellLayout(cell))
    {
      return 0.0;
    }

  width = (originalIMP != NULL) ? originalIMP(self, _cmd) : 0.0;
  if ([[cell menuView] isHorizontal] == NO && (width > 0.0 || [[cell menuItem] hasSubmenu]))
    {
      /* MenuFlyoutItem: 24pt between the text and the accelerator, and
         padding after it. */
      width = MAX(width, 12.0) + WinUIThemeMenuKeyEquivalentGap + WinUIThemeMenuKeyEquivalentTrailing;
    }
  return width;
}

- (NSRect) _overrideNSMenuItemCellMethod_stateImageRectForBounds: (NSRect)cellFrame
{
  typedef NSRect (*StateRectIMP)(id, SEL, NSRect);
  StateRectIMP originalIMP = (StateRectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;

  if (WinUIThemeUsesPopupButtonCellLayout(cell))
    {
      return NSZeroRect;
    }

  return (originalIMP != NULL) ? originalIMP(self, _cmd, cellFrame) : cellFrame;
}

- (void) _overrideNSMenuItemCellMethod_drawKeyEquivalentWithFrame: (NSRect)cellFrame
                                                           inView: (NSView *)controlView
{
  typedef void (*DrawKeyEquivalentIMP)(id, SEL, NSRect, NSView *);
  DrawKeyEquivalentIMP originalIMP = (DrawKeyEquivalentIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;

  GSTheme *current = [GSTheme theme];
  WinUITheme *theme = [current isKindOfClass: [WinUITheme class]] ? (WinUITheme *)current : nil;
  NSRect keyRect;
  NSColor *color = nil;

  if (WinUIThemeUsesPopupButtonCellLayout(cell))
    {
      return;
    }
  if (theme == nil || [[cell menuView] isHorizontal])
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }

  keyRect = [cell keyEquivalentRectForBounds: cellFrame];
  keyRect.size.width = MAX(0.0, NSWidth(keyRect) - WinUIThemeMenuKeyEquivalentTrailing);
  color = [cell isEnabled]
    ? WinUIThemeColorFromTheme(theme, @"secondaryLabelColor", [NSColor controlTextColor])
    : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor", [NSColor disabledControlTextColor]);
  if ([cell isHighlighted] && [[theme settings] highContrastEnabled])
    {
      color = WinUIThemeColorFromTheme(theme, @"selectedMenuItemTextColor", [NSColor selectedMenuItemTextColor]);
    }

  if ([[cell menuItem] hasSubmenu])
    {
      WinUIThemeDrawMenuChevron(NSMakeRect(NSMaxX(keyRect) - 12.0, NSMidY(keyRect) - 6.0, 12.0, 12.0),
                                WinUIThemeMenuChevronRight,
                                color);
    }
  else
    {
      NSString *key = [cell _keyEquivalentString];

      if ([key length] > 0)
        {
          NSFont *font = [cell font] != nil ? [cell font] : [NSFont menuFontOfSize: 0.0];
          NSDictionary *attributes = WinUIThemeMenuTextAttributes(font, color, WinUIThemeRightTextAlignment());
          NSSize size = [key sizeWithAttributes: attributes];
          NSRect textRect = NSMakeRect(NSMinX(keyRect),
                                       floor(NSMidY(keyRect) - size.height / 2.0),
                                       NSWidth(keyRect),
                                       ceil(size.height));

          [key drawInRect: textRect withAttributes: attributes];
        }
    }
}

- (void) _overrideNSMenuItemCellMethod_drawStateImageWithFrame: (NSRect)cellFrame
                                                        inView: (NSView *)controlView
{
  typedef void (*DrawStateImageIMP)(id, SEL, NSRect, NSView *);
  DrawStateImageIMP originalIMP = (DrawStateImageIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;

  if (WinUIThemeUsesPopupButtonCellLayout(cell))
    {
      return;
    }

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, cellFrame, controlView);
    }
}

- (void) _overrideNSMenuItemCellMethod_drawImageWithFrame: (NSRect)cellFrame
                                                    inView: (NSView *)controlView
{
  typedef void (*DrawImageIMP)(id, SEL, NSRect, NSView *);
  DrawImageIMP originalIMP = (DrawImageIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuItemCell class]);
  NSMenuItemCell *cell = (NSMenuItemCell *)self;

  if (WinUIThemeUsesPopupButtonCellLayout(cell))
    {
      return;
    }

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, cellFrame, controlView);
    }
}

/* A table built in code starts with libs-gui's defaults: 16pt rows, both
   grid lines, and 5x2pt intercell spacing. Those become WinUI's (#28):
   32pt rows (the theme's table row height, scaled with the desktop), no
   grid, and rows that meet. Tables from nibs keep their archived values,
   and an app's own settings, made after this, win. */
- (id) _overrideNSTableViewMethod_initWithFrame: (NSRect)frameRect
{
  typedef id (*InitWithFrameIMP)(id, SEL, NSRect);
  InitWithFrameIMP originalIMP
    = (InitWithFrameIMP)WinUIThemeOriginalMethod(_cmd, self, [NSTableView class]);
  NSTableView *tableView = (originalIMP != NULL) ? originalIMP(self, _cmd, frameRect) : self;
  GSTheme *theme = [GSTheme theme];

  if (tableView == nil || [theme isKindOfClass: [WinUITheme class]] == NO)
    {
      return tableView;
    }
  if (fabs([tableView rowHeight] - 16.0) < 0.01)
    {
      [tableView setRowHeight: [[(WinUITheme *)theme metrics] tableRowHeight]];
    }
  if ([tableView gridStyleMask] == (NSTableViewSolidVerticalGridLineMask
                                    | NSTableViewSolidHorizontalGridLineMask))
    {
      [tableView setGridStyleMask: NSTableViewGridNone];
    }
  if (NSEqualSizes([tableView intercellSpacing], NSMakeSize(5.0, 2.0)))
    {
      [tableView setIntercellSpacing: NSZeroSize];
    }
  return tableView;
}

/* The row under the pointer, for the hover fill. */
- (void) _overrideNSTableViewMethod_mouseMoved: (NSEvent *)event
{
  typedef void (*MouseMovedIMP)(id, SEL, NSEvent *);
  MouseMovedIMP originalIMP = (MouseMovedIMP)WinUIThemeOriginalMethod(_cmd, self, [NSTableView class]);
  NSTableView *tableView = (NSTableView *)self;

  if ([[GSTheme theme] isKindOfClass: [WinUITheme class]])
    {
      NSPoint point = [tableView convertPoint: [event locationInWindow] fromView: nil];
      NSInteger row = [tableView rowAtPoint: point];
      NSNumber *old = objc_getAssociatedObject(tableView, &WinUIThemeHoverRowKey);

      WinUIThemeSetViewHovered(WinUIThemeTableHoverView(tableView), YES);

      if (old == nil || [old integerValue] != row)
        {
          if (old != nil && [old integerValue] >= 0 && [old integerValue] < [tableView numberOfRows])
            {
              [tableView setNeedsDisplayInRect: [tableView rectOfRow: [old integerValue]]];
            }
          if (row >= 0)
            {
              [tableView setNeedsDisplayInRect: [tableView rectOfRow: row]];
            }
          objc_setAssociatedObject(tableView, &WinUIThemeHoverRowKey,
                                   [NSNumber numberWithInteger: row],
                                   OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, event);
    }
}

/* libs-gui makes every header 22pt tall. A header grows when its titles'
   font needs more, as with a larger Windows text size (#44). */
- (void) _overrideNSTableViewMethod_tile
{
  typedef void (*TileIMP)(id, SEL);
  TileIMP originalIMP = (TileIMP)WinUIThemeOriginalMethod(_cmd, self, [NSTableView class]);
  NSTableView *tableView = (NSTableView *)self;
  NSTableHeaderView *headerView = nil;
  NSArray *columns = nil;
  NSFont *font = nil;
  CGFloat needed = 0.0;

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }
  if ([[GSTheme theme] isKindOfClass: [WinUITheme class]] == NO
      || (headerView = [tableView headerView]) == nil)
    {
      return;
    }

  columns = [tableView tableColumns];
  font = ([columns count] > 0) ? [[[columns objectAtIndex: 0] headerCell] font] : nil;
  if (font == nil)
    {
      font = [NSFont systemFontOfSize: 0];
    }
  /* The title's line, inside -tableHeaderCellDrawingRectForBounds:. */
  needed = ceil([font defaultLineHeightForFont]) + 2.0;
  if (NSHeight([headerView frame]) + 0.5 < needed)
    {
      [headerView setFrameSize: NSMakeSize(NSWidth([headerView frame]), needed)];
      [[tableView cornerView] setFrameSize: NSMakeSize(NSWidth([[tableView cornerView] frame]), needed)];
      [[tableView enclosingScrollView] tile];
    }
}

@end
