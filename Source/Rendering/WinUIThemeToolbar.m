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
#import "../Settings/WinUIThemeMetrics.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>

/* Toolbars as WinUI's CommandBar, after the Adwaita theme's toolbar
   layout. libs-gui gives every item a fixed 60pt (50pt small) slot with a
   label row even for empty labels, drops views taller than 32pt, makes
   images 32x32 and draws a dark grey line under the toolbar
   (libs-gui#972). The theme sizes items from their content instead:

   - icon only: CommandBar's 48pt row, 40pt AppBarButtons
   - icon and label: a 20pt icon over a caption-sized label, as an
     AppBarButton with its label at the bottom
   - label only: 32pt text buttons
   - views stay however tall they are, and the row grows to fit them

   Every item then gets the tallest one's height, so the row is even.
   Buttons get AppBarButton's hover and pressed fills (the text colour at
   6% and 4%, 4pt corners), and view items' labels are drawn in the text
   colour (libs-gui draws them black, lost in the dark palette). */

/* GSToolbarButton and GSToolbarBackView, private to libs-gui. */
@protocol WinUIThemeToolbarButton
- (NSToolbarItem *) toolbarItem;
@end

@interface NSToolbarItem (WinUIThemeToolbarPrivate)
- (NSView *) _backView;
@end

static const CGFloat WinUIThemeToolbarRowHeight = 48.0;
static const CGFloat WinUIThemeToolbarButtonSize = 40.0;
static const CGFloat WinUIThemeToolbarTextButtonHeight = 32.0;
static const CGFloat WinUIThemeToolbarSpacing = 2.0;
static const CGFloat WinUIThemeToolbarIconPadding = 10.0;
static const CGFloat WinUIThemeToolbarLabeledIconPadding = 6.0;
static const CGFloat WinUIThemeToolbarLabelPadding = 12.0;
static const CGFloat WinUIThemeToolbarLabelGap = 4.0;
static const CGFloat WinUIThemeToolbarIconSize = 20.0;
static const CGFloat WinUIThemeToolbarSmallIconSize = 16.0;

/* On an item's image: its own size, before libs-gui first resized it. */
static char WinUIThemeToolbarImageSizeKey;
/* On a toolbar button: its hover tracking-rect tag, and whether the
   pointer is over it. */
static char WinUIThemeToolbarButtonTrackingKey;
static char WinUIThemeToolbarButtonHoverKey;

/* Owns toolbar buttons' tracking rects and records hover from their
   enter and exit events. (The window's -mouseLocationOutsideOfEventStream
   goes stale at draw time.) */
@interface WinUIThemeToolbarHoverTracker : NSObject
+ (WinUIThemeToolbarHoverTracker *) sharedTracker;
@end

@implementation WinUIThemeToolbarHoverTracker

+ (WinUIThemeToolbarHoverTracker *) sharedTracker
{
  static WinUIThemeToolbarHoverTracker *tracker = nil;

  if (tracker == nil)
    {
      tracker = [WinUIThemeToolbarHoverTracker new];
    }
  return tracker;
}

