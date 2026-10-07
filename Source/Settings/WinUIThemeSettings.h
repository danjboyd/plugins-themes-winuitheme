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

#ifndef GNUstep_WINUITHEMESETTINGS_H
#define GNUstep_WINUITHEMESETTINGS_H

#import <AppKit/AppKit.h>

typedef enum
{
  WinUIThemeColorSchemeDefault = 0,
  WinUIThemeColorSchemePreferLight = 1,
  WinUIThemeColorSchemePreferDark = 2
} WinUIThemeColorScheme;

@interface WinUIThemeSettings : NSObject
{
  NSString *_interfaceFontName;
  CGFloat _interfaceFontSize;
  NSString *_menuFontName;
  CGFloat _menuFontSize;
  NSString *_monospaceFontName;
  CGFloat _monospaceFontSize;
  NSColor *_accentColor;
  NSArray *_accentPalette;
  WinUIThemeColorScheme _colorScheme;
  BOOL _highContrast;
  BOOL _reducedTransparency;
  BOOL _dynamicScrollbars;
  CGFloat _desktopScaleFactor;
  CGFloat _textScaleFactor;
  BOOL _systemSettingsAvailable;
  BOOL _compactMetrics;
}

- (void) reload;

- (NSString *) interfaceFontName;
- (CGFloat) interfaceFontSize;
- (NSString *) monospaceFontName;
- (CGFloat) monospaceFontSize;
- (NSColor *) accentColor;
/* The accent's shades, as Windows' AccentPalette has them: 3, 2, 1 are
   Light3..Light1, 0 the accent itself, -1..-3 Dark1..Dark3. WinUI fills
   with Dark1 in the light theme and Light2 in the dark one. */
- (NSColor *) accentShade: (NSInteger)level;
- (WinUIThemeColorScheme) colorScheme;
- (BOOL) prefersDarkAppearance;
- (BOOL) highContrastEnabled;
- (BOOL) reducedTransparencyEnabled;
/* Windows' "Automatically hide scroll bars" (Accessibility > Visual
   effects): YES unless it's off. */
- (BOOL) dynamicScrollbarsEnabled;
- (CGFloat) desktopScaleFactor;
/* Windows' Text size (Accessibility), 1.0 to 2.25: it scales the fonts. */
- (CGFloat) textScaleFactor;
- (BOOL) systemSettingsAvailable;
/* Compact metrics (#31), for layouts made at GNUstep's sizes: apps with a
   main Gorm or nib file (NSMainNibFile, NSMainStoryboardFile or
   GSMainMarkupFile in their Info.plist) get them unless they say otherwise.
   WinUIThemeMetrics, "winui" or "compact", in the user's defaults or the
   app's Info.plist, overrides the choice. */
- (BOOL) compactMetrics;

- (NSFont *) interfaceFont;
- (NSFont *) menuFont;
- (NSFont *) menuBarFont;
- (NSFont *) semiboldInterfaceFontOfSize: (CGFloat)size;
- (NSFont *) fixedPitchFont;

@end

NSFont *WinUIThemeSemiboldFont(NSFont *font, CGFloat size);

#endif
