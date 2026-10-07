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
#import <objc/runtime.h>

/* WinUI's ScrollBar (#29). The content runs under the scroll bars, which
   show only while it scrolls or the pointer is over them, then fade: a 2px
   indicator while scrolling; under the pointer a track with a 6px thumb
   and arrow glyphs at its ends. Ported from the Adwaita theme's overlay
   scrollers.

   With Windows' "Automatically hide scroll bars" off, in high contrast, or
   with WinUIThemeOverlayScrollbars NO, scroll bars keep their strips and
   are always shown, expanded.

   libs-gui lays the scroll view out (-tile) with the scrollers beside the
   content; here the clip view (and a table's header) is widened under
   them and they're put on top. Overlapping the content brings three
   things to take care of: the clip view must redraw rather than copy its
   pixels on scrolling (it would copy the scroller's along), a scroller's
   redraws go through the scroll view (it's no longer opaque), and a
   hidden scroller lets presses through to the content. */

/* How long the indicator stays after the last scroll, and how long it
   takes to fade. */
static const NSTimeInterval WinUIThemeOverlayLinger = 1.0;
static const NSTimeInterval WinUIThemeOverlayFade = 0.2;
static const NSTimeInterval WinUIThemeOverlayStep = 0.04;

static char WinUIThemeOverlayStateKey;

@interface NSObject (WinUIThemeOverlayScrollers)
- (NSView *) headerView;
@end

BOOL
WinUIThemeUsesOverlayScrollers(void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  GSTheme *theme = [GSTheme theme];

  if ([theme isKindOfClass: [WinUITheme class]] == NO)
    {
      return NO;
    }
  if ([defaults objectForKey: @"WinUIThemeOverlayScrollbars"] != nil)
    {
      return [defaults boolForKey: @"WinUIThemeOverlayScrollbars"];
    }
  if ([[(WinUITheme *)theme settings] highContrastEnabled])
    {
      return NO;
    }
  return [[(WinUITheme *)theme settings] dynamicScrollbarsEnabled];
}

/* A scroll view's overlay scrollers: shown how much, the pointer over
   which, when to start fading. */
@interface WinUIThemeOverlayState : NSObject
{
@public
  NSScrollView *scrollView;     /* Not retained: it holds this. */
  CGFloat alpha;
  NSScroller *hovered;          /* Not retained: a subview of scrollView. */
  NSDate *hideAt;
  NSTimer *timer;
  NSPoint origin;
  BOOL originKnown;
  /* Widening the clip view has libs-gui reflect the scroll and, with
     auto-hiding scrollers, tile again: that nested tile is skipped. */
  BOOL adjusting;
  NSTrackingRectTag tags[2];
}
- (void) reveal;
- (void) redisplay;
- (void) tick: (NSTimer *)timer;
- (void) stopTimer;
@end

/* The fade timer's target. A timer retains its target, so the state
   can't be: it would outlive its scroll view (which holds it) and tick on
   freed views (plugins-themes-Adwaita#38). The state stops the timer and
   lets go of this when it goes. */
@interface WinUIThemeOverlayTicker : NSObject
{
@public
  WinUIThemeOverlayState *state;        /* Not retained. */
}
@end

@implementation WinUIThemeOverlayTicker

- (void) tick: (NSTimer *)timer
{
  [state tick: timer];
}

@end

