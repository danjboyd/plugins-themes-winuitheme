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
#import <AppKit/PSOperators.h>
#import <GNUstepGUI/GSTheme.h>

/* WinUI's focus visual (#36): a 2px outer stroke in the primary text
   colour and a 1px inner one in the background colour, 3px outside the
   control and following its corners. Shown only when focus came from the
   keyboard (FocusState.Keyboard): a key press shows it, a pointer press
   hides it, as the Adwaita theme's focus-visible. Text inputs have no ring:
   they show an accent underline instead.

   The ring is outside the control, which libs-gui clips its drawing to, so
   it's drawn with the clip widened to the superview's visible part, and
   the superview redraws that margin when the ring goes. */

static BOOL WinUIThemeFocusVisible = NO;
/* The view the ring was last drawn around, and its frame then. */
static NSView *WinUIThemeRingView = nil;
static NSRect WinUIThemeRingFrame;

static const CGFloat WinUIThemeFocusMargin = 3.0;

BOOL
WinUIThemeKeyboardFocusVisible(void)
{
  return WinUIThemeFocusVisible;
}

/* The view, and the ring's margin around it in its superview. */
static void
WinUIThemeRedisplayWithMargin(NSView *view, NSRect frame)
{
  [view setNeedsDisplay: YES];
  if ([view superview] != nil)
    {
      [[view superview] setNeedsDisplayInRect:
        NSInsetRect(frame, -(WinUIThemeFocusMargin + 1.0), -(WinUIThemeFocusMargin + 1.0))];
    }
}

/* Each window's focused view: an editing field's first responder is its
   field editor. */
static NSView *
WinUIThemeFocusedView(NSWindow *window)
{
  id responder = [window firstResponder];

  if ([responder isKindOfClass: [NSText class]]
      && [[responder delegate] isKindOfClass: [NSView class]])
    {
      responder = [responder delegate];
    }
  return [responder isKindOfClass: [NSView class]] ? responder : nil;
}

static void
WinUIThemeRedisplayFocusedViews(void)
{
  NSEnumerator *enumerator = [[NSApp windows] objectEnumerator];
  NSWindow *window = nil;

  while ((window = [enumerator nextObject]) != nil)
    {
      NSView *view = nil;

      if ([window isVisible] == NO)
        {
          continue;
        }
      view = WinUIThemeFocusedView(window);
      if (view != nil)
        {
          WinUIThemeRedisplayWithMargin(view, [view frame]);
        }
    }
}

/* The ring went (focus moved, or the pointer was pressed): the margin it
   drew in is the superview's to redraw. */
static void
WinUIThemeForgetStaleRing(void)
{
  NSView *view = WinUIThemeRingView;

  if (view == nil)
    {
      return;
    }
  if (WinUIThemeFocusVisible && [view window] != nil
      && WinUIThemeFocusedView([view window]) == view
      && NSEqualRects([view frame], WinUIThemeRingFrame))
    {
      return;
    }
  WinUIThemeRedisplayWithMargin(view, WinUIThemeRingFrame);
  DESTROY(WinUIThemeRingView);
}

/* Text inputs show an underline, not a ring. */
static BOOL
WinUIThemeViewTakesFocusRing(NSView *view)
{
  return view != nil
    && [view isKindOfClass: [NSTextField class]] == NO
    && [view isKindOfClass: [NSText class]] == NO;
}

