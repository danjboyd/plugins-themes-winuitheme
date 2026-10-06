#ifndef GNUstep_WINUITHEMEDRAWING_H
#define GNUstep_WINUITHEMEDRAWING_H

#import <AppKit/AppKit.h>
#import <AppKit/NSGraphics.h>

#import "../WinUITheme.h"

@interface NSCell (WinUIThemePrivateTextDrawing)
- (NSDictionary *) _nonAutoreleasedTypingAttributes;
- (BOOL) _shouldShortenStringForRect: (NSRect)titleRect
                                size: (NSSize)titleSize
                              length: (NSUInteger)length;
- (void) _drawAttributedText: (NSAttributedString *)attrstring
                     inFrame: (NSRect)cellFrame;
- (void) _drawText: (NSString *)text
           inFrame: (NSRect)cellFrame;
@end

@interface NSTextFieldCell (WinUIThemePrivateTextDrawing)
- (BOOL) _inEditing;
- (NSAttributedString *) _drawAttributedString;
- (void) _drawEditorWithFrame: (NSRect)cellFrame
                       inView: (NSView *)controlView;
- (BOOL) _shouldShortenStringForRect: (NSRect)titleRect
                                size: (NSSize)titleSize
                              length: (NSUInteger)length;
- (NSAttributedString *) _resizeAttributedString: (NSAttributedString *)attrstring
                                         forRect: (NSRect)titleRect;
@end

@interface NSComboBoxCell (WinUIThemePrivate)
- (void) _didClickWithinButton: (id)sender;
@end

@interface NSPopUpButtonCell (WinUIThemePrivate)
- (NSImage *) _currentArrowImage;
@end

CGFloat WinUIThemeControlCornerRadius(WinUITheme *theme);
CGFloat WinUIThemeOverlayCornerRadius(WinUITheme *theme);

/* YES when scroll bars overlay the content and hide (WinUIThemeScrollers.m). */
BOOL WinUIThemeUsesOverlayScrollers(void);

/* YES while focus rings show: after a key press, until a pointer press
   (WinUIThemeFocus.m). */
BOOL WinUIThemeKeyboardFocusVisible(void);

/* Pointer-over state (WinUIThemeHover.m). */
void WinUIThemeTrackHover(NSView *view);
BOOL WinUIThemeViewIsHovered(NSView *view);

CGFloat WinUIThemeClamp(CGFloat value, CGFloat minimum, CGFloat maximum);
NSColor *WinUIThemeColorFromTheme(WinUITheme *theme, NSString *key, NSColor *fallback);
NSColor *WinUIThemeColorWithAlpha(NSColor *color, CGFloat alpha);
NSColor *WinUIThemeBlendColor(NSColor *fromColor, NSColor *toColor, CGFloat amount);
NSBezierPath *WinUIThemeRoundedPath(NSRect rect, CGFloat radius);
NSBezierPath *WinUIThemeSegmentedControlPath(NSRect rect,
                                             CGFloat radius,
                                             BOOL roundedLeft,
                                             BOOL roundedRight);
void WinUIThemeFillAndStrokeRoundedRect(NSRect rect,
                                        CGFloat radius,
                                        NSColor *fillColor,
                                        NSColor *strokeColor,
                                        CGFloat strokeWidth);
void WinUIThemeDrawRoundedSegment(NSRect frame,
                                  CGFloat radius,
                                  BOOL roundedLeft,
                                  BOOL roundedRight,
                                  NSColor *fillColor,
                                  NSColor *borderColor);

BOOL WinUIThemeStateIsHighlighted(GSThemeControlState state);
BOOL WinUIThemeStateHasFocus(GSThemeControlState state);
BOOL WinUIThemeControlEnabled(id control);
BOOL WinUIThemeViewHasFocus(NSView *view);
BOOL WinUIThemeUsesModernPushButton(int style);
BOOL WinUIThemeButtonIsDefault(NSCell *cell);
BOOL WinUIThemePopupButtonMenuVisible(NSCell *cell);
BOOL WinUIThemeUsesInputBorder(NSBorderType aType, NSView *view);
BOOL WinUIThemeButtonCellIsCheckbox(NSButtonCell *cell);
BOOL WinUIThemeButtonCellIsRadio(NSButtonCell *cell);
BOOL WinUIThemeButtonCellUsesLegacyReturnImage(NSButtonCell *cell);
BOOL WinUIThemeButtonCellUsesSearchImage(NSButtonCell *cell);
BOOL WinUIThemeButtonCellUsesCancelImage(NSButtonCell *cell);

/* Template images (WinUIThemeTemplateImages.m). */
BOOL WinUIThemeImageIsTemplate(NSImage *image);
NSImage *WinUIThemeTintedImage(NSImage *image, NSColor *color);
NSColor *WinUIThemeTemplateImageColor(WinUITheme *theme, NSButtonCell *cell, NSView *controlView);

