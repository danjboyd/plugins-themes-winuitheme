#import "WinUIThemeDrawing.h"

#import "../Settings/WinUIThemeMetrics.h"
#import "../Settings/WinUIThemeSettings.h"

@interface NSCell (WinUIThemeTextDrawingPrivate)
- (NSDictionary *) _nonAutoreleasedTypingAttributes;
- (BOOL) _shouldShortenStringForRect: (NSRect)titleRect
                                size: (NSSize)titleSize
                              length: (NSUInteger)length;
- (void) _drawAttributedText: (NSAttributedString *)attrstring
                     inFrame: (NSRect)cellFrame;
- (void) _drawText: (NSString *)aString
           inFrame: (NSRect)cellFrame;
@end

static inline WinUITheme *
WinUIThemeActiveTheme(void)
{
  GSTheme *theme = [GSTheme theme];

  if ([theme isKindOfClass: [WinUITheme class]] == NO)
    {
      return nil;
    }

  return (WinUITheme *)theme;
}

static NSColor *
WinUIThemeAccentStrokeColor(WinUITheme *theme)
{
  NSColor *accent = WinUIThemeColorFromTheme(theme,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);

  if ([[theme settings] prefersDarkAppearance])
    {
      return WinUIThemeBlendColor(accent, [NSColor blackColor], 0.28);
    }

  return WinUIThemeBlendColor(accent, [NSColor blackColor], 0.16);
}

static BOOL
WinUIThemeButtonImageLooksLikeSwitch(NSImage *image)
{
  NSString *name = [image name];

  return (image != nil
          && (image == [NSImage imageNamed: @"NSSwitch"]
          || image == [NSImage imageNamed: @"NSHighlightedSwitch"]
          || image == [NSImage imageNamed: @"GSSwitch"]
          || image == [NSImage imageNamed: @"GSSwitchSelected"]
          || (name != nil
              && [name rangeOfString: @"switch"
                              options: NSCaseInsensitiveSearch].location != NSNotFound)));
}

static BOOL
WinUIThemeButtonImageLooksLikeRadio(NSImage *image)
{
  NSString *name = [image name];

  return (image != nil
          && (image == [NSImage imageNamed: @"NSRadioButton"]
          || image == [NSImage imageNamed: @"NSHighlightedRadioButton"]
          || image == [NSImage imageNamed: @"GSRadio"]
          || image == [NSImage imageNamed: @"GSRadioSelected"]
          || (name != nil
              && [name rangeOfString: @"radio"
                              options: NSCaseInsensitiveSearch].location != NSNotFound)));
}

static void
WinUIThemeDrawCheckboxOrRadioIndicator(WinUITheme *theme,
                                       NSButtonCell *cell,
                                       NSRect indicatorFrame,
                                       NSView *controlView,
                                       BOOL radio)
{
  BOOL enabled = [cell isEnabled];
  BOOL highlighted = [cell isHighlighted];
  NSInteger state = [cell state];
  CGFloat indicatorSize = MIN(18.0,
                              MAX(14.0, floor(MIN(indicatorFrame.size.width,
                                                  indicatorFrame.size.height) - 1.0)));
  NSRect indicatorRect = NSMakeRect(floor(NSMidX(indicatorFrame) - (indicatorSize / 2.0)),
                                    floor(NSMidY(indicatorFrame) - (indicatorSize / 2.0)),
                                    indicatorSize,
                                    indicatorSize);
  NSColor *fillColor = nil;
  NSColor *borderColor = nil;
  NSColor *markColor = nil;
  NSBezierPath *path = nil;

  if (state == NSOnState || state == NSMixedState)
    {
      fillColor = WinUIThemeColorFromTheme(theme,
                                           @"accentColor",
                                           [NSColor selectedControlColor]);
      borderColor = WinUIThemeAccentStrokeColor(theme);
      markColor = WinUIThemeColorFromTheme(theme,
                                           @"selectedControlTextColor",
                                           [NSColor selectedControlTextColor]);
    }
  else
    {
      NSColor *separator = WinUIThemeColorFromTheme(theme,
                                                    @"separatorColor",
                                                    [NSColor controlShadowColor]);
      NSColor *labelColor = WinUIThemeColorFromTheme(theme,
                                                     @"labelColor",
                                                     [NSColor controlTextColor]);

      fillColor = WinUIThemeColorFromTheme(theme,
                                           @"fieldBackgroundColor",
                                           [NSColor textBackgroundColor]);
      borderColor = WinUIThemeBlendColor(separator, labelColor, 0.12);
      markColor = labelColor;
    }

  if (highlighted && enabled)
    {
      fillColor = WinUIThemeBlendColor(fillColor,
                                       WinUIThemeColorFromTheme(theme,
                                                                @"separatorColor",
                                                                [NSColor controlShadowColor]),
                                       0.12);
    }
  if (enabled == NO)
    {
      fillColor = WinUIThemeBlendColor(fillColor,
                                       WinUIThemeColorFromTheme(theme,
                                                                @"windowBackgroundColor",
                                                                [NSColor windowBackgroundColor]),
                                       0.35);
      borderColor = WinUIThemeBlendColor(borderColor, fillColor, 0.30);
      markColor = WinUIThemeColorFromTheme(theme,
                                           @"disabledControlTextColor",
                                           [NSColor disabledControlTextColor]);
    }

  if (WinUIThemeViewHasFocus(controlView) && enabled)
    {
      NSColor *accent = WinUIThemeColorFromTheme(theme,
                                                 @"accentColor",
                                                 [NSColor keyboardFocusIndicatorColor]);
      NSRect focusRect = NSInsetRect(indicatorRect, -2.0, -2.0);
      NSBezierPath *focusPath = WinUIThemeRoundedPath(focusRect,
                                                      radio ? focusRect.size.height / 2.0 : 6.0);

      [WinUIThemeColorWithAlpha(accent, 0.18) set];
      [focusPath setLineWidth: 2.0];
      [focusPath stroke];
    }

  if (radio)
    {
      path = [NSBezierPath bezierPathWithOvalInRect: NSInsetRect(indicatorRect, 0.5, 0.5)];
    }
  else
    {
      path = WinUIThemeRoundedPath(NSInsetRect(indicatorRect, 0.5, 0.5), 4.0);
    }

  [fillColor set];
  [path fill];
  [borderColor set];
  [path setLineWidth: 1.0];
  [path stroke];

  if (state == NSOnState)
    {
      if (radio)
        {
          WinUIThemeDrawRadioDot(NSInsetRect(indicatorRect,
                                             indicatorSize * 0.28,
                                             indicatorSize * 0.28),
                                 markColor);
        }
      else
        {
          WinUIThemeDrawCheckmark(indicatorRect, markColor);
        }
    }
  else if (state == NSMixedState)
    {
      NSRect dashRect = NSMakeRect(NSMinX(indicatorRect) + indicatorSize * 0.22,
                                   NSMidY(indicatorRect) - 1.5,
                                   indicatorSize * 0.56,
                                   3.0);

      WinUIThemeFillAndStrokeRoundedRect(dashRect, 1.5, markColor, nil, 0.0);
    }
}

static BOOL
WinUIThemeDrawCheckboxOrRadioCell(NSButtonCell *cell,
                                  NSRect cellFrame,
                                  NSView *controlView)
{
  WinUITheme *theme = WinUIThemeActiveTheme();
  BOOL checkbox = WinUIThemeButtonCellIsCheckbox(cell);
  BOOL radio = WinUIThemeButtonCellIsRadio(cell);

  if (theme == nil || (checkbox == NO && radio == NO))
    {
      return NO;
    }

  {
    BOOL enabled = [cell isEnabled];
    NSRect contentRect = [cell drawingRectForBounds: cellFrame];
    CGFloat indicatorSize = MIN(18.0, MAX(14.0, floor(contentRect.size.height - 2.0)));
    NSRect indicatorRect = NSMakeRect(contentRect.origin.x + 1.0,
                                      floor(NSMidY(contentRect) - (indicatorSize / 2.0)),
                                      indicatorSize,
                                      indicatorSize);
    NSRect titleRect = contentRect;

    titleRect.origin.x = NSMaxX(indicatorRect) + 8.0;
    titleRect.size.width = MAX(0.0, NSMaxX(contentRect) - titleRect.origin.x);
    WinUIThemeDrawCheckboxOrRadioIndicator(theme, cell, indicatorRect, controlView, radio);

    WinUIThemeDrawIndicatorLabel(cell, titleRect, controlView, enabled);
  }

  return YES;
}

