#import "WinUIThemeDrawing.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

/* Menu tracking as on Windows: a click on a menu bar title, a pop-up button
   or a context menu opens the menu, which stays open after the click's
   release; a click on an item picks it; press, drag and release onto an
   item picks it too; a press outside the menus closes them and goes
   nowhere else; Escape closes them. Adapted from the Adwaita theme.

   libs-gui master (a84b42471) ignores the opening click's release itself.
   In gui 0.32 any release ends menu tracking (82717eefe), so a click
   opened a menu and closed it again; there the theme drops that release
   while the pointer is still on the item it started on. Master, which has
   -[NSImage isTemplate] (added after a84b42471, not in 0.32), is left to
   do it itself. */

@interface NSMenu (WinUIThemeMenuTrackingPrivate)
- (BOOL) _ownedByPopUp;
@end

/* The menu view tracking (innermost), the item the press started on, and
   whether that press's release is still to be dropped. */
static NSMenuView *WinUIThemeTrackingMenuView = nil;
static NSInteger WinUIThemeTrackingFirstIndex = -1;
static BOOL WinUIThemeTrackingIgnoresRelease = NO;

/* The outermost menu view tracking, and whether the release of a press
   that closed the menus is still to come. */
static NSMenuView *WinUIThemeTrackingRootView = nil;
static BOOL WinUIThemeDropNextRelease = NO;

/* Ends menu tracking without running an item: with nothing highlighted, a
   mouse up ends it. Two are posted: gui 0.32 stops at the first, while
   master ignores a first release when the pointer hasn't left the first
   item; a spare release does nothing. They carry no window, which tells
   them from the user's. */
static BOOL WinUIThemeMenuDismissed = NO;
/* Posted releases not yet fetched: one is left over when the first ends
   tracking, and is dropped rather than reach the next menu or a window. */
static NSUInteger WinUIThemeSpareReleases = 0;
/* Each outermost menu tracking, and the one the spares were posted for. */
static NSUInteger WinUIThemeTrackingSession = 0;
static NSUInteger WinUIThemeSpareSession = 0;

static void
WinUIThemeEndMenuTracking(NSMenu *menu, NSTimeInterval timestamp)
{
  NSEvent *release = nil;

  WinUIThemeMenuDismissed = YES;
  while (menu != nil)
    {
      [[menu menuRepresentation] setHighlightedItemIndex: -1];
      menu = [menu attachedMenu];
    }
  release = [NSEvent mouseEventWithType: NSLeftMouseUp
                               location: NSZeroPoint
                          modifierFlags: 0
                              timestamp: timestamp
                           windowNumber: 0
                                context: nil
                            eventNumber: 0
                             clickCount: 1
                               pressure: 0.0];
  [NSApp postEvent: release atStart: YES];
  [NSApp postEvent: release atStart: NO];
  WinUIThemeSpareReleases = 2;
  WinUIThemeSpareSession = WinUIThemeTrackingSession;
}

/* Escape closes a menu, as on Windows. GNUstep's menu tracking ignores
   keys, so a timer in the tracking mode looks for it. Other keys stay
   queued for the window. */
@interface WinUIThemeMenuEscape : NSObject
+ (void) closeMenuOnEscape: (NSTimer *)timer;
@end

@implementation WinUIThemeMenuEscape

+ (void) closeMenuOnEscape: (NSTimer *)timer
{
  NSEvent *key = [NSApp nextEventMatchingMask: NSKeyDownMask
                                    untilDate: [NSDate distantPast]
                                       inMode: NSEventTrackingRunLoopMode
                                      dequeue: NO];
  NSMenu *menu = [timer userInfo];

  if (key == nil
      || [[key charactersIgnoringModifiers] isEqualToString:
           [NSString stringWithFormat: @"%C", (unichar)0x1b]] == NO)
    {
      return;
    }
  [NSApp nextEventMatchingMask: NSKeyDownMask
                     untilDate: [NSDate distantPast]
                        inMode: NSEventTrackingRunLoopMode
                       dequeue: YES];
  WinUIThemeEndMenuTracking(menu, [key timestamp]);
  [timer invalidate];
}

@end

