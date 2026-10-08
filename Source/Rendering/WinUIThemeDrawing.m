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

#include <math.h>

static CGFloat WinUIThemeMinimumControlFontSize = 13.0;

static NSColor *
WinUIThemeCalibratedColor(NSColor *color)
{
  NSColor *converted = nil;

  if (color == nil)
    {
      return nil;
    }

  converted = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  return converted != nil ? converted : color;
}

static BOOL
WinUIThemeUsesScreenFonts(void)
{
  NSGraphicsContext *context = GSCurrentContext();
  NSAffineTransform *transform = GSCurrentCTM(context);
  NSAffineTransformStruct matrix = [transform transformStruct];

  return (matrix.m11 == 1.0
          && matrix.m12 == 0.0
          && matrix.m21 == 0.0
          && fabs(matrix.m22) == 1.0);
}

static NSDictionary *
WinUIThemeEditorTypingAttributes(NSTextFieldCell *cell,
                                 NSTextView *textView,
                                 NSFont *font)
{
  NSMutableDictionary *attributes = nil;
  NSDictionary *cellAttributes = [cell _nonAutoreleasedTypingAttributes];
  NSDictionary *editorAttributes = [textView typingAttributes];

  if (editorAttributes != nil)
    {
      attributes = [editorAttributes mutableCopy];
    }
  else if (cellAttributes != nil)
    {
      attributes = [cellAttributes mutableCopy];
    }
  else
    {
      attributes = [[NSMutableDictionary alloc] init];
    }

  if (cellAttributes != nil)
    {
      NSEnumerator *enumerator = [cellAttributes keyEnumerator];
      id key = nil;

      while ((key = [enumerator nextObject]) != nil)
        {
          id value = [cellAttributes objectForKey: key];

          if (value != nil)
            {
              [attributes setObject: value forKey: key];
            }
        }
      RELEASE(cellAttributes);
    }

  if (font != nil)
    {
      [attributes setObject: font forKey: NSFontAttributeName];
    }

  return AUTORELEASE(attributes);
}

static NSAttributedString *
WinUIThemeNormalizedEditorContent(NSTextFieldCell *cell, NSDictionary *attributes)
{
  NSAttributedString *cellContent = [cell attributedStringValue];
  NSMutableAttributedString *mutableContent = nil;
  NSRange fullRange = NSMakeRange(0, 0);
  id value = nil;

  if ([cellContent length] == 0)
    {
      return nil;
    }

  mutableContent = AUTORELEASE([cellContent mutableCopy]);
  fullRange.length = [mutableContent length];

  value = [attributes objectForKey: NSFontAttributeName];
  if (value != nil)
    {
      [mutableContent addAttribute: NSFontAttributeName value: value range: fullRange];
    }

  value = [attributes objectForKey: NSForegroundColorAttributeName];
  if (value != nil)
    {
      [mutableContent addAttribute: NSForegroundColorAttributeName
                             value: value
                             range: fullRange];
    }

  value = [attributes objectForKey: NSParagraphStyleAttributeName];
  if (value != nil)
    {
      [mutableContent addAttribute: NSParagraphStyleAttributeName
                             value: value
                             range: fullRange];
    }

  return mutableContent;
}

NSRect
WinUIThemeCenteredRect(NSRect frame, CGFloat width, CGFloat height)
{
  return NSMakeRect(NSMidX(frame) - (width / 2.0),
                    NSMidY(frame) - (height / 2.0),
                    width,
                    height);
}

/* WinUI's ControlCornerRadius (buttons, fields, list items) and
   OverlayCornerRadius (flyouts, dialogs, cards), scaled with the display
   (#35). */
CGFloat
WinUIThemeControlCornerRadius(WinUITheme *theme)
{
  return [[theme metrics] controlCornerRadius];
}

CGFloat
WinUIThemeOverlayCornerRadius(WinUITheme *theme)
{
  return [[theme metrics] windowCornerRadius];
}

CGFloat
WinUIThemeClamp(CGFloat value, CGFloat minimum, CGFloat maximum)
{
  return MIN(MAX(value, minimum), maximum);
}

NSColor *
WinUIThemeColorFromTheme(WinUITheme *theme, NSString *key, NSColor *fallback)
{
  NSColor *color = nil;

  if (theme != nil)
    {
      color = [[theme colors] colorWithKey: key];
    }

  return color != nil ? color : fallback;
}

NSColor *
WinUIThemeColorWithAlpha(NSColor *color, CGFloat alpha)
{
  NSColor *converted = WinUIThemeCalibratedColor(color);

  if (converted == nil)
    {
      return nil;
    }

  return [NSColor colorWithCalibratedRed: [converted redComponent]
                                   green: [converted greenComponent]
                                    blue: [converted blueComponent]
                                   alpha: WinUIThemeClamp(alpha, 0.0, 1.0)];
}

NSColor *
WinUIThemeBlendColor(NSColor *fromColor, NSColor *toColor, CGFloat amount)
{
  NSColor *from = WinUIThemeCalibratedColor(fromColor);
  NSColor *to = WinUIThemeCalibratedColor(toColor);
  CGFloat fraction = WinUIThemeClamp(amount, 0.0, 1.0);

  if (from == nil)
    {
      return to;
    }
  if (to == nil)
    {
      return from;
    }

  return [NSColor colorWithCalibratedRed: ([from redComponent] * (1.0 - fraction))
                                         + ([to redComponent] * fraction)
                                   green: ([from greenComponent] * (1.0 - fraction))
                                         + ([to greenComponent] * fraction)
                                    blue: ([from blueComponent] * (1.0 - fraction))
                                         + ([to blueComponent] * fraction)
                                   alpha: ([from alphaComponent] * (1.0 - fraction))
                                         + ([to alphaComponent] * fraction)];
}

NSBezierPath *
WinUIThemeRoundedPath(NSRect rect, CGFloat radius)
{
  CGFloat limitedRadius = MIN(radius, MIN(rect.size.width, rect.size.height) / 2.0);

  if (limitedRadius <= 0.0)
    {
      return [NSBezierPath bezierPathWithRect: rect];
    }

  return [NSBezierPath bezierPathWithRoundedRect: rect
                                         xRadius: limitedRadius
                                         yRadius: limitedRadius];
}

