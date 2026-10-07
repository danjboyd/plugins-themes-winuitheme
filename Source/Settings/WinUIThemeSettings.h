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
  CGFloat _desktopScaleFactor;
  BOOL _systemSettingsAvailable;
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
- (CGFloat) desktopScaleFactor;
- (BOOL) systemSettingsAvailable;

- (NSFont *) interfaceFont;
- (NSFont *) menuFont;
- (NSFont *) menuBarFont;
- (NSFont *) fixedPitchFont;

@end

#endif