static BOOL
WinUIThemeEventIsOutsideMenus(NSEvent *event)
{
  NSWindow *window = [event window];
  NSPoint point = (window != nil)
    ? [window convertBaseToScreen: [event locationInWindow]]
    : [event locationInWindow];
  NSMenuView *root = WinUIThemeTrackingRootView;
  NSMenu *menu = [root menu];

  if ([root isHorizontal])
    {
      NSRect bar = [root convertRect: [root bounds] toView: nil];

      bar.origin = [[root window] convertBaseToScreen: bar.origin];
      if (NSPointInRect(point, bar))
        {
          return NO;
        }
      menu = [menu attachedMenu];
    }
  while (menu != nil)
    {
      NSWindow *menuWindow = [[menu menuRepresentation] window];

      if (menuWindow != nil && [menuWindow isVisible]
          && NSPointInRect(point, [menuWindow frame]))
        {
          return NO;
        }
      menu = [menu attachedMenu];
    }
  return YES;
}

static BOOL
WinUIThemeMenuTrackingEndsOnFirstRelease(void)
{
  static int ends = -1;

  if (ends < 0)
    {
      ends = [NSImage instancesRespondToSelector: @selector(isTemplate)] ? 0 : 1;
    }
  return ends == 1;
}

/* The item under an event in the tracking menu view: where the event is
   when it's in that view's window, else where the pointer is. */
static NSInteger
WinUIThemeTrackingIndexForEvent(NSEvent *event)
{
  NSMenuView *menuView = WinUIThemeTrackingMenuView;
  NSWindow *window = [menuView window];
  NSPoint location = (event != nil && [event window] == window)
    ? [event locationInWindow]
    : [window mouseLocationOutsideOfEventStream];

  return [menuView indexOfItemAtPoint: [menuView convertPoint: location fromView: nil]];
}

static BOOL
WinUIThemeMenuIsOwnedByPopUp(NSMenu *menu)
{
  return [menu respondsToSelector: @selector(_ownedByPopUp)]
    && [menu _ownedByPopUp];
}

@implementation WinUITheme (MenuTracking)

/* While a menu tracks: a press, or the pointer onto another item, is
   something happening, and the release after it ends tracking as usual;
   in 0.32 a release still on the first item is dropped. A press outside
   the menus closes them. */
- (NSEvent *) _overrideNSApplicationMethod_nextEventMatchingMask: (NSUInteger)mask
                                                       untilDate: (NSDate *)expiration
                                                          inMode: (NSString *)mode
                                                         dequeue: (BOOL)flag
{
  typedef NSEvent *(*NextIMP)(id, SEL, NSUInteger, NSDate *, NSString *, BOOL);
  NextIMP originalIMP = (NextIMP)WinUIThemeOriginalMethod(_cmd, self, [NSApplication class]);
  NSEvent *event = originalIMP(self, _cmd, mask, expiration, mode, flag);

  while (event != nil && flag)
    {
      NSEventType type = [event type];

      if (WinUIThemeSpareReleases > 0 && type == NSLeftMouseUp && [event windowNumber] == 0)
        {
          WinUIThemeSpareReleases--;
          if (WinUIThemeTrackingRootView == nil
              || WinUIThemeSpareSession != WinUIThemeTrackingSession)
            {
              event = originalIMP(self, _cmd, mask, expiration, mode, flag);
              continue;
            }
          break;
        }
      if (WinUIThemeDropNextRelease && [event windowNumber] != 0
          && (type == NSLeftMouseUp || type == NSRightMouseUp || type == NSOtherMouseUp))
        {
          WinUIThemeDropNextRelease = NO;
          event = originalIMP(self, _cmd, mask, expiration, mode, flag);
          continue;
        }
      if (WinUIThemeTrackingRootView != nil
          && (type == NSLeftMouseDown || type == NSRightMouseDown || type == NSOtherMouseDown)
          && WinUIThemeEventIsOutsideMenus(event))
        {
          WinUIThemeTrackingIgnoresRelease = NO;
          WinUIThemeDropNextRelease = YES;
          WinUIThemeEndMenuTracking([WinUIThemeTrackingRootView menu], [event timestamp]);
          event = originalIMP(self, _cmd, mask, expiration, mode, flag);
          continue;
        }
      break;
    }
  while (WinUIThemeTrackingIgnoresRelease && event != nil && flag)
    {
      NSEventType type = [event type];

      if (type == NSLeftMouseDown || type == NSRightMouseDown || type == NSOtherMouseDown)
        {
          WinUIThemeTrackingIgnoresRelease = NO;
        }
      else if (type == NSPeriodic || type == NSLeftMouseDragged || type == NSRightMouseDragged
               || type == NSOtherMouseDragged || type == NSMouseMoved)
        {
          if (WinUIThemeTrackingIndexForEvent(event) != WinUIThemeTrackingFirstIndex)
            {
              WinUIThemeTrackingIgnoresRelease = NO;
            }
        }
      else if (type == NSLeftMouseUp || type == NSRightMouseUp || type == NSOtherMouseUp)
        {
          WinUIThemeTrackingIgnoresRelease = NO;
          if (WinUIThemeTrackingIndexForEvent(event) == WinUIThemeTrackingFirstIndex)
            {
              event = originalIMP(self, _cmd, mask, expiration, mode, flag);
              continue;
            }
        }
      break;
    }
  return event;
}

