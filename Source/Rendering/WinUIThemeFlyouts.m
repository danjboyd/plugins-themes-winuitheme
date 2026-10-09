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
#import "../Native/WinUIThemeWindowIntegration.h"
#import "../Settings/WinUIThemeSettings.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

/* Popover panels as WinUI flyouts (ScreenshotTool #67, #164). GNUstep's
   NSPopover can't become key and draws a fixed panel (libs-gui#988), so
   apps show their popovers in a borderless panel of their own. A panel
   whose class adopts the empty protocol GSThemePopoverPanel asks the theme
   to draw it; the theme says it does with GSThemeDrawsPopoverPanels in its
   Info-gnustep.plist, and the app then leaves the panel's background to
   it. Only marked panels: other borderless windows (lists, drag images,
   notices) keep their own look.

   The flyout is the MenuFlyout's: its layer fill and 1px stroke, 8px
   corners and the shadow from DWM (as the menus, #39), no arrow. On
   Windows it is owned by the main window and kept out of the taskbar and
   Alt+Tab (#30), and it can still become key. */

BOOL
WinUIThemeWindowIsFlyout(NSWindow *window)
{
  /* libobjc2 registers a protocol once something adopts it: apps that
     don't have none to find. */
  Protocol *mark = NSProtocolFromString(@"GSThemePopoverPanel");

  return (window != nil && mark != nil && [window conformsToProtocol: mark]);
}

@implementation WinUITheme (Flyouts)

- (void) drawWindowBackground: (NSRect)frame view: (NSView *)view
{
  NSWindow *window = [view window];
  NSColor *fill = nil;
  NSColor *border = nil;
  NSBezierPath *path = nil;

  if (WinUIThemeWindowIsFlyout(window) == NO)
    {
      [super drawWindowBackground: frame view: view];
      return;
    }

  fill = WinUIThemeColorFromTheme(self, @"menuBackgroundColor", [NSColor controlBackgroundColor]);
  border = WinUIThemeColorFromTheme(self, @"menuBorderColor", [NSColor controlShadowColor]);
  WinUIThemeWindowIntegrationMakeFlyout(window, border);

  /* The whole window: DWM rounds it, as it does the menus' windows. */
  [fill set];
  NSRectFill(frame);
  path = [NSBezierPath bezierPathWithRect: NSInsetRect(NSIntegralRect(frame), 0.5, 0.5)];
  [path setLineWidth: 1.0];
  [border set];
  [path stroke];
}

@end
