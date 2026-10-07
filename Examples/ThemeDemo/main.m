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

#import "TDAppDelegate.h"

int main(int argc, const char **argv)
{
  (void)argc;
  (void)argv;

  @autoreleasepool
    {
      NSApplication *application = [NSApplication sharedApplication];
      TDAppDelegate *delegate = [[TDAppDelegate alloc] init];

      [application setDelegate: delegate];
      [application run];
      [delegate release];
    }

  return 0;
}