static void
WinUIThemeUpdateSegmentFrame(NSSegmentedCell *cell,
                             NSInteger segmentIndex,
                             NSRect frame)
{
  NSArray *items = nil;
  id item = nil;

  if (cell == nil)
    {
      return;
    }

  @try
    {
      items = [cell valueForKey: @"_items"];
    }
  @catch (id exception)
    {
      items = nil;
    }

  if ([items respondsToSelector: @selector(objectAtIndex:)] == NO
      || segmentIndex < 0
      || segmentIndex >= (NSInteger)[items count])
    {
      return;
    }

  item = [items objectAtIndex: segmentIndex];
  if ([item respondsToSelector: @selector(setFrame:)])
    {
      [item setFrame: frame];
    }
}

static NSDictionary *
WinUIThemeSegmentedLabelAttributes(NSSegmentedCell *cell,
                                   WinUITheme *theme,
                                   BOOL selected)
{
  NSMutableDictionary *attributes = nil;
  NSFont *font = nil;
  NSColor *color = nil;
  NSMutableParagraphStyle *paragraphStyle = nil;

  if (cell == nil || theme == nil)
    {
      return nil;
    }

  attributes = [[cell _nonAutoreleasedTypingAttributes] mutableCopy];
  font = WinUIThemePreferredControlFont(theme,
                                        [attributes objectForKey: NSFontAttributeName],
                                        selected);
  if (font != nil)
    {
      [attributes setObject: font forKey: NSFontAttributeName];
    }

  color = WinUIThemeColorFromTheme(theme,
                                   selected ? @"labelColor" : @"secondaryLabelColor",
                                   [NSColor controlTextColor]);
  if (color != nil)
    {
      [attributes setObject: color forKey: NSForegroundColorAttributeName];
    }

  paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [paragraphStyle setAlignment: NSCenterTextAlignment];
  [paragraphStyle setLineBreakMode: NSLineBreakByTruncatingTail];
  [attributes setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];

  return attributes;
}

static void
WinUIThemeDrawSegmentedLabel(NSSegmentedCell *cell,
                             WinUITheme *theme,
                             NSString *label,
                             NSRect frame,
                             BOOL selected,
                             BOOL roundedLeft,
                             BOOL roundedRight)
{
  NSDictionary *attributes = nil;
  NSSize titleSize = NSZeroSize;
  NSRect textFrame = frame;
  CGFloat opticalXOffset = 0.0;
  CGFloat leftInset = 6.0;
  CGFloat rightInset = 6.0;
  NSAttributedString *attrstring = nil;

  if (cell == nil || theme == nil || [label length] == 0)
    {
      return;
    }

  attributes = WinUIThemeSegmentedLabelAttributes(cell, theme, selected);
  titleSize = [label sizeWithAttributes: attributes];

  if ([cell _shouldShortenStringForRect: frame
                                   size: titleSize
                                 length: [label length]])
    {
      NSAttributedString *attrstring = AUTORELEASE([[NSAttributedString alloc]
        initWithString: label
            attributes: attributes]);

      [cell _drawAttributedText: attrstring inFrame: frame];
      RELEASE(attributes);
      return;
    }

  if (roundedLeft != roundedRight)
    {
      CGFloat radius = MAX(6.0, [[theme metrics] controlCornerRadius] + 2.0);
      CGFloat capOffset = MIN(4.0, MAX(2.0, ceil(radius * 0.5)));

      opticalXOffset = roundedLeft ? capOffset : -capOffset;
      if (roundedLeft)
        {
          leftInset += capOffset;
        }
      else
        {
          rightInset += capOffset;
        }
    }

  attrstring = AUTORELEASE([[NSAttributedString alloc] initWithString: label
                                                           attributes: attributes]);
  textFrame.origin.x += leftInset;
  textFrame.size.width = MAX(0.0, textFrame.size.width - (leftInset + rightInset));
  textFrame.origin.x += opticalXOffset;
  textFrame.origin.y = floor(NSMidY(frame) - (titleSize.height / 2.0)) - 1.0;
  textFrame.size.height = ceil(titleSize.height);
  [cell _drawAttributedText: attrstring inFrame: textFrame];
  RELEASE(attributes);
}

static void
WinUIThemeDrawSegmentedImage(NSImage *image,
                             NSRect frame,
                             NSView *view,
                             BOOL enabled)
{
  NSSize imageSize = NSZeroSize;
  CGFloat maxIconSize = 18.0;
  CGFloat scale = 1.0;
  NSRect destinationRect = NSZeroRect;
  CGFloat fraction = enabled ? 1.0 : 0.45;
  WinUITheme *theme = WinUIThemeActiveTheme();

  if (image == nil || NSIsEmptyRect(frame))
    {
      return;
    }
  /* Template images in the segment's text colour (#25). */
  if (theme != nil && WinUIThemeImageIsTemplate(image))
    {
      image = WinUIThemeTintedImage(image,
                                    enabled
                                      ? WinUIThemeColorFromTheme(theme, @"labelColor",
                                                                 [NSColor controlTextColor])
                                      : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor",
                                                                 [NSColor disabledControlTextColor]));
      fraction = 1.0;
    }

  imageSize = [image size];
  if (imageSize.width <= 0.0 || imageSize.height <= 0.0)
    {
      return;
    }

  maxIconSize = MAX(10.0, MIN(22.0, MIN(frame.size.width - 8.0, frame.size.height - 6.0)));
  scale = MIN(1.0, MIN(maxIconSize / imageSize.width, maxIconSize / imageSize.height));
  imageSize.width = floor(imageSize.width * scale);
  imageSize.height = floor(imageSize.height * scale);

  destinationRect = NSMakeRect(floor(NSMidX(frame) - (imageSize.width / 2.0)),
                               floor(NSMidY(frame) - (imageSize.height / 2.0)),
                               imageSize.width,
                               imageSize.height);

  if (view != nil)
    {
      destinationRect = [view centerScanRect: destinationRect];
    }

  [image drawInRect: destinationRect
           fromRect: NSZeroRect
          operation: NSCompositeSourceOver
           fraction: fraction];
}

static NSString *
WinUIThemePopupDisplayString(NSPopUpButtonCell *cell)
{
  NSString *title = nil;
  NSInteger selectedIndex = -1;
  id item = nil;

  if (cell == nil)
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
  if ([title length] == 0
      && [cell respondsToSelector: @selector(indexOfSelectedItem)]
      && [cell respondsToSelector: @selector(itemAtIndex:)])
    {
      selectedIndex = [(id)cell indexOfSelectedItem];
      if (selectedIndex >= 0)
        {
          item = [(id)cell itemAtIndex: selectedIndex];
          if ([item respondsToSelector: @selector(title)])
            {
              title = [item title];
            }
        }
    }
  if ([title length] == 0 && [cell respondsToSelector: @selector(titleOfSelectedItem)])
    {
      title = [(id)cell titleOfSelectedItem];
    }
  if ([title length] == 0)
    {
      title = [cell title];
    }
  if ([title length] == 0 && [cell respondsToSelector: @selector(menuItem)])
    {
      item = [(id)cell menuItem];
      if ([item respondsToSelector: @selector(title)])
        {
          title = [item title];
        }
    }

  return (title != nil) ? title : @"";
}

@implementation WinUITheme (Controls)

- (void) setKeyEquivalent: (NSString *)key
            forButtonCell: (NSButtonCell *)cell
{
  if ([key isEqualToString: @"\r"] || [key isEqualToString: @"\n"])
    {
      WinUIThemeRemoveDefaultButtonGlyph(cell);
      return;
    }

  [super setKeyEquivalent: key forButtonCell: cell];
}

