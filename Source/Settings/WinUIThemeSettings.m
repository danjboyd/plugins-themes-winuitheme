#import "WinUIThemeSettings.h"

#import <AppKit/AppKit.h>
#import <math.h>

#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN 1
#include <windows.h>
#endif

static NSString *WinUIThemeDefaultInterfaceFontName = @"Segoe UI Variable Text";
static NSString *WinUIThemeDefaultMonospaceFontName = @"Cascadia Mono";
static CGFloat WinUIThemeDefaultInterfaceFontSize = 9.0;
static CGFloat WinUIThemeDefaultMonospaceFontSize = 9.0;
static CGFloat WinUIThemeMinimumResolvedInterfaceFontSize = 13.0;
static CGFloat WinUIThemeMinimumResolvedMenuFontSize = 13.0;
static NSString *WinUIThemePersonalizeRegistryPath = @"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
static NSString *WinUIThemeAccentRegistryPath = @"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Accent";
/* Windows' default blue. */
static NSString *WinUIThemeDefaultAccentHex = @"0078D4";

static NSNumber *
WinUIThemeBooleanNumberFromArgumentValue(NSString *value)
{
  if ([value length] == 0)
    {
      return nil;
    }

  value = [value lowercaseString];
  if ([value isEqualToString: @"1"]
      || [value isEqualToString: @"yes"]
      || [value isEqualToString: @"true"]
      || [value isEqualToString: @"on"])
    {
      return [NSNumber numberWithBool: YES];
    }
  if ([value isEqualToString: @"0"]
      || [value isEqualToString: @"no"]
      || [value isEqualToString: @"false"]
      || [value isEqualToString: @"off"])
    {
      return [NSNumber numberWithBool: NO];
    }

  return nil;
}

static NSColor *
WinUIThemeColorFromHexString(NSString *string)
{
  unsigned int rgb = 0;
  NSString *value = [string stringByReplacingOccurrencesOfString: @"#" withString: @""];

  if ([value length] != 6)
    {
      return nil;
    }
  if ([[NSScanner scannerWithString: value] scanHexInt: &rgb] == NO)
    {
      return nil;
    }

  return [NSColor colorWithCalibratedRed: ((rgb >> 16) & 0xFF) / 255.0
                                   green: ((rgb >> 8) & 0xFF) / 255.0
                                    blue: (rgb & 0xFF) / 255.0
                                   alpha: 1.0];
}

/* Shades for an accent Windows didn't give a palette for (an override,
   or no AccentPalette): lighter shades blend towards white and darker ones
   towards black, about as Windows' palette steps. */
