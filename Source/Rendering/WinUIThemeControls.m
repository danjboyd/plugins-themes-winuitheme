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

/* A mutable copy of a cell's typing attributes, which the caller releases.
   libs-gui's -_nonAutoreleasedTypingAttributes returns a retained
   dictionary, so it's released here. */
static NSMutableDictionary *
WinUIThemeMutableTypingAttributes(NSCell *cell)
{
  NSDictionary *typing = [cell _nonAutoreleasedTypingAttributes];
  NSMutableDictionary *attributes = [typing mutableCopy];

  RELEASE(typing);
  return attributes;
}

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

/* A bezelled or bordered field with libs-gui's default background: the
   TextBox chrome fills it. */
static BOOL
WinUIThemeTextFieldUsesChromeFill(NSTextFieldCell *cell)
{
  NSColor *background = [cell backgroundColor];

  return ([cell isBezeled] || [cell isBordered])
    && [cell isKindOfClass: [NSTableHeaderCell class]] == NO
    && (background == nil || [background isEqual: [NSColor textBackgroundColor]]);
}

/* WinUI's Button and AccentButton (#38): ControlFillColorDefault, with
   Secondary under the pointer and Tertiary pressed; the elevation border,
   ControlStrokeColorDefault with a darker ControlStrokeColorSecondary along
   the bottom; 4pt corners (#35); no gloss (#10). An accent button fills
   with the accent, at 90% under the pointer and 80% pressed. Fluent's
   colours are white or black at an opacity over the layer; these blend
   them over the window background. Pop-ups and combo boxes (#40) use it
   too. Returns the title colour. */