static WinUIThemeOverlayState *
WinUIThemeOverlayStateFor(NSScrollView *scrollView, BOOL create)
{
  WinUIThemeOverlayState *state = objc_getAssociatedObject(scrollView, &WinUIThemeOverlayStateKey);

  if (state == nil && create)
    {
      state = AUTORELEASE([WinUIThemeOverlayState new]);
      state->scrollView = scrollView;
      objc_setAssociatedObject(scrollView, &WinUIThemeOverlayStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  return state;
}

@implementation WinUIThemeOverlayState

- (void) dealloc
{
  [self stopTimer];
  RELEASE(hideAt);
  [super dealloc];
}

- (void) stopTimer
{
  if (timer != nil)
    {
      WinUIThemeOverlayTicker *ticker = [timer userInfo];

      ticker->state = nil;
      [timer invalidate];
      DESTROY(timer);
    }
}

/* The scrollers' strips, redrawn from the scroll view: they aren't
   opaque, and what's under them has to be drawn first. */
- (void) redisplay
{
  NSScroller *scrollers[2] = { [scrollView verticalScroller], [scrollView horizontalScroller] };
  int i;

  for (i = 0; i < 2; i++)
    {
      if (scrollers[i] != nil && [scrollers[i] superview] == scrollView && [scrollers[i] isHidden] == NO)
        {
          [scrollView setNeedsDisplayInRect: [scrollers[i] frame]];
        }
    }
}

- (void) startTimer
{
  if (timer == nil)
    {
      WinUIThemeOverlayTicker *ticker = AUTORELEASE([WinUIThemeOverlayTicker new]);

      ticker->state = self;
      timer = RETAIN([NSTimer timerWithTimeInterval: WinUIThemeOverlayStep
                                             target: ticker
                                           selector: @selector(tick:)
                                           userInfo: ticker
                                            repeats: YES]);
      [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSDefaultRunLoopMode];
      [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSEventTrackingRunLoopMode];
      [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
    }
}

- (void) reveal
{
  ASSIGN(hideAt, [NSDate dateWithTimeIntervalSinceNow: WinUIThemeOverlayLinger]);
  if (alpha < 1.0)
    {
      alpha = 1.0;
      [self redisplay];
    }
  [self startTimer];
}

- (void) tick: (NSTimer *)aTimer
{
  NSTimeInterval left = [hideAt timeIntervalSinceNow];

  /* Kept while the pointer is over a scroller or its thumb is dragged. */
  if (hovered != nil || [[scrollView verticalScroller] hitPart] == NSScrollerKnob
      || [[scrollView horizontalScroller] hitPart] == NSScrollerKnob)
    {
      ASSIGN(hideAt, [NSDate dateWithTimeIntervalSinceNow: WinUIThemeOverlayLinger]);
      return;
    }
  if (left > 0.0)
    {
      return;
    }
  alpha = MAX(0.0, 1.0 + left / WinUIThemeOverlayFade);
  [self redisplay];
  if (alpha <= 0.0)
    {
      [self stopTimer];
    }
}

@end

static BOOL
WinUIThemeScrollerIsHorizontal(NSScroller *scroller)
{
  NSRect bounds = [scroller bounds];

  return NSWidth(bounds) >= NSHeight(bounds);
}

/* A filled triangle pointing up, down, left or right, about 8px across:
   the scroll bar's arrow glyphs. */
static void
WinUIThemeDrawScrollArrow(NSRect rect, BOOL horizontal, BOOL increment, BOOL flipped, NSColor *color)
{
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSPoint center = NSMakePoint(floor(NSMidX(rect)) + 0.5, floor(NSMidY(rect)) + 0.5);
  CGFloat half = 3.5;
  CGFloat depth = 2.5;

  if (horizontal)
    {
      CGFloat direction = increment ? 1.0 : -1.0;

      [path moveToPoint: NSMakePoint(center.x + direction * depth, center.y)];
      [path lineToPoint: NSMakePoint(center.x - direction * depth, center.y - half)];
      [path lineToPoint: NSMakePoint(center.x - direction * depth, center.y + half)];
    }
  else
    {
      /* Increment is down the screen. */
      CGFloat direction = (increment == flipped) ? 1.0 : -1.0;

      [path moveToPoint: NSMakePoint(center.x, center.y + direction * depth)];
      [path lineToPoint: NSMakePoint(center.x - half, center.y - direction * depth)];
      [path lineToPoint: NSMakePoint(center.x + half, center.y - direction * depth)];
    }
  [path closePath];
  [color set];
  [path fill];
}

/* A scroll bar at `alpha`: the 2px indicator, or expanded, the track,
   thumb and arrows. `background` is the track's colour expanded, or nil
   for none (always-shown bars sit on the scroll view's rail). */
static void
WinUIThemeDrawScrollBar(WinUITheme *theme, NSScroller *scroller, CGFloat alpha, BOOL expanded,
                        NSColor *background)
{
  NSRect bounds = [scroller bounds];
  BOOL horizontal = WinUIThemeScrollerIsHorizontal(scroller);
  BOOL dark = [[theme settings] prefersDarkAppearance];
  BOOL highContrast = [[theme settings] highContrastEnabled];
  NSScrollerPart hit = [scroller hitPart];
  BOOL dragging = (hit == NSScrollerKnob);
  NSColor *ink = highContrast
    ? WinUIThemeColorFromTheme(theme, @"labelColor", [NSColor controlTextColor])
    : (dark ? [NSColor whiteColor] : [NSColor blackColor]);
  /* ControlStrongFillColorDefault: black at 45%, white at 54%. */
  CGFloat strong = highContrast ? 1.0 : (dark ? 0.544 : 0.446);
  NSRect knob = [scroller rectForPart: NSScrollerKnob];
  NSRect decrement = [scroller rectForPart: NSScrollerDecrementLine];
  NSRect increment = [scroller rectForPart: NSScrollerIncrementLine];
  BOOL scrollable = ([scroller isEnabled] && [scroller knobProportion] < 0.999 && NSIsEmptyRect(knob) == NO);
  CGFloat thickness = expanded ? 6.0 : 2.0;
  NSRect thumb;

  if (alpha <= 0.0)
    {
      return;
    }

  if (expanded && background != nil)
    {
      CGFloat radius = MIN(6.0, MIN(NSWidth(bounds), NSHeight(bounds)) / 2.0);

      [[background colorWithAlphaComponent: [background alphaComponent] * alpha] set];
      [WinUIThemeRoundedPath(NSInsetRect(bounds, 1.0, 1.0), radius) fill];
    }
  if (scrollable == NO)
    {
      return;
    }

  if (horizontal)
    {
      CGFloat y = expanded ? floor(NSMidY(bounds) - thickness / 2.0)
                           : ([scroller isFlipped] ? NSMaxY(bounds) - 3.0 - thickness : NSMinY(bounds) + 3.0);

      thumb = NSMakeRect(NSMinX(knob) + 2.0, y, MAX(thickness, NSWidth(knob) - 4.0), thickness);
    }
  else
    {
      CGFloat x = expanded ? floor(NSMidX(bounds) - thickness / 2.0) : NSMaxX(bounds) - 3.0 - thickness;

      thumb = NSMakeRect(x, NSMinY(knob) + 2.0, thickness, MAX(thickness, NSHeight(knob) - 4.0));
    }
  [[ink colorWithAlphaComponent: MIN(1.0, strong * (dragging ? 1.3 : 1.0)) * alpha] set];
  [WinUIThemeRoundedPath(thumb, thickness / 2.0) fill];

  if (expanded)
    {
      if (NSIsEmptyRect(decrement) == NO)
        {
          WinUIThemeDrawScrollArrow(decrement, horizontal, NO, [scroller isFlipped],
                                    [ink colorWithAlphaComponent:
                                      MIN(1.0, strong * (hit == NSScrollerDecrementLine ? 1.3 : 1.0)) * alpha]);
        }
      if (NSIsEmptyRect(increment) == NO)
        {
          WinUIThemeDrawScrollArrow(increment, horizontal, YES, [scroller isFlipped],
                                    [ink colorWithAlphaComponent:
                                      MIN(1.0, strong * (hit == NSScrollerIncrementLine ? 1.3 : 1.0)) * alpha]);
        }
    }
}

/* Tracking rects on the scrollers' strips (whose presses the scrollers
   take only while shown): the pointer reveals and expands them. Owned by
   the scroll view, so they go with it. */
static void
WinUIThemeUpdateOverlayTracking(NSScrollView *scrollView, WinUIThemeOverlayState *state)
{
  NSScroller *scrollers[2] = { [scrollView verticalScroller], [scrollView horizontalScroller] };
  BOOL has[2] = { [scrollView hasVerticalScroller], [scrollView hasHorizontalScroller] };
  int i;

  for (i = 0; i < 2; i++)
    {
      if (state->tags[i] != 0)
        {
          [scrollView removeTrackingRect: state->tags[i]];
          state->tags[i] = 0;
        }
      if ([scrollView window] != nil && has[i] && scrollers[i] != nil && [scrollers[i] isHidden] == NO)
        {
          state->tags[i] = [scrollView addTrackingRect: [scrollers[i] frame]
                                                 owner: scrollView
                                              userData: (void *)scrollers[i]
                                          assumeInside: NO];
        }
    }
}

@implementation WinUITheme (Scrollers)

/* Always-shown scroll bars (and scrollers outside scroll views): expanded,
   on the strip's rail. */
- (void) drawScrollerRect: (NSRect)rect
                   inView: (NSView *)view
                  hitPart: (NSScrollerPart)hitPart
             isHorizontal: (BOOL)isHorizontal
{
  (void)hitPart;
  (void)isHorizontal;

  [WinUIThemeColorFromTheme(self, @"surfaceColor", [NSColor controlBackgroundColor]) set];
  NSRectFill(rect);
  WinUIThemeDrawScrollBar(self, (NSScroller *)view, 1.0, YES, nil);
}

@end

@implementation WinUITheme (ScrollerOverrides)

- (void) _overrideNSScrollViewMethod_tile
{
  typedef void (*TileIMP)(id, SEL);
  TileIMP originalIMP = (TileIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScrollView class]);
  NSScrollView *scrollView = (NSScrollView *)self;
  NSClipView *clip;
  NSRect content;
  NSScroller *vertical, *horizontal;
  id documentView;
  WinUIThemeOverlayState *state = WinUIThemeOverlayStateFor(scrollView, NO);

  WinUIThemeSyncBrowserColumn(scrollView);

  if (state != nil && state->adjusting)
    {
      return;
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }
  if (WinUIThemeUsesOverlayScrollers() == NO)
    {
      return;
    }
  state = WinUIThemeOverlayStateFor(scrollView, YES);
  state->adjusting = YES;
  clip = [scrollView contentView];
  content = [clip frame];
  vertical = [scrollView hasVerticalScroller] ? [scrollView verticalScroller] : nil;
  horizontal = [scrollView hasHorizontalScroller] ? [scrollView horizontalScroller] : nil;
  if (vertical != nil && [vertical superview] == scrollView)
    {
      NSRect strip = [vertical frame];

      content = NSUnionRect(content, NSMakeRect(NSMinX(strip), NSMinY(content), NSWidth(strip), NSHeight(content)));
    }
  if (horizontal != nil && [horizontal superview] == scrollView)
    {
      NSRect strip = [horizontal frame];

      content = NSUnionRect(content, NSMakeRect(NSMinX(content), NSMinY(strip), NSWidth(content), NSHeight(strip)));
    }
  /* Inside the scroll view's border. */
  if ([scrollView borderType] != NSNoBorder)
    {
      content = NSIntersectionRect(content, NSInsetRect([scrollView bounds], 1.0, 1.0));
    }
  if (NSEqualRects(content, [clip frame]) == NO)
    {
      [clip setFrame: content];
    }
  [clip setCopiesOnScroll: NO];
  /* A table's header runs as wide as its rows. */
  documentView = [scrollView documentView];
  if ([documentView respondsToSelector: @selector(headerView)])
    {
      NSView *headerClip = [[documentView headerView] superview];

      if ([headerClip superview] == scrollView)
        {
          NSRect header = [headerClip frame];

          header.origin.x = NSMinX(content);
          header.size.width = NSWidth(content);
          [headerClip setFrame: header];
        }
    }
  /* Above the content they overlap. */
  if (vertical != nil && [vertical superview] == scrollView && [[scrollView subviews] lastObject] != vertical)
    {
      RETAIN(vertical);
      [vertical removeFromSuperviewWithoutNeedingDisplay];
      [scrollView addSubview: vertical];
      RELEASE(vertical);
    }
  /* The horizontal one just below the vertical one, or on top without
     it. Without a vertical scroller in the view (nil, or kept after
     -setHasVerticalScroller: NO), "below" it meant below everything,
     under the clip view, which hid the horizontal scroller. */
  if (horizontal != nil && [horizontal superview] == scrollView && [[scrollView subviews] lastObject] != horizontal)
    {
      BOOL besideVertical = (vertical != nil && [vertical superview] == scrollView);

      if (besideVertical == NO || [[scrollView subviews] lastObject] != vertical)
        {
          RETAIN(horizontal);
          [horizontal removeFromSuperviewWithoutNeedingDisplay];
          if (besideVertical)
            {
              [scrollView addSubview: horizontal positioned: NSWindowBelow relativeTo: vertical];
            }
          else
            {
              [scrollView addSubview: horizontal];
            }
          RELEASE(horizontal);
        }
    }
  state->adjusting = NO;
  WinUIThemeUpdateOverlayTracking(scrollView, state);
}

/* Freed: its overlay state stops its fade timer and forgets it, even
   where the state itself outlives it (plugins-themes-Adwaita#38). */
- (void) _overrideNSScrollViewMethod_dealloc
{
  typedef void (*DeallocIMP)(id, SEL);
  DeallocIMP originalIMP = (DeallocIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScrollView class]);
  WinUIThemeOverlayState *state = objc_getAssociatedObject(self, &WinUIThemeOverlayStateKey);

  if (state != nil)
    {
      [state stopTimer];
      state->scrollView = nil;
      state->hovered = nil;
      objc_setAssociatedObject(self, &WinUIThemeOverlayStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }
}

- (void) _overrideNSScrollViewMethod_viewDidMoveToWindow
{
  typedef void (*MovedIMP)(id, SEL);
  MovedIMP originalIMP = (MovedIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScrollView class]);
  WinUIThemeOverlayState *state;

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd);
    }
  state = WinUIThemeOverlayStateFor((NSScrollView *)self, NO);
  if (state != nil && WinUIThemeUsesOverlayScrollers())
    {
      WinUIThemeUpdateOverlayTracking((NSScrollView *)self, state);
    }
}

