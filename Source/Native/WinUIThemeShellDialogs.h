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

#ifndef GNUstep_WINUITHEME_SHELLDIALOGS_H
#define GNUstep_WINUITHEME_SHELLDIALOGS_H

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

@interface WinUIThemeSavePanel : NSSavePanel
@end

@interface WinUIThemeOpenPanel : NSOpenPanel
@end

@interface WinUIThemePrintPanel : GSPrintPanel
@end

@interface WinUIThemePageLayout : GSPageLayout
@end

#endif