- (void) drawButton: (NSRect)frame
                 in: (NSCell *)cell
               view: (NSView *)view
              style: (int)style
              state: (GSThemeControlState)state
{
  BOOL popupButton = [cell isKindOfClass: [NSPopUpButtonCell class]];
  BOOL popupOpen = (popupButton && WinUIThemePopupButtonMenuVisible(cell));
  BOOL enabled = (state != GSThemeDisabledState);
  BOOL defaultButton = enabled && WinUIThemeButtonIsDefault(cell);
  BOOL highlighted = WinUIThemeStateIsHighlighted(state);
  BOOL focused = WinUIThemeStateHasFocus(state);
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *accent = WinUIThemeColorFromTheme(self,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"fieldBackgroundColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *window = WinUIThemeColorFromTheme(self,
                                             @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSColor *labelColor = WinUIThemeColorFromTheme(self,
                                                 @"labelColor",
                                                 [NSColor controlTextColor]);
  NSColor *fillColor = nil;
  NSColor *borderColor = nil;
  NSColor *topHighlight = nil;
  NSColor *titleColor = nil;
  CGFloat radius = MAX(7.0, [[self metrics] controlCornerRadius] + 2.0);
  NSRect drawRect = NSInsetRect(NSIntegralRect(frame), 0.5, 0.5);
  NSBezierPath *buttonPath = nil;

  if (popupButton)
    {
      WinUIThemeDrawInputChrome(self,
                                frame,
                                enabled,
                                highlighted || popupOpen,
                                focused || WinUIThemeViewHasFocus(view),
                                YES,
                                YES);
      return;
    }

  if (WinUIThemeUsesModernPushButton(style) == NO)
    {
      [super drawButton: frame in: cell view: view style: style state: state];
      return;
    }

  if ([cell isKindOfClass: [NSButtonCell class]])
    {
      WinUIThemeRemoveDefaultButtonGlyph((NSButtonCell *)cell);
    }

  if (defaultButton)
    {
      fillColor = highlighted
        ? WinUIThemeBlendColor(accent,
                               dark ? [NSColor whiteColor] : [NSColor blackColor],
                               dark ? 0.10 : 0.16)
        : accent;
      borderColor = highlighted
        ? WinUIThemeBlendColor(WinUIThemeAccentStrokeColor(self), [NSColor blackColor], 0.10)
        : WinUIThemeAccentStrokeColor(self);
      topHighlight = WinUIThemeColorWithAlpha([NSColor whiteColor], dark ? 0.18 : 0.24);
      titleColor = WinUIThemeColorFromTheme(self,
                                            @"selectedControlTextColor",
                                            [NSColor selectedControlTextColor]);
    }
  else if (enabled == NO)
    {
      fillColor = WinUIThemeBlendColor(surface, window, dark ? 0.20 : 0.34);
      borderColor = WinUIThemeBlendColor(separator, surface, dark ? 0.34 : 0.28);
      topHighlight = WinUIThemeColorWithAlpha([NSColor whiteColor], dark ? 0.02 : 0.08);
      titleColor = WinUIThemeColorFromTheme(self,
                                            @"disabledControlTextColor",
                                            [NSColor disabledControlTextColor]);
    }
  else
    {
      fillColor = highlighted
        ? WinUIThemeBlendColor(surface, separator, dark ? 0.20 : 0.10)
        : surface;
      borderColor = focused
        ? WinUIThemeBlendColor(separator, accent, dark ? 0.56 : 0.40)
        : WinUIThemeBlendColor(separator,
                               dark ? [NSColor whiteColor] : labelColor,
                               dark ? 0.12 : 0.03);
      topHighlight = WinUIThemeColorWithAlpha([NSColor whiteColor], dark ? 0.03 : 0.14);
      titleColor = labelColor;
    }

  if ([cell isKindOfClass: [NSButtonCell class]] && titleColor != nil)
    {
      WinUIThemeApplyButtonTitleAttributes(self,
                                           (NSButtonCell *)cell,
                                           titleColor,
                                           defaultButton);
    }

  buttonPath = WinUIThemeRoundedPath(drawRect, radius);
  [fillColor set];
  [buttonPath fill];

  [borderColor set];
  [buttonPath setLineWidth: 1.0];
  [buttonPath stroke];

  if (topHighlight != nil && NSHeight(drawRect) > 10.0)
    {
      NSGraphicsContext *context = [NSGraphicsContext currentContext];
      NSRect topRect = NSInsetRect(drawRect, 1.0, 1.0);
      NSBezierPath *innerPath = WinUIThemeRoundedPath(NSInsetRect(drawRect, 1.0, 1.0),
                                                      MAX(5.0, radius - 1.0));

      topRect.size.height = MAX(3.0, floor(topRect.size.height * 0.42));

      [context saveGraphicsState];
      [innerPath addClip];
      [topHighlight set];
      NSRectFill(topRect);
      [context restoreGraphicsState];
    }
}

- (GSThemeMargins) buttonMarginsForCell: (NSCell *)cell
                                  style: (int)style
                                  state: (GSThemeControlState)state
{
  GSThemeMargins margins;

  if ([cell isKindOfClass: [NSPopUpButtonCell class]])
    {
      CGFloat verticalInset = MAX(5.0, ceil([[self metrics] buttonVerticalPadding]));

      margins.left = 12.0;
      margins.right = 42.0;
      margins.top = verticalInset + 1.0;
      margins.bottom = MAX(4.0, verticalInset - 1.0);
      return margins;
    }

  if (WinUIThemeUsesModernPushButton(style) == NO)
    {
      return [super buttonMarginsForCell: cell style: style state: state];
    }

  margins.left = MAX(8.0, ceil([[self metrics] buttonHorizontalPadding] * 0.78));
  margins.right = margins.left;
  margins.top = MAX(6.0, ceil([[self metrics] buttonVerticalPadding] + 1.0));
  margins.bottom = MAX(4.0, margins.top - 2.0);

  (void)state;
  return margins;
}

- (void) drawBorderType: (NSBorderType)aType
                  frame: (NSRect)frame
                   view: (NSView *)view
{
  if (WinUIThemeUsesInputBorder(aType, view))
    {
      WinUIThemeDrawInputChrome(self,
                                frame,
                                WinUIThemeControlEnabled(view),
                                NO,
                                WinUIThemeViewHasFocus(view),
                                YES,
                                YES);
      return;
    }

  [super drawBorderType: aType frame: frame view: view];
}

- (void) drawFocusFrame: (NSRect)frame view: (NSView *)view
{
  NSColor *accent = WinUIThemeColorFromTheme(self,
                                             @"accentColor",
                                             [NSColor keyboardFocusIndicatorColor]);
  CGFloat radius = MAX(8.0, [[self metrics] controlCornerRadius] + 4.0);
  NSRect outerRect = NSInsetRect(NSIntegralRect(frame), -3.0, -3.0);
  NSRect innerRect = NSInsetRect(outerRect, 1.5, 1.5);
  NSBezierPath *outerPath = WinUIThemeRoundedPath(outerRect, radius);
  NSBezierPath *innerPath = WinUIThemeRoundedPath(innerRect, MAX(5.0, radius - 1.5));

  (void)view;

  [WinUIThemeColorWithAlpha(accent, 0.24) set];
  [outerPath setLineWidth: 3.0];
  [outerPath stroke];

  [WinUIThemeColorWithAlpha(accent, 0.88) set];
  [innerPath setLineWidth: 1.5];
  [innerPath stroke];
}

- (void) drawPopUpButtonCellInteriorWithFrame: (NSRect)cellFrame
                                     withCell: (NSCell *)cell
                                       inView: (NSView *)controlView
{
  BOOL enabled = WinUIThemeControlEnabled(cell);
  BOOL highlighted = NO;
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
  NSRect drawRect = NSInsetRect(NSIntegralRect(cellFrame), 1.0, 1.0);
  CGFloat arrowWidth = MAX(34.0, ceil([[self metrics] popupControlHeight] * 0.96));
  CGFloat dividerX = NSMaxX(drawRect) - arrowWidth;
  NSColor *chevronColor = nil;
  NSColor *laneColor = nil;
  NSRect laneRect = NSMakeRect(dividerX,
                               drawRect.origin.y + 1.0,
                               arrowWidth,
                               MAX(0.0, drawRect.size.height - 2.0));

  if ([cell respondsToSelector: @selector(isHighlighted)])
    {
      highlighted = [(id)cell isHighlighted];
    }

  laneColor = popupOpen
    ? WinUIThemeBlendColor(surface, accent, dark ? 0.24 : 0.08)
    : WinUIThemeBlendColor(surface,
                           WinUIThemeColorFromTheme(self,
                                                    @"windowBackgroundColor",
                                                    [NSColor windowBackgroundColor]),
                           dark ? 0.08 : 0.03);

  [laneColor set];
  [[NSBezierPath bezierPathWithRoundedRect: laneRect xRadius: 7.0 yRadius: 7.0] fill];

  [WinUIThemeColorWithAlpha(separator, popupOpen ? (dark ? 0.58 : 0.78) : (dark ? 0.72 : 0.92)) set];
  NSRectFill(NSMakeRect(dividerX,
                        drawRect.origin.y + 7.0,
                        1.0,
                        MAX(4.0, drawRect.size.height - 14.0)));

  chevronColor = enabled
    ? (highlighted || popupOpen ? accent : labelColor)
    : disabledColor;
  WinUIThemeDrawChevron(NSMakePoint(dividerX + floor(arrowWidth / 2.0) - 1.0,
                                    NSMidY(drawRect)),
                        NO,
                        chevronColor);

  (void)controlView;
}

- (void) drawSegmentedControlSegment: (NSCell *)cell
                           withFrame: (NSRect)cellFrame
                              inView: (NSView *)controlView
                               style: (NSSegmentStyle)style
                               state: (GSThemeControlState)state
                         roundedLeft: (BOOL)roundedLeft
                        roundedRight: (BOOL)roundedRight
{
  BOOL enabled = (state != GSThemeDisabledState);
  BOOL selected = WinUIThemeStateIsHighlighted(state);
  BOOL focused = WinUIThemeStateHasFocus(state);
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);

  (void)cell;
  (void)controlView;
  (void)style;

  WinUIThemeDrawSegmentChrome(self,
                              cellFrame,
                              enabled,
                              selected,
                              focused,
                              roundedLeft,
                              roundedRight);

  if (roundedRight == NO)
    {
      NSRect drawRect = NSInsetRect(NSIntegralRect(cellFrame), 0.5, 0.5);

      [WinUIThemeColorWithAlpha(separator, dark ? 0.72 : 0.92) set];
      NSRectFill(NSMakeRect(NSMaxX(drawRect) - 0.5,
                            drawRect.origin.y + 7.0,
                            1.0,
                            MAX(4.0, drawRect.size.height - 14.0)));
    }
}

