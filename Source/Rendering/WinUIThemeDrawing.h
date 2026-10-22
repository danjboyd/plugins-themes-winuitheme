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
void WinUIThemeSetViewHovered(NSView *view, BOOL hovered);

/* Motion (#105, WinUIThemeMotion.m): whether the theme animates (Windows'
   "Animation effects", or the WinUIThemeAnimations default); a value easing
   towards `target` for the view, which redraws until it arrives (a view's
   first value is `target` at once); a control's pointer-over and pressed
   states as 0 to 1, fading over WinUI's 83ms; and a window fading in as it
   opens. */
BOOL WinUIThemeAnimationsEnabled(void);
CGFloat WinUIThemeAnimatedValue(NSView *view, const void *key, CGFloat target,
                                NSTimeInterval duration);
CGFloat WinUIThemeHoverAmount(NSView *view, BOOL hovered);
CGFloat WinUIThemePressAmount(NSView *view, BOOL pressed);
CGFloat WinUIThemeToggleAmount(NSView *view, BOOL on);
CGFloat WinUIThemeCheckAmount(NSView *view, BOOL checked);
void WinUIThemeFadeInWindow(NSWindow *window, NSTimeInterval duration);
BOOL WinUIThemeWindowIsFadingIn(NSWindow *window);

/* Text size changes reaching open windows (#105, WinUIThemeTextScale.m):
   the theme's font sizes before a reload, and after it every open
   window's fonts at those sizes moved to the new ones (YES if they
   changed). */
id WinUIThemeTextScaleSnapshotTake(WinUITheme *theme);
BOOL WinUIThemeTextScaleApply(WinUITheme *theme, id snapshot);

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
/* A theme-owned image that draws `image` at `size`, leaving `image` as
   it is, and is a template when `image` is (#89); `image` itself when it
   already has that size. */
NSImage *WinUIThemeSizedImageCopy(NSImage *image, NSSize size);
/* The image a sized image draws, or nil. */
NSImage *WinUIThemeSizedImageSource(NSImage *image);
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
void WinUIThemeDrawCheckmarkDrawnIn(NSRect rect, NSColor *color, CGFloat amount);
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
/* `hovered` and `hover` run from 0 to 1 (WinUIThemeHoverAmount). */
NSColor *WinUIThemeTextBoxFillColor(WinUITheme *theme, BOOL enabled, CGFloat hovered, BOOL focused);
void WinUIThemeDrawTextBoxChrome(WinUITheme *theme, NSRect frame, NSView *view, BOOL enabled);
void WinUIThemeDrawTextBoxChromeInState(WinUITheme *theme, NSRect frame, BOOL flipped,
                                        BOOL enabled, CGFloat hovered, BOOL focused);
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
                                    BOOL defaultButton, BOOL pressed, CGFloat hover);
CGFloat WinUIThemeComboBoxButtonWidth(NSRect cellFrame);
NSRect WinUIThemeComboBoxButtonRect(NSRect cellFrame);
NSRect WinUIThemeComboBoxTextRect(NSComboBoxCell *cell, NSRect cellFrame);
NSString *WinUIThemeComboBoxDisplayString(NSComboBoxCell *cell);
NSInteger WinUIThemeSegmentIndexAtPoint(NSSegmentedCell *cell,
                                        NSRect cellFrame,
                                        NSPoint point);
NSRect WinUIThemeSwitchTrackRect(NSRect rect);
/* Slider, progress and level colours (WinUIThemeControls.m): the track
   (ControlStrongFill/Stroke), the accent value, the slider thumb and its
   borders. Any argument may be NULL. */
void WinUIThemeRangeColors(WinUITheme *theme, BOOL enabled,
                           NSColor **trackOut, NSColor **valueOut,
                           NSColor **thumbOut, NSColor **borderOut, NSColor **bottomOut);
NSRect WinUIThemeSliderTrackRect(WinUITheme *theme, NSRect rect, BOOL horizontal);
/* SystemFillColorCaution, or SystemFillColorCritical when `critical`, in
   the palette's mode; `fallback` in high contrast or disabled. */
NSColor *WinUIThemeStatusColor(WinUITheme *theme, BOOL critical, BOOL enabled, NSColor *fallback);

/* While a selected table or outline row draws in high contrast, the colour
   its text takes whatever the app set (WinUIThemeMenusAndData.m); nil
   otherwise. */
NSColor *WinUIThemeSelectedRowTextColor(NSView *controlView);

/* NSBrowser's columns (WinUIThemeBrowser.m): YES for a column's scroll
   view; its card, drawn as its border. */
BOOL WinUIThemeIsBrowserColumn(NSView *view);
void WinUIThemeDrawBrowserColumnCard(WinUITheme *theme, NSRect frame);
NSColor *WinUIThemeBrowserCardColor(WinUITheme *theme);
/* CardStrokeColorDefault, for cards (browser columns, tab view content). */
NSColor *WinUIThemeCardStrokeColor(WinUITheme *theme);
/* DividerStrokeColorDefault, for separators and line borders
   (WinUIThemeBoxes.m). */
NSColor *WinUIThemeDividerColor(WinUITheme *theme);
void WinUIThemeSyncBrowserColumn(NSScrollView *scrollView);

/* A popover panel the app marked for the theme (its class adopts
   GSThemePopoverPanel), drawn as a WinUI flyout (WinUIThemeFlyouts.m). */
BOOL WinUIThemeWindowIsFlyout(NSWindow *window);

/* The menu bar from the keyboard (#78) and its overflow (#77),
   WinUIThemeMenuBarKeyboard.m. -[NSApplication sendEvent:] offers it each
   event first; YES when it took the event. */
BOOL WinUIThemeMenuBarHandleEvent(NSEvent *event);
/* Whether menu titles show their access keys underlined (Alt held, or the
   bar reached from the keyboard), and the part of a title to underline. */
BOOL WinUIThemeMenuAccessKeysVisible(void);
NSRange WinUIThemeMenuAccessKeyRange(NSString *title);
/* The overflow button of a bar too narrow for its titles (empty when they
   fit), and whether it's selected. */
NSRect WinUIThemeMenuBarOverflowRect(NSMenuView *bar);
/* Window tabs (#133, WinUIThemeWindowTabs.m): a window that can tab
   shows its tab bar with one tab, as Notepad and Terminal open. Call for
   each window that becomes key or main. */
void WinUIThemeWindowTabsWindowBecameKey(NSWindow *window);
/* The overflow button's width, and the inset before a bar's first title
   (libs-gui's layout): WinUIThemeMenuStyle `more` sizes the bar from
   them in the toolbar's row. */
extern const CGFloat WinUIThemeMenuBarOverflowButtonWidth;
CGFloat WinUIThemeMenuBarFirstTitleInset(NSMenuView *bar);
BOOL WinUIThemeMenuBarOverflowSelected(NSMenuView *bar);

/* An accent button without a default button's Return: -setGSThemeStyle:
   @"accent" (WinUIThemeControls.m), as the Adwaita theme has it. */
@interface NSButtonCell (WinUIThemeButtonStyle)
- (void) setGSThemeStyle: (NSString *)style;
- (NSString *) GSThemeStyle;
@end

@interface NSButton (WinUIThemeButtonStyle)
- (void) setGSThemeStyle: (NSString *)style;
- (NSString *) GSThemeStyle;
@end

#endif