NSBezierPath *
WinUIThemeSegmentedControlPath(NSRect rect,
                               CGFloat radius,
                               BOOL roundedLeft,
                               BOOL roundedRight)
{
  CGFloat clampedRadius = MIN(radius, MIN(rect.size.width, rect.size.height) / 2.0);
  CGFloat minX = NSMinX(rect);
  CGFloat maxX = NSMaxX(rect);
  CGFloat minY = NSMinY(rect);
  CGFloat maxY = NSMaxY(rect);
  NSBezierPath *path = nil;

  if (clampedRadius <= 0.0 || (roundedLeft == NO && roundedRight == NO))
    {
      return [NSBezierPath bezierPathWithRect: rect];
    }

  if (roundedLeft && roundedRight)
    {
      return WinUIThemeRoundedPath(rect, clampedRadius);
    }

  path = [NSBezierPath bezierPath];
  [path moveToPoint: NSMakePoint(minX + (roundedLeft ? clampedRadius : 0.0), minY)];
  [path lineToPoint: NSMakePoint(maxX - (roundedRight ? clampedRadius : 0.0), minY)];

  if (roundedRight)
    {
      [path appendBezierPathWithArcFromPoint: NSMakePoint(maxX, minY)
                                     toPoint: NSMakePoint(maxX, minY + clampedRadius)
                                      radius: clampedRadius];
      [path lineToPoint: NSMakePoint(maxX, maxY - clampedRadius)];
      [path appendBezierPathWithArcFromPoint: NSMakePoint(maxX, maxY)
                                     toPoint: NSMakePoint(maxX - clampedRadius, maxY)
                                      radius: clampedRadius];
    }
  else
    {
      [path lineToPoint: NSMakePoint(maxX, minY)];
      [path lineToPoint: NSMakePoint(maxX, maxY)];
    }

  [path lineToPoint: NSMakePoint(minX + (roundedLeft ? clampedRadius : 0.0), maxY)];

  if (roundedLeft)
    {
      [path appendBezierPathWithArcFromPoint: NSMakePoint(minX, maxY)
                                     toPoint: NSMakePoint(minX, maxY - clampedRadius)
                                      radius: clampedRadius];
      [path lineToPoint: NSMakePoint(minX, minY + clampedRadius)];
      [path appendBezierPathWithArcFromPoint: NSMakePoint(minX, minY)
                                     toPoint: NSMakePoint(minX + clampedRadius, minY)
                                      radius: clampedRadius];
    }
  else
    {
      [path lineToPoint: NSMakePoint(minX, maxY)];
      [path lineToPoint: NSMakePoint(minX, minY)];
    }

  [path closePath];
  return path;
}

void
WinUIThemeFillAndStrokeRoundedRect(NSRect rect,
                                   CGFloat radius,
                                   NSColor *fillColor,
                                   NSColor *strokeColor,
                                   CGFloat strokeWidth)
{
  NSBezierPath *path = WinUIThemeRoundedPath(rect, radius);

  if (fillColor != nil)
    {
      [fillColor set];
      [path fill];
    }

  if (strokeColor != nil && strokeWidth > 0.0)
    {
      [strokeColor set];
      [path setLineWidth: strokeWidth];
      [path stroke];
    }
}

void
WinUIThemeDrawRoundedSegment(NSRect frame,
                             CGFloat radius,
                             BOOL roundedLeft,
                             BOOL roundedRight,
                             NSColor *fillColor,
                             NSColor *borderColor)
{
  NSRect drawRect = NSInsetRect(NSIntegralRect(frame), 0.5, 0.5);
  NSRect shapeRect = drawRect;
  NSBezierPath *shapePath = nil;
  NSGraphicsContext *context = [NSGraphicsContext currentContext];

  if (roundedLeft == NO && roundedRight == NO)
    {
      shapePath = [NSBezierPath bezierPathWithRect: drawRect];
    }
  else
    {
      if (roundedLeft == NO)
        {
          shapeRect.origin.x -= radius;
          shapeRect.size.width += radius;
        }
      if (roundedRight == NO)
        {
          shapeRect.size.width += radius;
        }

      shapePath = WinUIThemeRoundedPath(shapeRect, radius);
    }

  [context saveGraphicsState];
  [[NSBezierPath bezierPathWithRect: drawRect] addClip];

  if (fillColor != nil)
    {
      [fillColor set];
      [shapePath fill];
    }

  if (borderColor != nil)
    {
      [borderColor set];
      [shapePath setLineWidth: 1.0];
      [shapePath stroke];
    }

  [context restoreGraphicsState];
}

BOOL
WinUIThemeStateIsHighlighted(GSThemeControlState state)
{
  return (state == GSThemeHighlightedState
          || state == GSThemeHighlightedFirstResponderState
          || state == GSThemeSelectedState
          || state == GSThemeSelectedFirstResponderState);
}

BOOL
WinUIThemeStateHasFocus(GSThemeControlState state)
{
  return (state == GSThemeFirstResponderState
          || state == GSThemeHighlightedFirstResponderState
          || state == GSThemeSelectedFirstResponderState);
}

BOOL
WinUIThemeControlEnabled(id control)
{
  if ([control respondsToSelector: @selector(isEnabled)] == NO)
    {
      return YES;
    }

  return [control isEnabled];
}

BOOL
WinUIThemeViewHasFocus(NSView *view)
{
  id firstResponder = nil;

  if (view == nil || [view window] == nil)
    {
      return NO;
    }

  if ([view isKindOfClass: [NSControl class]]
      && [(NSControl *)view currentEditor] != nil)
    {
      return YES;
    }

  firstResponder = [[view window] firstResponder];
  if (firstResponder == view)
    {
      return YES;
    }
  if ([firstResponder respondsToSelector: @selector(delegate)])
    {
      return ([firstResponder delegate] == view);
    }

  return NO;
}

BOOL
WinUIThemeUsesModernPushButton(int style)
{
  switch (style)
    {
      /* No bezel style set: libs-gui's -[NSButtonCell init] leaves 0, and
         NSAlert's buttons (made with -init) keep it. Cocoa draws such a
         button as a rounded push button. Left to GNUstep's bezel, an
         alert's default button got GNUstep's white bezel under the
         theme's white default-button title, and read as an empty box. */
      case 0:
      case NSRoundRectBezelStyle:
      case NSTexturedRoundedBezelStyle:
      case NSRoundedBezelStyle:
      case NSTexturedSquareBezelStyle:
      case NSSmallSquareBezelStyle:
      case NSRegularSquareBezelStyle:
      case NSShadowlessSquareBezelStyle:
      case NSThickSquareBezelStyle:
      case NSThickerSquareBezelStyle:
        return YES;

      default:
        return NO;
    }
}