- (void) drawStepperCell: (NSCell *)cell
               withFrame: (NSRect)cellFrame
                  inView: (NSView *)controlView
             highlightUp: (BOOL)highlightUp
           highlightDown: (BOOL)highlightDown
{
  BOOL enabled = WinUIThemeControlEnabled(cell);
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"fieldBackgroundColor",
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
  NSRect drawRect = NSInsetRect(NSIntegralRect(cellFrame), 0.5, 0.5);
  NSRect upRect = [self stepperUpButtonRectWithFrame: drawRect];
  NSRect downRect = [self stepperDownButtonRectWithFrame: drawRect];
  NSBezierPath *outerPath = WinUIThemeRoundedPath(drawRect,
                                                  MAX(7.0, [[self metrics] controlCornerRadius] + 2.0));
  NSColor *arrowColor = enabled ? labelColor : disabledColor;

  [surface set];
  [outerPath fill];

  [WinUIThemeBlendColor(separator,
                        dark ? [NSColor whiteColor] : labelColor,
                        dark ? 0.16 : 0.10) set];
  [outerPath setLineWidth: 1.0];
  [outerPath stroke];

  if (highlightUp)
    {
      NSGraphicsContext *context = [NSGraphicsContext currentContext];

      [context saveGraphicsState];
      [outerPath addClip];
      [WinUIThemeBlendColor(surface, accent, dark ? 0.26 : 0.10) set];
      NSRectFill(upRect);
      [context restoreGraphicsState];
      arrowColor = accent;
    }

  if (highlightDown)
    {
      NSGraphicsContext *context = [NSGraphicsContext currentContext];

      [context saveGraphicsState];
      [outerPath addClip];
      [WinUIThemeBlendColor(surface, accent, dark ? 0.26 : 0.10) set];
      NSRectFill(downRect);
      [context restoreGraphicsState];
      arrowColor = accent;
    }

  [WinUIThemeColorWithAlpha(separator, dark ? 0.82 : 1.0) set];
  NSRectFill(NSMakeRect(drawRect.origin.x + 1.0,
                        NSMaxY(downRect) - 0.5,
                        drawRect.size.width - 2.0,
                        1.0));

  WinUIThemeDrawChevron(NSMakePoint(NSMidX(upRect), NSMidY(upRect)), YES, arrowColor);
  WinUIThemeDrawChevron(NSMakePoint(NSMidX(downRect), NSMidY(downRect)), NO, arrowColor);

  (void)controlView;
}

/* WinUI ToggleSwitch colours. Off: a strong-stroke outline round an empty
   track and a knob in the secondary text colour. On: an accent track and a
   knob in the text-on-accent colour. Disabled keeps the on/off difference
   in the disabled colours. Fluent's colours are the text colour at an
   opacity; these blend it over the window background. */
