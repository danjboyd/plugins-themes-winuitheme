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

#import <AppKit/AppKit.h>
#import "QuirkProbe.h"

static NSMenuItem *
QuirkProbeAddMenu(NSMenu *mainMenu, NSString *title, NSMenu **submenuOut)
{
  NSMenuItem *item = (NSMenuItem *)[mainMenu addItemWithTitle: title
                                                       action: NULL
                                                keyEquivalent: @""];
  NSMenu *submenu = [[NSMenu alloc] initWithTitle: title];

  [mainMenu setSubmenu: submenu forItem: item];
  *submenuOut = submenu;
  return item;
}

int
main(int argc, const char *argv[])
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSMenu *mainMenu = nil;
  NSMenu *appMenu = nil;
  NSMenu *servicesMenu = nil;
  NSMenu *fileMenu = nil;
  NSMenu *editMenu = nil;
  NSMenuItem *servicesItem = nil;
  QuirkProbe *probe = nil;

  [NSApplication sharedApplication];

  /* A Cocoa-style main menu, as many apps build theirs: an untitled
     application menu first (About, Preferences, Services, Hide, Quit),
     then File and Edit, and no Help menu. The theme should hand the
     application menu's items to Windows' places
     (checkWindowsMenuConventions). */
  mainMenu = [[NSMenu alloc] initWithTitle: @"QuirkProbe"];
  QuirkProbeAddMenu(mainMenu, @"", &appMenu);
  [appMenu addItemWithTitle: @"About QuirkProbe"
                     action: @selector(orderFrontStandardAboutPanel:)
              keyEquivalent: @""];
  [appMenu addItem: [NSMenuItem separatorItem]];
  [appMenu addItemWithTitle: @"Preferences..."
                     action: @selector(orderFrontPreferencesPanel:)
              keyEquivalent: @","];
  [appMenu addItem: [NSMenuItem separatorItem]];
  servicesItem = (NSMenuItem *)[appMenu addItemWithTitle: @"Services"
                                                  action: NULL
                                           keyEquivalent: @""];
  servicesMenu = [[NSMenu alloc] initWithTitle: @"Services"];
  [appMenu setSubmenu: servicesMenu forItem: servicesItem];
  [NSApp setServicesMenu: servicesMenu];
  [appMenu addItem: [NSMenuItem separatorItem]];
  [appMenu addItemWithTitle: @"Hide QuirkProbe"
                     action: @selector(hide:)
              keyEquivalent: @"h"];
  [appMenu addItemWithTitle: @"Show All"
                     action: @selector(unhideAllApplications:)
              keyEquivalent: @""];
  [appMenu addItem: [NSMenuItem separatorItem]];
  [appMenu addItemWithTitle: @"Quit QuirkProbe"
                     action: @selector(terminate:)
              keyEquivalent: @"q"];

  QuirkProbeAddMenu(mainMenu, @"File", &fileMenu);
  [fileMenu addItemWithTitle: @"Open..." action: NULL keyEquivalent: @"o"];
  QuirkProbeAddMenu(mainMenu, @"Edit", &editMenu);
  [editMenu addItemWithTitle: @"Copy" action: @selector(copy:) keyEquivalent: @"c"];

  [NSApp setAppleMenu: appMenu];
  [NSApp setMainMenu: mainMenu];
  RELEASE(appMenu);
  RELEASE(servicesMenu);
  RELEASE(fileMenu);
  RELEASE(editMenu);
  RELEASE(mainMenu);

  /* NSApp doesn't retain its delegate. */
  probe = [QuirkProbe new];
  [NSApp setDelegate: probe];
  [NSApp run];

  RELEASE(probe);
  [pool drain];
  return 0;
}