NSColor *
WinUIThemeDrawButtonChrome(WinUITheme *theme, NSRect frame, NSView *view, BOOL enabled,
                           BOOL defaultButton, BOOL pressed, BOOL hover)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  BOOL highContrast = [[theme settings] highContrastEnabled];
  NSColor *accent = WinUIThemeColorFromTheme(theme, @"accentColor", [NSColor selectedControlColor]);
  NSColor *window = WinUIThemeColorFromTheme(theme, @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *text = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
  NSColor *fillColor = nil;
  NSColor *strokeColor = nil;
  NSColor *bottomStrokeColor = nil;
  NSColor *titleColor = nil;
  NSRect drawRect = NSInsetRect(NSIntegralRect(frame), 0.5, 0.5);
  NSBezierPath *buttonPath = nil;

  if (highContrast)
    {
      fillColor = (defaultButton || pressed) ? accent : window;
      strokeColor = enabled ? text
        : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor", [NSColor disabledControlTextColor]);
      bottomStrokeColor = strokeColor;
      titleColor = (defaultButton || pressed)
        ? WinUIThemeColorFromTheme(theme, @"selectedControlTextColor", [NSColor selectedControlTextColor])
        : strokeColor;
    }
  else if (defaultButton)
    {
      NSColor *onAccent = WinUIThemeColorFromTheme(theme, @"selectedControlTextColor",
                                                   [NSColor selectedControlTextColor]);

      fillColor = pressed ? WinUIThemeBlendColor(window, accent, 0.80)
        : (hover ? WinUIThemeBlendColor(window, accent, 0.90) : accent);
      /* ControlStrokeColorOnAccentDefault and ...Secondary. */
      strokeColor = WinUIThemeBlendColor(fillColor, [NSColor whiteColor], 0.08);
      bottomStrokeColor = pressed ? strokeColor
        : WinUIThemeBlendColor(fillColor, [NSColor blackColor], dark ? 0.14 : 0.40);
      /* TextOnAccentFillColorSecondary while pressed. */
      titleColor = pressed ? WinUIThemeBlendColor(fillColor, onAccent, dark ? 0.50 : 0.70) : onAccent;
    }
  else if (enabled == NO)
    {
      /* ControlFillColorDisabled and TextFillColorDisabled. */
      fillColor = WinUIThemeBlendColor(window, [NSColor whiteColor], dark ? 0.04 : 0.30);
      strokeColor = WinUIThemeBlendColor(fillColor, dark ? [NSColor whiteColor] : [NSColor blackColor],
                                         dark ? 0.07 : 0.06);
      bottomStrokeColor = strokeColor;
      titleColor = WinUIThemeColorFromTheme(theme, @"disabledControlTextColor",
                                            [NSColor disabledControlTextColor]);
    }
  else
    {
      CGFloat fill = pressed ? (dark ? 0.03 : 0.30)
        : (hover ? (dark ? 0.08 : 0.50) : (dark ? 0.06 : 0.70));

      fillColor = WinUIThemeBlendColor(window, [NSColor whiteColor], fill);
      strokeColor = WinUIThemeBlendColor(fillColor, dark ? [NSColor whiteColor] : [NSColor blackColor],
                                         dark ? 0.07 : 0.06);
      bottomStrokeColor = pressed ? strokeColor
        : WinUIThemeBlendColor(fillColor, dark ? [NSColor whiteColor] : [NSColor blackColor],
                               dark ? 0.09 : 0.16);
      /* TextFillColorSecondary while pressed. */
      titleColor = pressed ? WinUIThemeColorFromTheme(theme, @"secondaryLabelColor", text) : text;
    }

  buttonPath = WinUIThemeRoundedPath(drawRect, WinUIThemeControlCornerRadius(theme));
  [fillColor set];
  [buttonPath fill];
  [buttonPath setLineWidth: 1.0];
  [strokeColor set];
  [buttonPath stroke];

  /* The elevation border's darker bottom: its last 3px. */
  if (bottomStrokeColor != nil && [bottomStrokeColor isEqual: strokeColor] == NO)
    {
      NSGraphicsContext *context = [NSGraphicsContext currentContext];
      BOOL flipped = (view != nil && [view isFlipped]);
      NSRect bottom = NSMakeRect(NSMinX(drawRect) - 1.0,
                                 flipped ? NSMaxY(drawRect) - 2.5 : NSMinY(drawRect) - 1.0,
                                 NSWidth(drawRect) + 2.0, 3.5);

      [context saveGraphicsState];
      [[NSBezierPath bezierPathWithRect: bottom] addClip];
      [bottomStrokeColor set];
      [buttonPath stroke];
      [context restoreGraphicsState];
    }
  return titleColor;
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

/* A checkbox or radio: its indicator 1pt in, then an 8pt gap before the
   title. -cellSize measures with these (#14). */
static const CGFloat WinUIThemeIndicatorLeading = 1.0;
static const CGFloat WinUIThemeIndicatorLabelGap = 8.0;

/* WinUI's 20px indicator, scaled with the desktop, or smaller in a frame
   too short for it. */
static CGFloat
WinUIThemeIndicatorSizeForHeight(WinUITheme *theme, CGFloat height)
{
  CGFloat full = round(20.0 * MAX(1.0, [[theme settings] desktopScaleFactor]));

  return MIN(full, MAX(12.0, floor(height - 2.0)));
}

/* How much narrower a cell's -drawingRectForBounds: is than its bounds. */
static CGFloat
WinUIThemeCellHorizontalMargins(NSCell *cell)
{
  NSRect bounds = NSMakeRect(0.0, 0.0, 1000.0, 1000.0);

  return NSWidth(bounds) - NSWidth([cell drawingRectForBounds: bounds]);
}

/* WinUI's CheckBox and RadioButton (#5): a 20px indicator (4pt corners on
   a box), scaled with the desktop. Fluent's colours are white or black at
   an opacity, blended over the window:
   - unchecked: ControlAltFillColorSecondary, Tertiary under the pointer,
     Quarternary pressed, inside a ControlStrongStrokeColorDefault border;
   - checked or mixed: the accent, at 90% under the pointer and 80%
     pressed, with a check or dash in TextOnAccentFillColorPrimary;
   - a checked radio: the accent ring around a centre dot of 12px, 14px
     under the pointer, 10px pressed;
   - disabled: ControlStrongStrokeColorDisabled outlines and
     AccentFillColorDisabled fills.
   High contrast: the highlight for checked, the text colour for borders. */
static void
WinUIThemeDrawCheckboxOrRadioIndicator(WinUITheme *theme,
                                       NSButtonCell *cell,
                                       NSRect indicatorFrame,
                                       NSView *controlView,
                                       BOOL radio)
{
  BOOL enabled = [cell isEnabled];
  BOOL pressed = enabled && [cell isHighlighted];
  BOOL hover = NO;
  BOOL dark = [[theme settings] prefersDarkAppearance];
  BOOL highContrast = [[theme settings] highContrastEnabled];
  NSInteger state = [cell state];
  BOOL on = (state == NSOnState || state == NSMixedState);
  CGFloat scale = MAX(1.0, [[theme settings] desktopScaleFactor]);
  CGFloat indicatorSize = WinUIThemeIndicatorSizeForHeight(theme, MIN(NSWidth(indicatorFrame),
                                                                      NSHeight(indicatorFrame)) + 2.0);
  NSRect indicatorRect = NSMakeRect(floor(NSMidX(indicatorFrame) - (indicatorSize / 2.0)),
                                    floor(NSMidY(indicatorFrame) - (indicatorSize / 2.0)),
                                    indicatorSize,
                                    indicatorSize);
  NSColor *window = WinUIThemeColorFromTheme(theme, @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *ink = dark ? [NSColor whiteColor] : [NSColor blackColor];
  NSColor *accent = WinUIThemeColorFromTheme(theme, @"accentColor", [NSColor selectedControlColor]);
  NSColor *onAccent = WinUIThemeColorFromTheme(theme, @"selectedControlTextColor",
                                               [NSColor selectedControlTextColor]);
  NSColor *fillColor = nil;
  NSColor *borderColor = nil;
  NSColor *markColor = nil;
  NSBezierPath *path = nil;

  if ([controlView isKindOfClass: [NSButton class]])
    {
      WinUIThemeTrackHover(controlView);
      hover = enabled && WinUIThemeViewIsHovered(controlView);
    }

  if (highContrast)
    {
      NSColor *text = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
      NSColor *disabled = WinUIThemeColorFromTheme(theme, @"disabledControlTextColor",
                                                   [NSColor disabledControlTextColor]);

      fillColor = (on && enabled) ? accent : window;
      borderColor = enabled ? (on ? accent : text) : disabled;
      markColor = enabled ? onAccent : disabled;
    }
  else if (on)
    {
      fillColor = enabled
        ? (pressed ? WinUIThemeBlendColor(window, accent, 0.80)
                   : (hover ? WinUIThemeBlendColor(window, accent, 0.90) : accent))
        : WinUIThemeBlendColor(window, ink, dark ? 0.16 : 0.22);
      borderColor = fillColor;
      markColor = enabled ? onAccent
        : (dark ? WinUIThemeBlendColor(fillColor, [NSColor whiteColor], 0.53) : [NSColor whiteColor]);
    }
  else
    {
      CGFloat fill = pressed ? (dark ? 0.07 : 0.09) : (hover ? (dark ? 0.04 : 0.06) : (dark ? 0.0 : 0.024));

      /* Dark's ControlAltFillColorSecondary is black at 10%. */
      fillColor = (dark && pressed == NO && hover == NO)
        ? WinUIThemeBlendColor(window, [NSColor blackColor], 0.10)
        : WinUIThemeBlendColor(window, ink, fill);
      borderColor = enabled
        ? WinUIThemeBlendColor(window, ink, dark ? 0.54 : 0.45)
        : WinUIThemeBlendColor(window, ink, dark ? 0.16 : 0.22);
      markColor = borderColor;
      if (enabled == NO)
        {
          fillColor = window;
        }
    }

  path = radio
    ? [NSBezierPath bezierPathWithOvalInRect: NSInsetRect(indicatorRect, 0.5, 0.5)]
    : WinUIThemeRoundedPath(NSInsetRect(indicatorRect, 0.5, 0.5), round(4.0 * scale));
  [fillColor set];
  [path fill];
  [borderColor set];
  [path setLineWidth: 1.0];
  [path stroke];

  if (radio && (state == NSOnState || (pressed && state == NSOffState)))
    {
      /* A checked radio's centre; pressed, an unchecked one shows it too,
         in the border's colour. */
      CGFloat dot = round((pressed ? 10.0 : (hover ? 14.0 : 12.0)) * scale);

      WinUIThemeDrawRadioDot(WinUIThemeCenteredRect(indicatorRect, dot, dot),
                             state == NSOnState ? markColor : borderColor);
    }
  else if (radio == NO && state == NSOnState)
    {
      WinUIThemeDrawCheckmark(indicatorRect, markColor);
    }
  else if (radio == NO && state == NSMixedState)
    {
      NSRect dashRect = WinUIThemeCenteredRect(indicatorRect, round(8.0 * scale), MAX(1.5, round(1.5 * scale)));

      [markColor set];
      NSRectFill(NSIntegralRect(dashRect));
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
    CGFloat indicatorSize = WinUIThemeIndicatorSizeForHeight(theme, contentRect.size.height);
    NSRect indicatorRect = NSMakeRect(contentRect.origin.x + WinUIThemeIndicatorLeading,
                                      floor(NSMidY(contentRect) - (indicatorSize / 2.0)),
                                      indicatorSize,
                                      indicatorSize);
    NSRect titleRect = contentRect;

    titleRect.origin.x = NSMaxX(indicatorRect) + WinUIThemeIndicatorLabelGap;
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

  attributes = WinUIThemeMutableTypingAttributes(cell);
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
  [paragraphStyle setAlignment: WinUIThemeCenterTextAlignment()];
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

/* A pop-up's title runs from 12pt in to 33pt short of its right side,
   clear of the chevron. -cellSize measures with these (#14). */
static const CGFloat WinUIThemePopupTitleLeading = 12.0;
#define WinUIThemePopupTitleTrailing (WinUIThemeComboBoxGlyphInset + 13.0)

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

/* Slider and progress colours (#41, #42). Fluent's are white or black at
   an opacity, blended over the window here:
   - track: ControlStrongFillColorDefault (ControlStrongStroke, the
     progress track line, has the same values), or ...Disabled;
   - value: the accent, or AccentFillColorDisabled;
   - the thumb: ControlSolidFillColorDefault, its border
     ControlStrokeColorDefault, darker (...Secondary) along its bottom.
   High contrast: text-colour track, highlight value, window-coloured
   thumb. Any argument may be NULL. */
void
WinUIThemeRangeColors(WinUITheme *theme, BOOL enabled,
                      NSColor **trackOut, NSColor **valueOut,
                      NSColor **thumbOut, NSColor **borderOut, NSColor **bottomOut)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *window = WinUIThemeColorFromTheme(theme, @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *ink = dark ? [NSColor whiteColor] : [NSColor blackColor];
  NSColor *accent = WinUIThemeColorFromTheme(theme, @"accentColor", [NSColor selectedControlColor]);
  NSColor *track = nil, *value = nil, *thumb = nil, *border = nil, *bottom = nil;

  if ([[theme settings] highContrastEnabled])
    {
      NSColor *text = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
      NSColor *disabled = WinUIThemeColorFromTheme(theme, @"disabledControlTextColor",
                                                   [NSColor disabledControlTextColor]);

      track = enabled ? text : disabled;
      value = enabled ? accent : disabled;
      thumb = window;
      border = bottom = enabled ? text : disabled;
    }
  else
    {
      track = WinUIThemeBlendColor(window, ink, enabled ? (dark ? 0.54 : 0.45) : (dark ? 0.25 : 0.22));
      value = enabled ? accent : WinUIThemeBlendColor(window, ink, dark ? 0.16 : 0.22);
      thumb = dark ? [NSColor colorWithCalibratedWhite: 0x45 / 255.0 alpha: 1.0]
                   : [NSColor whiteColor];
      border = WinUIThemeBlendColor(thumb, ink, dark ? 0.07 : 0.06);
      bottom = WinUIThemeBlendColor(thumb, ink, dark ? 0.09 : 0.16);
    }

  if (trackOut != NULL) *trackOut = track;
  if (valueOut != NULL) *valueOut = value;
  if (thumbOut != NULL) *thumbOut = thumb;
  if (borderOut != NULL) *borderOut = border;
  if (bottomOut != NULL) *bottomOut = bottom;
}

/* WinUI's 20px Slider thumb, scaled with the desktop. */
static CGFloat
WinUIThemeSliderThumbSize(WinUITheme *theme)
{
  return round(20.0 * MAX(1.0, [[theme settings] desktopScaleFactor]));
}

/* WinUI's ProgressRing: an accent arc, its stroke an eighth of the ring's
   size (4px at the default 32px), on no track. Indeterminate, it spins
   once every 2s while its length swings between 10 and 270 degrees;
   determinate, it runs clockwise from the top for the fraction. */
static void
WinUIThemeDrawProgressRing(WinUITheme *theme, NSRect bounds, NSColor *color,
                           BOOL indeterminate, double fraction)
{
  CGFloat size = floor(MIN(NSWidth(bounds), NSHeight(bounds)));
  CGFloat stroke = MAX(2.0, round(size / 8.0));
  CGFloat radius = (size - stroke) / 2.0;
  NSPoint centre = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
  BOOL flipped = [[NSView focusView] isFlipped];
  NSBezierPath *arc = [NSBezierPath bezierPath];
  CGFloat start, sweep;

  (void)theme;
  if (radius <= 0.0)
    {
      return;
    }
  if (indeterminate)
    {
      double t = [NSDate timeIntervalSinceReferenceDate];
      double phase = fmod(t, 2.0) / 2.0;

      sweep = 10.0 + 260.0 * (0.5 - 0.5 * cos(phase * 2.0 * M_PI));
      start = 90.0 - fmod(t * 180.0, 360.0);
    }
  else
    {
      if (fraction <= 0.0)
        {
          return;
        }
      sweep = 360.0 * MIN(1.0, fraction);
      start = 90.0;
    }

  /* Clockwise as the user sees it: in a flipped view, angles run the
     other way, and the top is -90 degrees. */
  if (flipped)
    {
      [arc appendBezierPathWithArcWithCenter: centre radius: radius
                                  startAngle: -start endAngle: -start + sweep clockwise: NO];
    }
  else
    {
      [arc appendBezierPathWithArcWithCenter: centre radius: radius
                                  startAngle: start endAngle: start - sweep clockwise: YES];
    }
  [arc setLineWidth: stroke];
  [arc setLineCapStyle: NSRoundLineCapStyle];
  [color set];
  [arc stroke];
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

/* WinUI's Button and AccentButton (#38): ControlFillColorDefault, with
   Secondary under the pointer and Tertiary pressed; the elevation border,
   ControlStrokeColorDefault with a darker ControlStrokeColorSecondary along
   the bottom; 4pt corners (#35); no gloss (#10). An accent button fills
   with the accent, at 90% under the pointer and 80% pressed. Fluent's
   colours are white or black at an opacity over the layer; these blend
   them over the window background. */
- (void) drawButton: (NSRect)frame
                 in: (NSCell *)cell
               view: (NSView *)view
              style: (int)style
              state: (GSThemeControlState)state
{
  BOOL popupButton = [cell isKindOfClass: [NSPopUpButtonCell class]];
  BOOL popupOpen = (popupButton && WinUIThemePopupButtonMenuVisible(cell));
  BOOL enabled = (state != GSThemeDisabledState);
  BOOL defaultButton = enabled && popupButton == NO && WinUIThemeButtonIsDefault(cell);
  BOOL pressed = WinUIThemeStateIsHighlighted(state) || popupOpen;
  BOOL hover = NO;
  NSColor *titleColor = nil;

  /* A pop-up button is WinUI's ComboBox: a button with a chevron (#40). */
  if (popupButton == NO && WinUIThemeUsesModernPushButton(style) == NO)
    {
      [super drawButton: frame in: cell view: view style: style state: state];
      return;
    }

  if ([cell isKindOfClass: [NSButtonCell class]])
    {
      WinUIThemeRemoveDefaultButtonGlyph((NSButtonCell *)cell);
    }
  if ([view isKindOfClass: [NSButton class]])
    {
      WinUIThemeTrackHover(view);
      hover = enabled && WinUIThemeViewIsHovered(view);
    }

  titleColor = WinUIThemeDrawButtonChrome(self, frame, view, enabled, defaultButton, pressed, hover);
  if (popupButton == NO && [cell isKindOfClass: [NSButtonCell class]] && titleColor != nil)
    {
      WinUIThemeApplyButtonTitleAttributes(self, (NSButtonCell *)cell, titleColor, NO);
    }
}

/* WinUI's buttons don't move their contents when pressed (#38). gui after
   0.32 asks the theme; 0.32 displaces them a pixel, which the interior
   override undoes. */
- (NSSize) buttonPushInOffsetForCell: (NSCell *)cell
{
  return NSZeroSize;
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
  if ([view isKindOfClass: [NSComboBox class]] && [(NSComboBox *)view isEditable] == NO
      && (aType == NSBezelBorder || aType == NSLineBorder))
    {
      BOOL enabled = WinUIThemeControlEnabled(view);
      NSCell *cell = [(NSControl *)view cell];

      WinUIThemeTrackHover(view);
      WinUIThemeDrawButtonChrome(self, frame, view, enabled, NO,
                                 [cell isHighlighted],
                                 enabled && WinUIThemeViewIsHovered(view));
      return;
    }
  if (WinUIThemeUsesInputBorder(aType, view))
    {
      WinUIThemeDrawTextBoxChrome(self, frame, view, WinUIThemeControlEnabled(view));
      return;
    }

  [super drawBorderType: aType frame: frame view: view];
}

- (void) drawPopUpButtonCellInteriorWithFrame: (NSRect)cellFrame
                                     withCell: (NSCell *)cell
                                       inView: (NSView *)controlView
{
  (void)controlView;
  WinUIThemeDrawComboBoxGlyph(self, cellFrame, WinUIThemeControlEnabled(cell));
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
                              NO,
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
  NSBezierPath *outerPath = WinUIThemeRoundedPath(drawRect, WinUIThemeControlCornerRadius(self));
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

/* WinUI's ProgressBar (#42): a 1px track line in ControlStrongStroke under
   a 3px rounded accent bar, without the bezel. Indeterminate, two accent
   segments slide across, timed by the clock rather than the redraw count
   so they move evenly. The spinning style is a ProgressRing. */
- (void) drawProgressIndicator: (NSProgressIndicator *)progress
                    withBounds: (NSRect)bounds
                      withClip: (NSRect)rect
                       atCount: (int)count
                      forValue: (double)val
{
  BOOL enabled = WinUIThemeControlEnabled(progress);
  BOOL vertical = [progress isVertical];
  double fraction = WinUIThemeClamp(val, 0.0, 1.0);
  NSColor *track = nil;
  NSColor *bar = nil;
  NSRect barArea = NSIntegralRect(bounds);
  CGFloat thickness = MIN(3.0, vertical ? NSWidth(barArea) : NSHeight(barArea));
  NSRect trackLine;

  (void)rect;
  (void)count;
  WinUIThemeRangeColors(self, enabled, &track, &bar, NULL, NULL, NULL);

  if ([progress style] == NSProgressIndicatorSpinningStyle)
    {
      WinUIThemeDrawProgressRing(self, bounds, bar, [progress isIndeterminate], fraction);
      return;
    }

  /* The bar, centred across the control; the track line through its middle. */
  if (vertical)
    {
      barArea = NSMakeRect(floor(NSMidX(barArea) - thickness / 2.0), NSMinY(barArea),
                           thickness, NSHeight(barArea));
      trackLine = NSMakeRect(floor(NSMidX(barArea) - 0.5), NSMinY(barArea), 1.0, NSHeight(barArea));
    }
  else
    {
      barArea = NSMakeRect(NSMinX(barArea), floor(NSMidY(barArea) - thickness / 2.0),
                           NSWidth(barArea), thickness);
      trackLine = NSMakeRect(NSMinX(barArea), floor(NSMidY(barArea) - 0.5), NSWidth(barArea), 1.0);
    }
  [track set];
  NSRectFill(trackLine);

  if ([progress isIndeterminate])
    {
      double t = fmod([NSDate timeIntervalSinceReferenceDate], 2.0) / 2.0;
      CGFloat length = vertical ? NSHeight(barArea) : NSWidth(barArea);
      /* The first segment, 40% long, crosses in the first three quarters
         of a 2s cycle; the second, 25%, in the last half. */
      CGFloat starts[2] = { -0.4 + 1.4 * MIN(1.0, t / 0.75), -0.25 + 1.25 * MAX(0.0, (t - 0.5) / 0.5) };
      CGFloat sizes[2] = { 0.4, 0.25 };
      BOOL shown[2] = { t < 0.75, t >= 0.5 };
      NSUInteger index;

      [NSGraphicsContext saveGraphicsState];
      NSRectClip(barArea);
      for (index = 0; index < 2; index++)
        {
          NSRect segment = barArea;

          if (shown[index] == NO)
            {
              continue;
            }
          if (vertical)
            {
              segment.origin.y += floor(starts[index] * length);
              segment.size.height = floor(sizes[index] * length);
            }
          else
            {
              segment.origin.x += floor(starts[index] * length);
              segment.size.width = floor(sizes[index] * length);
            }
          WinUIThemeFillAndStrokeRoundedRect(segment, thickness / 2.0, bar, nil, 0.0);
        }
      [NSGraphicsContext restoreGraphicsState];
      return;
    }

  if (vertical)
    {
      CGFloat fillHeight = floor(NSHeight(barArea) * fraction);

      barArea.origin.y = [progress isFlipped] ? NSMaxY(barArea) - fillHeight : NSMinY(barArea);
      barArea.size.height = fillHeight;
    }
  else
    {
      barArea.size.width = floor(NSWidth(barArea) * fraction);
    }
  if (NSWidth(barArea) > 0.0 && NSHeight(barArea) > 0.0)
    {
      WinUIThemeFillAndStrokeRoundedRect(barArea, thickness / 2.0, bar, nil, 0.0);
    }
}

/* WinUI's Slider (#41): a 4px track in ControlStrongFill, the value part
   in the accent, under the thumb. */
- (void) drawSliderBorderAndBackground: (NSBorderType)aType
                                 frame: (NSRect)cellFrame
                                inCell: (NSCell *)cell
                          isHorizontal: (BOOL)horizontal
{
  NSSliderCell *sliderCell = (NSSliderCell *)cell;
  NSRect trackRect = NSIntegralRect(WinUIThemeSliderTrackRect(self, cellFrame, horizontal));
  NSColor *track = nil;

  if ([sliderCell sliderType] != NSLinearSlider)
    {
      [super drawSliderBorderAndBackground: aType
                                     frame: cellFrame
                                    inCell: cell
                              isHorizontal: horizontal];
      return;
    }

  WinUIThemeRangeColors(self, WinUIThemeControlEnabled(cell), &track, NULL, NULL, NULL, NULL);
  WinUIThemeFillAndStrokeRoundedRect(trackRect, 2.0, track, nil, 0.0);
}

- (void) drawBarInside: (NSRect)rect inCell: (NSCell *)cell flipped: (BOOL)flipped
{
  NSSliderCell *sliderCell = (NSSliderCell *)cell;
  CGFloat thumb = WinUIThemeSliderThumbSize(self);
  NSRect knobRect;
  BOOL horizontal = (rect.size.width >= rect.size.height);
  NSRect trackRect = WinUIThemeSliderTrackRect(self, rect, horizontal);
  NSRect activeRect = trackRect;
  NSColor *value = nil;

  if ([sliderCell sliderType] != NSLinearSlider)
    {
      [super drawBarInside: rect inCell: cell flipped: flipped];
      return;
    }

  /* The thumb's travel: the theme's knob image is 20pt; at a larger
     desktop scale the thumb is larger. */
  if ([sliderCell knobThickness] > 0.0 && fabs([sliderCell knobThickness] - thumb) > 0.5)
    {
      [sliderCell setKnobThickness: thumb];
    }
  knobRect = [sliderCell knobRectFlipped: flipped];

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

  if (NSWidth(activeRect) <= 0.0 || NSHeight(activeRect) <= 0.0)
    {
      return;
    }

  WinUIThemeRangeColors(self, WinUIThemeControlEnabled(cell), NULL, &value, NULL, NULL, NULL);
  WinUIThemeFillAndStrokeRoundedRect(NSIntegralRect(activeRect), 2.0, value, nil, 0.0);
}

/* The thumb: a 20px circle in ControlSolidFill with the elevation border,
   around an accent dot of 12px, 14px under the pointer and 10px pressed. */
- (void) drawKnobInCell: (NSCell *)cell
{
  NSSliderCell *sliderCell = (NSSliderCell *)cell;
  NSView *controlView = [cell controlView];
  BOOL enabled = WinUIThemeControlEnabled(cell);
  CGFloat scale = [[self settings] desktopScaleFactor];
  CGFloat thumb = WinUIThemeSliderThumbSize(self);
  NSRect knobRect;
  NSRect circleRect;
  NSColor *fill = nil;
  NSColor *border = nil;
  NSColor *bottom = nil;
  NSColor *dot = nil;
  CGFloat dotSize = 12.0;
  NSBezierPath *path = nil;

  if ([sliderCell sliderType] != NSLinearSlider)
    {
      [super drawKnobInCell: cell];
      return;
    }

  knobRect = [sliderCell knobRectFlipped: [controlView isFlipped]];
  circleRect = NSMakeRect(floor(NSMidX(knobRect) - thumb / 2.0) + 0.5,
                          floor(NSMidY(knobRect) - thumb / 2.0) + 0.5,
                          thumb - 1.0, thumb - 1.0);
  WinUIThemeRangeColors(self, enabled, NULL, &dot, &fill, &border, &bottom);

  if ([controlView isKindOfClass: [NSView class]])
    {
      WinUIThemeTrackHover(controlView);
    }
  if (enabled && [cell isHighlighted])
    {
      dotSize = 10.0;
    }
  else if (enabled && controlView != nil && WinUIThemeViewIsHovered(controlView))
    {
      dotSize = 14.0;
    }
  dotSize = round(dotSize * MAX(1.0, scale));

  path = [NSBezierPath bezierPathWithOvalInRect: circleRect];
  [fill set];
  [path fill];
  [path setLineWidth: 1.0];
  [border set];
  [path stroke];
  /* The elevation border's darker lower half. */
  if ([bottom isEqual: border] == NO)
    {
      NSRect lower = circleRect;

      lower.size.height = NSHeight(circleRect) / 2.0;
      if ([controlView isFlipped])
        {
          lower.origin.y = NSMidY(circleRect);
        }
      lower = NSInsetRect(lower, -1.0, -1.0);
      [NSGraphicsContext saveGraphicsState];
      NSRectClip(lower);
      [bottom set];
      [path stroke];
      [NSGraphicsContext restoreGraphicsState];
    }

  [dot set];
  [[NSBezierPath bezierPathWithOvalInRect:
     NSMakeRect(NSMidX(circleRect) - dotSize / 2.0, NSMidY(circleRect) - dotSize / 2.0,
                dotSize, dotSize)] fill];
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
      CGFloat horizontalInset = readonlyField ? 12.0 : 7.0;

      titleRect.origin.x += horizontalInset;
      titleRect.size.width -= (horizontalInset * 2.0);
    }

  /* Table and outline rows: text 12pt in from the column's edge, as the
     headers' titles, clear of the selection pill (#43). The cell starts
     half the intercell spacing in, none in a table built in code (#28). */
  if ([cell isBezeled] == NO && [cell isBordered] == NO
      && [[cell controlView] isKindOfClass: [NSTableView class]])
    {
      CGFloat inset = MAX(0.0, 12.0 - [(NSTableView *)[cell controlView] intercellSpacing].width / 2.0);

      titleRect.origin.x += inset;
      titleRect.size.width = MAX(0.0, titleRect.size.width - inset);
    }

  titleRect.origin.y = aRect.origin.y + floor((aRect.size.height - titleSize.height) / 2.0);
  titleRect.size.height = ceil(titleSize.height);

  /* A TextBox keeps its text, and the field editor's background, off its
     border and focus underline, however large Windows' text size makes the
     font (#44). */
  if (([cell isBezeled] || [cell isBordered])
      && [cell isKindOfClass: [NSTableHeaderCell class]] == NO
      && NSHeight(titleRect) > NSHeight(aRect) - 4.0)
    {
      titleRect.origin.y = aRect.origin.y + 2.0;
      titleRect.size.height = MAX(0.0, NSHeight(aRect) - 4.0);
    }

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
      if (WinUIThemeTextFieldUsesChromeFill(cell))
        {
          [editor setBackgroundColor: WinUIThemeTextBoxFillColor(theme, YES, NO, YES)];
        }
    }
  return editor;
}

/* A bezelled field's own background (textBackgroundColor, the window's)
   would cover the TextBox fill: the chrome's fill shows instead, unless
   the app chose a colour. */
- (void) _overrideNSTextFieldCellMethod__drawBackgroundWithFrame: (NSRect)cellFrame
                                                          inView: (NSView *)controlView
{
  typedef void (*DrawBackgroundIMP)(id, SEL, NSRect, NSView *);
  DrawBackgroundIMP originalIMP = (DrawBackgroundIMP)WinUIThemeOriginalMethod(_cmd, self, [NSTextFieldCell class]);

  if (WinUIThemeActiveTheme() != nil && WinUIThemeTextFieldUsesChromeFill((NSTextFieldCell *)self))
    {
      return;
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, cellFrame, controlView);
    }
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
    CGFloat rightInset = WinUIThemeComboBoxGlyphInset + 12.0;
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
  BOOL enabled = [(NSCell *)self isEnabled];
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

  attributes = WinUIThemeMutableTypingAttributes(cell);
  font = WinUIThemePreferredControlFont(theme,
                                        [attributes objectForKey: NSFontAttributeName],
                                        NO);
  if (font != nil)
    {
      [attributes setObject: font forKey: NSFontAttributeName];
    }

  textColor = enabled
    ? WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor])
    : WinUIThemeColorFromTheme(theme,
                               @"disabledControlTextColor",
                               [NSColor disabledControlTextColor]);
  [attributes setObject: textColor forKey: NSForegroundColorAttributeName];

  drawRect = NSInsetRect(NSIntegralRect(cellFrame), 1.0, 1.0);
  titleRect = NSIntegralRect(cellFrame);
  titleRect.origin.x += WinUIThemePopupTitleLeading;
  titleRect.size.width = MAX(0.0, titleRect.size.width
                                    - WinUIThemePopupTitleLeading - WinUIThemePopupTitleTrailing);
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

/* As wide as -drawTitleWithFrame:inView: needs for the longest item (#14).
   libs-gui leaves room for its arrow image, which the theme replaces with
   a wider chevron, so a pop-up sized to fit cut its title. */
- (NSSize) _overrideNSPopUpButtonCellMethod_cellSize
{
  typedef NSSize (*CellSizeIMP)(id, SEL);
  CellSizeIMP originalIMP = (CellSizeIMP)WinUIThemeOriginalMethod(_cmd, self, [NSPopUpButtonCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSPopUpButtonCell *cell = (NSPopUpButtonCell *)self;
  NSSize size = (originalIMP != NULL) ? originalIMP(self, _cmd) : NSZeroSize;
  NSMutableDictionary *attributes = nil;
  NSFont *font = nil;
  NSArray *titles = nil;
  NSEnumerator *enumerator = nil;
  NSString *title = nil;
  CGFloat widest = 0.0;

  if (theme == nil)
    {
      return size;
    }

  attributes = WinUIThemeMutableTypingAttributes(cell);
  font = WinUIThemePreferredControlFont(theme, [attributes objectForKey: NSFontAttributeName], NO);
  if (font != nil)
    {
      [attributes setObject: font forKey: NSFontAttributeName];
    }
  titles = ([cell numberOfItems] > 0) ? [cell itemTitles]
    : [NSArray arrayWithObject: ([cell title] != nil ? [cell title] : @"")];
  enumerator = [titles objectEnumerator];
  while ((title = [enumerator nextObject]) != nil)
    {
      widest = MAX(widest, [title sizeWithAttributes: attributes].width);
    }
  RELEASE(attributes);

  size.width = ceil(widest) + WinUIThemePopupTitleLeading + WinUIThemePopupTitleTrailing
    + WinUIThemeCellHorizontalMargins(cell);
  return size;
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

/* WinUI's AutoSuggestBox (#9): one TextBox, the text, then the delete
   button (only with text), then the query button at the trailing edge.
   libs-gui put the search button before the field and drew the bezel
   round the text alone, leaving both buttons outside it. */
static const CGFloat WinUIThemeSearchQueryWidth = 32.0;
static const CGFloat WinUIThemeSearchDeleteWidth = 28.0;

- (NSRect) _overrideNSSearchFieldCellMethod_searchButtonRectForBounds: (NSRect)rect
{
  typedef NSRect (*RectIMP)(id, SEL, NSRect);
  RectIMP originalIMP = (RectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSearchFieldCell class]);

  if (WinUIThemeActiveTheme() == nil)
    {
      return originalIMP != NULL ? originalIMP(self, _cmd, rect) : rect;
    }
  return NSMakeRect(NSMaxX(rect) - WinUIThemeSearchQueryWidth, NSMinY(rect),
                    MIN(WinUIThemeSearchQueryWidth, NSWidth(rect)), NSHeight(rect));
}

- (NSRect) _overrideNSSearchFieldCellMethod_cancelButtonRectForBounds: (NSRect)rect
{
  typedef NSRect (*RectIMP)(id, SEL, NSRect);
  RectIMP originalIMP = (RectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSearchFieldCell class]);

  if (WinUIThemeActiveTheme() == nil)
    {
      return originalIMP != NULL ? originalIMP(self, _cmd, rect) : rect;
    }
  return NSMakeRect(NSMaxX(rect) - WinUIThemeSearchQueryWidth - WinUIThemeSearchDeleteWidth,
                    NSMinY(rect), WinUIThemeSearchDeleteWidth, NSHeight(rect));
}

- (NSRect) _overrideNSSearchFieldCellMethod_searchTextRectForBounds: (NSRect)rect
{
  typedef NSRect (*RectIMP)(id, SEL, NSRect);
  RectIMP originalIMP = (RectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSearchFieldCell class]);

  if (WinUIThemeActiveTheme() == nil)
    {
      return originalIMP != NULL ? originalIMP(self, _cmd, rect) : rect;
    }
  rect.size.width = MAX(0.0, NSWidth(rect) - WinUIThemeSearchQueryWidth - WinUIThemeSearchDeleteWidth);
  return rect;
}

/* The delete button while typing: libs-gui empties the cell's string but
   not the field editor's, so the text stayed. */
- (void) _overrideNSSearchFieldCellMethod_clearSearch: (id)sender
{
  typedef void (*ClearIMP)(id, SEL, id);
  ClearIMP originalIMP = (ClearIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSearchFieldCell class]);
  NSText *editor = [[NSApp keyWindow] fieldEditor: NO forObject: nil];

  /* Only the editor editing this field. */
  if ([[editor delegate] isKindOfClass: [NSControl class]] == NO
      || [(NSControl *)[editor delegate] cell] != self)
    {
      editor = nil;
    }

  if (editor != nil && WinUIThemeActiveTheme() != nil)
    {
      [editor setString: @""];
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, sender);
    }
}

