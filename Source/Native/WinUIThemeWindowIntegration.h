#ifndef GNUstep_WINUITHEME_WINDOWINTEGRATION_H
#define GNUstep_WINUITHEME_WINDOWINTEGRATION_H

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSWindowDecorationView.h>

@class WinUITheme;

@interface WinUIThemeBackendWindowDecorationView : GSBackendWindowDecorationView
@end

@interface WinUIThemeStandardWindowDecorationView : GSStandardWindowDecorationView
@end

void WinUIThemeWindowIntegrationActivate(WinUITheme *theme);
void WinUIThemeWindowIntegrationDeactivate(void);
void WinUIThemeWindowIntegrationReloadTheme(WinUITheme *theme);
void WinUIThemeWindowIntegrationSynchronizeWindow(NSWindow *window);
void WinUIThemeWindowIntegrationForgetWindow(NSWindow *window);

#endif
