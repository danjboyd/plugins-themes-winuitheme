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