static void
WinUIThemeSwitchColors(WinUITheme *theme,
                       BOOL on,
                       BOOL enabled,
                       NSColor **fillOut,
                       NSColor **strokeOut,
                       NSColor **knobOut)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *text = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
  NSColor *window = WinUIThemeColorFromTheme(theme,
                                             @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *accent = WinUIThemeColorFromTheme(theme,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  NSColor *onAccent = dark ? [NSColor blackColor] : [NSColor whiteColor];

  if (on && enabled)
    {
      *fillOut = accent;
      *strokeOut = nil;
      *knobOut = onAccent;
    }
  else if (on)
    {
      *fillOut = WinUIThemeBlendColor(window, text, dark ? 0.16 : 0.22);
      *strokeOut = nil;
      *knobOut = dark ? WinUIThemeBlendColor(window, [NSColor whiteColor], 0.53)
                      : [NSColor whiteColor];
    }
  else if (enabled)
    {
      *fillOut = nil;
      *strokeOut = WinUIThemeBlendColor(window, text, dark ? 0.54 : 0.45);
      *knobOut = WinUIThemeBlendColor(window, text, dark ? 0.79 : 0.62);
    }
  else
    {
      *fillOut = nil;
      *strokeOut = WinUIThemeBlendColor(window, text, dark ? 0.16 : 0.22);
      *knobOut = WinUIThemeBlendColor(window, text, 0.36);
    }
}

- (void) drawSwitchBezel: (NSRect)frame
                forState: (NSControlStateValue)value
                 enabled: (BOOL)enabled
{
  NSRect trackRect = WinUIThemeSwitchTrackRect(frame);
  NSColor *fillColor = nil;
  NSColor *strokeColor = nil;
  NSColor *knobColor = nil;
  NSBezierPath *trackPath = nil;

  if (NSHeight(trackRect) < 2.0)
    {
      return;
    }

  WinUIThemeSwitchColors(self, value == NSControlStateValueOn, enabled,
                         &fillColor, &strokeColor, &knobColor);
  if (fillColor != nil)
    {
      trackPath = WinUIThemeRoundedPath(trackRect, NSHeight(trackRect) / 2.0);
      [fillColor set];
      [trackPath fill];
    }
  if (strokeColor != nil)
    {
      NSRect strokeRect = NSInsetRect(trackRect, 0.5, 0.5);

      trackPath = WinUIThemeRoundedPath(strokeRect, NSHeight(strokeRect) / 2.0);
      [strokeColor set];
      [trackPath setLineWidth: 1.0];
      [trackPath stroke];
    }
}

- (void) drawSwitchKnob: (NSRect)frame
               forState: (NSControlStateValue)value
                enabled: (BOOL)enabled
{
  NSRect trackRect = WinUIThemeSwitchTrackRect(frame);
  BOOL on = (value == NSControlStateValueOn);
  CGFloat radius = NSHeight(trackRect) / 2.0;
  /* A 12px knob in the 20px track. */
  CGFloat diameter = round(NSHeight(trackRect) * 0.6);
  CGFloat centerX = on ? NSMaxX(trackRect) - radius : NSMinX(trackRect) + radius;
  NSColor *fillColor = nil;
  NSColor *strokeColor = nil;
  NSColor *knobColor = nil;

  if (NSHeight(trackRect) < 2.0)
    {
      return;
    }

  WinUIThemeSwitchColors(self, on, enabled, &fillColor, &strokeColor, &knobColor);
  [knobColor set];
  [[NSBezierPath bezierPathWithOvalInRect:
     NSMakeRect(centerX - (diameter / 2.0),
                NSMidY(trackRect) - (diameter / 2.0),
                diameter,
                diameter)] fill];
}

- (void) drawSwitchInRect: (NSRect)rect
                 forState: (NSControlStateValue)state
                  enabled: (BOOL)enabled
{
  [self drawSwitchBezel: rect forState: state enabled: enabled];
  [self drawSwitchKnob: rect forState: state enabled: enabled];
}

- (void) drawProgressIndicator: (NSProgressIndicator *)progress
                    withBounds: (NSRect)bounds
                      withClip: (NSRect)rect
                       atCount: (int)count
                      forValue: (double)val
{
  NSRect contentRect = bounds;
  BOOL enabled = WinUIThemeControlEnabled(progress);
  BOOL vertical = [progress isVertical];
  double fraction = WinUIThemeClamp(val, 0.0, 1.0);

  if ([progress style] == NSProgressIndicatorSpinningStyle)
    {
      [super drawProgressIndicator: progress
                        withBounds: bounds
                          withClip: rect
                           atCount: count
                          forValue: val];
      return;
    }

  if ([progress isBezeled])
    {
      contentRect = [self drawProgressIndicatorBezel: bounds withClip: rect];
    }

  if ([progress isIndeterminate])
    {
      NSRect chunkRect = contentRect;
      CGFloat phase = ((count % 24) / 23.0);

      if (vertical)
        {
          CGFloat chunkHeight = MAX(8.0, floor(contentRect.size.height * 0.34));

          chunkRect.size.height = MIN(chunkHeight, contentRect.size.height);
          chunkRect.origin.y = contentRect.origin.y + floor((contentRect.size.height - chunkRect.size.height) * phase);
        }
      else
        {
          CGFloat chunkWidth = MAX(16.0, floor(contentRect.size.width * 0.32));

          chunkRect.size.width = MIN(chunkWidth, contentRect.size.width);
          chunkRect.origin.x = contentRect.origin.x + floor((contentRect.size.width - chunkRect.size.width) * phase);
        }

      [self drawProgressIndicatorBarDeterminate: chunkRect];
      return;
    }

  if (vertical)
    {
      CGFloat fillHeight = floor(contentRect.size.height * fraction);
      NSRect fillRect = NSMakeRect(contentRect.origin.x,
                                   [progress isFlipped]
                                     ? NSMaxY(contentRect) - fillHeight
                                     : contentRect.origin.y,
                                   contentRect.size.width,
                                   fillHeight);

      if (fillRect.size.height > 0.0)
        {
          [self drawProgressIndicatorBarDeterminate: fillRect];
        }
    }
  else
    {
      NSRect fillRect = NSMakeRect(contentRect.origin.x,
                                   contentRect.origin.y,
                                   floor(contentRect.size.width * fraction),
                                   contentRect.size.height);

      if (fillRect.size.width > 0.0)
        {
          [self drawProgressIndicatorBarDeterminate: fillRect];
        }
    }

  if (enabled == NO)
    {
      [WinUIThemeColorWithAlpha([NSColor windowBackgroundColor], 0.20) set];
      NSRectFillUsingOperation(contentRect, NSCompositeSourceOver);
    }
}

- (NSRect) drawProgressIndicatorBezel: (NSRect)bounds withClip: (NSRect)rect
{
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSRect drawRect = NSInsetRect(NSIntegralRect(bounds), 0.5, 0.5);
  CGFloat radius = MIN(MAX(4.0, [[self metrics] controlCornerRadius]),
                       floor(drawRect.size.height / 2.0));
  NSBezierPath *trackPath = WinUIThemeRoundedPath(drawRect, radius);

  [WinUIThemeBlendColor(surface,
                        WinUIThemeColorFromTheme(self,
                                                 @"windowBackgroundColor",
                                                 [NSColor windowBackgroundColor]),
                        dark ? 0.12 : 0.04) set];
  [trackPath fill];

  [WinUIThemeBlendColor(separator, surface, 0.12) set];
  [trackPath setLineWidth: 1.0];
  [trackPath stroke];

  (void)rect;
  return NSInsetRect(drawRect, 2.0, 2.0);
}

- (void) drawProgressIndicatorBarDeterminate: (NSRect)bounds
{
  NSColor *accent = WinUIThemeColorFromTheme(self,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  NSBezierPath *fillPath = WinUIThemeRoundedPath(bounds,
                                                 MIN(floor(bounds.size.height / 2.0),
                                                     MAX(3.0, [[self metrics] controlCornerRadius] - 1.0)));

  [accent set];
  [fillPath fill];

  [WinUIThemeColorWithAlpha([NSColor whiteColor], 0.18) set];
  NSRectFill(NSMakeRect(bounds.origin.x,
                        bounds.origin.y + MAX(1.0, floor(bounds.size.height / 2.0)),
                        bounds.size.width,
                        MAX(1.0, floor(bounds.size.height / 2.0) - 1.0)));
}

- (void) drawSliderBorderAndBackground: (NSBorderType)aType
                                 frame: (NSRect)cellFrame
                                inCell: (NSCell *)cell
                          isHorizontal: (BOOL)horizontal
{
  NSSliderCell *sliderCell = (NSSliderCell *)cell;
  NSRect trackRect = NSIntegralRect(WinUIThemeSliderTrackRect(self, cellFrame, horizontal));
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"surfaceColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSBezierPath *trackPath = nil;

  if ([sliderCell sliderType] != NSLinearSlider)
    {
      [super drawSliderBorderAndBackground: aType
                                     frame: cellFrame
                                    inCell: cell
                              isHorizontal: horizontal];
      return;
    }

  trackPath = WinUIThemeRoundedPath(trackRect, trackRect.size.height / 2.0);
  [WinUIThemeBlendColor(surface,
                        WinUIThemeColorFromTheme(self,
                                                 @"windowBackgroundColor",
                                                 [NSColor windowBackgroundColor]),
                        0.08) set];
  [trackPath fill];

  [WinUIThemeBlendColor(separator, surface, 0.10) set];
  [trackPath setLineWidth: 1.0];
  [trackPath stroke];
}

- (void) drawBarInside: (NSRect)rect inCell: (NSCell *)cell flipped: (BOOL)flipped
{
  NSSliderCell *sliderCell = (NSSliderCell *)cell;
  NSView *controlView = [cell controlView];
  NSRect knobRect = [sliderCell knobRectFlipped: flipped];
  BOOL horizontal = (rect.size.width >= rect.size.height);
  NSRect trackRect = WinUIThemeSliderTrackRect(self, rect, horizontal);
  NSRect activeRect = trackRect;
  double range = [sliderCell maxValue] - [sliderCell minValue];
  double fraction = range == 0.0 ? 0.0 : ([sliderCell doubleValue] - [sliderCell minValue]) / range;

  if ([sliderCell sliderType] != NSLinearSlider)
    {
      [super drawBarInside: rect inCell: cell flipped: flipped];
      return;
    }

  fraction = WinUIThemeClamp(fraction, 0.0, 1.0);

  if (horizontal)
    {
      activeRect.size.width = MAX(0.0, MIN(trackRect.size.width, NSMidX(knobRect) - trackRect.origin.x));
    }
  else if (flipped)
    {
      activeRect.size.height = MAX(0.0, MIN(trackRect.size.height, NSMaxY(trackRect) - NSMidY(knobRect)));
      activeRect.origin.y = NSMaxY(trackRect) - activeRect.size.height;
    }
  else
    {
      activeRect.size.height = MAX(0.0, MIN(trackRect.size.height, NSMidY(knobRect) - trackRect.origin.y));
    }

  if ((horizontal && activeRect.size.width <= 0.0)
      || (horizontal == NO && activeRect.size.height <= 0.0))
    {
      return;
    }

  [self drawProgressIndicatorBarDeterminate: activeRect];

  if (controlView != nil && fabs(fraction - 0.5) < 0.001)
    {
      [controlView setNeedsDisplayInRect: knobRect];
    }
}

- (void) drawKnobInCell: (NSCell *)cell
{
  NSSliderCell *sliderCell = (NSSliderCell *)cell;
  NSView *controlView = [cell controlView];
  BOOL enabled = WinUIThemeControlEnabled(cell);
  BOOL dark = [[self settings] prefersDarkAppearance];
  NSColor *surface = WinUIThemeColorFromTheme(self,
                                              @"fieldBackgroundColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(self,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSColor *accent = WinUIThemeColorFromTheme(self,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  NSRect knobRect = [sliderCell knobRectFlipped: [controlView isFlipped]];
  CGFloat diameter = MIN(knobRect.size.width, knobRect.size.height) - 1.0;
  NSRect circleRect = NSMakeRect(NSMidX(knobRect) - (diameter / 2.0),
                                 NSMidY(knobRect) - (diameter / 2.0),
                                 diameter,
                                 diameter);
  NSBezierPath *knobPath = nil;
  NSColor *fillColor = nil;
  NSColor *borderColor = nil;

  if ([sliderCell sliderType] != NSLinearSlider)
    {
      [super drawKnobInCell: cell];
      return;
    }

  fillColor = enabled ? surface : WinUIThemeBlendColor(surface, separator, 0.24);
  borderColor = enabled
    ? WinUIThemeBlendColor(separator, accent, dark ? 0.10 : 0.18)
    : WinUIThemeBlendColor(separator, surface, 0.35);
  knobPath = [NSBezierPath bezierPathWithOvalInRect: circleRect];

  [fillColor set];
  [knobPath fill];

  [borderColor set];
  [knobPath setLineWidth: 1.0];
  [knobPath stroke];
}

@end

@implementation WinUITheme (Overrides)

- (NSRect) _overrideNSTextFieldCellMethod_titleRectForBounds: (NSRect)aRect
{
  typedef NSRect (*TitleRectIMP)(id, SEL, NSRect);
  TitleRectIMP originalIMP = (TitleRectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSTextFieldCell class]);
  NSTextFieldCell *cell = (NSTextFieldCell *)self;
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSRect titleRect = (originalIMP != NULL) ? originalIMP(self, _cmd, aRect) : aRect;
  NSFont *font = WinUIThemeResolvedEditorFont(theme, cell);
  NSDictionary *attributes = [NSDictionary dictionaryWithObject: font
                                                         forKey: NSFontAttributeName];
  NSSize titleSize = [@"Ag" sizeWithAttributes: attributes];

  /* Labels (text fields without a bezel or border) whose text needs more
     than one line (line breaks, or a wrapping cell too narrow for it) keep
     the full rect; centring them on one line showed only their first line,
     e.g. an NSAlert's informative text. Only when the frame has room for a
     second line: a one-line label that's too long stays centred. Cells drawn
     by table and header views stay single-line. */
  if ([cell isBezeled] == NO && [cell isBordered] == NO
      && [[cell controlView] isKindOfClass: [NSTextField class]])
    {
      NSString *string = [cell stringValue];
      BOOL hasBreaks = ([string rangeOfCharacterFromSet:
                          [NSCharacterSet newlineCharacterSet]].location != NSNotFound);
      BOOL overflows = ([cell wraps]
                        && [[cell attributedStringValue] size].width > NSWidth(titleRect));

      if ((hasBreaks || overflows) && NSHeight(aRect) >= 2.0 * titleSize.height)
        {
          return titleRect;
        }
    }

  /* Header cells call themselves bezeled, but -tableHeaderCellDrawingRectForBounds:
     already insets their titles; the read-only field's inset would double it. */
  if (([cell isBezeled] || [cell isBordered])
      && [cell isKindOfClass: [NSTableHeaderCell class]] == NO)
    {
      BOOL readonlyField = ([cell isEditable] == NO && [cell isSelectable] == NO);
      CGFloat horizontalInset = readonlyField ? 12.0 : 5.0;

      titleRect.origin.x += horizontalInset;
      titleRect.size.width -= (horizontalInset * 2.0);
    }

  titleRect.origin.y = aRect.origin.y + floor((aRect.size.height - titleSize.height) / 2.0);
  titleRect.size.height = ceil(titleSize.height);

  return titleRect;
}

- (NSText *) _overrideNSTextFieldCellMethod_setUpFieldEditorAttributes: (NSText *)textObject
{
  typedef NSText *(*SetUpFieldEditorAttributesIMP)(id, SEL, NSText *);
  SetUpFieldEditorAttributesIMP originalIMP
    = (SetUpFieldEditorAttributesIMP)WinUIThemeOriginalMethod(_cmd, self, [NSTextFieldCell class]);
  NSTextFieldCell *cell = (NSTextFieldCell *)self;
  NSText *editor = textObject;
  WinUITheme *theme = WinUIThemeActiveTheme();

  if (originalIMP != NULL)
    {
      editor = originalIMP(self, _cmd, textObject);
    }

  if (theme != nil)
    {
      WinUIThemeApplyEditorFont(theme, cell, editor);
    }
  return editor;
}

- (void) _overrideNSTextFieldCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                       inView: (NSView *)controlView
{
  NSTextFieldCell *cell = (NSTextFieldCell *)self;

  if ([cell _inEditing])
    {
      [cell _drawEditorWithFrame: cellFrame inView: controlView];
      return;
    }

  WinUIThemeDrawAttributedStringWithEditorLayout(cell,
                                                 [cell _drawAttributedString],
                                                 [cell titleRectForBounds: cellFrame],
                                                 controlView);
}

- (void) _overrideNSSegmentedCellMethod_drawSegment: (NSInteger)segmentIndex
                                            inFrame: (NSRect)frame
                                           withView: (NSView *)view
{
  typedef void (*DrawSegmentIMP)(id, SEL, NSInteger, NSRect, NSView *);
  DrawSegmentIMP originalIMP = (DrawSegmentIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSegmentedCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSSegmentedCell *cell = (NSSegmentedCell *)self;
  NSString *label = [cell labelForSegment: segmentIndex];
  NSImage *segmentImage = [cell imageForSegment: segmentIndex];
  BOOL selected = NO;
  GSThemeControlState state;
  BOOL roundedLeft = (segmentIndex == 0);
  BOOL roundedRight = (segmentIndex == ([cell segmentCount] - 1));
  NSView *controlView = [cell controlView];

  if ([cell trackingMode] == NSSegmentSwitchTrackingSelectOne)
    {
      selected = ([cell selectedSegment] == segmentIndex);
    }
  else
    {
      selected = [cell isSelectedForSegment: segmentIndex];
    }

  WinUIThemeUpdateSegmentFrame(cell, segmentIndex, frame);
  if ([cell isEnabledForSegment: segmentIndex] == NO)
    {
      state = GSThemeDisabledState;
    }
  else
    {
      state = selected ? GSThemeSelectedState : GSThemeNormalState;
    }

  if (theme == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, segmentIndex, frame, view);
        }
      return;
    }

  [theme drawSegmentedControlSegment: cell
                           withFrame: frame
                              inView: (controlView != nil) ? controlView : view
                               style: [cell segmentStyle]
                               state: state
                         roundedLeft: roundedLeft
                        roundedRight: roundedRight];

  if ([label length] > 0)
    {
      WinUIThemeDrawSegmentedLabel(cell,
                                   theme,
                                   label,
                                   frame,
                                   selected,
                                   roundedLeft,
                                   roundedRight);
    }

  WinUIThemeDrawSegmentedImage(segmentImage,
                               frame,
                               (controlView != nil) ? controlView : view,
                               [cell isEnabledForSegment: segmentIndex]);
}

- (void) _overrideNSPopUpButtonCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                         inView: (NSView *)controlView
{
  typedef void (*DrawInteriorIMP)(id, SEL, NSRect, NSView *);
  DrawInteriorIMP originalIMP = (DrawInteriorIMP)WinUIThemeOriginalMethod(_cmd, self, [NSPopUpButtonCell class]);
  NSPopUpButtonCell *cell = (NSPopUpButtonCell *)self;
  WinUITheme *theme = WinUIThemeActiveTheme();
  id menuItem = nil;
  NSImage *arrowImage = nil;
  NSImage *savedArrowImage = nil;
  NSFont *originalFont = [cell font];
  NSFont *popupFont = nil;
  NSPopUpArrowPosition originalArrowPosition = NSPopUpNoArrow;
  BOOL restoreArrowPosition = NO;

  if (theme == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }

  popupFont = WinUIThemePreferredControlFont(theme, originalFont, NO);

  if ([cell respondsToSelector: @selector(menuItem)])
    {
      menuItem = [(id)cell menuItem];
    }
  if ([cell respondsToSelector: NSSelectorFromString(@"_currentArrowImage")])
    {
      arrowImage = [(id)cell performSelector: NSSelectorFromString(@"_currentArrowImage")];
    }
  if ([cell respondsToSelector: @selector(arrowPosition)])
    {
      originalArrowPosition = [cell arrowPosition];
      restoreArrowPosition = YES;
      [cell setArrowPosition: NSPopUpNoArrow];
    }
  if ([cell respondsToSelector: @selector(setImagePosition:)])
    {
      [(id)cell setImagePosition: NSNoImage];
    }
  if (menuItem != nil
      && [menuItem respondsToSelector: @selector(image)]
      && [menuItem respondsToSelector: @selector(setImage:)]
      && [menuItem image] == arrowImage)
    {
      savedArrowImage = RETAIN([menuItem image]);
      [menuItem setImage: nil];
    }
  if (popupFont != nil)
    {
      [cell setFont: popupFont];
    }

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, cellFrame, controlView);
    }

  if (savedArrowImage != nil)
    {
      [menuItem setImage: savedArrowImage];
      RELEASE(savedArrowImage);
    }
  if (restoreArrowPosition)
    {
      [cell setArrowPosition: originalArrowPosition];
    }
  if (popupFont != nil)
    {
      [cell setFont: originalFont];
    }
}