NSFont *WinUIThemePreferredControlFont(WinUITheme *theme,
                                       NSFont *font,
                                       BOOL emphasized);
NSFont *WinUIThemeResolvedEditorFont(WinUITheme *theme, NSTextFieldCell *cell);
void WinUIThemeApplyEditorFont(WinUITheme *theme,
                               NSTextFieldCell *cell,
                               NSText *textObject);
void WinUIThemeDrawAttributedStringWithEditorLayout(NSTextFieldCell *cell,
                                                    NSAttributedString *string,
                                                    NSRect rect,
                                                    NSView *controlView);

void WinUIThemeApplyButtonTitleAttributes(WinUITheme *theme,
                                          NSButtonCell *cell,
                                          NSColor *textColor,
                                          BOOL emphasized);
void WinUIThemeRemoveDefaultButtonGlyph(NSButtonCell *cell);
NSSize WinUIThemeButtonTitleSize(WinUITheme *theme, NSButtonCell *cell);
CGFloat WinUIThemeButtonTitleInset(NSButtonCell *cell);
NSRect WinUIThemeButtonTitleRect(NSButtonCell *cell, NSRect cellFrame);
void WinUIThemeDrawButtonLabel(WinUITheme *theme,
                               NSButtonCell *cell,
                               NSRect titleRect,
                               NSView *controlView,
                               NSColor *textColor,
                               BOOL emphasized);
void WinUIThemeDrawIndicatorLabel(NSButtonCell *cell,
                                  NSRect titleRect,
                                  NSView *controlView,
                                  BOOL enabled);

void WinUIThemeDrawChevron(NSPoint center, BOOL pointingUp, NSColor *color);
void WinUIThemeDrawCheckmark(NSRect rect, NSColor *color);
void WinUIThemeDrawRadioDot(NSRect rect, NSColor *color);
void WinUIThemeDrawSearchGlyph(NSRect rect, NSColor *color);
NSRect WinUIThemeCenteredRect(NSRect frame, CGFloat width, CGFloat height);
void WinUIThemeDrawCrossGlyph(NSRect rect, NSColor *color);
void WinUIThemeDrawDismissGlyph(NSRect rect,
                                NSColor *fillColor,
                                NSColor *markColor);
void WinUIThemeDrawStepperGlyph(NSRect rect, BOOL increment, NSColor *color);

void WinUIThemeDrawInputChrome(WinUITheme *theme,
                               NSRect frame,
                               BOOL enabled,
                               BOOL highlighted,
                               BOOL focused,
                               BOOL roundedLeft,
                               BOOL roundedRight);
NSColor *WinUIThemeTextBoxFillColor(WinUITheme *theme, BOOL enabled, BOOL hovered, BOOL focused);
void WinUIThemeDrawTextBoxChrome(WinUITheme *theme, NSRect frame, NSView *view, BOOL enabled);
void WinUIThemeDrawSegmentChrome(WinUITheme *theme,
                                 NSRect frame,
                                 BOOL enabled,
                                 BOOL selected,
                                 BOOL focused,
                                 BOOL roundedLeft,
                                 BOOL roundedRight);
void WinUIThemeResolveEntryColors(WinUITheme *theme,
                                  NSView *view,
                                  BOOL enabled,
                                  BOOL focused,
                                  BOOL readonlyField,
                                  NSColor **fillOut,
                                  NSColor **borderOut,
                                  CGFloat *lineWidthOut);

/* The ComboBox chevron's centre, from the control's trailing edge. */
#define WinUIThemeComboBoxGlyphInset 20.0
void WinUIThemeDrawComboBoxGlyph(WinUITheme *theme, NSRect frame, BOOL enabled);
NSColor *WinUIThemeDrawButtonChrome(WinUITheme *theme, NSRect frame, NSView *view, BOOL enabled,
                                    BOOL defaultButton, BOOL pressed, BOOL hover);
CGFloat WinUIThemeComboBoxButtonWidth(NSRect cellFrame);
NSRect WinUIThemeComboBoxButtonRect(NSRect cellFrame);
NSRect WinUIThemeComboBoxTextRect(NSComboBoxCell *cell, NSRect cellFrame);
NSString *WinUIThemeComboBoxDisplayString(NSComboBoxCell *cell);
NSInteger WinUIThemeSegmentIndexAtPoint(NSSegmentedCell *cell,
                                        NSRect cellFrame,
                                        NSPoint point);
NSRect WinUIThemeSwitchTrackRect(NSRect rect);
NSRect WinUIThemeSliderTrackRect(WinUITheme *theme, NSRect rect, BOOL horizontal);

#endif
