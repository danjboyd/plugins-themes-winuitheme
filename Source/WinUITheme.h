#ifndef GNUstep_WINUITHEME_H
#define GNUstep_WINUITHEME_H

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

@class WinUIThemeSettings;
@class WinUIThemeMetrics;

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

