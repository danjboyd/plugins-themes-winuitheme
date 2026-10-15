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
#import "../WinUITheme.h"
#import "../Native/WinUIThemeWindowIntegration.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <objc/runtime.h>

#include <windows.h>

/* Motion (#105). WinUI eases between visual states rather than jumping:
   a control's fills cross-fade when the pointer comes and goes and when
   it's pressed (BrushTransition, 83ms); a toggle switch's knob slides and
   a checkbox's tick draws in; flyouts and menus fade in as they open,
   sliding into place, and dialogs fade in.

   One clock drives it all. A drawing function asks for an animated value
   (WinUIThemeAnimatedValue) with the state it wants to show; while a
   value is on its way, the view is in the clock's set, and each tick marks
   it for display until its values arrive. The clock runs in the modes
   where libs-gui tracks the pointer and runs panels, so menus and button
   presses animate too. A view's first value is shown at once: windows
   open in their final state, not fading from nothing.

   Windows' "Animation effects" setting (SPI_GETCLIENTAREAANIMATION) turns
   it off, as it does WinUI's. The WinUIThemeAnimations default (YES or NO)
   overrides the setting; the probe uses it. */

static const NSTimeInterval WinUIThemeMotionTick = 1.0 / 60.0;

@interface WinUIThemeTransition : NSObject
{
@public
  CGFloat from;
  CGFloat to;
  NSTimeInterval start;
  NSTimeInterval duration;
}
@end

@implementation WinUIThemeTransition
@end

@interface WinUIThemeMotionClock : NSObject
{
  NSMutableDictionary *_ends;
  NSTimer *_timer;
}
+ (WinUIThemeMotionClock *) sharedClock;
- (void) animate: (NSView *)view until: (NSTimeInterval)end;
@end

static NSTimeInterval
WinUIThemeMotionNow(void)
{
  return [NSDate timeIntervalSinceReferenceDate];
}

@implementation WinUIThemeMotionClock

+ (WinUIThemeMotionClock *) sharedClock
{
  static WinUIThemeMotionClock *clock = nil;

  if (clock == nil)
    {
      clock = [WinUIThemeMotionClock new];
    }
  return clock;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _ends = [NSMutableDictionary new];
    }
  return self;
}

/* Views are keyed by pointer and retained until their values arrive. */
- (void) animate: (NSView *)view until: (NSTimeInterval)end
{
  NSValue *key = [NSValue valueWithNonretainedObject: view];
  NSArray *entry = [_ends objectForKey: key];

  if (entry != nil && [[entry objectAtIndex: 1] doubleValue] >= end)
    {
      return;
    }
  [_ends setObject: [NSArray arrayWithObjects: view, [NSNumber numberWithDouble: end], nil]
            forKey: key];
  if (_timer == nil)
    {
      NSRunLoop *loop = [NSRunLoop currentRunLoop];

      _timer = [NSTimer timerWithTimeInterval: WinUIThemeMotionTick
                                       target: self
                                     selector: @selector(tick:)
                                     userInfo: nil
                                      repeats: YES];
      [loop addTimer: _timer forMode: NSDefaultRunLoopMode];
      [loop addTimer: _timer forMode: NSEventTrackingRunLoopMode];
      [loop addTimer: _timer forMode: NSModalPanelRunLoopMode];
      [loop addTimer: _timer forMode: NSRunLoopCommonModes];
    }
}

- (void) tick: (NSTimer *)timer
{
  NSTimeInterval now = WinUIThemeMotionNow();
  NSEnumerator *enumerator = [[_ends allKeys] objectEnumerator];
  NSValue *key = nil;

  while ((key = [enumerator nextObject]) != nil)
    {
      NSArray *entry = [_ends objectForKey: key];
      NSView *view = [entry objectAtIndex: 0];

      [view setNeedsDisplay: YES];
      /* One last frame at the end value, then let the view go. */
      if (now > [[entry objectAtIndex: 1] doubleValue])
        {
          [_ends removeObjectForKey: key];
        }
    }
  if ([_ends count] == 0)
    {
      [_timer invalidate];
      _timer = nil;
    }
}

@end

