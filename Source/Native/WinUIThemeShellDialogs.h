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
#import "../WinUITheme.h"

@interface WinUIThemeSavePanel : NSSavePanel
@end

@interface WinUIThemeOpenPanel : NSOpenPanel
@end

@interface WinUIThemePrintPanel : GSPrintPanel
@end

@interface WinUIThemePageLayout : GSPageLayout
@end

/* The type filters the native Open and Save dialogs offer (#76), for
   QuirkProbe, which reaches it by name. `request` holds "types" (the
   allowed file types), "saving" and "allowsOtherFileTypes" (NSNumbers) and
   "fileName" (a save panel's suggested name). The answer holds "filters",
   dictionaries of "name" and "pattern" in the dialog's order, and
   "selectedIndex", the one selected (from 0). */
@interface WinUITheme (FileDialogFilters)
+ (NSDictionary *) fileDialogFilters: (NSDictionary *)request;
@end

#endif