/* Pop-up buttons get the menu bar's treatment: libs-gui master then
   ignores the release of the click that opened the menu (in 0.32 the
   theme drops it, above). */
- (BOOL) doesProcessEventsForPopUpMenu
{
  return YES;
}

/* The menu bar's, context and pop-up buttons' menus in Windows 95 style:
   Escape closes them, and in 0.32 the opening click's release is dropped. */
- (BOOL) _overrideNSMenuViewMethod_trackWithEvent: (NSEvent *)event
{
  typedef BOOL (*TrackIMP)(id, SEL, NSEvent *);
  TrackIMP originalIMP = (TrackIMP)WinUIThemeOriginalMethod(_cmd, self, [NSMenuView class]);
  NSMenuView *menuView = (NSMenuView *)self;
  NSMenuView *outerView = WinUIThemeTrackingMenuView;
  NSMenuView *outerRoot = WinUIThemeTrackingRootView;
  NSInteger outerIndex = WinUIThemeTrackingFirstIndex;
  BOOL outerIgnores = WinUIThemeTrackingIgnoresRelease;
  NSTimer *escape = nil;
  BOOL result = NO;

  if (originalIMP == NULL)
    {
      return NO;
    }
  if (NSInterfaceStyleForKey(@"NSMenuInterfaceStyle", menuView) != NSWindows95InterfaceStyle
      || ([menuView isHorizontal] == NO
          && [[menuView menu] isTransient] == NO
          && WinUIThemeMenuIsOwnedByPopUp([menuView menu]) == NO))
    {
      return originalIMP(self, _cmd, event);
    }

  escape = [NSTimer timerWithTimeInterval: 0.05
                                   target: [WinUIThemeMenuEscape class]
                                 selector: @selector(closeMenuOnEscape:)
                                 userInfo: [menuView menu]
                                  repeats: YES];
  [[NSRunLoop currentRunLoop] addTimer: escape forMode: NSEventTrackingRunLoopMode];
  if (outerRoot == nil)
    {
      WinUIThemeTrackingRootView = menuView;
      WinUIThemeMenuDismissed = NO;
      WinUIThemeTrackingSession++;
    }
  if (WinUIThemeMenuTrackingEndsOnFirstRelease())
    {
      WinUIThemeTrackingMenuView = menuView;
      WinUIThemeTrackingFirstIndex = WinUIThemeTrackingIndexForEvent(event);
      WinUIThemeTrackingIgnoresRelease = YES;
    }

  NS_DURING
    {
      result = originalIMP(self, _cmd, event);
    }
  NS_HANDLER
    {
      [escape invalidate];
      WinUIThemeTrackingRootView = outerRoot;
      WinUIThemeTrackingMenuView = outerView;
      WinUIThemeTrackingFirstIndex = outerIndex;
      WinUIThemeTrackingIgnoresRelease = outerIgnores;
      [localException raise];
    }
  NS_ENDHANDLER

  [escape invalidate];
  /* Dismissed by Escape or a press outside: master leaves the menu bar's
     menu attached when the pointer isn't on the bar; close it. */
  if (outerRoot == nil && WinUIThemeMenuDismissed && [menuView isHorizontal])
    {
      [menuView setHighlightedItemIndex: -1];
      [[[menuView menu] attachedMenu] close];
    }
  WinUIThemeTrackingRootView = outerRoot;
  WinUIThemeTrackingMenuView = outerView;
  WinUIThemeTrackingFirstIndex = outerIndex;
  WinUIThemeTrackingIgnoresRelease = outerIgnores;
  return result;
}

@end