/* A window's default button: one with Return as its key equivalent, or the
   window's default button cell (GNUstep's alerts make OK default that way).
   The bezel and the title must agree, or a white title is drawn on a
   button that isn't filled with the accent. */
BOOL
WinUIThemeButtonIsDefault(NSCell *cell)
{
  NSString *keyEquivalent = nil;
  NSWindow *window = nil;

  if ([cell isKindOfClass: [NSButtonCell class]] == NO)
    {
      return NO;
    }

  keyEquivalent = [(NSButtonCell *)cell keyEquivalent];
  if ([keyEquivalent isEqualToString: @"\r"]
      || [keyEquivalent isEqualToString: @"\n"])
    {
      return YES;
    }

  window = [[cell controlView] window];
  return (window != nil && [window defaultButtonCell] == (NSButtonCell *)cell);
}

BOOL
WinUIThemePopupButtonMenuVisible(NSCell *cell)
{
  id menu = nil;
  id window = nil;

  if (cell == nil || [cell respondsToSelector: @selector(menu)] == NO)
    {
      return NO;
    }

  menu = [(id)cell menu];
  if (menu == nil || [menu respondsToSelector: @selector(window)] == NO)
    {
      return NO;
    }

  window = [menu window];
  return (window != nil
          && [window respondsToSelector: @selector(isVisible)]
          && [window isVisible]);
}

BOOL
WinUIThemeUsesInputBorder(NSBorderType aType, NSView *view)
{
  if (view == nil)
    {
      return NO;
    }

  if (aType != NSBezelBorder && aType != NSLineBorder)
    {
      return NO;
    }

  if ([view isKindOfClass: [NSTextField class]]
      || [view isKindOfClass: [NSComboBox class]])
    {
      return YES;
    }

  if ([view isKindOfClass: [NSScrollView class]])
    {
      NSView *documentView = [(NSScrollView *)view documentView];

      return [documentView isKindOfClass: [NSTextView class]];
    }

  return NO;
}

/* YES when `image` is the image named `name`. Where gnustep-gui's images
   aren't installed, +imageNamed: answers nil, and a button without an image
   would match it: an MSI that left them out drew every button and menu item
   as a radio button. */
static BOOL
WinUIThemeImageIsNamed(NSImage *image, NSString *name)
{
  return image != nil && image == [NSImage imageNamed: name];
}

BOOL
WinUIThemeButtonCellIsCheckbox(NSButtonCell *cell)
{
  NSNumber *buttonTypeValue = nil;
  NSImage *image = [cell image];
  NSImage *alternateImage = [cell alternateImage];
  NSString *imageName = [image name];
  NSString *alternateName = [alternateImage name];

  @try
    {
      buttonTypeValue = [cell valueForKey: @"_buttonType"];
    }
  @catch (id exception)
    {
      buttonTypeValue = nil;
    }

  if ([buttonTypeValue respondsToSelector: @selector(integerValue)])
    {
      NSInteger buttonType = [buttonTypeValue integerValue];

      if (buttonType == NSSwitchButton || buttonType == NSOnOffButton)
        {
          return YES;
        }
    }

  return (WinUIThemeImageIsNamed(image, @"NSSwitch")
          || WinUIThemeImageIsNamed(alternateImage, @"NSHighlightedSwitch")
          || WinUIThemeImageIsNamed(image, @"GSSwitch")
          || WinUIThemeImageIsNamed(alternateImage, @"GSSwitchSelected")
          || (imageName != nil
              && [imageName rangeOfString: @"switch"
                                   options: NSCaseInsensitiveSearch].location != NSNotFound)
          || (alternateName != nil
              && [alternateName rangeOfString: @"switch"
                                      options: NSCaseInsensitiveSearch].location != NSNotFound));
}

BOOL
WinUIThemeButtonCellIsRadio(NSButtonCell *cell)
{
  NSNumber *buttonTypeValue = nil;
  NSImage *image = [cell image];
  NSImage *alternateImage = [cell alternateImage];
  NSString *imageName = [image name];
  NSString *alternateName = [alternateImage name];

  @try
    {
      buttonTypeValue = [cell valueForKey: @"_buttonType"];
    }
  @catch (id exception)
    {
      buttonTypeValue = nil;
    }

  if ([buttonTypeValue respondsToSelector: @selector(integerValue)])
    {
      if ([buttonTypeValue integerValue] == NSRadioButton)
        {
          return YES;
        }
    }

  return (WinUIThemeImageIsNamed(image, @"NSRadioButton")
          || WinUIThemeImageIsNamed(alternateImage, @"NSHighlightedRadioButton")
          || WinUIThemeImageIsNamed(image, @"GSRadio")
          || WinUIThemeImageIsNamed(alternateImage, @"GSRadioSelected")
          || (imageName != nil
              && [imageName rangeOfString: @"radio"
                                   options: NSCaseInsensitiveSearch].location != NSNotFound)
          || (alternateName != nil
              && [alternateName rangeOfString: @"radio"
                                      options: NSCaseInsensitiveSearch].location != NSNotFound));
}

BOOL
WinUIThemeButtonCellUsesLegacyReturnImage(NSButtonCell *cell)
{
  return (WinUIThemeImageIsNamed([cell image], @"common_ret")
          || WinUIThemeImageIsNamed([cell alternateImage], @"common_retH"));
}

BOOL
WinUIThemeButtonCellUsesSearchImage(NSButtonCell *cell)
{
  return WinUIThemeImageIsNamed([cell image], @"GSSearch");
}

BOOL
WinUIThemeButtonCellUsesCancelImage(NSButtonCell *cell)
{
  return WinUIThemeImageIsNamed([cell image], @"GSStop");
}

NSFont *
WinUIThemePreferredControlFont(WinUITheme *theme,
                               NSFont *font,
                               BOOL emphasized)
{
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFont *resolvedFont = nil;
  CGFloat pointSize = 0.0;

  if (font == nil && theme != nil)
    {
      font = [[theme settings] interfaceFont];
    }
  if (font == nil)
    {
      font = [NSFont systemFontOfSize: WinUIThemeMinimumControlFontSize];
    }

  pointSize = MAX(WinUIThemeMinimumControlFontSize, [font pointSize]);
  if (fabs(pointSize - [font pointSize]) > 0.01)
    {
      resolvedFont = [NSFont fontWithName: [font fontName] size: pointSize];
      if (resolvedFont != nil)
        {
          font = resolvedFont;
        }
    }

  if (emphasized == NO || fontManager == nil)
    {
      return font;
    }

  /* Emphasis is Semibold, WinUI's BodyStrong (#44). */
  return WinUIThemeSemiboldFont(font, [font pointSize]);
}