BOOL
WinUIThemeAnimationsEnabled(void)
{
  id setting = [[NSUserDefaults standardUserDefaults] objectForKey: @"WinUIThemeAnimations"];
  /* Win32's 4-byte BOOL: SystemParametersInfoW writes all of it, and
     Objective-C's 1-byte BOOL here had it overrun the stack. */
  WINBOOL enabled = TRUE;

  if (setting != nil && [setting respondsToSelector: @selector(boolValue)])
    {
      return [setting boolValue];
    }
  if (SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &enabled, 0) == FALSE)
    {
      return YES;
    }
  return enabled ? YES : NO;
}

/* WinUI's decelerating curve for things settling into place
   (ControlFastOutSlowInKeySpline, 0,0,0,1, approximated). */
static CGFloat
WinUIThemeEaseOut(CGFloat t)
{
  CGFloat inverse = 1.0 - t;

  return 1.0 - (inverse * inverse * inverse);
}

CGFloat
WinUIThemeAnimatedValue(NSView *view, const void *key, CGFloat target, NSTimeInterval duration)
{
  WinUIThemeTransition *transition = nil;
  NSTimeInterval now;
  CGFloat t;

  if (view == nil || key == NULL)
    {
      return target;
    }
  transition = objc_getAssociatedObject(view, key);
  if (transition == nil)
    {
      transition = [WinUIThemeTransition new];
      transition->from = target;
      transition->to = target;
      transition->start = 0.0;
      transition->duration = 0.0;
      objc_setAssociatedObject(view, key, transition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      RELEASE(transition);
      return target;
    }

  now = WinUIThemeMotionNow();
  if (transition->to != target)
    {
      CGFloat current = WinUIThemeAnimatedValue(view, key, transition->to, 0.0);

      if (WinUIThemeAnimationsEnabled() == NO || duration <= 0.0 || [view window] == nil)
        {
          transition->from = target;
          transition->duration = 0.0;
        }
      else
        {
          /* Turning back part way runs from where the value is now. */
          transition->from = current;
          transition->duration = duration;
          [[WinUIThemeMotionClock sharedClock] animate: view until: now + duration];
        }
      transition->to = target;
      transition->start = now;
    }

  if (transition->duration <= 0.0)
    {
      return transition->to;
    }
  t = (now - transition->start) / transition->duration;
  if (t >= 1.0)
    {
      transition->duration = 0.0;
      transition->from = transition->to;
      return transition->to;
    }
  return transition->from + (transition->to - transition->from) * WinUIThemeEaseOut(MAX(0.0, t));
}

/* WinUI's ControlFasterAnimationDuration, the brush transitions of a
   control's PointerOver and Pressed states. */
static const NSTimeInterval WinUIThemeStateFadeDuration = 0.083;

static char WinUIThemeHoverAmountKey;
static char WinUIThemePressAmountKey;

CGFloat
WinUIThemeHoverAmount(NSView *view, BOOL hovered)
{
  return WinUIThemeAnimatedValue(view, &WinUIThemeHoverAmountKey, hovered ? 1.0 : 0.0,
                                 WinUIThemeStateFadeDuration);
}

CGFloat
WinUIThemePressAmount(NSView *view, BOOL pressed)
{
  return WinUIThemeAnimatedValue(view, &WinUIThemePressAmountKey, pressed ? 1.0 : 0.0,
                                 WinUIThemeStateFadeDuration);
}

/* ControlFastAnimationDuration: a toggle switch's knob crossing, and a
   checkbox's tick drawing in. */
static const NSTimeInterval WinUIThemeToggleDuration = 0.167;

static char WinUIThemeToggleAmountKey;
static char WinUIThemeCheckAmountKey;

CGFloat
WinUIThemeToggleAmount(NSView *view, BOOL on)
{
  return WinUIThemeAnimatedValue(view, &WinUIThemeToggleAmountKey, on ? 1.0 : 0.0,
                                 WinUIThemeToggleDuration);
}

/* Checking draws the tick in; unchecking takes it away at once. */
CGFloat
WinUIThemeCheckAmount(NSView *view, BOOL checked)
{
  return WinUIThemeAnimatedValue(view, &WinUIThemeCheckAmountKey, checked ? 1.0 : 0.0,
                                 checked ? WinUIThemeToggleDuration : 0.0);
}

/* Fading a window in as it opens: menus and flyouts (WinUI's popup
   theme transition, about 167ms), tool tips and dialogs. The window's
   alpha goes from 0 to 1; libs-back's windows are layered, so this is
   SetLayeredWindowAttributes. Menus and flyouts also slide down into
   place. If the app moves the window meanwhile, the slide gives way.
   A dialog also scales, as WinUI's ContentDialog does: its content from
   105% to 100% about its centre over 250ms, through the content view's
   bounds, while it's opaque after the first third (83ms). The layered
   window's alpha can't scale the window itself. */
@interface WinUIThemeWindowFade : NSObject
{
  NSWindow *_window;
  NSTimeInterval _start;
  NSTimeInterval _duration;
  NSTimer *_timer;
  NSSize _slide;
  NSPoint _target;
  NSPoint _last;
  CGFloat _scaleFrom;
  NSView *_scaled;
  NSRect _bounds;
}
- (id) initWithWindow: (NSWindow *)window
             duration: (NSTimeInterval)duration
                slide: (NSSize)slide;
- (void) scaleContentFrom: (CGFloat)scale;
- (void) scaleTo: (CGFloat)eased;
- (void) finish;
@end

static NSMapTable *WinUIThemeWindowFades = nil;

@implementation WinUIThemeWindowFade

- (id) initWithWindow: (NSWindow *)window
             duration: (NSTimeInterval)duration
                slide: (NSSize)slide
{
  if ((self = [super init]) != nil)
    {
      NSRunLoop *loop = [NSRunLoop currentRunLoop];

      _window = RETAIN(window);
      _start = WinUIThemeMotionNow();
      _duration = duration;
      _timer = [NSTimer timerWithTimeInterval: WinUIThemeMotionTick
                                       target: self
                                     selector: @selector(tick:)
                                     userInfo: nil
                                      repeats: YES];
      [loop addTimer: _timer forMode: NSDefaultRunLoopMode];
      [loop addTimer: _timer forMode: NSEventTrackingRunLoopMode];
      [loop addTimer: _timer forMode: NSModalPanelRunLoopMode];
      [loop addTimer: _timer forMode: NSRunLoopCommonModes];
      [_window setAlphaValue: 0.0];
      if (slide.width != 0.0 || slide.height != 0.0)
        {
          _slide = slide;
          _target = [_window frame].origin;
          _last = NSMakePoint(_target.x + slide.width, _target.y + slide.height);
          [_window setFrameOrigin: _last];
        }
    }
  return self;
}

/* A dialog's content starts at `scale` and settles at its own size. */
- (void) scaleContentFrom: (CGFloat)scale
{
  NSView *content = [_window contentView];

  if (content == nil || scale <= 1.0)
    {
      return;
    }
  _scaleFrom = scale;
  ASSIGN(_scaled, content);
  _bounds = [content bounds];
  [self scaleTo: 0.0];
}

/* The content at the scale `eased` of the way from the start to its own
   size, about its centre. Left alone if the app has changed its bounds or
   frame meanwhile. */
- (void) scaleTo: (CGFloat)eased
{
  CGFloat scale;
  NSRect bounds;

  if (_scaled == nil)
    {
      return;
    }
  if (NSEqualSizes([_scaled frame].size, _bounds.size) == NO)
    {
      DESTROY(_scaled);
      return;
    }
  scale = _scaleFrom + (1.0 - _scaleFrom) * eased;
  bounds.size = NSMakeSize(NSWidth(_bounds) / scale, NSHeight(_bounds) / scale);
  bounds.origin = NSMakePoint(NSMidX(_bounds) - NSWidth(bounds) / 2.0,
                              NSMidY(_bounds) - NSHeight(bounds) / 2.0);
  [_scaled setBounds: (eased >= 1.0) ? _bounds : bounds];
  [_scaled setNeedsDisplay: YES];
}

/* Where the slide has the window at `eased`, unless the app moved it. */
- (void) slideTo: (CGFloat)eased
{
  if (_slide.width == 0.0 && _slide.height == 0.0)
    {
      return;
    }
  if (NSEqualPoints([_window frame].origin, _last) == NO)
    {
      _slide = NSZeroSize;
      return;
    }
  _last = NSMakePoint(round(_target.x + _slide.width * (1.0 - eased)),
                      round(_target.y + _slide.height * (1.0 - eased)));
  [_window setFrameOrigin: _last];
}

- (void) tick: (NSTimer *)timer
{
  CGFloat t = (WinUIThemeMotionNow() - _start) / _duration;

  if (t >= 1.0 || [_window isVisible] == NO)
    {
      [self finish];
      return;
    }
  if (_scaled != nil)
    {
      [_window setAlphaValue: MIN(1.0, MAX(0.0, t) * 3.0)];
      [self scaleTo: WinUIThemeEaseOut(MAX(0.0, t))];
      return;
    }
  [_window setAlphaValue: WinUIThemeEaseOut(MAX(0.0, t))];
  [self slideTo: WinUIThemeEaseOut(MAX(0.0, t))];
}

- (void) finish
{
  NSWindow *window = _window;

  [_timer invalidate];
  _timer = nil;
  if (window != nil)
    {
      [self slideTo: 1.0];
      [self scaleTo: 1.0];
      DESTROY(_scaled);
      _window = nil;
      [window setAlphaValue: 1.0];
      NSMapRemove(WinUIThemeWindowFades, window);
      RELEASE(window);
    }
}

@end

static WinUIThemeWindowFade *
WinUIThemeOpenWindow(NSWindow *window, NSTimeInterval duration, NSSize slide)
{
  WinUIThemeWindowFade *fade = nil;

  if (window == nil || WinUIThemeAnimationsEnabled() == NO || duration <= 0.0)
    {
      return nil;
    }
  if (WinUIThemeWindowFades == nil)
    {
      WinUIThemeWindowFades = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                               NSObjectMapValueCallBacks, 8);
    }
  if (NSMapGet(WinUIThemeWindowFades, window) != NULL)
    {
      return nil;
    }
  fade = [[WinUIThemeWindowFade alloc] initWithWindow: window duration: duration slide: slide];
  NSMapInsert(WinUIThemeWindowFades, window, fade);
  RELEASE(fade);
  return fade;
}