/* The ring round `view`, if it has focus from the keyboard. */
static void
WinUIThemeDrawFocusRing(NSView *view)
{
  GSTheme *current = [GSTheme theme];
  WinUITheme *theme = [current isKindOfClass: [WinUITheme class]] ? (WinUITheme *)current : nil;
  NSGraphicsContext *context = [NSGraphicsContext currentContext];
  NSView *superview = [view superview];
  NSRect control = [view bounds];
  NSRect allowed;
  CGFloat radius;
  BOOL dark, highContrast;
  NSColor *outer = nil;
  NSColor *inner = nil;
  NSBezierPath *path = nil;

  if (theme == nil || WinUIThemeFocusVisible == NO || WinUIThemeViewTakesFocusRing(view) == NO
      || [view window] == nil || WinUIThemeFocusedView([view window]) != view
      || ([view isKindOfClass: [NSControl class]] && [(NSControl *)view isEnabled] == NO))
    {
      return;
    }

  dark = [[theme settings] prefersDarkAppearance];
  highContrast = [[theme settings] highContrastEnabled];
  radius = WinUIThemeControlCornerRadius(theme);
  /* FocusStrokeColorOuter is the primary text colour; FocusStrokeColorInner
     white at 70% (light) or black at 70% (dark). */
  outer = WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor]);
  inner = highContrast
    ? WinUIThemeColorFromTheme(theme, @"windowBackgroundColor", [NSColor windowBackgroundColor])
    : WinUIThemeColorWithAlpha(dark ? [NSColor blackColor] : [NSColor whiteColor], 0.70);

  allowed = (superview != nil)
    ? [view convertRect: [superview visibleRect] fromView: superview]
    : [view bounds];

  [context saveGraphicsState];
  DPSinitclip(GSCurrentContext());
  [[NSBezierPath bezierPathWithRect: allowed] addClip];

  path = WinUIThemeRoundedPath(NSInsetRect(control, -2.0, -2.0), radius + 2.0);
  [path setLineWidth: 2.0];
  [outer set];
  [path stroke];
  path = WinUIThemeRoundedPath(NSInsetRect(control, -0.5, -0.5), radius + 0.5);
  [path setLineWidth: 1.0];
  [inner set];
  [path stroke];

  [context restoreGraphicsState];

  if (view != WinUIThemeRingView)
    {
      ASSIGN(WinUIThemeRingView, view);
    }
  WinUIThemeRingFrame = [view frame];
}

@implementation WinUITheme (Focus)

- (void) _overrideNSApplicationMethod_sendEvent: (NSEvent *)event
{
  typedef void (*SendEventIMP)(id, SEL, NSEvent *);
  SendEventIMP originalIMP = (SendEventIMP)WinUIThemeOriginalMethod(_cmd, self, [NSApplication class]);
  NSEventType type = [event type];
  BOOL visible = WinUIThemeFocusVisible;
  BOOL watch = NO;

  switch (type)
    {
      case NSKeyDown:
        visible = YES;
        watch = YES;
        break;
      case NSLeftMouseDown:
      case NSRightMouseDown:
      case NSOtherMouseDown:
        visible = NO;
        watch = YES;
        break;
      default:
        break;
    }
  /* Before dispatch, so a click that moves focus also clears the ring of
     the view losing it. */
  if (visible != WinUIThemeFocusVisible)
    {
      WinUIThemeFocusVisible = visible;
      WinUIThemeRedisplayFocusedViews();
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, event);
    }
  /* A key may have moved focus (Tab): the new view draws the ring, the old
     one's margin is redrawn. */
  if (watch)
    {
      WinUIThemeForgetStaleRing();
      if (WinUIThemeFocusVisible && [NSApp keyWindow] != nil)
        {
          NSView *view = WinUIThemeFocusedView([NSApp keyWindow]);

          if (view != nil && view != WinUIThemeRingView)
            {
              WinUIThemeRedisplayWithMargin(view, [view frame]);
            }
        }
    }
}

/* libs-gui's ring goes round a cell's interior, and only for cells that
   ask for it; the theme draws its own round whole controls instead. */
- (void) drawFocusFrame: (NSRect)frame view: (NSView *)view
{
  (void)frame;
  (void)view;
}

- (void) _overrideNSControlMethod_drawRect: (NSRect)rect
{
  typedef void (*DrawRectIMP)(id, SEL, NSRect);
  DrawRectIMP originalIMP = (DrawRectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSControl class]);

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, rect);
    }
  WinUIThemeDrawFocusRing((NSView *)self);
}

- (void) _overrideNSSwitchMethod_drawRect: (NSRect)rect
{
  typedef void (*DrawRectIMP)(id, SEL, NSRect);
  DrawRectIMP originalIMP = (DrawRectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSSwitch class]);

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, rect);
    }
  WinUIThemeDrawFocusRing((NSView *)self);
}

@end