NSFont *
WinUIThemeResolvedEditorFont(WinUITheme *theme, NSTextFieldCell *cell)
{
  NSFont *font = [cell font];

  return WinUIThemePreferredControlFont(theme, font, NO);
}

void
WinUIThemeApplyEditorFont(WinUITheme *theme,
                          NSTextFieldCell *cell,
                          NSText *textObject)
{
  NSFont *font = nil;
  NSTextView *textView = nil;
  NSDictionary *typingAttributes = nil;
  NSAttributedString *content = nil;
  NSTextStorage *textStorage = nil;

  if (textObject == nil)
    {
      return;
    }

  font = WinUIThemeResolvedEditorFont(theme, cell);
  if (font == nil)
    {
      return;
    }

  [textObject setFont: font];

  if ([textObject isKindOfClass: [NSTextView class]] == NO)
    {
      return;
    }

  textView = (NSTextView *)textObject;
  [textView setTextContainerInset: NSZeroSize];
  if ([textView textContainer] != nil)
    {
      [[textView textContainer] setLineFragmentPadding: 0.0];
    }

  typingAttributes = WinUIThemeEditorTypingAttributes(cell, textView, font);
  if (typingAttributes != nil)
    {
      [textView setTypingAttributes: typingAttributes];
    }

  content = WinUIThemeNormalizedEditorContent(cell, typingAttributes);
  if (content == nil)
    {
      return;
    }

  textStorage = [textView textStorage];
  if (textStorage != nil)
    {
      [textStorage setAttributedString: content];
    }
}

void
WinUIThemeDrawAttributedStringWithEditorLayout(NSTextFieldCell *cell,
                                               NSAttributedString *string,
                                               NSRect rect,
                                               NSView *controlView)
{
  static NSTextStorage *textStorage = nil;
  static NSLayoutManager *layoutManager = nil;
  static NSTextContainer *textContainer = nil;
  NSGraphicsContext *context = GSCurrentContext();
  NSSize titleSize = NSZeroSize;
  NSRange glyphRange = NSMakeRange(0, 0);
  BOOL viewFlipped = NO;

  if ([string length] == 0 || NSWidth(rect) <= 0.0 || NSHeight(rect) <= 0.0)
    {
      return;
    }

  if (textStorage == nil)
    {
      textStorage = [[NSTextStorage alloc] init];
      layoutManager = [[NSLayoutManager alloc] init];
      textContainer = [[NSTextContainer alloc] initWithContainerSize: rect.size];
      [textContainer setLineFragmentPadding: 0.0];
      [textStorage addLayoutManager: layoutManager];
      [layoutManager addTextContainer: textContainer];
    }

  titleSize = [string size];
  if ([cell _shouldShortenStringForRect: rect size: titleSize length: [string length]])
    {
      string = [cell _resizeAttributedString: string forRect: rect];
    }

  [textStorage setAttributedString: string];
  [textContainer setContainerSize: rect.size];
  if ([layoutManager respondsToSelector: @selector(setUsesScreenFonts:)])
    {
      [(id)layoutManager setUsesScreenFonts: WinUIThemeUsesScreenFonts()];
    }

  glyphRange = [layoutManager glyphRangeForBoundingRect: NSMakeRect(0.0,
                                                                    0.0,
                                                                    rect.size.width,
                                                                    rect.size.height)
                                        inTextContainer: textContainer];
  viewFlipped = (controlView != nil) ? [controlView isFlipped] : NO;

  DPSgsave(context);
  DPSrectclip(context, NSMinX(rect), NSMinY(rect), NSWidth(rect), NSHeight(rect));

  if (viewFlipped)
    {
      [layoutManager drawBackgroundForGlyphRange: glyphRange atPoint: rect.origin];
      [layoutManager drawGlyphsForGlyphRange: glyphRange atPoint: rect.origin];
    }
  else
    {
      /* Text fields are flipped; this is a cell drawn by some other view,
         such as a browser's column title (#74). Flipping the context by
         hand here drew the glyphs mirrored, upside down at the foot of
         the rect, so string drawing handles it, as Adwaita's theme does. */
      [string drawInRect: rect];
    }

  DPSgrestore(context);
}

void
WinUIThemeApplyButtonTitleAttributes(WinUITheme *theme,
                                     NSButtonCell *cell,
                                     NSColor *textColor,
                                     BOOL emphasized)
{
  NSString *title = nil;
  NSString *alternateTitle = nil;
  NSFont *font = nil;
  NSMutableParagraphStyle *paragraphStyle = nil;
  NSDictionary *attributes = nil;
  NSAttributedString *attributedTitle = nil;
  NSAttributedString *attributedAlternateTitle = nil;

  if (cell == nil || textColor == nil)
    {
      return;
    }

  title = [cell title];
  alternateTitle = [cell alternateTitle];
  font = WinUIThemePreferredControlFont(theme, [cell font], emphasized);
  paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [paragraphStyle setAlignment: [cell alignment]];
  [paragraphStyle setLineBreakMode: NSLineBreakByTruncatingTail];

  attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                               font, NSFontAttributeName,
                               textColor, NSForegroundColorAttributeName,
                               paragraphStyle, NSParagraphStyleAttributeName,
                               nil];
  attributedTitle = [[[NSAttributedString alloc] initWithString: (title != nil ? title : @"")
                                                     attributes: attributes] autorelease];
  [cell setAttributedTitle: attributedTitle];

  attributedAlternateTitle = [[[NSAttributedString alloc]
    initWithString: ([alternateTitle length] > 0 ? alternateTitle : (title != nil ? title : @""))
       attributes: attributes] autorelease];
  [cell setAttributedAlternateTitle: attributedAlternateTitle];
}

void
WinUIThemeRemoveDefaultButtonGlyph(NSButtonCell *cell)
{
  NSImage *returnImage = [NSImage imageNamed: @"common_ret"];
  NSImage *returnAlternateImage = [NSImage imageNamed: @"common_retH"];

  if (cell == nil)
    {
      return;
    }

  if ([cell image] == returnImage)
    {
      [cell setImage: nil];
    }
  if ([cell alternateImage] == returnAlternateImage)
    {
      [cell setAlternateImage: nil];
    }
  if ([cell image] == nil)
    {
      [cell setImagePosition: NSNoImage];
    }
}

