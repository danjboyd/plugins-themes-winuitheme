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

#ifndef GNUstep_WINUITHEMENIBWINDOWS_H
#define GNUstep_WINUITHEMENIBWINDOWS_H

#import <AppKit/AppKit.h>

@class WinUITheme;

/* Compact metrics for the windows an app loads from a nib or Gorm file
   when the app itself has WinUI's (#182): their controls were laid out at
   GNUstep's sizes. */

/* Has NSWindow mark the windows a nib loads (-awakeFromNib). Later calls
   do nothing. */
void WinUIThemeNibWindowsInstall(void);

/* Whether `window` came from a nib in an app with WinUI's metrics. */
BOOL WinUIThemeWindowUsesCompactMetrics(NSWindow *window);

/* Whether `theme`'s compact choices apply: the app has compact metrics,
   or a control in a compact window is drawing. */
BOOL WinUIThemeCompactMetricsInEffect(WinUITheme *theme);

/* Bracket a control's drawing, so the theme's choices made while it draws
   follow its window's metrics. */
void WinUIThemeBeginDrawingInView(NSView *view);
void WinUIThemeEndDrawingInView(NSView *view);

#endif