static NSArray *
WinUIThemeAccentPaletteFromColor(NSColor *accent)
{
  static const CGFloat steps[7] = { 0.62, 0.40, 0.18, 0.0, 0.16, 0.42, 0.66 };
  NSColor *rgb = [accent colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  NSMutableArray *palette = [NSMutableArray arrayWithCapacity: 7];
  NSUInteger index = 0;

  if (rgb == nil)
    {
      return nil;
    }
  for (index = 0; index < 7; index++)
    {
      NSColor *towards = (index < 3) ? [NSColor whiteColor] : [NSColor blackColor];
      NSColor *shade = (index == 3) ? rgb : [rgb blendedColorWithFraction: steps[index] ofColor: towards];

      [palette addObject: (shade != nil) ? shade : rgb];
    }
  return palette;
}

static NSString *
WinUIThemeHexStringFromColor(NSColor *color)
{
  NSColor *rgbColor = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  NSInteger red = 0;
  NSInteger green = 0;
  NSInteger blue = 0;

  if (rgbColor == nil)
    {
      return nil;
    }

  red = (NSInteger)round([rgbColor redComponent] * 255.0);
  green = (NSInteger)round([rgbColor greenComponent] * 255.0);
  blue = (NSInteger)round([rgbColor blueComponent] * 255.0);

  return [NSString stringWithFormat: @"%02lX%02lX%02lX",
                                      (long)red,
                                      (long)green,
                                      (long)blue];
}

static NSFont *
WinUIThemeResolveFont(NSString *preferredName,
                      CGFloat preferredSize,
                      NSArray *fallbackNames,
                      BOOL fixedPitch)
{
  NSFont *font = nil;
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSEnumerator *enumerator = [fallbackNames objectEnumerator];
  NSString *candidate = nil;
  CGFloat size = preferredSize > 0.0 ? preferredSize : WinUIThemeDefaultInterfaceFontSize;
  NSFontTraitMask traits = fixedPitch ? NSFixedPitchFontMask : 0;

  if ([preferredName length] > 0)
    {
      font = [NSFont fontWithName: preferredName size: size];
      if (font == nil && fontManager != nil)
        {
          font = [fontManager fontWithFamily: preferredName
                                      traits: traits
                                      weight: 5
                                        size: size];
        }
    }

  while (font == nil && (candidate = [enumerator nextObject]) != nil)
    {
      font = [NSFont fontWithName: candidate size: size];
      if (font == nil && fontManager != nil)
        {
          font = [fontManager fontWithFamily: candidate
                                      traits: traits
                                      weight: 5
                                        size: size];
        }
    }

  if (font == nil && fixedPitch)
    {
      font = [NSFont userFixedPitchFontOfSize: size];
    }
  else if (font == nil)
    {
      font = [NSFont systemFontOfSize: size];
    }

  return font;
}

#ifdef _WIN32
static BOOL
WinUIThemeReadRegistryDWORD(NSString *subkey,
                            NSString *valueName,
                            DWORD *value)
{
  HKEY key = NULL;
  DWORD type = 0;
  DWORD size = sizeof(DWORD);
  LONG status = ERROR_SUCCESS;

  if (subkey == nil || valueName == nil || value == NULL)
    {
      return NO;
    }

  status = RegOpenKeyExA(HKEY_CURRENT_USER,
                         [subkey UTF8String],
                         0,
                         KEY_QUERY_VALUE,
                         &key);
  if (status != ERROR_SUCCESS)
    {
      return NO;
    }

  status = RegQueryValueExA(key,
                            [valueName UTF8String],
                            NULL,
                            &type,
                            (LPBYTE)value,
                            &size);
  RegCloseKey(key);

  return (status == ERROR_SUCCESS && type == REG_DWORD);
}

static CGFloat
WinUIThemeSystemDpi(void)
{
  HMODULE user32 = LoadLibraryW(L"user32.dll");
  CGFloat dpi = 96.0;

  if (user32 != NULL)
    {
      typedef UINT (WINAPI *WinUIThemeGetDpiForSystemFunc)(void);
      WinUIThemeGetDpiForSystemFunc getDpiForSystem = NULL;

      getDpiForSystem = (WinUIThemeGetDpiForSystemFunc)
        GetProcAddress(user32, "GetDpiForSystem");
      if (getDpiForSystem != NULL)
        {
          dpi = (CGFloat)getDpiForSystem();
        }
      FreeLibrary(user32);
    }

  if (dpi <= 0.0)
    {
      dpi = 96.0;
    }

  return dpi;
}

static CGFloat
WinUIThemePointSizeFromLogfontHeight(LONG height)
{
  LONG pixelHeight = height < 0 ? -height : height;
  CGFloat dpi = WinUIThemeSystemDpi();

  if (pixelHeight <= 0)
    {
      return 0.0;
    }

  return ((CGFloat)pixelHeight * 72.0) / dpi;
}

static NSString *
WinUIThemeStringFromWideCharacters(const WCHAR *characters)
{
  if (characters == NULL || characters[0] == L'\0')
    {
      return nil;
    }

  return [NSString stringWithCharacters: (const unichar *)characters
                                 length: wcslen(characters)];
}

static BOOL
WinUIThemeLoadNonClientFonts(NSString **interfaceFontName,
                             CGFloat *interfaceFontSize,
                             NSString **menuFontName,
                             CGFloat *menuFontSize)
{
  NONCLIENTMETRICSW metrics;

  memset(&metrics, 0, sizeof(metrics));
  metrics.cbSize = sizeof(metrics);

  if (SystemParametersInfoW(SPI_GETNONCLIENTMETRICS,
                            metrics.cbSize,
                            &metrics,
                            0) == FALSE)
    {
      return NO;
    }

  if (interfaceFontName != NULL)
    {
      *interfaceFontName = WinUIThemeStringFromWideCharacters(metrics.lfMessageFont.lfFaceName);
    }
  if (interfaceFontSize != NULL)
    {
      *interfaceFontSize = WinUIThemePointSizeFromLogfontHeight(metrics.lfMessageFont.lfHeight);
    }
  if (menuFontName != NULL)
    {
      *menuFontName = WinUIThemeStringFromWideCharacters(metrics.lfMenuFont.lfFaceName);
    }
  if (menuFontSize != NULL)
    {
      *menuFontSize = WinUIThemePointSizeFromLogfontHeight(metrics.lfMenuFont.lfHeight);
    }

  return YES;
}

static BOOL
WinUIThemeHighContrastEnabledFromSystem(void)
{
  HIGHCONTRASTW settings;

  memset(&settings, 0, sizeof(settings));
  settings.cbSize = sizeof(settings);
  if (SystemParametersInfoW(SPI_GETHIGHCONTRAST, settings.cbSize, &settings, 0) == FALSE)
    {
      return NO;
    }

  return ((settings.dwFlags & HCF_HIGHCONTRASTON) != 0);
}

/* The app accent, as Windows' Settings sets it: AccentColorMenu is
   0xAABBGGRR. (DWM's ColorizationColor, read before, is the window
   frame's colour, which the user can turn off or tint differently.) */
static NSColor *
WinUIThemeAccentColorFromSystem(void)
{
  DWORD accent = 0;

  if (WinUIThemeReadRegistryDWORD(WinUIThemeAccentRegistryPath,
                                  @"AccentColorMenu",
                                  &accent) == NO)
    {
      return nil;
    }

  return [NSColor colorWithCalibratedRed: (accent & 0xFF) / 255.0
                                   green: ((accent >> 8) & 0xFF) / 255.0
                                    blue: ((accent >> 16) & 0xFF) / 255.0
                                   alpha: 1.0];
}

/* Windows' accent palette: AccentPalette is eight RGBA entries, Light3,
   Light2, Light1, the accent, Dark1, Dark2, Dark3 and one unused. */
static NSArray *
WinUIThemeAccentPaletteFromSystem(void)
{
  HKEY key = NULL;
  DWORD type = 0;
  BYTE bytes[32];
  DWORD size = sizeof(bytes);
  NSMutableArray *palette = nil;
  NSUInteger index = 0;
  LONG status = RegOpenKeyExA(HKEY_CURRENT_USER,
                              [WinUIThemeAccentRegistryPath UTF8String],
                              0,
                              KEY_QUERY_VALUE,
                              &key);

  if (status != ERROR_SUCCESS)
    {
      return nil;
    }
  status = RegQueryValueExA(key, "AccentPalette", NULL, &type, bytes, &size);
  RegCloseKey(key);
  if (status != ERROR_SUCCESS || type != REG_BINARY || size < 28)
    {
      return nil;
    }

  palette = [NSMutableArray arrayWithCapacity: 7];
  for (index = 0; index < 7; index++)
    {
      [palette addObject: [NSColor colorWithCalibratedRed: bytes[index * 4] / 255.0
                                                    green: bytes[index * 4 + 1] / 255.0
                                                     blue: bytes[index * 4 + 2] / 255.0
                                                    alpha: 1.0]];
    }
  return palette;
}
#endif

@implementation WinUIThemeSettings

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      [self reload];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_interfaceFontName);
  RELEASE(_menuFontName);
  RELEASE(_monospaceFontName);
  RELEASE(_accentColor);
  RELEASE(_accentPalette);
  [super dealloc];
}

