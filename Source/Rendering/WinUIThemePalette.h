#ifndef GNUstep_WINUITHEMEPALETTE_H
#define GNUstep_WINUITHEMEPALETTE_H

#import <AppKit/AppKit.h>

@class WinUIThemeSettings;

@interface WinUIThemePalette : NSObject

+ (NSColorList *) colorListForSettings: (WinUIThemeSettings *)settings;

@end

#endif

