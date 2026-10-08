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

#include <objc/runtime.h>

/* NSBox and NSForm as WinUI's settings surfaces (#27). A bezelled, grooved
   or lined box is a card (CardBackgroundFillColorDefault, a 1px
   CardStrokeColorDefault border, 8pt corners) with its title above it in
   BodyStrong, not set into a groove; a separator box is a
   DividerStrokeColorDefault hairline. A form's entries are TextBoxes
   beside their titles. libs-gui drew NeXT's groove and bezel, and filled a
   form entry over its chrome with textBackgroundColor. */

/* A title inside the card, from its leading edge. */
static const CGFloat WinUIThemeBoxTitleInset = 12.0;
/* Between a form's title and its entry, as libs-gui lays them out. */
static const CGFloat WinUIThemeFormTitleGap = 3.0;

@interface NSFormCell (WinUIThemePrivate)
- (BOOL) _inEditing;
@end

static WinUITheme *
WinUIThemeBoxTheme(void)
{
  GSTheme *theme = [GSTheme theme];

  return [theme isKindOfClass: [WinUITheme class]] ? (WinUITheme *)theme : nil;
}

/* DividerStrokeColorDefault: black at 8% (white at 8% dark) over the
   window; the text colour in high contrast. */
NSColor *
WinUIThemeDividerColor(WinUITheme *theme)
{
  NSColor *window = WinUIThemeColorFromTheme(theme, @"windowBackgroundColor", [NSColor windowBackgroundColor]);
  NSColor *text = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);

  return WinUIThemeBlendColor(window, text, [[theme settings] highContrastEnabled] ? 1.0 : 0.08);
}

/* The card's colours: the browser column's (WinUIThemeBrowser.m). */
static void
WinUIThemeDrawBoxCard(WinUITheme *theme, NSRect frame)
{
  WinUIThemeFillAndStrokeRoundedRect(NSInsetRect(NSIntegralRect(frame), 0.5, 0.5),
                                     WinUIThemeOverlayCornerRadius(theme),
                                     WinUIThemeBrowserCardColor(theme),
                                     WinUIThemeCardStrokeColor(theme), 1.0);
}

/* The title in BodyStrong (semibold at the title's size, which the box was
   laid out for), starting at `x`, centred in the title's rect. Drawn as a
   string, so it reads the right way up in a box that isn't flipped. */
static void
WinUIThemeDrawBoxTitle(WinUITheme *theme, NSBox *box, CGFloat x)
{
  NSString *title = [box title];
  NSFont *font = [box titleFont];
  NSRect titleRect = [box titleRect];
  NSDictionary *attributes;
  NSSize size;

  if ([title length] == 0)
    {
      return;
    }
  if (font == nil)
    {
      font = [NSFont systemFontOfSize: 0];
    }
  font = WinUIThemeSemiboldFont(font, [font pointSize]);
  attributes = [NSDictionary dictionaryWithObjectsAndKeys:
    font, NSFontAttributeName,
    WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]), NSForegroundColorAttributeName,
    nil];
  size = [title sizeWithAttributes: attributes];
  [title drawAtPoint: NSMakePoint(x, floor(NSMidY(titleRect) - size.height / 2.0))
      withAttributes: attributes];
}

@implementation WinUITheme (Boxes)

/* Only the card is drawn, with rounded corners, so what's under the box
   (the window, or a card it sits in) shows round it. */
- (BOOL) isBoxOpaque: (NSBox *)box
{
  if ([box boxType] == NSBoxCustom)
    {
      return [super isBoxOpaque: box];
    }
  return NO;
}