- (void) reload
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *interfaceFontNameOverride = [defaults stringForKey: @"WinUIThemeInterfaceFontName"];
  NSString *menuFontName = nil;
  NSString *monospaceFontNameOverride = [defaults stringForKey: @"WinUIThemeMonospaceFontName"];
  NSString *accentHexOverride = [defaults stringForKey: @"WinUIThemeAccentColorHex"];
  NSNumber *colorSchemeOverride = [defaults objectForKey: @"WinUIThemeColorScheme"];
  NSNumber *preferDarkOverride = [defaults objectForKey: @"WinUIThemePreferDark"];
  NSNumber *preferLightOverride = [defaults objectForKey: @"WinUIThemePreferLight"];
  NSNumber *highContrastOverride = [defaults objectForKey: @"WinUIThemeHighContrast"];
  NSNumber *reducedTransparencyOverride = [defaults objectForKey: @"WinUIThemeReducedTransparency"];
  NSNumber *desktopScaleFactorOverride = [defaults objectForKey: @"WinUIThemeDesktopScaleFactor"];
  NSNumber *interfaceFontSizeOverride = [defaults objectForKey: @"WinUIThemeInterfaceFontSize"];
  NSNumber *monospaceFontSizeOverride = [defaults objectForKey: @"WinUIThemeMonospaceFontSize"];
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  NSString *interfaceFontName = nil;
  NSString *monospaceFontName = nil;
  NSString *accentHex = nil;
  NSString *commandModeOverride = nil;
  NSNumber *commandHighContrastOverride = nil;
  NSNumber *commandReducedTransparencyOverride = nil;
  CGFloat interfaceFontSize = 0.0;
  CGFloat menuFontSize = 0.0;
  CGFloat monospaceFontSize = 0.0;
  CGFloat commandScaleFactorOverride = 0.0;
  CGFloat desktopScaleFactor = 1.0;
  BOOL highContrast = NO;
  BOOL reducedTransparency = NO;
  BOOL systemSettingsAvailable = NO;
  WinUIThemeColorScheme colorScheme = WinUIThemeColorSchemePreferLight;
  NSColor *accentColor = nil;
  NSArray *accentPalette = nil;
  NSUInteger i = 1;

