#ifndef GNUstep_WINUITHEME_SHELLDIALOGS_H
#define GNUstep_WINUITHEME_SHELLDIALOGS_H

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

@interface WinUIThemeSavePanel : NSSavePanel
@end

@interface WinUIThemeOpenPanel : NSOpenPanel
@end

@interface WinUIThemePrintPanel : GSPrintPanel
@end

@interface WinUIThemePageLayout : GSPageLayout
@end

#endif