/* The size of a button's title in the font the theme draws it in. */
NSSize
WinUIThemeButtonTitleSize(WinUITheme *theme, NSButtonCell *cell)
{
  NSMutableAttributedString *title = AUTORELEASE([[cell attributedTitle] mutableCopy]);
  NSFont *font = WinUIThemePreferredControlFont(theme, [cell font], NO);

  if ([title length] == 0)
    {
      return NSZeroSize;
    }
  if (font != nil)
    {
      [title addAttribute: NSFontAttributeName
                    value: font
                    range: NSMakeRange(0, [title length])];
    }
  return [title size];
}

/* Between a button's margins (WinUI's 11pt padding), or 4pt in from a
   borderless button's sides. -cellSize leaves this much room (#14), and
   when a frame is narrower the padding gives way before the title is
   cut, down to 2pt from the sides. */
CGFloat
WinUIThemeButtonTitleInset(NSButtonCell *cell)
{
  return ([cell isBordered] || [cell isBezeled]) ? 0.0 : 4.0;
}

NSRect
WinUIThemeButtonTitleRect(NSButtonCell *cell, NSRect cellFrame)
{
  NSRect titleRect = [cell drawingRectForBounds: cellFrame];
  CGFloat leftInset = WinUIThemeButtonTitleInset(cell);
  CGFloat rightInset = leftInset;
  CGFloat titleWidth = 0.0;
  WinUITheme *theme = nil;

  if ([cell isKindOfClass: [NSPopUpButtonCell class]])
    {
      leftInset = 14.0;
      rightInset = WinUIThemeComboBoxButtonWidth(cellFrame) + 12.0;
      titleRect.origin.x += leftInset;
      titleRect.size.width = MAX(0.0, titleRect.size.width - leftInset - rightInset);
      return titleRect;
    }

  if ([[GSTheme theme] isKindOfClass: [WinUITheme class]])
    {
      theme = (WinUITheme *)[GSTheme theme];
    }
  titleWidth = ceil(WinUIThemeButtonTitleSize(theme, cell).width);

  /* The padding gives way first, evenly. */
  if (titleWidth + leftInset + rightInset > NSWidth(titleRect))
    {
      leftInset = rightInset = MAX(0.0, floor((NSWidth(titleRect) - titleWidth) / 2.0));
    }
  titleRect.origin.x += leftInset;
  titleRect.size.width = MAX(0.0, titleRect.size.width - leftInset - rightInset);

  /* Then the margins, to 2pt from the sides. */
  if (titleWidth > NSWidth(titleRect))
    {
      NSRect widest = NSInsetRect(cellFrame, MIN(2.0, NSWidth(cellFrame) / 4.0), 0.0);
      CGFloat grow = MIN(titleWidth, NSWidth(widest)) - NSWidth(titleRect);

      if (grow > 0.0)
        {
          titleRect.origin.x = MAX(NSMinX(widest), NSMinX(titleRect) - floor(grow / 2.0));
          titleRect.size.width = MIN(NSMaxX(widest) - NSMinX(titleRect), NSWidth(titleRect) + grow);
        }
    }

  return titleRect;
}

void
WinUIThemeDrawButtonLabel(WinUITheme *theme,
                          NSButtonCell *cell,
                          NSRect titleRect,
                          NSView *controlView,
                          NSColor *textColor,
                          BOOL emphasized)
{
  NSAttributedString *title = [cell attributedTitle];

  if ([title length] == 0)
    {
      return;
    }

  if (textColor != nil)
    {
      NSMutableAttributedString *mutableTitle = AUTORELEASE([title mutableCopy]);
      NSFont *font = WinUIThemePreferredControlFont(theme, [cell font], emphasized);

      [mutableTitle addAttribute: NSForegroundColorAttributeName
                           value: textColor
                           range: NSMakeRange(0, [mutableTitle length])];
      if (font != nil)
        {
          [mutableTitle addAttribute: NSFontAttributeName
                               value: font
                               range: NSMakeRange(0, [mutableTitle length])];
        }
      title = mutableTitle;
    }

  [cell drawTitle: title withFrame: titleRect inView: controlView];
}

void
WinUIThemeDrawIndicatorLabel(NSButtonCell *cell,
                             NSRect titleRect,
                             NSView *controlView,
                             BOOL enabled)
{
  NSAttributedString *title = [cell attributedTitle];

  if ([title length] == 0)
    {
      return;
    }

  if (enabled == NO)
    {
      NSMutableAttributedString *mutableTitle = AUTORELEASE([title mutableCopy]);

      [mutableTitle addAttribute: NSForegroundColorAttributeName
                           value: [NSColor disabledControlTextColor]
                           range: NSMakeRange(0, [mutableTitle length])];
      title = mutableTitle;
    }

  [cell drawTitle: title withFrame: titleRect inView: controlView];
}

void
WinUIThemeDrawChevron(NSPoint center, BOOL pointingUp, NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat width = 5.5;
  CGFloat height = 3.0;
  /* Up and down as the user sees them: in a flipped view (buttons, pop-ups,
     text fields) up is towards smaller y, in an unflipped one (NSStepper)
     towards larger y. The stepper's chevrons used to point the wrong way. */
  BOOL apexAtSmallerY = (pointingUp == [[NSView focusView] isFlipped]);

  if (apexAtSmallerY)
    {
      [path moveToPoint: NSMakePoint(center.x - (width / 2.0), center.y + (height / 2.0))];
      [path lineToPoint: NSMakePoint(center.x, center.y - (height / 2.0))];
      [path lineToPoint: NSMakePoint(center.x + (width / 2.0), center.y + (height / 2.0))];
    }
  else
    {
      [path moveToPoint: NSMakePoint(center.x - (width / 2.0), center.y - (height / 2.0))];
      [path lineToPoint: NSMakePoint(center.x, center.y + (height / 2.0))];
      [path lineToPoint: NSMakePoint(center.x + (width / 2.0), center.y - (height / 2.0))];
    }

  [path setLineWidth: 1.35];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [color set];
  [path stroke];
}

