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

#ifndef GNUstep_WINUITHEME_H
#define GNUstep_WINUITHEME_H

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

@class WinUIThemeSettings;
@class WinUIThemeMetrics;

/* The implementation a theme override replaced. GSTheme's -overriddenMethod:for:
   only matches the receiver's exact class, so when a subclass (for example
   GSToolbarButtonCell or NSSecureTextFieldCell) reaches an override, it answers
   NULL and the override has nothing to fall back on. This looks the method up
   for `baseClass`, the class the override was installed on, instead. */
IMP WinUIThemeOriginalMethod(SEL selector, id receiver, Class baseClass);

@interface WinUITheme : GSTheme
{
  WinUIThemeSettings *_settings;
  WinUIThemeMetrics *_metrics;
  NSColorList *_palette;
  BOOL _runtimeDefaultsApplied;
}

+ (NSString *) themeName;

- (void) reloadConfiguration;
/* After Windows' theme, accent, contrast, colours or text size change
   (#46): reloads, has AppKit recache its system colours, and redraws
   every window. */
- (void) systemSettingsDidChange;
- (WinUIThemeSettings *) settings;
- (WinUIThemeMetrics *) metrics;

@end

@interface WinUITheme (ApplicationMenu)
/* Hands a horizontal main menu's application menu to Windows' places
   (WinUIThemeApplicationMenu.m). */
- (void) tidyMainMenu;
@end

#endif