- (void) setHover: (BOOL)hover forEvent: (NSEvent *)event
{
  NSView *button = (NSView *)[event userData];

  if (button == nil)
    {
      return;
    }
  objc_setAssociatedObject(button, &WinUIThemeToolbarButtonHoverKey,
                           hover ? [NSNumber numberWithBool: YES] : nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [button setNeedsDisplay: YES];
}

- (void) mouseEntered: (NSEvent *)event
{
  [self setHover: YES forEvent: event];
}

- (void) mouseExited: (NSEvent *)event
{
  [self setHover: NO forEvent: event];
}

@end

/* Spaces and separators: sized by libs-gui, given the row's height. */
static BOOL
WinUIThemeToolbarItemIsSpace(NSToolbarItem *item)
{
  NSString *identifier = [item itemIdentifier];

  return [identifier isEqualToString: NSToolbarSpaceItemIdentifier]
    || [identifier isEqualToString: NSToolbarFlexibleSpaceItemIdentifier]
    || [identifier isEqualToString: NSToolbarSeparatorItemIdentifier];
}

static BOOL
WinUIThemeToolbarShowsLabels(NSToolbar *toolbar)
{
  return [toolbar displayMode] != NSToolbarDisplayModeIconOnly;
}

static BOOL
WinUIThemeToolbarTextItem(NSToolbarItem *item)
{
  return [[item toolbar] displayMode] == NSToolbarDisplayModeLabelOnly;
}

/* The label's font: the interface font for text buttons, WinUI's Caption
   size (12 of 14) under an icon. Kept: GSToolbarBackView doesn't retain
   its font. */
static NSFont *
WinUIThemeToolbarLabelFont(NSToolbar *toolbar)
{
  static NSFont *regular = nil;
  static NSFont *caption = nil;

  if (regular == nil || [regular pointSize] != [NSFont systemFontSize])
    {
      ASSIGN(regular, [NSFont systemFontOfSize: [NSFont systemFontSize]]);
      ASSIGN(caption, [NSFont systemFontOfSize: floor([NSFont systemFontSize] * 12.0 / 14.0 + 0.5)]);
    }
  return ([toolbar displayMode] == NSToolbarDisplayModeLabelOnly) ? regular : caption;
}

static NSSize
WinUIThemeToolbarLabelSize(NSToolbarItem *item)
{
  NSToolbar *toolbar = [item toolbar];
  NSString *label = [item label];
  NSSize size;

  if (WinUIThemeToolbarShowsLabels(toolbar) == NO || [label length] == 0)
    {
      return NSZeroSize;
    }
  size = [label sizeWithAttributes: [NSDictionary dictionaryWithObject: WinUIThemeToolbarLabelFont(toolbar)
                                                                forKey: NSFontAttributeName]];
  return NSMakeSize(ceil(size.width), ceil(size.height));
}

/* The size an item's image is drawn at: its own, scaled down to fit 20pt
   (16pt in small mode). */
static NSSize
WinUIThemeToolbarImageSize(NSImage *image, NSToolbar *toolbar)
{
  NSValue *own = nil;
  NSSize size;
  CGFloat limit = ([toolbar sizeMode] == NSToolbarSizeModeSmall)
    ? WinUIThemeToolbarSmallIconSize : WinUIThemeToolbarIconSize;

  if (image == nil)
    {
      return NSZeroSize;
    }
  own = objc_getAssociatedObject(image, &WinUIThemeToolbarImageSizeKey);
  if (own == nil)
    {
      own = [NSValue valueWithSize: [image size]];
      objc_setAssociatedObject(image, &WinUIThemeToolbarImageSizeKey, own,
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  size = [own sizeValue];
  if (size.width > limit || size.height > limit)
    {
      CGFloat scale = limit / MAX(size.width, size.height);

      size = NSMakeSize(floor(size.width * scale), floor(size.height * scale));
    }
  return size;
}

/* A view item's view width: its own, within the item's minSize and
   maxSize when it has them. */
static CGFloat
WinUIThemeToolbarViewWidth(NSToolbarItem *item)
{
  CGFloat width = NSWidth([[item view] frame]);
  CGFloat minWidth = [item minSize].width;
  CGFloat maxWidth = [item maxSize].width;

  if (minWidth > 0.0)
    {
      width = MAX(width, minWidth);
    }
  if (maxWidth > 0.0 && maxWidth >= minWidth)
    {
      width = MIN(width, maxWidth);
    }
  return width;
}

/* An item's content: the button an image item is drawn as, or a view
   item's view (with its label under it). */
static NSSize
WinUIThemeToolbarContentSize(NSToolbarItem *item)
{
  NSToolbar *toolbar = [item toolbar];
  NSSize label = WinUIThemeToolbarLabelSize(item);
  NSView *view = [item view];
  NSSize content;

  if (WinUIThemeToolbarTextItem(item))
    {
      return NSMakeSize(label.width + 2.0 * WinUIThemeToolbarLabelPadding,
                        WinUIThemeToolbarTextButtonHeight);
    }
  if (view != nil)
    {
      content = NSMakeSize(WinUIThemeToolbarViewWidth(item), NSHeight([view frame]));
    }
  else
    {
      NSSize image = WinUIThemeToolbarImageSize([item image], toolbar);
      CGFloat padding = (label.height > 0.0)
        ? WinUIThemeToolbarLabeledIconPadding : WinUIThemeToolbarIconPadding;

      content = NSMakeSize(image.width + 2.0 * WinUIThemeToolbarIconPadding,
                           image.height + 2.0 * padding);
      if (label.height == 0.0)
        {
          content.width = MAX(content.width, WinUIThemeToolbarButtonSize);
          content.height = MAX(content.height, WinUIThemeToolbarButtonSize);
        }
    }
  if (label.height > 0.0)
    {
      content.width = MAX(content.width, label.width + 2.0 * WinUIThemeToolbarLabelPadding);
      content.height += WinUIThemeToolbarLabelGap + label.height;
    }
  return content;
}

/* The height an item's slot needs. */
static CGFloat
WinUIThemeToolbarItemHeight(NSToolbarItem *item)
{
  NSSize content = WinUIThemeToolbarContentSize(item);

  return MAX(WinUIThemeToolbarRowHeight, content.height + 2.0 * 4.0);
}

/* Where an item's content sits in its slot: centred. */
static NSRect
WinUIThemeToolbarContentRect(NSToolbarItem *item, NSRect slot)
{
  NSSize content = WinUIThemeToolbarContentSize(item);

  return NSMakeRect(floor(NSMidX(slot) - content.width / 2.0),
                    floor(NSMidY(slot) - content.height / 2.0),
                    content.width, content.height);
}

/* Puts a view item's view in its slot, above its label. */
static void
WinUIThemePlaceToolbarView(NSView *backView, NSToolbarItem *item)
{
  NSView *view = [item view];
  NSRect content;

  if (view == nil || [view superview] != backView)
    {
      return;
    }
  content = WinUIThemeToolbarContentRect(item, [backView bounds]);
  [view setFrameOrigin: NSMakePoint(floor(NSMidX(content) - NSWidth([view frame]) / 2.0),
                                    NSMaxY(content) - NSHeight([view frame]))];
}

@implementation WinUITheme (Toolbar)

/* The toolbar sits on the window background with a hairline under it
   (DividerStrokeColorDefault), not libs-gui's dark grey line. */
- (NSColor *) toolbarBackgroundColor
{
  return WinUIThemeColorFromTheme(self, @"windowBackgroundColor", [NSColor windowBackgroundColor]);
}

- (NSColor *) toolbarBorderColor
{
  return WinUIThemeBlendColor([self toolbarBackgroundColor],
                              WinUIThemeColorFromTheme(self, @"labelColor", [NSColor controlTextColor]),
                              [[self settings] highContrastEnabled] ? 1.0 : 0.08);
}

- (void) _overrideGSToolbarBackViewMethod_layout
{
  typedef void (*LayoutIMP)(id, SEL);
  LayoutIMP originalIMP = (LayoutIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSToolbarBackView"));
  NSView *backView = (NSView *)self;
  NSToolbarItem *item = [(id<WinUIThemeToolbarButton>)backView toolbarItem];
  NSToolbar *toolbar = [item toolbar];
  NSView *view = [item view];
  NSSize content;

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }
  if (toolbar == nil)
    {
      return;
    }
  /* libs-gui drops a view taller than 32pt (24pt small): keep it. */
  if (view != nil && [view superview] == nil && [toolbar displayMode] != NSToolbarDisplayModeLabelOnly)
    {
      [backView addSubview: view];
    }
  content = WinUIThemeToolbarContentSize(item);
  [backView setFrameSize: NSMakeSize(content.width + 2.0 * WinUIThemeToolbarSpacing,
                                     WinUIThemeToolbarItemHeight(item))];
  WinUIThemePlaceToolbarView(backView, item);
}

/* A view item's label, under the view (or alone, centred), in the text
   colour. */
- (void) _overrideGSToolbarBackViewMethod_drawRect: (NSRect)rect
{
  typedef void (*DrawIMP)(id, SEL, NSRect);
  DrawIMP originalIMP = (DrawIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSToolbarBackView"));
  NSView *backView = (NSView *)self;
  NSToolbarItem *item = [(id<WinUIThemeToolbarButton>)backView toolbarItem];
  NSToolbar *toolbar = [item toolbar];
  WinUITheme *theme = (WinUITheme *)[GSTheme theme];
  NSMutableParagraphStyle *style = nil;
  NSDictionary *attributes = nil;
  NSSize label;
  NSRect content;
  NSRect labelRect;

  if (toolbar == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, rect);
        }
      return;
    }
  label = WinUIThemeToolbarLabelSize(item);
  if (label.height == 0.0)
    {
      return;
    }
  content = WinUIThemeToolbarContentRect(item, [backView bounds]);
  labelRect = NSMakeRect(NSMinX([backView bounds]), NSMinY(content), NSWidth([backView bounds]), label.height);
  if ([backView isFlipped])
    {
      labelRect.origin.y = NSMaxY(content) - label.height;
    }
  if ([toolbar displayMode] == NSToolbarDisplayModeLabelOnly)
    {
      labelRect.origin.y = floor(NSMidY(content) - label.height / 2.0);
    }
  style = AUTORELEASE([[NSParagraphStyle defaultParagraphStyle] mutableCopy]);
  [style setAlignment: NSCenterTextAlignment];
  attributes = [NSDictionary dictionaryWithObjectsAndKeys:
    WinUIThemeToolbarLabelFont(toolbar), NSFontAttributeName,
    [item isEnabled]
      ? WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor])
      : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor", [NSColor disabledControlTextColor]),
    NSForegroundColorAttributeName,
    style, NSParagraphStyleAttributeName, nil];
  [[item label] drawInRect: labelRect withAttributes: attributes];
}