- (NSRect) _overrideNSPopUpButtonCellMethod_titleRectForBounds: (NSRect)aRect
{
  typedef NSRect (*TitleRectIMP)(id, SEL, NSRect);
  TitleRectIMP originalIMP = (TitleRectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSPopUpButtonCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSRect rect = (originalIMP != NULL) ? originalIMP(self, _cmd, aRect) : aRect;

  if (theme == nil)
    {
      return rect;
    }

  {
    CGFloat leftInset = MAX(12.0, rect.origin.x - aRect.origin.x);
    CGFloat arrowWidth = MAX(34.0, ceil([[theme metrics] popupControlHeight] * 0.96));
    CGFloat rightInset = arrowWidth + 12.0;
    CGFloat rightEdge = NSMaxX(aRect) - rightInset;

    rect.origin.x = aRect.origin.x + leftInset;
    rect.size.width = MAX(0.0, rightEdge - rect.origin.x);
  }

  return rect;
}

- (void) _overrideNSPopUpButtonCellMethod_drawTitleWithFrame: (NSRect)cellFrame
                                                      inView: (NSView *)controlView
{
  typedef void (*DrawTitleIMP)(id, SEL, NSRect, NSView *);
  DrawTitleIMP originalIMP = (DrawTitleIMP)WinUIThemeOriginalMethod(_cmd, self, [NSPopUpButtonCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSPopUpButtonCell *cell = (NSPopUpButtonCell *)self;
  NSString *title = nil;
  NSMutableDictionary *attributes = nil;
  NSFont *font = nil;
  NSAttributedString *attributedTitle = nil;
  NSRect drawRect = NSZeroRect;
  NSRect titleRect = NSZeroRect;
  NSSize titleSize = NSZeroSize;
  CGFloat arrowWidth = 0.0;
  BOOL enabled = [(NSCell *)self isEnabled];
  BOOL focused = WinUIThemeViewHasFocus(controlView) && enabled;
  BOOL popupOpen = WinUIThemePopupButtonMenuVisible(cell);
  NSColor *textColor = nil;

  if (theme == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }

  title = WinUIThemePopupDisplayString(cell);
  if ([title length] == 0)
    {
      return;
    }

  attributes = [[cell _nonAutoreleasedTypingAttributes] mutableCopy];
  font = WinUIThemePreferredControlFont(theme,
                                        [attributes objectForKey: NSFontAttributeName],
                                        NO);
  if (font != nil)
    {
      [attributes setObject: font forKey: NSFontAttributeName];
    }

  textColor = enabled
    ? WinUIThemeColorFromTheme(theme,
                               (popupOpen || focused) ? @"labelColor" : @"secondaryLabelColor",
                               [NSColor controlTextColor])
    : WinUIThemeColorFromTheme(theme,
                               @"disabledControlTextColor",
                               [NSColor disabledControlTextColor]);
  [attributes setObject: textColor forKey: NSForegroundColorAttributeName];

  drawRect = NSInsetRect(NSIntegralRect(cellFrame), 1.0, 1.0);
  arrowWidth = MAX(34.0, ceil([[theme metrics] popupControlHeight] * 0.96));
  titleRect = drawRect;
  titleRect.origin.x += 12.0;
  titleRect.size.width = MAX(0.0, titleRect.size.width - (arrowWidth + 18.0));
  titleSize = [title sizeWithAttributes: attributes];
  titleRect.origin.y = floor(NSMidY(drawRect) - (titleSize.height / 2.0));
  titleRect.size.height = ceil(titleSize.height) + 1.0;
  attributedTitle = AUTORELEASE([[NSAttributedString alloc] initWithString: title
                                                                attributes: attributes]);

  if ([cell _shouldShortenStringForRect: titleRect
                                   size: titleSize
                                 length: [title length]])
    {
      [cell _drawAttributedText: attributedTitle inFrame: titleRect];
    }
  else
    {
      [attributedTitle drawAtPoint: titleRect.origin];
    }

  RELEASE(attributes);
}

- (NSImage *) _overrideNSPopUpButtonCellMethod__currentArrowImage
{
  WinUITheme *theme = WinUIThemeActiveTheme();

  if (theme != nil)
    {
      return nil;
    }

  {
    typedef id (*CurrentArrowImageIMP)(id, SEL);
    CurrentArrowImageIMP originalIMP = (CurrentArrowImageIMP)WinUIThemeOriginalMethod(_cmd, self, [NSPopUpButtonCell class]);

    if (originalIMP != NULL)
      {
        return originalIMP(self, _cmd);
      }
  }

  return nil;
}

- (void) _overrideNSPopUpButtonCellMethod_drawImageWithFrame: (NSRect)imageFrame
                                                      inView: (NSView *)controlView
{
  typedef void (*DrawImageIMP)(id, SEL, NSRect, NSView *);
  DrawImageIMP originalIMP = (DrawImageIMP)WinUIThemeOriginalMethod(_cmd, self, [NSPopUpButtonCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();

  if (theme != nil
      && [self respondsToSelector: @selector(imagePosition)]
      && [(id)self imagePosition] == NSImageRight)
    {
      return;
    }

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, imageFrame, controlView);
    }
}

- (void) _overrideNSComboBoxCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                      inView: (NSView *)controlView
{
  typedef void (*DrawInteriorIMP)(id, SEL, NSRect, NSView *);
  DrawInteriorIMP originalIMP = (DrawInteriorIMP)WinUIThemeOriginalMethod(_cmd, self, [NSComboBoxCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSComboBoxCell *cell = (NSComboBoxCell *)self;
  NSRect buttonRect = WinUIThemeComboBoxButtonRect(cellFrame);
  NSRect textRect = WinUIThemeComboBoxTextRect(cell, cellFrame);
  NSRect interiorRect = NSInsetRect(cellFrame, 1.0, 1.0);
  BOOL enabled = [(NSCell *)self isEnabled];
  BOOL focused = WinUIThemeViewHasFocus(controlView) && enabled;
  BOOL editing = ([controlView isKindOfClass: [NSControl class]]
                  && [(NSControl *)controlView currentEditor] != nil);
  NSColor *entryFill = nil;
  NSColor *arrowColor = WinUIThemeColorFromTheme(theme,
                                                 enabled ? @"controlTextColor" : @"disabledControlTextColor",
                                                 enabled ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]);
  NSString *displayString = WinUIThemeComboBoxDisplayString(cell);
  NSMutableDictionary *attributes = nil;
  NSSize textSize = NSZeroSize;
  NSFont *font = nil;

  if (theme == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }

  WinUIThemeResolveEntryColors(theme,
                               controlView,
                               enabled,
                               focused,
                               NO,
                               &entryFill,
                               NULL,
                               NULL);

  [cell setValue: [NSValue valueWithRect: cellFrame] forKey: @"_lastValidFrame"];

  if (editing)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }

  [entryFill set];
  NSRectFillUsingOperation(interiorRect, NSCompositeSourceOver);

  if ([displayString length] > 0)
    {
      attributes = [[cell _nonAutoreleasedTypingAttributes] mutableCopy];
      font = WinUIThemePreferredControlFont(theme,
                                            [attributes objectForKey: NSFontAttributeName],
                                            NO);
      if (font != nil)
        {
          [attributes setObject: font forKey: NSFontAttributeName];
        }
      [attributes setObject: enabled
                                ? WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor])
                                : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor", [NSColor disabledControlTextColor])
                     forKey: NSForegroundColorAttributeName];

      textSize = [displayString sizeWithAttributes: attributes];
      textRect.origin.y = floor(NSMidY(cellFrame) - (textSize.height / 2.0));
      textRect.size.width = MAX(textRect.size.width, ceil(textSize.width) + 2.0);
      textRect.size.height = ceil(textSize.height) + 1.0;
      {
        NSAttributedString *attributedString = AUTORELEASE([[NSAttributedString alloc]
          initWithString: displayString
              attributes: attributes]);

        if ([cell _shouldShortenStringForRect: textRect
                                         size: textSize
                                       length: [displayString length]])
          {
            [cell _drawAttributedText: attributedString inFrame: textRect];
          }
        else
          {
            [attributedString drawAtPoint: textRect.origin];
          }
      }
      RELEASE(attributes);
    }

  [entryFill set];
  NSRectFillUsingOperation(NSInsetRect(buttonRect, -1.0, 0.0), NSCompositeSourceOver);

  WinUIThemeDrawChevron(NSMakePoint(NSMidX(buttonRect), NSMidY(buttonRect)),
                        NO,
                        arrowColor);
}

- (BOOL) _overrideNSComboBoxCellMethod_trackMouse: (NSEvent *)theEvent
                                           inRect: (NSRect)cellFrame
                                           ofView: (NSView *)controlView
                                     untilMouseUp: (BOOL)flag
{
  typedef BOOL (*TrackMouseIMP)(id, SEL, NSEvent *, NSRect, NSView *, BOOL);
  TrackMouseIMP originalIMP = (TrackMouseIMP)WinUIThemeOriginalMethod(_cmd, self, [NSComboBoxCell class]);
  NSPoint point = [controlView convertPoint: [theEvent locationInWindow] fromView: nil];
  BOOL nonEditableCombo = ([controlView isKindOfClass: [NSComboBox class]]
                           && [(NSComboBox *)controlView isEditable] == NO);
  NSRect themedButtonRect = WinUIThemeComboBoxButtonRect(cellFrame);
  NSComboBoxCell *cell = (NSComboBoxCell *)self;

  if ((nonEditableCombo && NSMouseInRect(point, cellFrame, [controlView isFlipped]))
      || NSMouseInRect(point, themedButtonRect, [controlView isFlipped]))
    {
      if ([(NSCell *)self isEnabled])
        {
          id buttonCell = [cell valueForKey: @"_buttonCell"];

          [cell _didClickWithinButton: cell];
          [(NSCell *)cell setHighlighted: NO];
          if ([buttonCell respondsToSelector: @selector(setHighlighted:)])
            {
              [buttonCell setHighlighted: NO];
            }
          [controlView setNeedsDisplay: YES];
          [controlView displayIfNeededIgnoringOpacity];
          return YES;
        }
    }

  if (originalIMP != NULL)
    {
      return originalIMP(self, _cmd, theEvent, cellFrame, controlView, flag);
    }

  return NO;
}

- (void) _overrideNSComboBoxCellMethod_highlight: (BOOL)flag
                                       withFrame: (NSRect)cellFrame
                                          inView: (NSView *)controlView
{
  NSComboBoxCell *cell = (NSComboBoxCell *)self;

  if ([(NSCell *)cell isHighlighted] != flag)
    {
      [(NSCell *)cell setHighlighted: flag];
      [cell drawWithFrame: cellFrame inView: controlView];
    }
}

- (BOOL) _overrideNSSegmentedCellMethod_trackMouse: (NSEvent *)theEvent
                                            inRect: (NSRect)cellFrame
                                            ofView: (NSView *)controlView
                                      untilMouseUp: (BOOL)flag
{
  typedef BOOL (*TrackMouseIMP)(id, SEL, NSEvent *, NSRect, NSView *, BOOL);
  TrackMouseIMP originalIMP = (TrackMouseIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSegmentedCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSSegmentedCell *cell = (NSSegmentedCell *)self;
  NSPoint point = [controlView convertPoint: [theEvent locationInWindow] fromView: nil];
  NSInteger hitIndex = NSNotFound;

  if (theme == nil || [cell trackingMode] != NSSegmentSwitchTrackingSelectOne)
    {
      if (originalIMP != NULL)
        {
          return originalIMP(self, _cmd, theEvent, cellFrame, controlView, flag);
        }
      return NO;
    }

  hitIndex = WinUIThemeSegmentIndexAtPoint(cell, cellFrame, point);
  if (hitIndex == NSNotFound || [cell isEnabledForSegment: hitIndex] == NO)
    {
      if (originalIMP != NULL)
        {
          return originalIMP(self, _cmd, theEvent, cellFrame, controlView, flag);
        }
      return NO;
    }

  if ([controlView respondsToSelector: @selector(setSelectedSegment:)])
    {
      [(id)controlView setSelectedSegment: hitIndex];
    }
  else
    {
      [cell setSelectedSegment: hitIndex];
    }

  [controlView setNeedsDisplayInRect: cellFrame];

  if ([controlView isKindOfClass: [NSControl class]])
    {
      [(NSControl *)controlView sendAction: [cell action] to: [cell target]];
    }
  else
    {
      [NSApp sendAction: [cell action] to: [cell target] from: controlView];
    }

  return YES;
}

/* libs-gui 0.32's NSSwitch has no -initWithFrame:, so its _enabled ivar
   starts as NO and every switch made in code is disabled until the app
   calls -setEnabled: YES (later libs-gui sets it in -initWithFrame:). A
   control made with -initWithFrame: is enabled, as in Cocoa; switches
   decoded from a nib keep their archived NSEnabled. */
- (id) _overrideNSSwitchMethod_initWithFrame: (NSRect)frameRect
{
  typedef id (*InitWithFrameIMP)(id, SEL, NSRect);
  InitWithFrameIMP originalIMP
    = (InitWithFrameIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSwitch class]);
  id control = (originalIMP != NULL) ? originalIMP(self, _cmd, frameRect) : self;

  [control setEnabled: YES];
  return control;
}

- (void) _overrideNSButtonCellMethod_drawWithFrame: (NSRect)cellFrame
                                            inView: (NSView *)controlView
{
  typedef void (*DrawWithFrameIMP)(id, SEL, NSRect, NSView *);
  DrawWithFrameIMP originalIMP = (DrawWithFrameIMP)WinUIThemeOriginalMethod(_cmd, self, [NSButtonCell class]);

  if (WinUIThemeDrawCheckboxOrRadioCell((NSButtonCell *)self, cellFrame, controlView))
    {
      return;
    }

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, cellFrame, controlView);
    }
}