void
WinUIThemeFadeInWindow(NSWindow *window, NSTimeInterval duration)
{
  WinUIThemeOpenWindow(window, duration, NSZeroSize);
}

BOOL
WinUIThemeWindowIsFadingIn(NSWindow *window)
{
  return window != nil && WinUIThemeWindowFades != nil
    && NSMapGet(WinUIThemeWindowFades, window) != NULL;
}

/* A combo box's list (libs-gui's GSComboWindow), which opens as a
   flyout. */
static BOOL
WinUIThemeWindowIsComboListPanel(NSWindow *window)
{
  static Class comboWindowClass = Nil;

  if (comboWindowClass == Nil)
    {
      comboWindowClass = NSClassFromString(@"GSComboWindow");
    }
  return comboWindowClass != Nil && [window isKindOfClass: comboWindowClass];
}

/* The windows that fade in as they open: menus (MenuFlyout), tool tips
   (ToolTip) and the popover panels drawn as flyouts. */
BOOL
WinUIThemeWindowFadesInWhenShown(NSWindow *window)
{
  static Class menuPanelClass = Nil;
  static Class toolTipPanelClass = Nil;

  if (menuPanelClass == Nil)
    {
      menuPanelClass = NSClassFromString(@"NSMenuPanel");
      toolTipPanelClass = NSClassFromString(@"GSTTPanel");
    }
  return (menuPanelClass != Nil && [window isKindOfClass: menuPanelClass])
    || (toolTipPanelClass != Nil && [window isKindOfClass: toolTipPanelClass])
    || WinUIThemeWindowIsFlyout(window) || WinUIThemeWindowIsComboListPanel(window);
}