/* After libs-gui places the items: every slot gets the row's height (the
   tallest item's), so the row is even and spaces don't set it. */
- (void) _overrideGSToolbarViewMethod__handleBackViewsFrame
{
  typedef void (*HandleIMP)(id, SEL);
  HandleIMP originalIMP = (HandleIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSToolbarView"));
  NSToolbar *toolbar = [(id)self toolbar];
  NSEnumerator *enumerator = nil;
  NSToolbarItem *item = nil;
  CGFloat row = WinUIThemeToolbarRowHeight;
  Ivar heightIvar = NULL;

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }
  if (toolbar == nil)
    {
      return;
    }
  enumerator = [[toolbar items] objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      if (WinUIThemeToolbarItemIsSpace(item) == NO)
        {
          row = MAX(row, WinUIThemeToolbarItemHeight(item));
        }
    }
  enumerator = [[toolbar items] objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      NSView *backView = [item _backView];

      [backView setFrameSize: NSMakeSize(NSWidth([backView frame]), row)];
      WinUIThemePlaceToolbarView(backView, item);
    }
  heightIvar = class_getInstanceVariable([self class], "_heightFromLayout");
  if (heightIvar != NULL)
    {
      *(CGFloat *)((char *)self + ivar_getOffset(heightIvar)) = row;
    }
}