void
WinUIThemeDrawCheckmark(NSRect rect, NSColor *color)
{
  CGFloat size = MIN(rect.size.width, rect.size.height);
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat left = NSMinX(rect) + (size * 0.22);
  CGFloat midX = NSMinX(rect) + (size * 0.45);
  CGFloat right = NSMaxX(rect) - (size * 0.22);
  CGFloat top = NSMinY(rect) + (size * 0.30);
  CGFloat midY = NSMidY(rect) + (size * 0.10);
  CGFloat bottom = NSMaxY(rect) - (size * 0.24);

  [path moveToPoint: NSMakePoint(left, midY)];
  [path lineToPoint: NSMakePoint(midX, bottom)];
  [path lineToPoint: NSMakePoint(right, top)];
  [path setLineWidth: 2.0];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [color set];
  [path stroke];
}

void
WinUIThemeDrawRadioDot(NSRect rect, NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect: rect];

  [color set];
  [path fill];
}

void
WinUIThemeDrawSearchGlyph(NSRect rect, NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat diameter = MIN(rect.size.width, rect.size.height) - 6.0;
  NSRect lensRect = WinUIThemeCenteredRect(rect, diameter, diameter);
  CGFloat handleLength = MAX(3.0, diameter * 0.34);

  lensRect.origin.x -= 1.0;
  lensRect.origin.y += 0.5;
  [path appendBezierPathWithOvalInRect: NSInsetRect(lensRect, 1.0, 1.0)];
  [path moveToPoint: NSMakePoint(NSMaxX(lensRect) - 1.5, NSMaxY(lensRect) - 1.5)];
  [path lineToPoint: NSMakePoint(NSMaxX(lensRect) + handleLength - 1.5,
                                 NSMaxY(lensRect) + handleLength - 1.5)];
  [path setLineWidth: 1.8];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [path setLineJoinStyle: NSRoundLineJoinStyle];
  [color set];
  [path stroke];
}

/* A plain cross filling `rect`: WinUI's delete button. */
void
WinUIThemeDrawCrossGlyph(NSRect rect, NSColor *color)
{
  NSBezierPath *mark = [NSBezierPath bezierPath];

  [mark moveToPoint: NSMakePoint(NSMinX(rect), NSMinY(rect))];
  [mark lineToPoint: NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
  [mark moveToPoint: NSMakePoint(NSMinX(rect), NSMaxY(rect))];
  [mark lineToPoint: NSMakePoint(NSMaxX(rect), NSMinY(rect))];
  [mark setLineWidth: 1.3];
  [mark setLineCapStyle: NSRoundLineCapStyle];
  [color set];
  [mark stroke];
}

void
WinUIThemeDrawDismissGlyph(NSRect rect, NSColor *fillColor, NSColor *markColor)
{
  NSRect circleRect = WinUIThemeCenteredRect(rect, 14.0, 14.0);
  NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect: circleRect];
  NSBezierPath *mark = [NSBezierPath bezierPath];
  CGFloat inset = 4.4;

  [fillColor set];
  [circle fill];

  [mark moveToPoint: NSMakePoint(NSMinX(circleRect) + inset, NSMinY(circleRect) + inset)];
  [mark lineToPoint: NSMakePoint(NSMaxX(circleRect) - inset, NSMaxY(circleRect) - inset)];
  [mark moveToPoint: NSMakePoint(NSMinX(circleRect) + inset, NSMaxY(circleRect) - inset)];
  [mark lineToPoint: NSMakePoint(NSMaxX(circleRect) - inset, NSMinY(circleRect) + inset)];
  [mark setLineWidth: 1.6];
  [mark setLineCapStyle: NSRoundLineCapStyle];
  [mark setLineJoinStyle: NSRoundLineJoinStyle];
  [markColor set];
  [mark stroke];
}

void
WinUIThemeDrawStepperGlyph(NSRect rect, BOOL increment, NSColor *color)
{
  CGFloat span = floor(MIN(rect.size.width, rect.size.height) * 0.28);
  NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
  NSBezierPath *path = [NSBezierPath bezierPath];

  [path moveToPoint: NSMakePoint(center.x - span, center.y)];
  [path lineToPoint: NSMakePoint(center.x + span, center.y)];

  if (increment)
    {
      [path moveToPoint: NSMakePoint(center.x, center.y - span)];
      [path lineToPoint: NSMakePoint(center.x, center.y + span)];
    }

  [path setLineWidth: 1.3];
  [path setLineCapStyle: NSRoundLineCapStyle];
  [color set];
  [path stroke];
}