#ifdef _WIN32
  {
    DWORD appsUseLightTheme = 1;
    DWORD enableTransparency = 1;
    NSString *systemInterfaceFontName = nil;
    NSString *systemMenuFontName = nil;
    CGFloat systemInterfaceFontSize = 0.0;
    CGFloat systemMenuFontSize = 0.0;

    desktopScaleFactor = WinUIThemeSystemDpi() / 96.0;
    highContrast = WinUIThemeHighContrastEnabledFromSystem();
    reducedTransparency = YES;
    if (WinUIThemeReadRegistryDWORD(WinUIThemePersonalizeRegistryPath,
                                    @"EnableTransparency",
                                    &enableTransparency) == YES)
      {
        reducedTransparency = (enableTransparency == 0);
        systemSettingsAvailable = YES;
      }
    if (WinUIThemeReadRegistryDWORD(WinUIThemePersonalizeRegistryPath,
                                    @"AppsUseLightTheme",
                                    &appsUseLightTheme) == YES)
      {
        colorScheme = (appsUseLightTheme == 0)
          ? WinUIThemeColorSchemePreferDark
          : WinUIThemeColorSchemePreferLight;
        systemSettingsAvailable = YES;
      }
    if (WinUIThemeLoadNonClientFonts(&systemInterfaceFontName,
                                     &systemInterfaceFontSize,
                                     &systemMenuFontName,
                                     &systemMenuFontSize) == YES)
      {
        interfaceFontName = systemInterfaceFontName;
        interfaceFontSize = systemInterfaceFontSize;
        menuFontName = systemMenuFontName;
        menuFontSize = systemMenuFontSize;
        systemSettingsAvailable = YES;
      }

    accentPalette = WinUIThemeAccentPaletteFromSystem();
    accentColor = (accentPalette != nil)
      ? [accentPalette objectAtIndex: 3]
      : WinUIThemeAccentColorFromSystem();
    if (accentColor != nil)
      {
        accentHex = WinUIThemeHexStringFromColor(accentColor);
        systemSettingsAvailable = YES;
      }
  }