/* After libs-gui shares out the flexible width: it sets each view to its
   slot less its own 10pt insets, narrower than the slot this layout gives
   it, so views shrank on every layout (Adwaita#9). Each view gets its slot
   less the theme's insets instead, within its item's minSize and
   maxSize. */
- (void) _overrideGSToolbarViewMethod__takeInAccountFlexibleSpaces
{
  typedef void (*TakeIMP)(id, SEL);
  TakeIMP originalIMP = (TakeIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSToolbarView"));
  NSToolbar *toolbar = [(id)self toolbar];
  NSEnumerator *enumerator = nil;
  NSToolbarItem *item = nil;

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }
  if (toolbar == nil)
    {
      return;
    }
  enumerator = [[toolbar items] objectEnumerator];
  while ((item = [enumerator nextObject]) != nil)
    {
      NSView *backView = [item _backView];
      NSView *view = [item view];
      CGFloat width, minWidth, maxWidth;

      if (view == nil || [view superview] != backView)
        {
          continue;
        }
      width = NSWidth([backView frame]) - 2.0 * WinUIThemeToolbarSpacing;
      minWidth = [item minSize].width;
      maxWidth = [item maxSize].width;
      if (maxWidth > 0.0 && maxWidth >= minWidth)
        {
          width = MIN(width, maxWidth);
        }
      width = MAX(width, MAX(minWidth, 0.0));
      [view setFrameSize: NSMakeSize(width, NSHeight([view frame]))];
      WinUIThemePlaceToolbarView(backView, item);
    }
}

