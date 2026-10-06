#import "WinUIThemeDrawing.h"

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

  return horizontal ? MAX(7.0, baseRadius + 1.0) : MAX(10.0, baseRadius + 4.0);
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

static id
WinUIThemeScrollViewValueForKey(NSScrollView *scrollView, NSString *key)
{
  id value = nil;

  if (scrollView == nil || [key length] == 0)
    {
      return nil;
    }

  @try
    {
      value = [scrollView valueForKey: key];
    }
  @catch (id exception)
    {
      value = nil;
    }

  return value;
}

static BOOL
WinUIThemeScrollViewNeedsTrailingVerticalScrollerFix(NSScrollView *scrollView,
                                                     NSRect *contentFrameOut,
                                                     NSRect *verticalFrameOut,
                                                     NSRect *horizontalFrameOut,
                                                     CGFloat *leadingContentXOut,
                                                     CGFloat *trailingEdgeOut)
{
#ifdef _WIN32
  NSClipView *contentView = nil;
  NSScroller *verticalScroller = nil;
  NSScroller *horizontalScroller = nil;
  NSRect contentFrame = NSZeroRect;
  NSRect verticalFrame = NSZeroRect;
  NSRect horizontalFrame = NSZeroRect;
  BOOL hasHorizontalScroller = NO;
  CGFloat leadingContentX = 0.0;
  CGFloat trailingEdge = 0.0;

  if (scrollView == nil
      || [scrollView hasVerticalScroller] == NO)
    {
      return NO;
    }

  contentView = [scrollView contentView];
  verticalScroller = [scrollView verticalScroller];
  horizontalScroller = [scrollView horizontalScroller];
  if (contentView == nil || verticalScroller == nil)
    {
      return NO;
    }

  contentFrame = [contentView frame];
  verticalFrame = [verticalScroller frame];
  hasHorizontalScroller = ([scrollView hasHorizontalScroller]
                           && horizontalScroller != nil);
  if (hasHorizontalScroller)
    {
      horizontalFrame = [horizontalScroller frame];
      if (NSIsEmptyRect(horizontalFrame))
        {
          hasHorizontalScroller = NO;
        }
    }

  if (NSIsEmptyRect(contentFrame) || NSIsEmptyRect(verticalFrame))
    {
      return NO;
    }

  leadingContentX = NSMinX(contentFrame);
  if (hasHorizontalScroller)
    {
      leadingContentX = MIN(leadingContentX, NSMinX(horizontalFrame));
    }

  if (NSMaxX(verticalFrame) > leadingContentX + 0.5)
    {
      return NO;
    }

  trailingEdge = NSMaxX(contentFrame);
  if (hasHorizontalScroller)
    {
      trailingEdge = MAX(trailingEdge, NSMaxX(horizontalFrame));
    }

  if ((trailingEdge - NSWidth(verticalFrame)) <= NSMinX(verticalFrame) + 0.5)
    {
      return NO;
    }

  if (contentFrameOut != NULL)
    {
      *contentFrameOut = contentFrame;
    }
  if (verticalFrameOut != NULL)
    {
      *verticalFrameOut = verticalFrame;
    }
  if (horizontalFrameOut != NULL)
    {
      *horizontalFrameOut = horizontalFrame;
    }
  if (leadingContentXOut != NULL)
    {
      *leadingContentXOut = leadingContentX;
    }
  if (trailingEdgeOut != NULL)
    {
      *trailingEdgeOut = trailingEdge;
    }

  return YES;
#else
  (void)scrollView;
  (void)contentFrameOut;
  (void)verticalFrameOut;
  (void)horizontalFrameOut;
  (void)leadingContentXOut;
  (void)trailingEdgeOut;
  return NO;
#endif
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
  BOOL dark = [[self settings] prefersDarkAppearance];
  BOOL popupOwned = (horizontal == NO && WinUIThemeMenuViewOwnedByPopup(menuView));
  NSColor *background = WinUIThemeColorFromTheme(self,
                                                 horizontal ? @"menuBarBackgroundColor" : @"menuBackgroundColor",
                                                 [NSColor controlBackgroundColor]);
  NSColor *borderColor = WinUIThemeColorFromTheme(self,
                                                  horizontal ? @"menuBarBorderColor" : @"menuBorderColor",
                                                  [NSColor controlShadowColor]);
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
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

  if (popupOwned)
    {
      NSRect fillRect = NSIntegralRect(bounds);
      NSRect panelRect = fillRect;
      NSRect fillDirtyRect = NSIntersectionRect(fillRect, dirtyRect);
      CGFloat radius = WinUIThemeEffectiveMenuCornerRadius(self, NO, YES);

      if (NSIsEmptyRect(fillDirtyRect) == NO)
        {
          NSBezierPath *panelPath = WinUIThemeRoundedPath(panelRect, radius);

          [background set];
          [panelPath fill];
        }

      if (NSIsEmptyRect(panelRect) == NO)
        {
          NSBezierPath *panelPath = WinUIThemeRoundedPath(NSInsetRect(panelRect, 0.5, 0.5),
                                                          radius);

          [borderColor set];
          [panelPath setLineWidth: 1.0];
          [panelPath stroke];
        }

      return;
    }

  if (NSIsEmptyRect(NSIntersectionRect(bounds, dirtyRect)) == NO)
    {
      CGFloat radius = WinUIThemeEffectiveMenuCornerRadius(self, NO, NO);
      NSBezierPath *panelPath = WinUIThemeRoundedPath(drawRect,
                                                      radius);
      NSRect gutterRect = NSMakeRect(drawRect.origin.x + 8.0,
                                     drawRect.origin.y + 8.0,
                                     MIN(22.0, MAX(0.0, drawRect.size.width - 16.0)),
                                     MAX(0.0, drawRect.size.height - 16.0));
      NSColor *gutterColor = WinUIThemeBlendColor(background,
                                                  surface,
                                                  dark ? 0.18 : 0.08);

      [background set];
      [panelPath fill];

      [gutterColor set];
      [WinUIThemeRoundedPath(gutterRect, 7.0) fill];

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

  if (popupOwned)
    {
      highlighted = popupHovered;
      selection = WinUIThemePopupMenuSelectionFillColor(self, enabled);
    }

  if (highlighted == NO)
    {
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
      textColor = WinUIThemeColorFromTheme(self,
                                           popupOwned ? @"controlTextColor" : @"selectedMenuItemTextColor",
                                           popupOwned ? [NSColor controlTextColor]
                                                      : [NSColor selectedMenuItemTextColor]);
    }
  else
    {
      textColor = WinUIThemeColorFromTheme(self,
                                           isHorizontal ? @"labelColor" : @"controlTextColor",
                                           [NSColor controlTextColor]);
    }

  attributes = WinUIThemeMenuTextAttributes(font,
                                            textColor,
                                            isHorizontal ? NSCenterTextAlignment : NSLeftTextAlignment);
  attributedTitle = [[[NSAttributedString alloc] initWithString: title
                                                     attributes: attributes] autorelease];
  titleSize = [attributedTitle size];
  if (popupButtonDisplay)
    {
      CGFloat arrowWidth = MAX(34.0, ceil([[self metrics] popupControlHeight] * 0.96));
      NSRect drawRect = NSInsetRect(NSIntegralRect(cellFrame), 1.0, 1.0);
      CGFloat dividerX = NSMaxX(drawRect) - arrowWidth;
      BOOL enabled = [cell isEnabled];
      BOOL popupOpen = WinUIThemePopupButtonMenuVisible(cell);
      BOOL dark = [[self settings] prefersDarkAppearance];
      NSColor *surface = WinUIThemeColorFromTheme(self,
                                                  @"surfaceColor",
                                                  [NSColor controlBackgroundColor]);
      NSColor *separator = WinUIThemeColorFromTheme(self,
                                                    @"separatorColor",
                                                    [NSColor controlShadowColor]);
      NSColor *accent = WinUIThemeColorFromTheme(self,
                                                 @"accentColor",
                                                 [NSColor selectedControlColor]);
      NSColor *labelColor = WinUIThemeColorFromTheme(self,
                                                     @"secondaryLabelColor",
                                                     [NSColor controlTextColor]);
      NSColor *disabledColor = WinUIThemeColorFromTheme(self,
                                                        @"disabledControlTextColor",
                                                        [NSColor disabledControlTextColor]);
      NSColor *laneColor = popupOpen
        ? WinUIThemeBlendColor(surface, accent, dark ? 0.24 : 0.08)
        : WinUIThemeBlendColor(surface,
                               WinUIThemeColorFromTheme(self,
                                                        @"windowBackgroundColor",
                                                        [NSColor windowBackgroundColor]),
                               dark ? 0.08 : 0.03);
      NSColor *chevronColor = enabled
        ? (popupOpen ? accent : labelColor)
        : disabledColor;
      NSRect laneRect = NSMakeRect(dividerX,
                                   drawRect.origin.y + 1.0,
                                   arrowWidth,
                                   MAX(0.0, drawRect.size.height - 2.0));

      titleRect = drawRect;
      titleRect.origin.x += 12.0;
      titleRect.size.width = MAX(0.0, titleRect.size.width - (arrowWidth + 18.0));
      titleRect.origin.y = floor(NSMidY(drawRect) - (titleSize.height / 2.0));
      titleRect.size.height = ceil(titleSize.height) + 1.0;
      [attributedTitle drawAtPoint: titleRect.origin];

      [laneColor set];
      [[NSBezierPath bezierPathWithRoundedRect: laneRect xRadius: 7.0 yRadius: 7.0] fill];
      [WinUIThemeColorWithAlpha(separator, popupOpen ? (dark ? 0.58 : 0.78) : (dark ? 0.72 : 0.92)) set];
      NSRectFill(NSMakeRect(dividerX,
                            drawRect.origin.y + 7.0,
                            1.0,
                            MAX(4.0, drawRect.size.height - 14.0)));
      WinUIThemeDrawChevron(NSMakePoint(dividerX + floor(arrowWidth / 2.0) - 1.0,
                                        NSMidY(drawRect)),
                            NO,
                            chevronColor);
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
  CGFloat leftInset = isHorizontal ? 10.0 : [self menuSeparatorInset];
  CGFloat rightInset = 12.0;
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

- (void) drawTableHeaderCell: (NSTableHeaderCell *)cell
                   withFrame: (NSRect)cellFrame
                      inView: (NSView *)controlView
                       state: (GSThemeControlState)state
{
  NSString *title = [cell stringValue];
  NSRect drawRect = NSIntegralRect(cellFrame);
  NSRect textRect = [self tableHeaderCellDrawingRectForBounds: drawRect];
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
  NSDictionary *attributes = nil;
  NSFont *font = [cell font];
  NSSize titleSize = NSZeroSize;
  CGFloat dividerY = [controlView isFlipped] ? NSMaxY(drawRect) - 1.0 : drawRect.origin.y;

  if (font == nil)
    {
      font = [NSFont systemFontOfSize: 9.0];
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
  NSRectFill(NSMakeRect(NSMaxX(drawRect) - 1.0,
                        drawRect.origin.y + 4.0,
                        1.0,
                        MAX(0.0, drawRect.size.height - 8.0)));

  if ([title length] == 0)
    {
      return;
    }

  attributes = WinUIThemeMenuTextAttributes(font,
                                            [self tableHeaderTextColorForState: state],
                                            NSLeftTextAlignment);
  titleSize = [title sizeWithAttributes: attributes];
  textRect.origin.y = floor(NSMidY(textRect) - (titleSize.height / 2.0));
  [title drawInRect: textRect withAttributes: attributes];
}

- (NSRect) tableHeaderCellDrawingRectForBounds: (NSRect)theRect
{
  return NSInsetRect(theRect, 10.0, 8.0);
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
  CGFloat radius = MAX(10.0, [[self metrics] windowCornerRadius] + 2.0);
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
                                                              NSCenterTextAlignment);
      NSSize labelSize = [title sizeWithAttributes: attributes];
      CGFloat tabWidth = MAX(78.0, ceil(labelSize.width + 28.0));
      NSRect tabRect = NSMakeRect(x,
                                  [view isFlipped] ? stripRect.origin.y + (selected ? 4.0 : 7.0) : stripRect.origin.y,
                                  tabWidth,
                                  stripRect.size.height - (selected ? 4.0 : 10.0));
      NSRect labelRect = NSInsetRect(tabRect, 12.0, 0.0);

      if (selected)
        {
          NSBezierPath *path = WinUIThemeRoundedPath(NSInsetRect(tabRect, 0.5, 0.5), 10.0);

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
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"gridColor",
                                                [NSColor gridColor]);
  NSColor *borderColor = WinUIThemeDataViewBorderColor(self);
  NSColor *railColor = WinUIThemeDataViewRailColor(self);
  NSRect bounds = NSInsetRect(NSIntegralRect([view bounds]), 0.5, 0.5);
  CGFloat radius = MAX(8.0, [[self metrics] controlCornerRadius] + 4.0);
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

  if ([scrollView hasVerticalScroller] && verticalScroller != nil)
    {
      NSRect scrollerFrame = [verticalScroller frame];
      CGFloat x = scrollerFrame.origin.x - 1.0;

      [railColor set];
      NSRectFill(scrollerFrame);
      [separator set];
      NSRectFill(NSMakeRect(x,
                            scrollerFrame.origin.y,
                            1.0,
                            scrollerFrame.size.height));
    }
  if ([scrollView hasHorizontalScroller] && horizontalScroller != nil)
    {
      NSRect scrollerFrame = [horizontalScroller frame];
      CGFloat y = [scrollView isFlipped] ? scrollerFrame.origin.y - 1.0 : NSMaxY(scrollerFrame);

      [railColor set];
      NSRectFill(scrollerFrame);
      [separator set];
      NSRectFill(NSMakeRect(scrollerFrame.origin.x,
                            y,
                            scrollerFrame.size.width,
                            1.0));
    }
}

- (void) drawScrollerRect: (NSRect)rect
                   inView: (NSView *)view
                  hitPart: (NSScrollerPart)hitPart
             isHorizontal: (BOOL)isHorizontal
{
  NSScroller *scroller = (NSScroller *)view;
  BOOL dark = [[self settings] prefersDarkAppearance];
  BOOL enabled = [scroller isEnabled];
  NSRect slotRect = [scroller rectForPart: NSScrollerKnobSlot];
  NSRect knobRect = [scroller rectForPart: NSScrollerKnob];
  NSRect decrementRect = [scroller rectForPart: NSScrollerDecrementLine];
  NSRect incrementRect = [scroller rectForPart: NSScrollerIncrementLine];
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSColor *gridColor = WinUIThemeColorFromTheme(self,
                                                @"gridColor",
                                                [NSColor gridColor]);
  NSColor *accent = WinUIThemeColorFromTheme(self,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  NSColor *labelColor = WinUIThemeColorFromTheme(self,
                                                 @"secondaryLabelColor",
                                                 [NSColor controlTextColor]);
  NSColor *railColor = WinUIThemeDataViewRailColor(self);
  NSColor *trackColor = WinUIThemeBlendColor(railColor, surface, dark ? 0.20 : 0.24);
  NSColor *knobColor = enabled
    ? WinUIThemeBlendColor(labelColor, surface, dark ? 0.24 : 0.42)
    : WinUIThemeBlendColor(separator, surface, dark ? 0.34 : 0.54);
  NSColor *knobBorder = WinUIThemeColorWithAlpha(WinUIThemeDataViewBorderColor(self),
                                                 dark ? 0.70 : 0.85);
  NSColor *buttonColor = railColor;

  [railColor set];
  NSRectFill(rect);

  if (NSIsEmptyRect(slotRect) == NO)
    {
      NSRect slotDrawRect = NSInsetRect(slotRect, isHorizontal ? 3.0 : 4.0, isHorizontal ? 4.0 : 3.0);
      NSBezierPath *slotPath = WinUIThemeRoundedPath(slotDrawRect,
                                                     MIN(slotDrawRect.size.width,
                                                         slotDrawRect.size.height) / 2.0);

      [trackColor set];
      [slotPath fill];
    }

  if (NSIsEmptyRect(knobRect) == NO)
    {
      NSRect knobDrawRect = NSInsetRect(knobRect, 3.0, 3.0);
      NSBezierPath *knobPath = WinUIThemeRoundedPath(knobDrawRect,
                                                     MIN(knobDrawRect.size.width,
                                                         knobDrawRect.size.height) / 2.0);

      if (hitPart == NSScrollerKnob || hitPart == NSScrollerKnobSlot)
        {
          knobColor = WinUIThemeBlendColor(knobColor, accent, dark ? 0.12 : 0.08);
        }

      [knobColor set];
      [knobPath fill];

      [WinUIThemeColorWithAlpha(knobBorder, 0.65) set];
      [knobPath setLineWidth: 1.0];
      [knobPath stroke];
    }

  if (NSIsEmptyRect(decrementRect) == NO)
    {
      NSColor *fillColor = hitPart == NSScrollerDecrementLine
        ? WinUIThemeBlendColor(buttonColor, accent, dark ? 0.14 : 0.08)
        : buttonColor;

      WinUIThemeDrawSelectionFill(NSInsetRect(decrementRect, 1.0, 1.0), 7.0, fillColor, nil);
      [gridColor set];
      if (isHorizontal)
        {
          NSRectFill(NSMakeRect(NSMaxX(decrementRect) - 1.0,
                                decrementRect.origin.y + 2.0,
                                1.0,
                                MAX(0.0, decrementRect.size.height - 4.0)));
        }
      else
        {
          NSRectFill(NSMakeRect(decrementRect.origin.x + 2.0,
                                decrementRect.origin.y,
                                MAX(0.0, decrementRect.size.width - 4.0),
                                1.0));
        }
      WinUIThemeDrawMenuChevron(NSInsetRect(decrementRect, 2.0, 2.0),
                                isHorizontal ? WinUIThemeMenuChevronLeft : WinUIThemeMenuChevronUp,
                                enabled ? labelColor : WinUIThemeColorWithAlpha(labelColor, 0.45));
    }

  if (NSIsEmptyRect(incrementRect) == NO)
    {
      NSColor *fillColor = hitPart == NSScrollerIncrementLine
        ? WinUIThemeBlendColor(buttonColor, accent, dark ? 0.14 : 0.08)
        : buttonColor;

      WinUIThemeDrawSelectionFill(NSInsetRect(incrementRect, 1.0, 1.0), 7.0, fillColor, nil);
      [gridColor set];
      if (isHorizontal)
        {
          NSRectFill(NSMakeRect(incrementRect.origin.x,
                                incrementRect.origin.y + 2.0,
                                1.0,
                                MAX(0.0, incrementRect.size.height - 4.0)));
        }
      else
        {
          NSRectFill(NSMakeRect(incrementRect.origin.x + 2.0,
                                NSMaxY(incrementRect) - 1.0,
                                MAX(0.0, incrementRect.size.width - 4.0),
                                1.0));
        }
      WinUIThemeDrawMenuChevron(NSInsetRect(incrementRect, 2.0, 2.0),
                                isHorizontal ? WinUIThemeMenuChevronRight : WinUIThemeMenuChevronDown,
                                enabled ? labelColor : WinUIThemeColorWithAlpha(labelColor, 0.45));
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

- (void) highlightTableViewSelectionInClipRect: (NSRect)clipRect
                                        inView: (NSView *)view
                              selectingColumns: (BOOL)selectingColumns
{
  NSTableView *tableView = (NSTableView *)view;
  BOOL active = WinUIThemeViewIsActive(view);
  BOOL outline = [tableView isKindOfClass: [NSOutlineView class]];
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
  NSUInteger index = [selectedIndexes firstIndex];

  while (index != NSNotFound)
    {
      NSRect selectionRect = selectingColumns
        ? [tableView rectOfColumn: index]
        : [tableView rectOfRow: index];

      selectionRect = NSIntersectionRect(selectionRect, clipRect);
      if (selectingColumns)
        {
          selectionRect = NSInsetRect(selectionRect, 1.0, 2.0);
        }
      else if (outline)
        {
          selectionRect = NSInsetRect(selectionRect, 6.0, 0.0);
        }

      if (NSIsEmptyRect(selectionRect) == NO)
        {
          WinUIThemeDrawSelectionFill(selectionRect,
                                      (selectingColumns
                                       ? MAX(7.0, [[self metrics] controlCornerRadius] + 3.0)
                                       : (outline ? 8.0 : 0.0)),
                                      fillColor,
                                      WinUIThemeSelectionBorderColor(self,
                                                                     fillColor,
                                                                     active,
                                                                     outline));
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
  NSRect outlineCellRect = inputRect;
  NSRect glyphRect = NSZeroRect;
  NSColor *glyphColor = nil;

  if (tb != [outlineView outlineTableColumn])
    {
      return inputRect;
    }

  if ([outlineView respondsToSelector: @selector(frameOfOutlineCellAtRow:)])
    {
      outlineCellRect = [outlineView frameOfOutlineCellAtRow: rowIndex];
    }

  glyphRect = outlineCellRect;
  glyphRect.origin.x += indentation + 3.0;
  glyphRect.size.width = 12.0;
  glyphRect.origin.y = floor(NSMidY(outlineCellRect) - 6.0);
  glyphRect.size.height = 12.0;

  glyphColor = selected
    ? WinUIThemeColorFromTheme(self,
                               @"selectedMenuItemTextColor",
                               [NSColor selectedMenuItemTextColor])
    : WinUIThemeColorFromTheme(self,
                               expandable ? @"secondaryLabelColor" : @"separatorColor",
                               [NSColor controlTextColor]);

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

- (void) _overrideNSScrollViewMethod_tile
{
  typedef void (*TileIMP)(id, SEL);
  TileIMP originalIMP = (TileIMP)[[GSTheme theme] overriddenMethod: _cmd for: self];

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }

#ifdef _WIN32
  {
    NSScrollView *scrollView = (NSScrollView *)self;
    NSClipView *contentView = [scrollView contentView];
    NSScroller *verticalScroller = [scrollView verticalScroller];
    NSScroller *horizontalScroller = [scrollView horizontalScroller];
    NSView *headerClipView = nil;
    NSView *cornerView = nil;
    NSView *horizontalRulerView = nil;
    NSRect contentFrame = NSZeroRect;
    NSRect verticalFrame = NSZeroRect;
    NSRect horizontalFrame = NSZeroRect;
    NSRect frame = NSZeroRect;
    CGFloat leadingContentX = 0.0;
    CGFloat trailingEdge = 0.0;
    CGFloat shift = 0.0;

    if (WinUIThemeScrollViewNeedsTrailingVerticalScrollerFix(scrollView,
                                                             &contentFrame,
                                                             &verticalFrame,
                                                             &horizontalFrame,
                                                             &leadingContentX,
                                                             &trailingEdge) == NO)
      {
        return;
      }

    shift = leadingContentX - NSMinX(verticalFrame);
    if (shift <= 0.0)
      {
        return;
      }

    contentFrame.origin.x -= shift;
    [contentView setFrame: contentFrame];

    if ([scrollView hasHorizontalScroller] && horizontalScroller != nil)
      {
        horizontalFrame.origin.x -= shift;
        [horizontalScroller setFrame: horizontalFrame];
      }

    horizontalRulerView = [scrollView horizontalRulerView];
    if (horizontalRulerView != nil)
      {
        frame = [horizontalRulerView frame];
        if (NSMinX(frame) >= leadingContentX - 0.5)
          {
            frame.origin.x -= shift;
            [horizontalRulerView setFrame: frame];
          }
      }

    headerClipView = WinUIThemeScrollViewValueForKey(scrollView, @"_headerClipView");
    if (headerClipView != nil)
      {
        frame = [headerClipView frame];
        if (NSMinX(frame) >= leadingContentX - 0.5)
          {
            frame.origin.x -= shift;
            [headerClipView setFrame: frame];
          }
      }

    verticalFrame.origin.x = trailingEdge - NSWidth(verticalFrame);
    [verticalScroller setFrame: verticalFrame];

    cornerView = WinUIThemeScrollViewValueForKey(scrollView, @"_cornerView");
    if (cornerView != nil)
      {
        frame = [cornerView frame];
        frame.origin.x = verticalFrame.origin.x;
        [cornerView setFrame: frame];
      }

    [scrollView reflectScrolledClipView: contentView];
    [scrollView setNeedsDisplay: YES];
  }
#endif
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

  if (WinUIThemeUsesPopupButtonCellLayout(cell))
    {
      return 0.0;
    }

  return (originalIMP != NULL) ? originalIMP(self, _cmd) : 0.0;
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

  if (WinUIThemeUsesPopupButtonCellLayout(cell))
    {
      return;
    }

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, cellFrame, controlView);
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

@end

@implementation NSMenuItemCell (WinUIThemePopupLayoutFixes)

- (NSCellImagePosition) imagePosition
{
  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return NSNoImage;
    }

  return [super imagePosition];
}

- (CGFloat) imageWidth
{
  if (_needs_sizing)
    {
      [self calcSize];
    }

  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return 0.0;
    }

  return _imageWidth;
}

- (CGFloat) keyEquivalentWidth
{
  if (_needs_sizing)
    {
      [self calcSize];
    }

  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return 0.0;
    }

  return _keyEquivalentWidth;
}

- (CGFloat) stateImageWidth
{
  if (_needs_sizing)
    {
      [self calcSize];
    }

  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return 0.0;
    }

  return _stateImageWidth;
}

- (NSRect) imageRectForBounds: (NSRect)cellFrame
{
  if (_needs_sizing)
    {
      [self calcSize];
    }

  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return NSZeroRect;
    }

  if ([_menuView isHorizontal] == YES)
    {
      switch (_cell.image_position)
        {
          case NSNoImage:
            cellFrame = NSZeroRect;
            break;

          case NSImageOnly:
          case NSImageOverlaps:
            break;

          case NSImageLeft:
            cellFrame.origin.x += 4.0;
            cellFrame.size.width = _imageWidth;
            break;

          case NSImageRight:
            cellFrame.origin.x += _titleWidth;
            cellFrame.size.width = _imageWidth;
            break;

          case NSImageBelow:
            cellFrame.size.height /= 2.0;
            break;

          case NSImageAbove:
            cellFrame.size.height /= 2.0;
            cellFrame.origin.y += cellFrame.size.height;
            break;
        }
    }
  else
    {
      cellFrame.origin.x += [_menuView imageAndTitleOffset];
      cellFrame.size.width = [_menuView imageAndTitleWidth];

      switch (_cell.image_position)
        {
          case NSNoImage:
            cellFrame = NSZeroRect;
            break;

          case NSImageOnly:
          case NSImageOverlaps:
            break;

          case NSImageLeft:
            cellFrame.size.width = _imageWidth;
            break;

          case NSImageRight:
            cellFrame.origin.x += _titleWidth + GSCellTextImageXDist;
            cellFrame.size.width = _imageWidth;
            break;

          case NSImageBelow:
            cellFrame.size.height /= 2.0;
            break;

          case NSImageAbove:
            cellFrame.size.height /= 2.0;
            cellFrame.origin.y += cellFrame.size.height;
            break;
        }
    }

  return cellFrame;
}

- (NSRect) keyEquivalentRectForBounds: (NSRect)cellFrame
{
  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return NSZeroRect;
    }

  cellFrame.origin.x += [_menuView keyEquivalentOffset];
  cellFrame.size.width = [_menuView keyEquivalentWidth];
  return cellFrame;
}

- (NSRect) stateImageRectForBounds: (NSRect)cellFrame
{
  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return NSZeroRect;
    }

  cellFrame.origin.x += [_menuView stateImageOffset];
  cellFrame.size.width = [_menuView stateImageWidth];
  return cellFrame;
}

- (void) drawImageWithFrame: (NSRect)cellFrame
                     inView: (NSView *)controlView
{
  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return;
    }

  cellFrame = [self imageRectForBounds: cellFrame];
  [self drawImage: _imageToDisplay withFrame: cellFrame inView: controlView];
}