/* The content scrolled (by the wheel, the keyboard, the app): show the
   indicator for a while. The first call only records where it is. */
- (void) _overrideNSScrollViewMethod_reflectScrolledClipView: (NSClipView *)clipView
{
  typedef void (*ReflectIMP)(id, SEL, NSClipView *);
  ReflectIMP originalIMP = (ReflectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScrollView class]);
  WinUIThemeOverlayState *state;
  NSPoint origin;

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, clipView);
    }
  if (WinUIThemeUsesOverlayScrollers() == NO)
    {
      return;
    }
  state = WinUIThemeOverlayStateFor((NSScrollView *)self, YES);
  origin = [[(NSScrollView *)self contentView] bounds].origin;
  if (state->originKnown && NSEqualPoints(origin, state->origin) == NO)
    {
      [state reveal];
    }
  state->origin = origin;
  state->originKnown = YES;
}

- (void) _overrideNSScrollViewMethod_mouseEntered: (NSEvent *)event
{
  typedef void (*MouseIMP)(id, SEL, NSEvent *);
  WinUIThemeOverlayState *state = WinUIThemeOverlayStateFor((NSScrollView *)self, NO);

  if (state != nil && [event trackingNumber] != 0
      && ([event trackingNumber] == state->tags[0] || [event trackingNumber] == state->tags[1]))
    {
      state->hovered = (NSScroller *)[event userData];
      [state reveal];
      [state redisplay];
      return;
    }
  {
    MouseIMP originalIMP = (MouseIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScrollView class]);

    if (originalIMP != NULL)
      {
        originalIMP(self, _cmd, event);
      }
  }
}