/* Menus that slide as they open: a menu bar's menus, context menus,
   pop-up lists and flyouts. A submenu doesn't, so it opens beside its
   menu where that menu will stay, even if it's still sliding. */
/* WinUI's popup theme transition, about 167ms, and its distance. */
static const NSTimeInterval WinUIThemeOpenFadeDuration = 0.167;
static const CGFloat WinUIThemeOpenSlideDistance = 8.0;
/* WinUI's ContentDialog opening: 250ms, from 105%. */
static const NSTimeInterval WinUIThemeDialogOpenDuration = 0.25;
static const CGFloat WinUIThemeDialogOpenScale = 1.05;

/* Where a window opening slides in from (#105), as WinUI's popup theme
   transition has it: from the side it opens on, 8pt. A menu from the
   menu bar, or one hanging below the pointer, slides down into place; one
   that opens above the pointer (a context menu or pop-up list near the
   screen's foot) slides up; a submenu slides in from the menu it opens
   beside; a flyout slides down. Tool tips and alerts don't slide. */
static NSSize
WinUIThemeWindowSlideOffset(NSWindow *window)
{
  NSMenu *menu = nil;
  NSMenu *supermenu = nil;
  NSRect frame = [window frame];
  NSPoint pointer = [NSEvent mouseLocation];
  CGFloat distance = WinUIThemeOpenSlideDistance;

  /* A flyout: the pointer doesn't say what it opened from. */
  if (WinUIThemeWindowIsFlyout(window))
    {
      return NSMakeSize(0.0, distance);
    }
  if ([window respondsToSelector: @selector(_menu)] == NO
      && WinUIThemeWindowIsComboListPanel(window) == NO)
    {
      return NSZeroSize;
    }
  menu = [window respondsToSelector: @selector(_menu)] ? [window performSelector: @selector(_menu)] : nil;
  supermenu = [menu supermenu];
  if (supermenu == [NSApp mainMenu] || [[supermenu menuRepresentation] isHorizontal])
    {
      return NSMakeSize(0.0, distance);
    }
  if (supermenu != nil)
    {
      NSWindow *parent = [[supermenu menuRepresentation] window];

      if (parent == nil)
        {
          return NSZeroSize;
        }
      return NSMakeSize(NSMidX(frame) >= NSMidX([parent frame]) ? -distance : distance, 0.0);
    }
  /* Above the pointer, and over it: opened upwards from where it was
     asked for. */
  if (NSMinY(frame) >= pointer.y - 4.0
      && pointer.x >= NSMinX(frame) - 4.0 && pointer.x <= NSMaxX(frame) + 4.0)
    {
      return NSMakeSize(0.0, -distance);
    }
  return NSMakeSize(0.0, distance);
}

