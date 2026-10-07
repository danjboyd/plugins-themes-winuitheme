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
- (WinUIThemeSettings *) settings;
- (WinUIThemeMetrics *) metrics;

@end

#endif