- (void) drawKeyEquivalentWithFrame: (NSRect)cellFrame
                             inView: (NSView *)controlView
{
  NSImage *arrow = nil;

  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return;
    }

  if (_cell.is_highlighted)
    {
      arrow = [NSImage imageNamed: @"NSHighlightedMenuArrow"];
    }
  if (arrow == nil)
    {
      arrow = [NSImage imageNamed: @"NSMenuArrow"];
    }

  cellFrame = [self keyEquivalentRectForBounds: cellFrame];

  if ([_menuItem hasSubmenu] && arrow != nil)
    {
      NSSize size = [arrow size];
      NSPoint position = NSMakePoint(cellFrame.origin.x + cellFrame.size.width - size.width,
                                     MAX(NSMidY(cellFrame) - (size.height / 2.0), 0.0));

      if ([controlView isFlipped])
        {
          position.y += size.height;
        }

      [arrow compositeToPoint: position operation: NSCompositeSourceOver];
    }
  else if (![[_menuView menu] _ownedByPopUp] || (_imageToDisplay == nil))
    {
      if (_keyEquivalentFont != nil)
        {
          NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  _keyEquivalentFont, NSFontAttributeName,
                                                  [self textColor], NSForegroundColorAttributeName,
                                                  nil];
          NSAttributedString *aString = [[NSAttributedString alloc] initWithString: [self _keyEquivalentString]
                                                                         attributes: attrs];

          [self _drawAttributedText: aString inFrame: cellFrame];
          RELEASE(aString);
        }
      else
        {
          [self _drawText: [self _keyEquivalentString] inFrame: cellFrame];
        }
    }
}

- (void) drawStateImageWithFrame: (NSRect)cellFrame
                          inView: (NSView *)controlView
{
  NSImage *imageToDisplay = nil;

  if (WinUIThemeUsesPopupButtonCellLayout(self))
    {
      return;
    }

  switch ([_menuItem state])
    {
      case NSOnState:
        imageToDisplay = [_menuItem onStateImage];
        break;

      case NSMixedState:
        imageToDisplay = [_menuItem mixedStateImage];
        break;

      case NSOffState:
      default:
        imageToDisplay = [_menuItem offStateImage];
        break;
    }

  if (imageToDisplay == nil)
    {
      return;
    }

  cellFrame = [self stateImageRectForBounds: cellFrame];
  [self drawImage: imageToDisplay withFrame: cellFrame inView: controlView];
}

@end
