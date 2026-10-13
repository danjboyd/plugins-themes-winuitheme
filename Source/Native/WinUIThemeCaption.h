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

#ifndef GNUstep_WINUITHEME_CAPTION_H
#define GNUstep_WINUITHEME_CAPTION_H

#import <AppKit/AppKit.h>

@class GSWindowDecorationView;

/* The title bar a WinUI app draws (#83): with a libs-back that leaves the
   caption to the gui (GSBackClientDrawsCaptions, danjboyd/libs-back's
   win32-client-caption), the theme draws each titled window's caption row
   (the app's icon, the title, WinUI's 46x32 caption buttons) at the top of
   the client area, and tells the backend which parts drag the window and
   which are the buttons. With any other backend Windows keeps its caption. */

/* Whether the backend leaves the caption of a window with this style to the
   theme. */
BOOL WinUIThemeDrawsCaptionForStyle(NSUInteger style);

/* The caption row's height, which the decoration view keeps above the
   menu bar. */
CGFloat WinUIThemeCaptionHeight(void);

/* Lays the caption row out at the top of a decoration view (after the
   decoration view's own layout) and tells the backend its regions. */
void WinUIThemeCaptionLayout(GSWindowDecorationView *decoration, NSWindow *window,
                             int windowNumber);

/* Redraws the caption (the window's title or key state changed). */
void WinUIThemeCaptionSetNeedsDisplay(GSWindowDecorationView *decoration);

/* The tab strip's colour and its foot line, for a caption holding the
   window's tabs (#83; WinUIThemeWindowTabs.m). */
NSColor *WinUIThemeWindowTabStripColor(void);
NSColor *WinUIThemeWindowTabFootColor(void);

#endif