- (void) _overrideNSScrollViewMethod_mouseExited: (NSEvent *)event
{
  typedef void (*MouseIMP)(id, SEL, NSEvent *);
  WinUIThemeOverlayState *state = WinUIThemeOverlayStateFor((NSScrollView *)self, NO);

  if (state != nil && [event trackingNumber] != 0
      && ([event trackingNumber] == state->tags[0] || [event trackingNumber] == state->tags[1]))
    {
      state->hovered = nil;
      [state reveal];
      [state redisplay];
      return;
    }
  {
    MouseIMP originalIMP = (MouseIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScrollView class]);

    if (originalIMP != NULL)
      {
        originalIMP(self, _cmd, event);
      }
  }
}

/* Over the content: see-through. */
- (BOOL) _overrideNSScrollerMethod_isOpaque
{
  typedef BOOL (*OpaqueIMP)(id, SEL);
  OpaqueIMP originalIMP;

  if ((WinUIThemeUsesOverlayScrollers() && [[(NSView *)self superview] isKindOfClass: [NSScrollView class]])
      || ([[(NSView *)self superview] isKindOfClass: [NSBrowser class]]
          && [[GSTheme theme] isKindOfClass: [WinUITheme class]]))
    {
      return NO;
    }
  originalIMP = (OpaqueIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScroller class]);
  return originalIMP != NULL ? originalIMP(self, _cmd) : YES;
}