#endif

  while (i < [arguments count])
    {
      NSString *argument = [arguments objectAtIndex: i];
      NSString *nextValue = (i + 1 < [arguments count])
        ? [arguments objectAtIndex: i + 1]
        : nil;

      if ([argument isEqualToString: @"--mode"] && [nextValue length] > 0)
        {
          commandModeOverride = [nextValue lowercaseString];
          i += 2;
          continue;
        }
      if ([argument isEqualToString: @"--scale"] && [nextValue length] > 0)
        {
          commandScaleFactorOverride = [nextValue floatValue];
          if (commandScaleFactorOverride > 10.0)
            {
              commandScaleFactorOverride = commandScaleFactorOverride / 100.0;
            }
          i += 2;
          continue;
        }
      if ([argument isEqualToString: @"--high-contrast"])
        {
          NSNumber *parsedValue = nil;

          if ([nextValue hasPrefix: @"--"] == NO)
            {
              parsedValue = WinUIThemeBooleanNumberFromArgumentValue(nextValue);
              if (parsedValue != nil)
                {
                  commandHighContrastOverride = parsedValue;
                  i += 2;
                  continue;
                }
            }

          commandHighContrastOverride = [NSNumber numberWithBool: YES];
          i += 1;
          continue;
        }
      if ([argument isEqualToString: @"--reduced-transparency"])
        {
          NSNumber *parsedValue = nil;

          if ([nextValue hasPrefix: @"--"] == NO)
            {
              parsedValue = WinUIThemeBooleanNumberFromArgumentValue(nextValue);
              if (parsedValue != nil)
                {
                  commandReducedTransparencyOverride = parsedValue;
                  i += 2;
                  continue;
                }
            }

          commandReducedTransparencyOverride = [NSNumber numberWithBool: YES];
          i += 1;
          continue;
        }

      i += 1;
    }

  if ([interfaceFontName length] == 0)
    {
      interfaceFontName = interfaceFontNameOverride;
    }
  if ([menuFontName length] == 0)
    {
      menuFontName = interfaceFontName;
    }
  if ([interfaceFontName length] == 0)
    {
      interfaceFontName = WinUIThemeDefaultInterfaceFontName;
    }
  if ([menuFontName length] == 0)
    {
      menuFontName = interfaceFontName;
    }
  if ([monospaceFontName length] == 0)
    {
      monospaceFontName = monospaceFontNameOverride;
    }
  if ([monospaceFontName length] == 0)
    {
      monospaceFontName = WinUIThemeDefaultMonospaceFontName;
    }
  if (interfaceFontSize <= 0.0)
    {
      interfaceFontSize = [interfaceFontSizeOverride floatValue];
    }
  if (menuFontSize <= 0.0)
    {
      menuFontSize = interfaceFontSize;
    }
  if (monospaceFontSize <= 0.0)
    {
      monospaceFontSize = [monospaceFontSizeOverride floatValue];
    }
  if (interfaceFontSize <= 0.0)
    {
      interfaceFontSize = WinUIThemeDefaultInterfaceFontSize;
    }
  if (menuFontSize <= 0.0)
    {
      menuFontSize = interfaceFontSize;
    }
  if (monospaceFontSize <= 0.0)
    {
      monospaceFontSize = WinUIThemeDefaultMonospaceFontSize;
    }
  /* An explicit WinUIThemeAccentColorHex wins over the system's accent,
     as the other WinUITheme* overrides do. */
  if (WinUIThemeColorFromHexString(accentHexOverride) != nil)
    {
      accentHex = accentHexOverride;
      accentColor = WinUIThemeColorFromHexString(accentHexOverride);
      accentPalette = nil;
    }
  if ([accentHex length] == 0)
    {
      accentHex = WinUIThemeDefaultAccentHex;
    }
  if (accentColor == nil)
    {
      accentColor = WinUIThemeColorFromHexString(accentHex);
    }
  if (accentColor == nil)
    {
      accentColor = WinUIThemeColorFromHexString(WinUIThemeDefaultAccentHex);
    }
  if (accentPalette == nil)
    {
      accentPalette = WinUIThemeAccentPaletteFromColor(accentColor);
    }

  if (colorSchemeOverride != nil)
    {
      NSInteger overrideValue = [colorSchemeOverride integerValue];

      if (overrideValue == WinUIThemeColorSchemePreferDark
          || overrideValue == WinUIThemeColorSchemePreferLight)
        {
          colorScheme = (WinUIThemeColorScheme)overrideValue;
        }
    }
  else if (preferDarkOverride != nil && [preferDarkOverride boolValue] == YES)
    {
      colorScheme = WinUIThemeColorSchemePreferDark;
    }
  else if (preferLightOverride != nil && [preferLightOverride boolValue] == YES)
    {
      colorScheme = WinUIThemeColorSchemePreferLight;
    }

  if (highContrastOverride != nil)
    {
      highContrast = [highContrastOverride boolValue];
    }
  if (reducedTransparencyOverride != nil)
    {
      reducedTransparency = [reducedTransparencyOverride boolValue];
    }
  if ([desktopScaleFactorOverride floatValue] > 0.0)
    {
      desktopScaleFactor = [desktopScaleFactorOverride floatValue];
    }
  if ([commandModeOverride isEqualToString: @"dark"])
    {
      colorScheme = WinUIThemeColorSchemePreferDark;
    }
  else if ([commandModeOverride isEqualToString: @"light"])
    {
      colorScheme = WinUIThemeColorSchemePreferLight;
    }
  if (commandHighContrastOverride != nil)
    {
      highContrast = [commandHighContrastOverride boolValue];
    }
  if (commandReducedTransparencyOverride != nil)
    {
      reducedTransparency = [commandReducedTransparencyOverride boolValue];
    }
  if (commandScaleFactorOverride > 0.0)
    {
      desktopScaleFactor = commandScaleFactorOverride;
    }

  if ([interfaceFontNameOverride length] > 0)
    {
      interfaceFontName = interfaceFontNameOverride;
    }
  if ([monospaceFontNameOverride length] > 0)
    {
      monospaceFontName = monospaceFontNameOverride;
    }
  if ([interfaceFontSizeOverride floatValue] > 0.0)
    {
      interfaceFontSize = [interfaceFontSizeOverride floatValue];
      menuFontSize = interfaceFontSize;
    }
  if ([monospaceFontSizeOverride floatValue] > 0.0)
    {
      monospaceFontSize = [monospaceFontSizeOverride floatValue];
    }

  ASSIGNCOPY(_interfaceFontName, interfaceFontName);
  _interfaceFontSize = interfaceFontSize;
  ASSIGNCOPY(_menuFontName, menuFontName);
  _menuFontSize = menuFontSize;
  ASSIGNCOPY(_monospaceFontName, monospaceFontName);
  _monospaceFontSize = monospaceFontSize;
  ASSIGN(_accentColor, accentColor);
  ASSIGN(_accentPalette, accentPalette);
  _colorScheme = colorScheme;
  _highContrast = highContrast;
  _reducedTransparency = reducedTransparency;
  _desktopScaleFactor = desktopScaleFactor > 0.0 ? desktopScaleFactor : 1.0;
  _systemSettingsAvailable = systemSettingsAvailable;
}

