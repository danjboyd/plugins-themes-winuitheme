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

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

/* Pointer-over state for controls, for WinUI's PointerOver visual states.
   libs-gui registers no tracking rects for buttons, so the theme adds one
   the first time a control is drawn (and again when its size changes; the
   rect is in view coordinates, so moves don't matter) and records enter
   and exit events. (The window's -mouseLocationOutsideOfEventStream goes
   stale at draw time.) */

static char WinUIThemeHoverTagKey;
static char WinUIThemeHoverSizeKey;
static char WinUIThemeHoverKey;

@interface WinUIThemeHoverTracker : NSObject
+ (WinUIThemeHoverTracker *) sharedTracker;
@end

@implementation WinUIThemeHoverTracker

+ (WinUIThemeHoverTracker *) sharedTracker
{
  static WinUIThemeHoverTracker *tracker = nil;

  if (tracker == nil)
    {
      tracker = [WinUIThemeHoverTracker new];
    }
  return tracker;
}

- (void) setHover: (BOOL)hover forEvent: (NSEvent *)event
{
  NSView *view = (NSView *)[event userData];

  if (view == nil)
    {
      return;
    }
  objc_setAssociatedObject(view, &WinUIThemeHoverKey,
                           hover ? [NSNumber numberWithBool: YES] : nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [view setNeedsDisplay: YES];
}

- (void) mouseEntered: (NSEvent *)event
{
  [self setHover: YES forEvent: event];
}

- (void) mouseExited: (NSEvent *)event
{
  [self setHover: NO forEvent: event];
}

@end

void
WinUIThemeTrackHover(NSView *view)
{
  NSNumber *tag = nil;
  NSValue *size = nil;
  NSSize bounds;

  if (view == nil || [view window] == nil)
    {
      return;
    }
  bounds = [view bounds].size;
  size = objc_getAssociatedObject(view, &WinUIThemeHoverSizeKey);
  if (size != nil && NSEqualSizes([size sizeValue], bounds))
    {
      return;
    }
  tag = objc_getAssociatedObject(view, &WinUIThemeHoverTagKey);
  if (tag != nil)
    {
      [view removeTrackingRect: [tag integerValue]];
    }
  tag = [NSNumber numberWithInteger: [view addTrackingRect: [view bounds]
                                                     owner: [WinUIThemeHoverTracker sharedTracker]
                                                  userData: view
                                              assumeInside: NO]];
  objc_setAssociatedObject(view, &WinUIThemeHoverTagKey, tag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(view, &WinUIThemeHoverSizeKey, [NSValue valueWithSize: bounds],
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/* For a view that learns of the pointer otherwise, as a table does from
   -mouseMoved:. A pointer already inside when the tracking rect was added
   brings no entering, only the exit when it leaves. */
void
WinUIThemeSetViewHovered(NSView *view, BOOL hovered)
{
  if (view == nil || WinUIThemeViewIsHovered(view) == hovered)
    {
      return;
    }
  objc_setAssociatedObject(view, &WinUIThemeHoverKey,
                           hovered ? [NSNumber numberWithBool: YES] : nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

BOOL
WinUIThemeViewIsHovered(NSView *view)
{
  return view != nil && objc_getAssociatedObject(view, &WinUIThemeHoverKey) != nil;
}