/* A context menu opens with its top-left corner at the pointer
   (-[NSMenu displayTransient]), wherever that puts it. As Windows' menus
   and WinUI's MenuFlyout do, one that would run off the screen's right
   edge opens to the left of the pointer, and one that would run off its
   foot opens upwards from it; it then stays on the screen. A context menu
   is a menu panel with no supermenu whose top-left corner is at the
   pointer: pop-up lists and the menu bar's menus are placed elsewhere. */
static void
WinUIThemeFlipContextMenu(NSWindow *window)
{
  static Class menuPanelClass = Nil;
  NSMenu *menu = nil;
  NSRect frame = [window frame];
  NSPoint pointer = [NSEvent mouseLocation];
  NSRect visible;
  NSPoint origin;

  if (menuPanelClass == Nil)
    {
      menuPanelClass = NSClassFromString(@"NSMenuPanel");
    }
  if (menuPanelClass == Nil || [window isKindOfClass: menuPanelClass] == NO
      || [window respondsToSelector: @selector(_menu)] == NO)
    {
      return;
    }
  menu = [window performSelector: @selector(_menu)];
  if (menu == nil || [menu supermenu] != nil || menu == [NSApp mainMenu]
      || fabs(NSMinX(frame) - pointer.x) > 2.0 || fabs(NSMaxY(frame) - pointer.y) > 2.0)
    {
      return;
    }
  visible = [[window screen] visibleFrame];
  if (NSIsEmptyRect(visible))
    {
      visible = [[NSScreen mainScreen] visibleFrame];
    }
  if (NSIsEmptyRect(visible))
    {
      return;
    }
  origin = frame.origin;
  if (NSMaxX(frame) > NSMaxX(visible))
    {
      origin.x = pointer.x - NSWidth(frame);
    }
  if (NSMinY(frame) < NSMinY(visible))
    {
      origin.y = pointer.y;
    }
  origin.x = MAX(NSMinX(visible), MIN(origin.x, NSMaxX(visible) - NSWidth(frame)));
  origin.y = MAX(NSMinY(visible), MIN(origin.y, NSMaxY(visible) - NSHeight(frame)));
  if (NSEqualPoints(origin, frame.origin) == NO)
    {
      [window setFrameOrigin: origin];
    }
}

