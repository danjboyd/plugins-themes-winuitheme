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

#ifndef GNUstep_WINUITHEME_WINDOWINTEGRATION_H
#define GNUstep_WINUITHEME_WINDOWINTEGRATION_H

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSWindowDecorationView.h>

@class WinUITheme;

@interface WinUIThemeBackendWindowDecorationView : GSBackendWindowDecorationView
@end

@interface WinUIThemeStandardWindowDecorationView : GSStandardWindowDecorationView
@end

void WinUIThemeWindowIntegrationActivate(WinUITheme *theme);
void WinUIThemeWindowIntegrationDeactivate(void);
void WinUIThemeWindowIntegrationReloadTheme(WinUITheme *theme);
void WinUIThemeWindowIntegrationSynchronizeWindow(NSWindow *window);
void WinUIThemeWindowIntegrationForgetWindow(NSWindow *window);
void WinUIThemeWindowIntegrationRoundPopupWindow(NSWindow *window, BOOL small, NSColor *borderColor);
/* A popover panel as a WinUI flyout: rounded as a menu, owned by the main
   window and kept out of the taskbar and Alt+Tab (#30). */
void WinUIThemeWindowIntegrationMakeFlyout(NSWindow *window, NSColor *borderColor);

#endif