- (void) _overrideGSToolbarButtonMethod_layout
{
  typedef void (*LayoutIMP)(id, SEL);
  LayoutIMP originalIMP = (LayoutIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSToolbarButton"));
  NSButton *button = (NSButton *)self;
  NSNumber *tag = objc_getAssociatedObject(button, &WinUIThemeToolbarButtonTrackingKey);
  NSToolbarItem *toolbarItem = [button respondsToSelector: @selector(toolbarItem)]
    ? [(id<WinUIThemeToolbarButton>)button toolbarItem] : nil;
  NSToolbar *toolbar = [toolbarItem toolbar];

  /* Note the image's own size before libs-gui makes it 32x32. */
  if (toolbar != nil)
    {
      WinUIThemeToolbarImageSize([toolbarItem image], toolbar);
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }
  if (toolbar != nil)
    {
      if (WinUIThemeToolbarItemIsSpace(toolbarItem))
        {
          [button setFrameSize: NSMakeSize(NSWidth([button frame]), WinUIThemeToolbarRowHeight)];
        }
      else
        {
          NSSize image = WinUIThemeToolbarImageSize([toolbarItem image], toolbar);

          if (NSEqualSizes(image, NSZeroSize) == NO)
            {
              [[toolbarItem image] setSize: image];
            }
          [button setFont: WinUIThemeToolbarLabelFont(toolbar)];
          [button setFrameSize: NSMakeSize(WinUIThemeToolbarContentSize(toolbarItem).width
                                             + 2.0 * WinUIThemeToolbarSpacing,
                                           WinUIThemeToolbarItemHeight(toolbarItem))];
        }
      /* Without its label, a button is named by its tool tip, as an
         AppBarButton's label is. The item's own tool tip wins. */
      if ([toolbarItem toolTip] == nil)
        {
          [button setToolTip: ([toolbar displayMode] == NSToolbarDisplayModeIconOnly)
                                ? [toolbarItem label] : nil];
        }
    }
  /* The pressed state is the fill drawn below; GNUstep's own highlight
     (NSChangeGrayCellMask) turned the label white on it. */
  [[button cell] setHighlightsBy: NSNoCellMask];
  if (tag != nil)
    {
      [button removeTrackingRect: [tag integerValue]];
    }
  tag = [NSNumber numberWithInteger: [button addTrackingRect: [button bounds]
                                                      owner: [WinUIThemeToolbarHoverTracker sharedTracker]
                                                   userData: button
                                               assumeInside: NO]];
  objc_setAssociatedObject(button, &WinUIThemeToolbarButtonTrackingKey, tag,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/* AppBarButton's hover and pressed fills: SubtleFillColorSecondary (the
   text colour at 6%) under the pointer, SubtleFillColorTertiary (4%)
   pressed, 4pt corners. */
- (void) _overrideGSToolbarButtonCellMethod_drawWithFrame: (NSRect)cellFrame
                                                   inView: (NSView *)controlView
{
  typedef void (*DrawIMP)(id, SEL, NSRect, NSView *);
  DrawIMP originalIMP = (DrawIMP)WinUIThemeOriginalMethod(_cmd, self, NSClassFromString(@"GSToolbarButtonCell"));
  NSButtonCell *cell = (NSButtonCell *)self;
  WinUITheme *theme = (WinUITheme *)[GSTheme theme];
  NSToolbarItem *toolbarItem = [controlView respondsToSelector: @selector(toolbarItem)]
    ? [(id<WinUIThemeToolbarButton>)controlView toolbarItem] : nil;
  NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);

  /* The button is the item's content, centred in its slot, and its image
     and label are drawn there. */
  if ([toolbarItem toolbar] != nil && WinUIThemeToolbarItemIsSpace(toolbarItem) == NO)
    {
      cellFrame = WinUIThemeToolbarContentRect(toolbarItem, cellFrame);
      buttonRect = cellFrame;
    }
  if ([theme isKindOfClass: [WinUITheme class]] && [controlView window] != nil && [cell isEnabled])
    {
      BOOL pressed = [cell isHighlighted];
      BOOL hover = (objc_getAssociatedObject(controlView, &WinUIThemeToolbarButtonHoverKey) != nil);

      if (pressed || hover)
        {
          NSColor *background = [theme toolbarBackgroundColor];
          NSColor *textColor = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);

          WinUIThemeFillAndStrokeRoundedRect(buttonRect,
                                             [[theme metrics] controlCornerRadius],
                                             WinUIThemeBlendColor(background, textColor,
                                                                  pressed ? 0.04 : 0.06),
                                             nil,
                                             0.0);
        }
    }
  /* A label alone: libs-gui draws it at the top of the frame it's given;
     give it a frame of the label's height, centred in the button. */
  if ([toolbarItem toolbar] != nil && [cell imagePosition] == NSNoImage)
    {
      CGFloat height = WinUIThemeToolbarLabelSize(toolbarItem).height;

      if (height > 0.0 && height < NSHeight(cellFrame))
        {
          cellFrame = NSMakeRect(NSMinX(cellFrame), floor(NSMidY(cellFrame) - height / 2.0),
                                 NSWidth(cellFrame), height);
        }
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, cellFrame, controlView);
    }
}

@end