void
WinUIThemeDrawInputChrome(WinUITheme *theme,
                          NSRect frame,
                          BOOL enabled,
                          BOOL highlighted,
                          BOOL focused,
                          BOOL roundedLeft,
                          BOOL roundedRight)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *surface = WinUIThemeColorFromTheme(theme,
                                              @"fieldBackgroundColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *window = WinUIThemeColorFromTheme(theme,
                                             @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(theme,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSColor *accent = WinUIThemeColorFromTheme(theme,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  NSColor *fillColor = nil;
  NSColor *borderColor = nil;
  CGFloat radius = WinUIThemeControlCornerRadius(theme);

  if (enabled == NO)
    {
      fillColor = WinUIThemeBlendColor(surface, window, dark ? 0.20 : 0.30);
      borderColor = WinUIThemeBlendColor(separator, surface, dark ? 0.34 : 0.26);
    }
  else
    {
      fillColor = highlighted
        ? WinUIThemeBlendColor(surface, accent, dark ? 0.24 : 0.08)
        : surface;
      borderColor = focused
        ? WinUIThemeBlendColor(separator, accent, dark ? 0.66 : 0.44)
        : WinUIThemeBlendColor(separator,
                               dark ? [NSColor whiteColor] : [NSColor blackColor],
                               dark ? 0.14 : 0.04);
    }

  WinUIThemeDrawRoundedSegment(frame,
                               radius,
                               roundedLeft,
                               roundedRight,
                               fillColor,
                               borderColor);
}

/* WinUI's TextBox (#37). Fluent's colours are white or black at an
   opacity over the layer; these blend them over the window background.
   ControlFillColorDefault at rest, Secondary under the pointer,
   InputActive focused, Disabled. */
NSColor *
WinUIThemeTextBoxFillColor(WinUITheme *theme, BOOL enabled, BOOL hovered, BOOL focused)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *window = WinUIThemeColorFromTheme(theme, @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);

  if ([[theme settings] highContrastEnabled])
    {
      return window;
    }
  if (enabled == NO)
    {
      return WinUIThemeBlendColor(window, [NSColor whiteColor], dark ? 0.042 : 0.30);
    }
  if (focused)
    {
      return dark
        ? WinUIThemeBlendColor(window, [NSColor colorWithCalibratedWhite: 30.0 / 255.0 alpha: 1.0], 0.70)
        : WinUIThemeBlendColor(window, [NSColor whiteColor], 1.0);
    }
  return WinUIThemeBlendColor(window, [NSColor whiteColor],
                              hovered ? (dark ? 0.084 : 0.50) : (dark ? 0.06 : 0.70));
}

/* A text input has focus: its field editor, or a scroll view's text view. */
static BOOL
WinUIThemeTextInputHasFocus(NSView *view)
{
  if ([view isKindOfClass: [NSScrollView class]])
    {
      NSView *document = [(NSScrollView *)view documentView];

      return document != nil && [[view window] firstResponder] == document;
    }
  return WinUIThemeViewHasFocus(view);
}

/* The TextBox: its fill, a ControlStrokeColorDefault border whose bottom
   is ControlStrongStrokeColorDefault (TextControlElevationBorder), and,
   focused, a 2px accent bottom border in place of a ring. 4pt corners. */
void
WinUIThemeDrawTextBoxChrome(WinUITheme *theme, NSRect frame, NSView *view, BOOL enabled)
{
  BOOL focused = enabled && WinUIThemeTextInputHasFocus(view);
  BOOL hovered = NO;

  if (enabled && view != nil)
    {
      WinUIThemeTrackHover(view);
      hovered = WinUIThemeViewIsHovered(view);
    }
  WinUIThemeDrawTextBoxChromeInState(theme, frame, (view != nil && [view isFlipped]),
                                     enabled, hovered, focused);
}

/* The TextBox in a given state, for views holding several (form cells). */
void
WinUIThemeDrawTextBoxChromeInState(WinUITheme *theme, NSRect frame, BOOL flipped,
                                   BOOL enabled, BOOL hovered, BOOL focused)
{
  NSGraphicsContext *context = [NSGraphicsContext currentContext];
  BOOL dark = [[theme settings] prefersDarkAppearance];
  BOOL highContrast = [[theme settings] highContrastEnabled];
  NSColor *text = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
  NSColor *accent = WinUIThemeColorFromTheme(theme, @"accentColor", [NSColor selectedControlColor]);
  NSColor *fill = nil;
  NSColor *stroke = nil;
  NSColor *bottom = nil;
  CGFloat bottomWidth = 1.0;
  NSRect drawRect = NSInsetRect(NSIntegralRect(frame), 0.5, 0.5);
  NSBezierPath *path = WinUIThemeRoundedPath(drawRect, WinUIThemeControlCornerRadius(theme));

  fill = WinUIThemeTextBoxFillColor(theme, enabled, hovered, focused);
  if (highContrast)
    {
      stroke = enabled ? text : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor",
                                                         [NSColor disabledControlTextColor]);
      bottom = focused ? accent : stroke;
    }
  else
    {
      NSColor *ink = dark ? [NSColor whiteColor] : [NSColor blackColor];

      stroke = WinUIThemeBlendColor(fill, ink, dark ? 0.07 : 0.058);
      bottom = enabled ? WinUIThemeBlendColor(fill, ink, dark ? 0.544 : 0.446) : stroke;
      if (focused)
        {
          bottom = accent;
        }
    }
  if (focused)
    {
      bottomWidth = 2.0;
    }

  [fill set];
  [path fill];
  [stroke set];
  [path setLineWidth: 1.0];
  [path stroke];

  /* The bottom edge, following the corners. */
  {
    NSRect outer = NSIntegralRect(frame);
    NSRect band = NSMakeRect(NSMinX(outer),
                             flipped ? NSMaxY(outer) - bottomWidth : NSMinY(outer),
                             NSWidth(outer), bottomWidth);

    [context saveGraphicsState];
    [WinUIThemeRoundedPath(outer, WinUIThemeControlCornerRadius(theme)) addClip];
    [bottom set];
    NSRectFill(band);
    [context restoreGraphicsState];
  }
}