- (void) _overrideNSButtonCellMethod_drawImage: (NSImage *)imageToDisplay
                                      withFrame: (NSRect)imageFrame
                                         inView: (NSView *)controlView
{
  typedef void (*DrawImageIMP)(id, SEL, NSImage *, NSRect, NSView *);
  DrawImageIMP originalIMP = (DrawImageIMP)WinUIThemeOriginalMethod(_cmd, self, [NSButtonCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  BOOL radio = (WinUIThemeButtonCellIsRadio((NSButtonCell *)self)
                || WinUIThemeButtonImageLooksLikeRadio(imageToDisplay));
  BOOL checkbox = (WinUIThemeButtonCellIsCheckbox((NSButtonCell *)self)
                   || WinUIThemeButtonImageLooksLikeSwitch(imageToDisplay));

  if (theme != nil && (checkbox || radio))
    {
      WinUIThemeDrawCheckboxOrRadioIndicator(theme,
                                             (NSButtonCell *)self,
                                             imageFrame,
                                             controlView,
                                             radio);
      return;
    }

  /* Template images in the colour of the title (#25). */
  if (theme != nil && WinUIThemeImageIsTemplate(imageToDisplay))
    {
      imageToDisplay = WinUIThemeTintedImage(imageToDisplay,
                                             WinUIThemeTemplateImageColor(theme,
                                                                          (NSButtonCell *)self,
                                                                          controlView));
    }

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, imageToDisplay, imageFrame, controlView);
    }
}