/* A dialog: an alert, as WinUI's ContentDialog fades in. */
static BOOL
WinUIThemeWindowIsDialog(NSWindow *window)
{
  static Class alertPanelClass = Nil;

  if (alertPanelClass == Nil)
    {
      alertPanelClass = NSClassFromString(@"GSAlertPanel");
    }
  return alertPanelClass != Nil && [window isKindOfClass: alertPanelClass];
}


@implementation WinUITheme (Motion)

typedef void (*OrderWindowIMP)(id, SEL, NSWindowOrderingMode, NSInteger);

/* Panels as they're shown: menus, tool tips, flyouts and alerts open as
   WinUI's do, and menus, tool tips and alerts get the owner and window
   styles Windows' own have (#30). */
- (void) _overrideNSPanelMethod_orderWindow: (NSWindowOrderingMode)place
                                 relativeTo: (NSInteger)otherWin
{
  OrderWindowIMP originalIMP = (OrderWindowIMP)WinUIThemeOriginalMethod(_cmd, self, [NSPanel class]);
  NSWindow *window = (NSWindow *)self;
  BOOL themed = (place != NSWindowOut && [[GSTheme theme] isKindOfClass: [WinUITheme class]]);
  BOOL popup = themed && WinUIThemeWindowFadesInWhenShown(window) && WinUIThemeWindowIsFlyout(window) == NO
    && WinUIThemeWindowIsComboListPanel(window) == NO;
  BOOL dialog = themed && WinUIThemeWindowIsDialog(window);

  if (place != NSWindowOut && [window isVisible] == NO
      && [[GSTheme theme] isKindOfClass: [WinUITheme class]])
    {
      /* Before the slide, which comes from the side it opens on. */
      WinUIThemeFlipContextMenu(window);
      if (WinUIThemeWindowFadesInWhenShown(window))
        {
          WinUIThemeOpenWindow(window, WinUIThemeOpenFadeDuration,
                               WinUIThemeWindowSlideOffset(window));
        }
      else if (WinUIThemeWindowIsDialog(window))
        {
          [WinUIThemeOpenWindow(window, WinUIThemeDialogOpenDuration, NSZeroSize)
            scaleContentFrom: WinUIThemeDialogOpenScale];
        }
    }
  /* Before it shows, so it's never activated; and after, for a deferred
     window, which has no handle until it's first shown. */
  if (popup)
    {
      WinUIThemeWindowIntegrationMakePopup(window);
    }
  else if (dialog)
    {
      WinUIThemeWindowIntegrationOwnDialog(window);
    }
  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, place, otherWin);
    }
  if (popup)
    {
      WinUIThemeWindowIntegrationMakePopup(window);
    }
  else if (dialog)
    {
      WinUIThemeWindowIntegrationOwnDialog(window);
    }
}

typedef void (*SetMaxSizeIMP)(id, SEL, NSSize);

/* libs-back's setmaxsize toggles a window's maximize box (#67). */
- (void) _overrideNSWindowMethod_setMaxSize: (NSSize)size
{
  SetMaxSizeIMP originalIMP = (SetMaxSizeIMP)WinUIThemeOriginalMethod(_cmd, self, [NSWindow class]);

  if (originalIMP != NULL)
    {
      originalIMP(self, _cmd, size);
    }
  if ([[GSTheme theme] isKindOfClass: [WinUITheme class]])
    {
      WinUIThemeWindowIntegrationFixCaptionBoxes((NSWindow *)self);
    }
}

@end