- (NSString *) interfaceFontName
{
  return _interfaceFontName;
}

- (CGFloat) interfaceFontSize
{
  return MAX(WinUIThemeMinimumResolvedInterfaceFontSize, _interfaceFontSize);
}

- (NSString *) monospaceFontName
{
  return _monospaceFontName;
}

- (CGFloat) monospaceFontSize
{
  return _monospaceFontSize;
}

- (NSColor *) accentColor
{
  return _accentColor;
}

- (NSColor *) accentShade: (NSInteger)level
{
  NSInteger index = 3 - MAX(-3, MIN(3, level));

  if ([_accentPalette count] < 7)
    {
      return _accentColor;
    }
  return [_accentPalette objectAtIndex: index];
}

- (WinUIThemeColorScheme) colorScheme
{
  return _colorScheme;
}

- (BOOL) prefersDarkAppearance
{
  return (_colorScheme == WinUIThemeColorSchemePreferDark);
}

- (BOOL) highContrastEnabled
{
  return _highContrast;
}

- (BOOL) reducedTransparencyEnabled
{
  return _reducedTransparency;
}

- (CGFloat) desktopScaleFactor
{
  return _desktopScaleFactor;
}

- (BOOL) systemSettingsAvailable
{
  return _systemSettingsAvailable;
}

- (NSFont *) interfaceFont
{
  return WinUIThemeResolveFont(_interfaceFontName,
                               [self interfaceFontSize],
                               [NSArray arrayWithObjects: @"Segoe UI", @"Arial", nil],
                               NO);
}

- (NSFont *) menuFont
{
  return WinUIThemeResolveFont(_menuFontName,
                               MAX(WinUIThemeMinimumResolvedMenuFontSize, _menuFontSize),
                               [NSArray arrayWithObjects: @"Segoe UI", @"Arial", nil],
                               NO);
}

- (NSFont *) menuBarFont
{
  return WinUIThemeResolveFont(_menuFontName,
                               MAX(WinUIThemeMinimumResolvedMenuFontSize, _menuFontSize),
                               [NSArray arrayWithObjects: @"Segoe UI", @"Arial", nil],
                               NO);
}

- (NSFont *) fixedPitchFont
{
  return WinUIThemeResolveFont(_monospaceFontName,
                               _monospaceFontSize,
                               [NSArray arrayWithObjects: @"Cascadia Mono", @"Courier New", nil],
                               YES);
}

@end

