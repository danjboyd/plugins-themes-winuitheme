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

#ifndef GNUstep_WINUITHEME_TOOLBARINMENUBAR_H
#define GNUstep_WINUITHEME_TOOLBARINMENUBAR_H

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSWindowDecorationView.h>

@class GSToolbarView;

/* Single-row chrome (#91): a window's toolbar in its menu bar's row, the
   menu titles first and the toolbar's items after them, as Notepad and
   Paint have one row under the title bar. The app declares it with
   GSThemeToolbarInMenuBar in its Info.plist; a user default for the app
   or for all apps overrides it. */
BOOL WinUIThemeToolbarInMenuBarEnabled(void);

/* WinUIThemeMenuStyle (#130): `menubar` (the default) or `more`. With
   `more` a window's menu bar shows no titles, only its "..." See more
   button (CommandBar's), whose flyout holds the menus, as Edge and File
   Explorer have no menu bar; the toolbar goes in the row too, before
   the button. Read as GSThemeToolbarInMenuBar is. */
BOOL WinUIThemeMenuStyleIsMore(void);

/* Whether the toolbar is shown in a menu bar's row now. Its items are
   then icon-only CommandBar buttons at the row's height, their labels
   tool tips. */
BOOL WinUIThemeToolbarIsInMenuBar(NSToolbar *toolbar);

/* The default changed: open windows move their toolbars into or out of
   the menu bar's row, keeping their frames. */
void WinUIThemeToolbarInMenuBarSettingChanged(void);

/* The theme activating (YES) or deactivating (NO): toolbars move back
   to rows of their own while it's inactive. */
void WinUIThemeToolbarInMenuBarSetActive(BOOL active);

/* Called by the theme's decoration views (WinUIThemeWindowIntegration.m)
   from their own overrides of GSWindowDecorationView's methods. Each
   returns NO, or the rect unchanged, when the toolbar isn't (going) in
   the menu bar's row, so the view does what libs-gui does. */
@interface GSWindowDecorationView (WinUIThemeToolbarInMenuBar)
- (BOOL) winUIThemeHoldsToolbarInMenuBar;
- (BOOL) winUIThemeAddToolbarViewToMenuBar: (GSToolbarView *)toolbarView;
- (BOOL) winUIThemeRemoveToolbarViewFromMenuBar: (GSToolbarView *)toolbarView;
- (BOOL) winUIThemeAdjustToolbarViewInMenuBar: (GSToolbarView *)toolbarView;
/* After libs-gui added the menu bar: a toolbar in a row of its own
   moves into it. */
- (void) winUIThemeMenuViewAdded;
/* Before and after libs-gui removes the menu bar: the toolbar goes back
   to a row of its own. */
- (BOOL) winUIThemeMenuViewWillBeRemoved;
- (void) winUIThemeMenuViewRemoved: (BOOL)heldToolbar;
/* Around libs-gui's -layout: it gives the toolbar no row of its own. */
- (BOOL) winUIThemeBeginLayout;
- (void) winUIThemeEndLayout: (BOOL)heldToolbar;
- (NSRect) winUIThemeContentRect: (NSRect)content;
- (NSRect) winUIThemeFrameRect: (NSRect)frame;
- (void) winUIThemePlaceToolbarForSetting;
@end

#endif