- (void) _overrideNSButtonCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                    inView: (NSView *)controlView
{
  typedef void (*DrawInteriorIMP)(id, SEL, NSRect, NSView *);
  DrawInteriorIMP originalIMP = (DrawInteriorIMP)WinUIThemeOriginalMethod(_cmd, self, [NSButtonCell class]);
  NSButtonCell *cell = (NSButtonCell *)self;
  WinUITheme *theme = WinUIThemeActiveTheme();

  if (theme == nil)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }

  if (WinUIThemeDrawCheckboxOrRadioCell(cell, cellFrame, controlView) == NO)
    {
      BOOL defaultButton = NO;
      BOOL hasLegacyReturnImage = WinUIThemeButtonCellUsesLegacyReturnImage(cell);
      BOOL searchButton = WinUIThemeButtonCellUsesSearchImage(cell);
      BOOL cancelButton = WinUIThemeButtonCellUsesCancelImage(cell);
      BOOL hasCustomImage = ([cell image] != nil && hasLegacyReturnImage == NO);
      BOOL hasCustomAlternateImage = ([cell alternateImage] != nil
                                      && [cell alternateImage] != [NSImage imageNamed: @"common_retH"]);
      BOOL enabled = [cell isEnabled];
      NSColor *textColor = enabled
        ? WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor])
        : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor", [NSColor disabledControlTextColor]);
      NSRect titleRect = WinUIThemeButtonTitleRect(cell, cellFrame);

      if (searchButton || cancelButton)
        {
          NSColor *glyphColor = enabled
            ? WinUIThemeColorFromTheme(theme, @"secondaryLabelColor", [NSColor controlTextColor])
            : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor", [NSColor disabledControlTextColor]);

          if (searchButton)
            {
              WinUIThemeDrawSearchGlyph(cellFrame, glyphColor);
            }
          else
            {
              NSColor *circleFill = WinUIThemeBlendColor(WinUIThemeColorFromTheme(theme,
                                                                                  @"separatorColor",
                                                                                  [NSColor controlShadowColor]),
                                                         WinUIThemeColorFromTheme(theme,
                                                                                  @"windowBackgroundColor",
                                                                                  [NSColor windowBackgroundColor]),
                                                         0.22);

              if ([cell isHighlighted] && enabled)
                {
                  circleFill = WinUIThemeBlendColor(circleFill, [NSColor blackColor], 0.10);
                }
              if (enabled == NO)
                {
                  circleFill = WinUIThemeBlendColor(circleFill,
                                                    WinUIThemeColorFromTheme(theme,
                                                                             @"windowBackgroundColor",
                                                                             [NSColor windowBackgroundColor]),
                                                    0.35);
                }

              /* White on the grey circle: selectedControlTextColor is the
                 text-on-accent colour, black in the dark palette. */
              WinUIThemeDrawDismissGlyph(cellFrame,
                                         circleFill,
                                         [NSColor whiteColor]);
            }
          return;
        }

      if (hasCustomImage || hasCustomAlternateImage)
        {
          if (originalIMP != NULL)
            {
              originalIMP(self, _cmd, cellFrame, controlView);
            }
          return;
        }

      defaultButton = WinUIThemeButtonIsDefault(cell);

      if (defaultButton && enabled)
        {
          textColor = WinUIThemeColorFromTheme(theme,
                                               @"selectedControlTextColor",
                                               [NSColor selectedControlTextColor]);
        }

      if ([cell isHighlighted])
        {
          titleRect.origin.x += 1.0;
          titleRect.origin.y -= 1.0;
        }

      WinUIThemeDrawButtonLabel(theme,
                                cell,
                                titleRect,
                                controlView,
                                textColor,
                                defaultButton);
      return;
    }
}

@end