- (void) drawBoxInClipRect: (NSRect)clipRect
                   boxType: (NSBoxType)boxType
                borderType: (NSBorderType)borderType
                    inView: (NSBox *)box
{
  NSTitlePosition position = [box titlePosition];
  NSRect card = [box borderRect];
  NSRect titleRect = [box titleRect];
  CGFloat titleX;

  (void)clipRect;
  if (boxType == NSBoxSeparator)
    {
      [WinUIThemeDividerColor(self) set];
      NSRectFill([box borderRect]);
      return;
    }
  /* A custom box keeps the colours and border its app chose. */
  if (boxType == NSBoxCustom)
    {
      [super drawBoxInClipRect: clipRect boxType: boxType borderType: borderType inView: box];
      return;
    }

  /* A title on the border goes above (or below) the card instead. */
  if (position == NSAtTop)
    {
      card.size.height = MAX(0.0, NSMinY(titleRect) - NSMinY(card));
    }
  else if (position == NSAtBottom)
    {
      CGFloat top = NSMaxY(card);

      card.origin.y = NSMaxY(titleRect);
      card.size.height = MAX(0.0, top - NSMinY(card));
    }
  if (borderType == NSLineBorder && NSIsEmptyRect(card) == NO)
    {
      WinUIThemeFillAndStrokeRoundedRect(NSInsetRect(NSIntegralRect(card), 0.5, 0.5),
                                         WinUIThemeOverlayCornerRadius(self),
                                         nil, WinUIThemeDividerColor(self), 1.0);
    }
  else if (borderType != NSNoBorder && NSIsEmptyRect(card) == NO)
    {
      WinUIThemeDrawBoxCard(self, card);
    }

  if (position == NSNoTitle)
    {
      return;
    }
  /* WinUI's headers start at the card's leading edge; one inside the card
     lines up with its content. */
  titleX = NSMinX([box borderRect]);
  if (borderType != NSNoBorder && (position == NSBelowTop || position == NSAboveBottom))
    {
      titleX += WinUIThemeBoxTitleInset;
    }
  WinUIThemeDrawBoxTitle(self, box, titleX);
}

/* A form's entry, beside its title: the TextBox, its own state rather than
   the form's, which holds several. NSFormCell drew the border and then
   filled the entry with textBackgroundColor, covering the chrome. */
- (void) _overrideNSFormCellMethod__drawBorderAndBackgroundWithFrame: (NSRect)cellFrame
                                                              inView: (NSView *)controlView
{
  NSFormCell *cell = (NSFormCell *)self;
  WinUITheme *theme = WinUIThemeBoxTheme();
  Ivar titleWidthIvar = class_getInstanceVariable([NSFormCell class], "_displayedTitleWidth");
  CGFloat titleWidth = [cell titleWidth];
  NSRect entry = cellFrame;
  BOOL enabled = [cell isEnabled];
  BOOL focused = NO;
  BOOL hovered = NO;

  if (theme == nil)
    {
      typedef void (*DrawIMP)(id, SEL, NSRect, NSView *);
      DrawIMP originalIMP = (DrawIMP)WinUIThemeOriginalMethod(_cmd, self, [NSFormCell class]);

      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, cellFrame, controlView);
        }
      return;
    }
  if ([cell isBezeled] == NO && [cell isBordered] == NO)
    {
      return;
    }
  if (titleWidthIvar != NULL)
    {
      titleWidth = *(float *)((char *)cell + ivar_getOffset(titleWidthIvar));
    }
  entry.origin.x += titleWidth + WinUIThemeFormTitleGap;
  entry.size.width -= titleWidth + WinUIThemeFormTitleGap;

  if (controlView != nil && [controlView respondsToSelector: @selector(isEnabled)])
    {
      enabled = enabled && [(NSControl *)controlView isEnabled];
    }
  focused = enabled && [cell _inEditing] && WinUIThemeViewHasFocus(controlView);
  if (enabled && controlView != nil && [controlView window] != nil)
    {
      NSPoint point = [controlView convertPoint: [[controlView window] mouseLocationOutsideOfEventStream]
                                       fromView: nil];

      WinUIThemeTrackHover(controlView);
      hovered = WinUIThemeViewIsHovered(controlView)
        && NSMouseInRect(point, entry, [controlView isFlipped]);
    }
  WinUIThemeDrawTextBoxChromeInState(theme, entry, [controlView isFlipped], enabled, hovered, focused);
}

@end