/* Hidden, a scroller lets presses through to the content under it. */
- (NSView *) _overrideNSScrollerMethod_hitTest: (NSPoint)point
{
  typedef NSView *(*HitIMP)(id, SEL, NSPoint);
  HitIMP originalIMP = (HitIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScroller class]);
  NSView *superview = [(NSView *)self superview];

  if (WinUIThemeUsesOverlayScrollers() && [superview isKindOfClass: [NSScrollView class]])
    {
      WinUIThemeOverlayState *state = WinUIThemeOverlayStateFor((NSScrollView *)superview, NO);

      if (state == nil || (state->alpha <= 0.0 && state->hovered != (id)self))
        {
          return nil;
        }
    }
  return originalIMP != NULL ? originalIMP(self, _cmd, point) : nil;
}

/* A scroll view's scrollers draw here, enabled or not: overlaid, the
   indicator or the expanded bar at the state's opacity; always shown, the
   expanded bar on its rail. */
- (void) _overrideNSScrollerMethod_drawRect: (NSRect)rect
{
  typedef void (*DrawRectIMP)(id, SEL, NSRect);
  DrawRectIMP originalIMP = (DrawRectIMP)WinUIThemeOriginalMethod(_cmd, self, [NSScroller class]);
  NSScroller *scroller = (NSScroller *)self;
  GSTheme *current = [GSTheme theme];
  WinUITheme *theme = [current isKindOfClass: [WinUITheme class]] ? (WinUITheme *)current : nil;
  NSView *superview = [scroller superview];

  /* NSBrowser's horizontal scroller (#58), shown only when there are
     columns to scroll to: the thin bar, on no rail. */
  if (theme != nil && [superview isKindOfClass: [NSBrowser class]])
    {
      WinUIThemeDrawScrollBar(theme, scroller, 1.0, YES, nil);
      return;
    }
  if (theme == nil || [superview isKindOfClass: [NSScrollView class]] == NO)
    {
      if (originalIMP != NULL)
        {
          originalIMP(self, _cmd, rect);
        }
      return;
    }

  if (WinUIThemeUsesOverlayScrollers())
    {
      WinUIThemeOverlayState *state = WinUIThemeOverlayStateFor((NSScrollView *)superview, NO);
      BOOL expanded = (state != nil && (state->hovered == scroller || [scroller hitPart] != NSScrollerNoPart));
      BOOL dark = [[theme settings] prefersDarkAppearance];
      /* AcrylicBackgroundFillColorDefault's fallback, nearly opaque. */
      NSColor *track = WinUIThemeColorWithAlpha(WinUIThemeColorFromTheme(theme, @"menuBackgroundColor",
                                                                         [NSColor controlBackgroundColor]),
                                                dark ? 0.96 : 0.94);

      WinUIThemeDrawScrollBar(theme, scroller, state != nil ? state->alpha : 0.0, expanded, track);
      return;
    }

  /* Where scroll bars are always shown (high contrast), a browser
     column's shows only when its rows overflow, as a WinUI list's (#58).
     -setAutohidesScrollers: would re-tile the column into a loop. The
     scroller's state doesn't tell (enabled, proportion 0): the rows'
     height against the column's does. */
  if (WinUIThemeIsBrowserColumn(superview)
      && NSHeight([[(NSScrollView *)superview documentView] frame])
         <= [(NSScrollView *)superview contentSize].height + 0.5)
    {
      [WinUIThemeBrowserCardColor(theme) set];
      NSRectFill(rect);
      return;
    }
  [theme drawScrollerRect: rect inView: scroller hitPart: [scroller hitPart]
             isHorizontal: WinUIThemeScrollerIsHorizontal(scroller)];
}

@end