- (void) _overrideNSSearchFieldCellMethod_drawWithFrame: (NSRect)cellFrame
                                                 inView: (NSView *)controlView
{
  typedef void (*DrawIMP)(id, SEL, NSRect, NSView *);
  DrawIMP originalIMP = (DrawIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSearchFieldCell class]);
  NSSearchFieldCell *cell = (NSSearchFieldCell *)self;
  WinUITheme *theme = WinUIThemeActiveTheme();

  if (theme == nil || NSIsEmptyRect(cellFrame))
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }

  if ([cell isBezeled] || [cell isBordered])
    {
      WinUIThemeDrawTextBoxChrome(theme, cellFrame, controlView, [cell isEnabled]);
    }
  [cell drawInteriorWithFrame: [cell searchTextRectForBounds: cellFrame] inView: controlView];
  if ([[cell stringValue] length] > 0 || ([controlView isKindOfClass: [NSControl class]]
                                          && [[[(NSControl *)controlView currentEditor] string] length] > 0))
    {
      [[cell cancelButtonCell] drawWithFrame: [cell cancelButtonRectForBounds: cellFrame] inView: controlView];
    }
  [[cell searchButtonCell] drawWithFrame: [cell searchButtonRectForBounds: cellFrame] inView: controlView];
}

- (void) _overrideNSComboBoxCellMethod_drawInteriorWithFrame: (NSRect)cellFrame
                                                      inView: (NSView *)controlView
{
  typedef void (*DrawInteriorIMP)(id, SEL, NSRect, NSView *);
  DrawInteriorIMP originalIMP = (DrawInteriorIMP)WinUIThemeOriginalMethod(_cmd, self, [NSComboBoxCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSComboBoxCell *cell = (NSComboBoxCell *)self;
  NSRect textRect = WinUIThemeComboBoxTextRect(cell, cellFrame);
  BOOL enabled = [(NSCell *)self isEnabled];
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

  /* Where libs-gui's list window opens. */
  [cell setValue: [NSValue valueWithRect: cellFrame] forKey: @"_lastValidFrame"];

  if ([cell _inEditing])
    {
      NSRect editorFrame = cellFrame;

      editorFrame.size.width = MAX(0.0, NSWidth(cellFrame) - WinUIThemeComboBoxGlyphInset - 12.0);
      [cell _drawEditorWithFrame: editorFrame inView: controlView];
      WinUIThemeDrawComboBoxGlyph(theme, cellFrame, enabled);
      return;
    }

  if ([displayString length] > 0)
    {
      attributes = WinUIThemeMutableTypingAttributes(cell);
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

  WinUIThemeDrawComboBoxGlyph(theme, cellFrame, enabled);
}

/* A non-editable combo box is WinUI's ComboBox: no text editor (libs-gui
   started one on focus, drawing an empty field and its "..." button). */
- (void) _overrideNSComboBoxCellMethod_selectWithFrame: (NSRect)aRect
                                                inView: (NSView *)controlView
                                                editor: (NSText *)textObj
                                              delegate: (id)anObject
                                                 start: (NSInteger)selStart
                                                length: (NSInteger)selLength
{
  typedef void (*SelectIMP)(id, SEL, NSRect, NSView *, NSText *, id, NSInteger, NSInteger);
  SelectIMP originalIMP = (SelectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSComboBoxCell class]);

  if (WinUIThemeActiveTheme() != nil && [(NSCell *)self isEditable] == NO)
    {
      return;
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, aRect, controlView, textObj, anObject, selStart, selLength);
    }
}

- (void) _overrideNSComboBoxCellMethod_editWithFrame: (NSRect)aRect
                                              inView: (NSView *)controlView
                                              editor: (NSText *)textObj
                                            delegate: (id)anObject
                                               event: (NSEvent *)theEvent
{
  typedef void (*EditIMP)(id, SEL, NSRect, NSView *, NSText *, id, NSEvent *);
  EditIMP originalIMP = (EditIMP)WinUIThemeOriginalMethod(_cmd, self, [NSComboBoxCell class]);

  if (WinUIThemeActiveTheme() != nil && [(NSCell *)self isEditable] == NO)
    {
      return;
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, aRect, controlView, textObj, anObject, theEvent);
    }
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

  /* gui 0.32 displaces a pushed-in button's contents by a pixel, without
     asking the theme. */
  if ([GSTheme instancesRespondToSelector: @selector(buttonPushInOffsetForCell:)] == NO
      && [cell isHighlighted] && [cell isBordered])
    {
      NSInteger mask = [cell highlightsBy];

      if ([cell state] != NSOffState)
        {
          mask &= ~[cell showsStateBy];
        }
      if (mask & NSPushInCellMask)
        {
          cellFrame = NSOffsetRect(cellFrame, -1.0, [controlView isFlipped] ? -1.0 : 1.0);
        }
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

          /* Pressed: SubtleFillColorTertiary behind the glyph. */
          if ([cell isHighlighted] && enabled)
            {
              BOOL dark = [[theme settings] prefersDarkAppearance];
              NSRect pressedRect = WinUIThemeCenteredRect(cellFrame,
                                                          MIN(NSWidth(cellFrame) - 4.0, 24.0),
                                                          MIN(NSHeight(cellFrame) - 6.0, 24.0));

              [WinUIThemeColorWithAlpha(dark ? [NSColor whiteColor] : [NSColor blackColor],
                                        dark ? 0.04 : 0.024) set];
              [WinUIThemeRoundedPath(pressedRect, WinUIThemeControlCornerRadius(theme)) fill];
            }
          if (searchButton)
            {
              WinUIThemeDrawSearchGlyph(WinUIThemeCenteredRect(cellFrame, 18.0, 18.0), glyphColor);
            }
          else
            {
              WinUIThemeDrawCrossGlyph(WinUIThemeCenteredRect(cellFrame, 10.0, 10.0), glyphColor);
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

      /* High contrast fills a pressed button with the highlight colour, so
         its title takes the highlight text colour, as a default button's. */
      if (enabled && (defaultButton || ([cell isHighlighted] && [[theme settings] highContrastEnabled])))
        {
          textColor = WinUIThemeColorFromTheme(theme,
                                               @"selectedControlTextColor",
                                               [NSColor selectedControlTextColor]);
        }

      /* The title colour while pressed: TextFillColorSecondary, or
         TextOnAccentFillColorSecondary on an accent button. */
      if ([cell isHighlighted] && enabled && [[theme settings] highContrastEnabled] == NO)
        {
          textColor = defaultButton
            ? WinUIThemeColorWithAlpha(textColor, [[theme settings] prefersDarkAppearance] ? 0.50 : 0.70)
            : WinUIThemeColorFromTheme(theme, @"secondaryLabelColor", textColor);
        }
      WinUIThemeDrawButtonLabel(theme,
                                cell,
                                titleRect,
                                controlView,
                                textColor,
                                NO);
      return;
    }
}

/* Measured with the drawing's geometry (#14). libs-gui's -cellSize adds
   6pt beside the margins and measures the title in the cell's font, and
   knows nothing of the indicator and gap the theme draws for a checkbox
   or radio, so a control sized to fit cut its title. */
- (NSSize) _overrideNSButtonCellMethod_cellSize
{
  typedef NSSize (*CellSizeIMP)(id, SEL);
  CellSizeIMP originalIMP = (CellSizeIMP)WinUIThemeOriginalMethod(_cmd, self, [NSButtonCell class]);
  WinUITheme *theme = WinUIThemeActiveTheme();
  NSButtonCell *cell = (NSButtonCell *)self;
  NSSize size = (originalIMP != NULL) ? originalIMP(self, _cmd) : NSZeroSize;

  if (theme == nil || [cell isKindOfClass: [NSMenuItemCell class]])
    {
      return size;
    }

  if (WinUIThemeButtonCellIsCheckbox(cell) || WinUIThemeButtonCellIsRadio(cell))
    {
      CGFloat indicatorSize = WinUIThemeIndicatorSizeForHeight(theme, CGFLOAT_MAX);
      NSSize titleSize = ([cell imagePosition] == NSImageOnly) ? NSZeroSize
        : [[cell attributedTitle] size];

      size.width = WinUIThemeIndicatorLeading + indicatorSize
        + ((titleSize.width > 0.0) ? WinUIThemeIndicatorLabelGap + ceil(titleSize.width)
                                   : WinUIThemeIndicatorLeading)
        + WinUIThemeCellHorizontalMargins(cell);
      size.height = MAX(ceil(titleSize.height), indicatorSize + 2.0);
      return size;
    }

  /* The buttons whose title -drawInteriorWithFrame:inView: draws. */
  if (WinUIThemeButtonCellUsesSearchImage(cell) || WinUIThemeButtonCellUsesCancelImage(cell)
      || ([cell image] != nil && WinUIThemeButtonCellUsesLegacyReturnImage(cell) == NO)
      || ([cell alternateImage] != nil
          && [cell alternateImage] != [NSImage imageNamed: @"common_retH"])
      || [[cell title] length] == 0)
    {
      return size;
    }

  size.width = ceil(WinUIThemeButtonTitleSize(theme, cell).width)
    + 2.0 * WinUIThemeButtonTitleInset(cell) + WinUIThemeCellHorizontalMargins(cell);
  return size;
}

@end