void
WinUIThemeDrawSegmentChrome(WinUITheme *theme,
                            NSRect frame,
                            BOOL enabled,
                            BOOL selected,
                            BOOL focused,
                            BOOL roundedLeft,
                            BOOL roundedRight)
{
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *surface = WinUIThemeColorFromTheme(theme,
                                              @"fieldBackgroundColor",
                                              [NSColor controlBackgroundColor]);
  NSColor *window = WinUIThemeColorFromTheme(theme,
                                             @"windowBackgroundColor",
                                             [NSColor windowBackgroundColor]);
  NSColor *separator = WinUIThemeColorFromTheme(theme,
                                                @"separatorColor",
                                                [NSColor controlShadowColor]);
  NSColor *accent = WinUIThemeColorFromTheme(theme,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  NSColor *fillColor = nil;
  NSColor *borderColor = nil;
  CGFloat radius = WinUIThemeControlCornerRadius(theme);

  if (enabled == NO)
    {
      fillColor = selected
        ? WinUIThemeBlendColor(surface, accent, dark ? 0.22 : 0.10)
        : WinUIThemeBlendColor(surface, window, dark ? 0.20 : 0.30);
      borderColor = WinUIThemeBlendColor(separator, surface, dark ? 0.34 : 0.26);
    }
  else if (selected)
    {
      fillColor = WinUIThemeBlendColor(surface, accent, dark ? 0.30 : 0.13);
      borderColor = focused
        ? WinUIThemeBlendColor(separator, accent, dark ? 0.72 : 0.52)
        : WinUIThemeBlendColor(separator, accent, dark ? 0.52 : 0.34);
    }
  else
    {
      fillColor = surface;
      borderColor = focused
        ? WinUIThemeBlendColor(separator, accent, dark ? 0.66 : 0.44)
        : WinUIThemeBlendColor(separator,
                               dark ? [NSColor whiteColor] : [NSColor blackColor],
                               dark ? 0.14 : 0.04);
    }

  WinUIThemeDrawRoundedSegment(frame,
                               radius,
                               roundedLeft,
                               roundedRight,
                               fillColor,
                               borderColor);
}

void
WinUIThemeResolveEntryColors(WinUITheme *theme,
                             NSView *view,
                             BOOL enabled,
                             BOOL focused,
                             BOOL readonlyField,
                             NSColor **fillOut,
                             NSColor **borderOut,
                             CGFloat *lineWidthOut)
{
  NSColor *windowFill = WinUIThemeColorFromTheme(theme,
                                                 @"windowBackgroundColor",
                                                 [NSColor windowBackgroundColor]);
  NSColor *textFill = WinUIThemeColorFromTheme(theme,
                                               @"fieldBackgroundColor",
                                               [NSColor textBackgroundColor]);
  NSColor *shadowColor = WinUIThemeColorFromTheme(theme,
                                                  @"separatorColor",
                                                  [NSColor controlShadowColor]);
  NSColor *accent = WinUIThemeColorFromTheme(theme,
                                             @"accentColor",
                                             [NSColor selectedControlColor]);
  BOOL dark = [[theme settings] prefersDarkAppearance];
  NSColor *fillColor = WinUIThemeTextBoxFillColor(theme, enabled, NO, focused);
  NSColor *borderColor = nil;
  CGFloat lineWidth = 1.0;

  (void)view;
  (void)textFill;

  borderColor = WinUIThemeBlendColor(shadowColor,
                                     dark ? [NSColor whiteColor] : [NSColor blackColor],
                                     dark ? 0.14 : 0.04);

  (void)readonlyField;
  (void)windowFill;
  if (enabled == NO)
    {
      borderColor = WinUIThemeBlendColor(borderColor, fillColor, 0.24);
    }
  else if (focused)
    {
      borderColor = WinUIThemeBlendColor(shadowColor, accent, dark ? 0.66 : 0.44);
    }

  if (fillOut != NULL)
    {
      *fillOut = fillColor;
    }
  if (borderOut != NULL)
    {
      *borderOut = borderColor;
    }
  if (lineWidthOut != NULL)
    {
      *lineWidthOut = lineWidth;
    }
}

CGFloat
WinUIThemeComboBoxButtonWidth(NSRect cellFrame)
{
  return MIN(28.0, MAX(22.0, floor(cellFrame.size.height * 0.78)));
}

/* WinUI's ComboBox chevron: 12px wide, its right edge 14px from the
   control's, in TextFillColorSecondary (#40). */
void
WinUIThemeDrawComboBoxGlyph(WinUITheme *theme, NSRect frame, BOOL enabled)
{
  NSColor *color = enabled
    ? WinUIThemeColorFromTheme(theme, @"secondaryLabelColor", [NSColor controlTextColor])
    : WinUIThemeColorFromTheme(theme, @"disabledControlTextColor", [NSColor disabledControlTextColor]);

  WinUIThemeDrawChevron(NSMakePoint(NSMaxX(frame) - WinUIThemeComboBoxGlyphInset, NSMidY(frame)), NO, color);
}

NSRect
WinUIThemeComboBoxButtonRect(NSRect cellFrame)
{
  CGFloat buttonWidth = WinUIThemeComboBoxButtonWidth(cellFrame);

  return NSMakeRect(NSMaxX(cellFrame) - buttonWidth - 2.0,
                    NSMinY(cellFrame) + 2.0,
                    buttonWidth,
                    MAX(0.0, cellFrame.size.height - 4.0));
}

NSRect
WinUIThemeComboBoxTextRect(NSComboBoxCell *cell, NSRect cellFrame)
{
  NSRect textRect = [cell drawingRectForBounds: cellFrame];
  CGFloat leftInset = 12.0;
  CGFloat rightInset = WinUIThemeComboBoxButtonWidth(cellFrame) + 12.0;

  textRect.origin.x += leftInset;
  textRect.size.width = MAX(0.0, textRect.size.width - leftInset - rightInset);

  return textRect;
}

NSString *
WinUIThemeComboBoxDisplayString(NSComboBoxCell *cell)
{
  NSString *value = nil;
  id object = [cell objectValueOfSelectedItem];

  if ([object respondsToSelector: @selector(description)])
    {
      value = [object description];
    }
  if ([value length] == 0)
    {
      value = [cell stringValue];
    }

  return value;
}

NSInteger
WinUIThemeSegmentIndexAtPoint(NSSegmentedCell *cell,
                              NSRect cellFrame,
                              NSPoint point)
{
  NSInteger segmentCount = [cell segmentCount];
  CGFloat explicitWidth = 0.0;
  NSInteger flexibleSegments = 0;
  CGFloat defaultWidth = 0.0;
  CGFloat cursorX = NSMinX(cellFrame);
  NSInteger index = 0;

  if (segmentCount <= 0 || NSPointInRect(point, cellFrame) == NO)
    {
      return NSNotFound;
    }

  for (index = 0; index < segmentCount; index++)
    {
      CGFloat width = [cell widthForSegment: index];

      if (width > 0.0)
        {
          explicitWidth += width;
        }
      else
        {
          flexibleSegments++;
        }
    }

  if (flexibleSegments > 0)
    {
      defaultWidth = MAX(0.0, (cellFrame.size.width - explicitWidth) / flexibleSegments);
    }

  for (index = 0; index < segmentCount; index++)
    {
      CGFloat width = [cell widthForSegment: index];

      if (width <= 0.0)
        {
          width = defaultWidth;
        }

      if (point.x < (cursorX + width) || index == (segmentCount - 1))
        {
          return index;
        }

      cursorX += width;
    }

  return NSNotFound;
}

/* WinUI's ToggleSwitch track: 40x20, shrunk (keeping its 2:1 shape) to fit
   a smaller frame, centred in a larger one. It used to stretch to the
   frame's width. */
NSRect
WinUIThemeSwitchTrackRect(NSRect rect)
{
  CGFloat height = MIN(20.0, floor(NSHeight(rect)));
  CGFloat width = 2.0 * height;

  if (width > floor(NSWidth(rect)))
    {
      width = floor(NSWidth(rect));
      height = floor(width / 2.0);
    }

  return NSMakeRect(floor(NSMidX(rect) - (width / 2.0)),
                    floor(NSMidY(rect) - (height / 2.0)),
                    width,
                    height);
}

NSRect
WinUIThemeSliderTrackRect(WinUITheme *theme, NSRect rect, BOOL horizontal)
{
  /* WinUI's 4px Slider track (#41). */
  CGFloat thickness = round(4.0 * MAX(1.0, [[theme settings] desktopScaleFactor]));

  if (horizontal)
    {
      return NSMakeRect(rect.origin.x + 1.0,
                        floor(NSMidY(rect) - (thickness / 2.0)),
                        MAX(6.0, rect.size.width - 2.0),
                        thickness);
    }

  return NSMakeRect(floor(NSMidX(rect) - (thickness / 2.0)),
                    rect.origin.y + 1.0,
                    thickness,
                    MAX(6.0, rect.size.height - 2.0));
}
