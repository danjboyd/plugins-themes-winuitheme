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

#import "WinUIThemeWindowIntegration.h"

#import "../WinUITheme.h"
#import "../Settings/WinUIThemeSettings.h"
#import "GSWindowTabbing.h"

#import <AppKit/AppKit.h>
#import <math.h>
#import <objc/runtime.h>

#ifdef _WIN32
#ifndef WINVER
#define WINVER 0x0A00
#endif
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <dwmapi.h>

#ifndef NSWindowStyleMaskUtilityWindow
#define NSWindowStyleMaskUtilityWindow (1 << 4)
#endif
#ifndef NSWindowStyleMaskDocModalWindow
#define NSWindowStyleMaskDocModalWindow (1 << 6)
#endif
#ifndef NSWindowStyleMaskNonactivatingPanel
#define NSWindowStyleMaskNonactivatingPanel (1 << 7)
#endif
#ifndef NSWindowStyleMaskHUDWindow
#define NSWindowStyleMaskHUDWindow (1 << 13)
#endif
#endif

static void WinUIThemeForgetPopupCorners(NSWindow *window);

@interface WinUIThemeWindowIntegrationController : NSObject
{
  WinUITheme *_theme;
  NSMutableDictionary *_windowScaleFactors;
  BOOL _hasSystemSnapshot;
  BOOL _lastSystemPrefersDark;
  BOOL _lastSystemHighContrast;
  BOOL _lastSystemReducedTransparency;
  unsigned int _lastSystemAccent;
  unsigned int _lastSystemTextScale;
  BOOL _reloadingTheme;
  void *_listener;
  BOOL _pendingForcedRefresh;
}

- (id) initWithTheme: (WinUITheme *)theme;
- (void) updateTheme: (WinUITheme *)theme;
- (void) synchronizeAllWindowsForceRedraw: (BOOL)forceRedraw;
- (void) synchronizeWindow: (NSWindow *)window forceRedraw: (BOOL)forceRedraw;
- (void) forgetWindow: (NSWindow *)window;
- (void) restoreAllWindows;
- (void) systemSettingsMayHaveChanged: (BOOL)certainly;

@end

static WinUIThemeWindowIntegrationController *WinUIThemeSharedWindowIntegration = nil;

#ifdef _WIN32
typedef HRESULT (WINAPI *WinUIThemeDwmSetWindowAttributeFunc)(HWND hwnd,
                                                              DWORD attribute,
                                                              LPCVOID value,
                                                              DWORD size);
typedef UINT (WINAPI *WinUIThemeGetDpiForWindowFunc)(HWND hwnd);

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

static BOOL
WinUIThemeSystemPrefersDarkAppearance(void)
{
  DWORD appsUseLightTheme = 1;

  if (WinUIThemeReadRegistryDWORD(
        @"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        @"AppsUseLightTheme",
        &appsUseLightTheme) == NO)
    {
      return NO;
    }

  return (appsUseLightTheme == 0);
}

static BOOL
WinUIThemeSystemHighContrastEnabled(void)
{
  HIGHCONTRASTW settings;

  memset(&settings, 0, sizeof(settings));
  settings.cbSize = sizeof(settings);
  if (SystemParametersInfoW(SPI_GETHIGHCONTRAST,
                            settings.cbSize,
                            &settings,
                            0) == FALSE)
    {
      return NO;
    }

  return ((settings.dwFlags & HCF_HIGHCONTRASTON) != 0);
}

/* The accent Settings sets (0xAABBGGRR), or 0. */
static unsigned int
WinUIThemeSystemAccent(void)
{
  DWORD accent = 0;

  if (WinUIThemeReadRegistryDWORD(
        @"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Accent",
        @"AccentColorMenu",
        &accent) == NO)
    {
      return 0;
    }

  return (unsigned int)accent;
}

/* Settings > Accessibility > Text size, as a percentage (100 to 225). */
static unsigned int
WinUIThemeSystemTextScale(void)
{
  DWORD scale = 100;

  if (WinUIThemeReadRegistryDWORD(@"Software\\Microsoft\\Accessibility",
                                  @"TextScaleFactor",
                                  &scale) == NO)
    {
      return 100;
    }
  return (unsigned int)scale;
}

/* Live settings changes (#46): a hidden top-level window hears what
   Windows broadcasts when the theme, accent, contrast, colours or
   displays change (a message-only window hears no broadcasts). libs-back
   dispatches every message on its thread, this window's included. */
static const wchar_t *WinUIThemeSettingsListenerClass = L"WinUIThemeSettingsListener";

static LRESULT CALLBACK
WinUIThemeSettingsListenerProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
  switch (message)
    {
      case WM_SETTINGCHANGE:
        {
          /* Theme or accent (ImmersiveColorSet), contrast: certainly.
             Anything else, such as text size, when the settings differ. */
          const wchar_t *area = (const wchar_t *)lParam;
          BOOL certainly = (wParam == SPI_SETHIGHCONTRAST
                            || (area != NULL
                                && (wcscmp(area, L"ImmersiveColorSet") == 0
                                    || wcscmp(area, L"WindowsThemeElement") == 0)));

          [WinUIThemeSharedWindowIntegration systemSettingsMayHaveChanged: certainly];
          break;
        }
      case WM_SYSCOLORCHANGE:
      case WM_THEMECHANGED:
        [WinUIThemeSharedWindowIntegration systemSettingsMayHaveChanged: YES];
        break;
      case WM_DISPLAYCHANGE:
        [WinUIThemeSharedWindowIntegration systemSettingsMayHaveChanged: NO];
        break;
      default:
        break;
    }
  return DefWindowProcW(hwnd, message, wParam, lParam);
}

static HWND
WinUIThemeCreateSettingsListener(void)
{
  static BOOL registered = NO;
  const wchar_t *className = WinUIThemeSettingsListenerClass;
  HINSTANCE instance = GetModuleHandleW(NULL);

  if (registered == NO)
    {
      WNDCLASSW windowClass;

      memset(&windowClass, 0, sizeof(windowClass));
      windowClass.lpfnWndProc = WinUIThemeSettingsListenerProc;
      windowClass.hInstance = instance;
      windowClass.lpszClassName = className;
      registered = (RegisterClassW(&windowClass) != 0
                    || GetLastError() == ERROR_CLASS_ALREADY_EXISTS);
    }
  /* Never shown: a tool window keeps it off the taskbar and Alt+Tab. */
  return CreateWindowExW(WS_EX_TOOLWINDOW, className, L"", WS_POPUP,
                         0, 0, 0, 0, NULL, NULL, instance, NULL);
}

static BOOL
WinUIThemeSystemReducedTransparency(void)
{
  DWORD enableTransparency = 1;

  if (WinUIThemeReadRegistryDWORD(
        @"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        @"EnableTransparency",
        &enableTransparency) == NO)
    {
      return YES;
    }

  return (enableTransparency == 0);
}

static WinUIThemeDwmSetWindowAttributeFunc
WinUIThemeDwmSetWindowAttributeProc(void)
{
  static HMODULE module = NULL;
  static WinUIThemeDwmSetWindowAttributeFunc proc = NULL;
  static int didLookup = 0;

  if (didLookup == 0)
    {
      module = LoadLibraryW(L"dwmapi.dll");
      if (module != NULL)
        {
          proc = (WinUIThemeDwmSetWindowAttributeFunc)
            GetProcAddress(module, "DwmSetWindowAttribute");
        }
      didLookup = 1;
    }

  return proc;
}

static WinUIThemeGetDpiForWindowFunc
WinUIThemeGetDpiForWindowProc(void)
{
  static HMODULE module = NULL;
  static WinUIThemeGetDpiForWindowFunc proc = NULL;
  static int didLookup = 0;

  if (didLookup == 0)
    {
      module = LoadLibraryW(L"user32.dll");
      if (module != NULL)
        {
          proc = (WinUIThemeGetDpiForWindowFunc)
            GetProcAddress(module, "GetDpiForWindow");
        }
      didLookup = 1;
    }

  return proc;
}

static HWND
WinUIThemeWindowHandle(NSWindow *window)
{
  if (window == nil || [window respondsToSelector: @selector(windowHandle)] == NO)
    {
      return NULL;
    }

  return (HWND)[window windowHandle];
}

/* Window tabs (#72): the tab that last gave up key status, not retained
   (cleared when it closes or another tab of its group takes over). */
static NSWindow *WinUIThemeLastResignedKeyWindow = nil;

static BOOL
WinUIThemeWindowIsTabbed(NSWindow *window)
{
  return [window respondsToSelector: @selector(tabbedWindows)]
    && [[window tabbedWindows] count] > 1;
}

/* Only tabs are noted: selecting a tab hides the old one first, and key
   may pass through another window before the new tab takes it. */
static void
WinUIThemeTabResignedKey(NSWindow *window)
{
  if (WinUIThemeWindowIsTabbed(window))
    {
      WinUIThemeLastResignedKeyWindow = window;
    }
}

/* A selected tab takes its group's place on screen. The shared tabbing
   code gives it the previous tab's frame, but Windows keeps maximized
   (and the size to restore to) per window: a tab selected while the group
   was maximized filled the screen without being maximized, so the caption
   button and double-click didn't restore it, and a tab maximized before
   came back maximized in a restored group. When key moves from one tab
   of a group to another, the new tab takes the old one's placement. */
static void
WinUIThemeTabTakeOverPlacement(NSWindow *window)
{
  NSWindow *previous = WinUIThemeLastResignedKeyWindow;
  HWND handle;
  HWND previousHandle;
  WINDOWPLACEMENT placement;
  WINDOWPLACEMENT previousPlacement;
  BOOL zoomed;
  BOOL previousZoomed;

  if (previous == nil || WinUIThemeWindowIsTabbed(window) == NO)
    {
      return;
    }
  if (previous == window)
    {
      /* Key came back to the same tab. */
      WinUIThemeLastResignedKeyWindow = nil;
      return;
    }
  if ([[window tabbedWindows] indexOfObjectIdenticalTo: previous] == NSNotFound)
    {
      return;
    }
  WinUIThemeLastResignedKeyWindow = nil;
  handle = WinUIThemeWindowHandle(window);
  previousHandle = WinUIThemeWindowHandle(previous);
  if (handle == NULL || previousHandle == NULL)
    {
      return;
    }
  placement.length = sizeof(placement);
  previousPlacement.length = sizeof(previousPlacement);
  if (GetWindowPlacement(handle, &placement) == 0
      || GetWindowPlacement(previousHandle, &previousPlacement) == 0)
    {
      return;
    }
  zoomed = IsZoomed(handle) ? YES : NO;
  previousZoomed = IsZoomed(previousHandle) ? YES : NO;
  if (zoomed == NO && previousZoomed == NO)
    {
      return;
    }
  placement.flags = 0;
  placement.showCmd = previousZoomed ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
  placement.rcNormalPosition = previousPlacement.rcNormalPosition;
  SetWindowPlacement(handle, &placement);
}

static NSString *
WinUIThemeWindowCacheKey(NSWindow *window)
{
  return [NSString stringWithFormat: @"%p", window];
}

static BOOL
WinUIThemeShouldManageWindow(NSWindow *window)
{
  NSUInteger styleMask = 0;
  NSInteger level = 0;

  if (WinUIThemeWindowHandle(window) == NULL)
    {
      return NO;
    }

  styleMask = [window styleMask];
  if ((styleMask & NSTitledWindowMask) == 0)
    {
      return NO;
    }
  if (styleMask & (NSMiniWindowMask | NSIconWindowMask))
    {
      return NO;
    }

  level = [window level];
  if (level == NSDesktopWindowLevel
      || level == NSSubmenuWindowLevel
      || level == NSTornOffMenuWindowLevel
      || level == NSMainMenuWindowLevel
      || level == NSStatusWindowLevel
      || level == NSPopUpMenuWindowLevel)
    {
      return NO;
    }

  return YES;
}

static DWM_WINDOW_CORNER_PREFERENCE
WinUIThemeCornerPreferenceForWindow(NSWindow *window)
{
  NSUInteger styleMask = [window styleMask];

  if ((styleMask & NSTitledWindowMask) == 0)
    {
      return DWMWCP_DONOTROUND;
    }

  if ([window isKindOfClass: [NSPanel class]]
      || (styleMask & (NSWindowStyleMaskUtilityWindow
                       | NSWindowStyleMaskDocModalWindow
                       | NSWindowStyleMaskNonactivatingPanel
                       | NSWindowStyleMaskHUDWindow)) != 0)
    {
      return DWMWCP_ROUNDSMALL;
    }

  return DWMWCP_ROUND;
}

static NSColor *
WinUIThemeColorForKey(WinUITheme *theme, NSString *key, NSColor *fallback)
{
  NSColor *color = nil;

  if (theme != nil && key != nil)
    {
      color = [[theme colors] colorWithKey: key];
    }

  return color != nil ? color : fallback;
}

static COLORREF
WinUIThemeColorRefFromColor(NSColor *color)
{
  NSColor *rgbColor = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  NSUInteger red = 0;
  NSUInteger green = 0;
  NSUInteger blue = 0;

  if (rgbColor == nil)
    {
      rgbColor = [[NSColor blackColor]
        colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
    }

  red = (NSUInteger)lrint([rgbColor redComponent] * 255.0);
  green = (NSUInteger)lrint([rgbColor greenComponent] * 255.0);
  blue = (NSUInteger)lrint([rgbColor blueComponent] * 255.0);

  return RGB(red, green, blue);
}

static CGFloat
WinUIThemeScaleFactorForWindow(NSWindow *window, WinUIThemeSettings *settings)
{
  WinUIThemeGetDpiForWindowFunc getDpiForWindow = WinUIThemeGetDpiForWindowProc();
  HWND hwnd = WinUIThemeWindowHandle(window);
  UINT dpi = 0;

  if (getDpiForWindow != NULL && hwnd != NULL)
    {
      dpi = getDpiForWindow(hwnd);
    }
  if (dpi > 0)
    {
      return MAX(1.0, ((CGFloat)dpi) / 96.0);
    }
  if (settings != nil && [settings desktopScaleFactor] > 0.0)
    {
      return [settings desktopScaleFactor];
    }

  return 1.0;
}

static void
WinUIThemeSetDwmAttribute(HWND hwnd,
                          DWORD attribute,
                          const void *value,
                          DWORD valueSize)
{
  WinUIThemeDwmSetWindowAttributeFunc setAttribute = WinUIThemeDwmSetWindowAttributeProc();

  if (hwnd == NULL || setAttribute == NULL || value == NULL || valueSize == 0)
    {
      return;
    }

  setAttribute(hwnd, attribute, value, valueSize);
}

static void
WinUIThemeApplyWindowIdentity(NSWindow *window,
                              WinUITheme *theme,
                              BOOL restoreDefaults)
{
  HWND hwnd = WinUIThemeWindowHandle(window);
  BOOL highContrast = NO;
  BOOL darkMode = NO;
  int darkModeValue = FALSE;
  DWM_WINDOW_CORNER_PREFERENCE cornerPreference = DWMWCP_DEFAULT;
  COLORREF resetColor = DWMWA_COLOR_DEFAULT;
  COLORREF captionColor = 0;
  COLORREF borderColor = 0;
  COLORREF textColor = 0;

  if (hwnd == NULL)
    {
      return;
    }

  if (restoreDefaults)
    {
      highContrast = WinUIThemeSystemHighContrastEnabled();
      darkMode = (highContrast == NO && WinUIThemeSystemPrefersDarkAppearance());
    }
  else if (theme != nil)
    {
      highContrast = [[theme settings] highContrastEnabled];
      darkMode = (highContrast == NO && [[theme settings] prefersDarkAppearance]);
    }

  darkModeValue = darkMode ? TRUE : FALSE;
  WinUIThemeSetDwmAttribute(hwnd,
                            DWMWA_USE_IMMERSIVE_DARK_MODE,
                            &darkModeValue,
                            sizeof(darkModeValue));

  if (restoreDefaults || highContrast)
    {
      WinUIThemeSetDwmAttribute(hwnd,
                                DWMWA_WINDOW_CORNER_PREFERENCE,
                                &cornerPreference,
                                sizeof(cornerPreference));
      WinUIThemeSetDwmAttribute(hwnd,
                                DWMWA_CAPTION_COLOR,
                                &resetColor,
                                sizeof(resetColor));
      WinUIThemeSetDwmAttribute(hwnd,
                                DWMWA_BORDER_COLOR,
                                &resetColor,
                                sizeof(resetColor));
      WinUIThemeSetDwmAttribute(hwnd,
                                DWMWA_TEXT_COLOR,
                                &resetColor,
                                sizeof(resetColor));
      return;
    }

  cornerPreference = WinUIThemeCornerPreferenceForWindow(window);
  WinUIThemeSetDwmAttribute(hwnd,
                            DWMWA_WINDOW_CORNER_PREFERENCE,
                            &cornerPreference,
                            sizeof(cornerPreference));

  captionColor = WinUIThemeColorRefFromColor(
    WinUIThemeColorForKey(theme,
                          @"windowBackgroundColor",
                          [NSColor windowBackgroundColor]));
  borderColor = WinUIThemeColorRefFromColor(
    WinUIThemeColorForKey(theme,
                          @"windowFrameColor",
                          [NSColor windowFrameColor]));
  textColor = WinUIThemeColorRefFromColor(
    WinUIThemeColorForKey(theme,
                          @"windowFrameTextColor",
                          [NSColor windowFrameTextColor]));

  WinUIThemeSetDwmAttribute(hwnd,
                            DWMWA_CAPTION_COLOR,
                            &captionColor,
                            sizeof(captionColor));
  WinUIThemeSetDwmAttribute(hwnd,
                            DWMWA_BORDER_COLOR,
                            &borderColor,
                            sizeof(borderColor));
  WinUIThemeSetDwmAttribute(hwnd,
                            DWMWA_TEXT_COLOR,
                            &textColor,
                            sizeof(textColor));
}
#endif

@implementation WinUIThemeWindowIntegrationController

- (id) initWithTheme: (WinUITheme *)theme
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

  self = [super init];
  if (self != nil)
    {
      _windowScaleFactors = [NSMutableDictionary new];
      _hasSystemSnapshot = NO;
      _lastSystemPrefersDark = NO;
      _lastSystemHighContrast = NO;
      _lastSystemReducedTransparency = NO;
      _reloadingTheme = NO;

      [center addObserver: self
                 selector: @selector(windowBecameKey:)
                     name: NSWindowDidBecomeKeyNotification
                   object: nil];
      [center addObserver: self
                 selector: @selector(windowResignedKey:)
                     name: NSWindowDidResignKeyNotification
                   object: nil];
      [center addObserver: self
                 selector: @selector(windowMoved:)
                     name: NSWindowDidMoveNotification
                   object: nil];
      [center addObserver: self
                 selector: @selector(windowResized:)
                     name: NSWindowDidResizeNotification
                   object: nil];
      [center addObserver: self
                 selector: @selector(windowChangedScreen:)
                     name: NSWindowDidChangeScreenNotification
                   object: nil];
      [center addObserver: self
                 selector: @selector(windowWillClose:)
                     name: NSWindowWillCloseNotification
                   object: nil];
      [center addObserver: self
                 selector: @selector(screenParametersChanged:)
                     name: NSApplicationDidChangeScreenParametersNotification
                   object: NSApp];

#ifdef _WIN32
      _listener = (void *)WinUIThemeCreateSettingsListener();
#endif
      [self updateTheme: theme];
    }

  return self;
}

- (void) dealloc
{
  [NSObject cancelPreviousPerformRequestsWithTarget: self];
#ifdef _WIN32
  if (_listener != NULL)
    {
      DestroyWindow((HWND)_listener);
      _listener = NULL;
    }
#endif
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(_windowScaleFactors);
  RELEASE(_theme);
  [super dealloc];
}

- (void) _captureSystemSnapshot
{
#ifdef _WIN32
  _lastSystemPrefersDark = WinUIThemeSystemPrefersDarkAppearance();
  _lastSystemHighContrast = WinUIThemeSystemHighContrastEnabled();
  _lastSystemReducedTransparency = WinUIThemeSystemReducedTransparency();
  _lastSystemAccent = WinUIThemeSystemAccent();
  _lastSystemTextScale = WinUIThemeSystemTextScale();
  _hasSystemSnapshot = YES;
#endif
}

- (void) _refreshThemeIfSystemStateChanged
{
#ifdef _WIN32
  BOOL prefersDark = NO;
  BOOL highContrast = NO;
  BOOL reducedTransparency = NO;
  unsigned int accent = 0;
  unsigned int textScale = WinUIThemeSystemTextScale();

  prefersDark = WinUIThemeSystemPrefersDarkAppearance();
  highContrast = WinUIThemeSystemHighContrastEnabled();
  reducedTransparency = WinUIThemeSystemReducedTransparency();
  accent = WinUIThemeSystemAccent();

  if (_hasSystemSnapshot == NO)
    {
      _lastSystemPrefersDark = prefersDark;
      _lastSystemHighContrast = highContrast;
      _lastSystemReducedTransparency = reducedTransparency;
      _lastSystemAccent = accent;
      _lastSystemTextScale = textScale;
      _hasSystemSnapshot = YES;
      return;
    }

  if (_reloadingTheme == NO
      && (prefersDark != _lastSystemPrefersDark
          || highContrast != _lastSystemHighContrast
          || reducedTransparency != _lastSystemReducedTransparency
          || accent != _lastSystemAccent
          || textScale != _lastSystemTextScale))
    {
      _lastSystemPrefersDark = prefersDark;
      _lastSystemHighContrast = highContrast;
      _lastSystemReducedTransparency = reducedTransparency;
      _lastSystemAccent = accent;
      _lastSystemTextScale = textScale;

      if (_theme != nil)
        {
          _reloadingTheme = YES;
          [_theme systemSettingsDidChange];
          _reloadingTheme = NO;
          return;
        }
    }

  _lastSystemPrefersDark = prefersDark;
  _lastSystemHighContrast = highContrast;
  _lastSystemReducedTransparency = reducedTransparency;
  _lastSystemAccent = accent;
  _lastSystemTextScale = textScale;
#endif
}

/* From the listener window: a burst of messages (Windows sends several
   for one change) becomes one refresh, a tenth of a second later. */
- (void) systemSettingsMayHaveChanged: (BOOL)certainly
{
  _pendingForcedRefresh = _pendingForcedRefresh || certainly;
  [NSObject cancelPreviousPerformRequestsWithTarget: self
                                           selector: @selector(_refreshAfterSystemSettingsChange)
                                             object: nil];
  [self performSelector: @selector(_refreshAfterSystemSettingsChange)
             withObject: nil
             afterDelay: 0.1];
}

- (void) _refreshAfterSystemSettingsChange
{
  BOOL forced = _pendingForcedRefresh;

  _pendingForcedRefresh = NO;
  if (forced && _theme != nil && _reloadingTheme == NO)
    {
      [self _captureSystemSnapshot];
      _reloadingTheme = YES;
      [_theme systemSettingsDidChange];
      _reloadingTheme = NO;
      return;
    }
  [self _refreshThemeIfSystemStateChanged];
  [self synchronizeAllWindowsForceRedraw: NO];
}

- (void) updateTheme: (WinUITheme *)theme
{
  ASSIGN(_theme, theme);
  [_windowScaleFactors removeAllObjects];
  [self _captureSystemSnapshot];
  [self synchronizeAllWindowsForceRedraw: YES];
}

- (void) synchronizeAllWindowsForceRedraw: (BOOL)forceRedraw
{
  NSArray *windows = nil;
  NSEnumerator *enumerator = nil;
  NSWindow *window = nil;

  if (NSApp == nil)
    {
      return;
    }

  windows = [NSApp windows];
  enumerator = [windows objectEnumerator];
  while ((window = [enumerator nextObject]) != nil)
    {
      [self synchronizeWindow: window forceRedraw: forceRedraw];
    }
}

- (void) synchronizeWindow: (NSWindow *)window forceRedraw: (BOOL)forceRedraw
{
#ifdef _WIN32
  NSString *key = nil;
  NSNumber *previousScale = nil;
  CGFloat scaleFactor = 1.0;
  BOOL scaleChanged = NO;

  if (window == nil)
    {
      return;
    }

  key = WinUIThemeWindowCacheKey(window);
  if (WinUIThemeShouldManageWindow(window) == NO || _theme == nil)
    {
      if ([_windowScaleFactors objectForKey: key] != nil)
        {
          WinUIThemeApplyWindowIdentity(window, nil, YES);
          [_windowScaleFactors removeObjectForKey: key];
        }
      return;
    }

  scaleFactor = WinUIThemeScaleFactorForWindow(window, [_theme settings]);
  previousScale = [_windowScaleFactors objectForKey: key];
  scaleChanged = (previousScale == nil
                  || fabs([previousScale doubleValue] - scaleFactor) > 0.001);
  [_windowScaleFactors setObject: [NSNumber numberWithDouble: scaleFactor]
                          forKey: key];

  WinUIThemeApplyWindowIdentity(window, _theme, NO);

  if (forceRedraw || scaleChanged)
    {
      [window setViewsNeedDisplay: YES];
      [window invalidateShadow];
      [window displayIfNeeded];
    }
#else
  (void)window;
  (void)forceRedraw;
#endif
}

- (void) forgetWindow: (NSWindow *)window
{
#ifdef _WIN32
  if (window != nil)
    {
      [_windowScaleFactors removeObjectForKey: WinUIThemeWindowCacheKey(window)];
    }
#else
  (void)window;
#endif
}

- (void) restoreAllWindows
{
#ifdef _WIN32
  NSArray *windows = nil;
  NSEnumerator *enumerator = nil;
  NSWindow *window = nil;

  if (NSApp == nil)
    {
      return;
    }

  windows = [NSApp windows];
  enumerator = [windows objectEnumerator];
  while ((window = [enumerator nextObject]) != nil)
    {
      if (window != nil && WinUIThemeWindowHandle(window) != NULL)
        {
          WinUIThemeApplyWindowIdentity(window, nil, YES);
          WinUIThemeForgetPopupCorners(window);
        }
    }
  [_windowScaleFactors removeAllObjects];
#endif
}

- (void) windowBecameKey: (NSNotification *)notification
{
#ifdef _WIN32
  WinUIThemeTabTakeOverPlacement([notification object]);
#endif
  [self _refreshThemeIfSystemStateChanged];
  [self synchronizeWindow: [notification object] forceRedraw: NO];
}

- (void) windowResignedKey: (NSNotification *)notification
{
#ifdef _WIN32
  WinUIThemeTabResignedKey([notification object]);
#endif
  [self _refreshThemeIfSystemStateChanged];
  [self synchronizeWindow: [notification object] forceRedraw: NO];
}

- (void) windowMoved: (NSNotification *)notification
{
  [self synchronizeWindow: [notification object] forceRedraw: NO];
}

- (void) windowResized: (NSNotification *)notification
{
  [self synchronizeWindow: [notification object] forceRedraw: NO];
}

- (void) windowChangedScreen: (NSNotification *)notification
{
  [self _refreshThemeIfSystemStateChanged];
  [self synchronizeWindow: [notification object] forceRedraw: YES];
}

- (void) windowWillClose: (NSNotification *)notification
{
#ifdef _WIN32
  if (WinUIThemeLastResignedKeyWindow == [notification object])
    {
      WinUIThemeLastResignedKeyWindow = nil;
    }
#endif
  [self forgetWindow: [notification object]];
}

- (void) screenParametersChanged: (NSNotification *)notification
{
  (void)notification;
  [self _refreshThemeIfSystemStateChanged];
  [self synchronizeAllWindowsForceRedraw: YES];
}

@end

/* A menu bar makes a window taller (-[GSWindowDecorationView addMenuView:]
   grows the frame by the bar). The theme gives a window made after launch
   the main menu's bar when it becomes key or main (#1), and libs-gui may
   add it to every window when the menu changes; a tab (#72) has by then
   taken its group's frame, so each new tab grew the group by a menu bar.
   A window tabbed with others keeps its frame, and its content gives up
   the row. The shared tabbing code (4cb1b63) gives a selected tab its
   group's frame but doesn't see a menu bar added later, so this stays
   (QuirkProbe window-tab-keeps-group-frame fails without it). */
@interface GSWindowDecorationView (WinUIThemeMenuView)
- (void) addMenuView: (NSMenuView *)menuView;
@end

static void
WinUIThemeKeepTabFrame(NSWindow *window, NSRect frame)
{
  if ([window respondsToSelector: @selector(tabbedWindows)]
      && [[window tabbedWindows] count] > 1
      && NSEqualRects([window frame], frame) == NO)
    {
      [window setFrame: frame display: YES];
    }
}

@implementation WinUIThemeBackendWindowDecorationView

- (void) setWindowNumber: (int)theWindowNumber
{
  [super setWindowNumber: theWindowNumber];

  if (theWindowNumber == 0)
    {
      WinUIThemeWindowIntegrationForgetWindow(window);
    }
  else
    {
      WinUIThemeWindowIntegrationSynchronizeWindow(window);
    }
}

- (void) setInputState: (int)state
{
  [super setInputState: state];
  WinUIThemeWindowIntegrationSynchronizeWindow(window);
}

- (void) addMenuView: (NSMenuView *)menuView
{
  NSRect frame = [window frame];

  [super addMenuView: menuView];
  WinUIThemeKeepTabFrame(window, frame);
}

@end

@implementation WinUIThemeStandardWindowDecorationView

- (void) setWindowNumber: (int)theWindowNumber
{
  [super setWindowNumber: theWindowNumber];

  if (theWindowNumber == 0)
    {
      WinUIThemeWindowIntegrationForgetWindow(window);
    }
  else
    {
      WinUIThemeWindowIntegrationSynchronizeWindow(window);
    }
}

- (void) setInputState: (int)state
{
  [super setInputState: state];
  WinUIThemeWindowIntegrationSynchronizeWindow(window);
}

- (void) addMenuView: (NSMenuView *)menuView
{
  NSRect frame = [window frame];

  [super addMenuView: menuView];
  WinUIThemeKeepTabFrame(window, frame);
}

@end

void
WinUIThemeWindowIntegrationActivate(WinUITheme *theme)
{
  if (theme == nil)
    {
      return;
    }

  if (WinUIThemeSharedWindowIntegration == nil)
    {
      WinUIThemeSharedWindowIntegration =
        [[WinUIThemeWindowIntegrationController alloc] initWithTheme: theme];
      return;
    }

  [WinUIThemeSharedWindowIntegration updateTheme: theme];
}

void
WinUIThemeWindowIntegrationDeactivate(void)
{
  if (WinUIThemeSharedWindowIntegration != nil)
    {
      [WinUIThemeSharedWindowIntegration restoreAllWindows];
      DESTROY(WinUIThemeSharedWindowIntegration);
    }
}

void
WinUIThemeWindowIntegrationReloadTheme(WinUITheme *theme)
{
  if (WinUIThemeSharedWindowIntegration != nil)
    {
      [WinUIThemeSharedWindowIntegration updateTheme: theme];
    }
}

void
WinUIThemeWindowIntegrationSynchronizeWindow(NSWindow *window)
{
  if (WinUIThemeSharedWindowIntegration != nil)
    {
      [WinUIThemeSharedWindowIntegration synchronizeWindow: window
                                               forceRedraw: NO];
    }
}

void
WinUIThemeWindowIntegrationForgetWindow(NSWindow *window)
{
  if (WinUIThemeSharedWindowIntegration != nil)
    {
      [WinUIThemeSharedWindowIntegration forgetWindow: window];
    }
}

/* Menus and tool tips (#39): asks DWM to round an untitled popup window,
   as Windows 11 rounds its own menus and tool tips, and to draw its border
   in the theme's colour. Windows 10 refuses, and Windows 11 doesn't round
   without a GPU (a virtual machine's basic display adapter), so the theme
   draws the border itself as well; DWM's covers it where it rounds. Asked
   once per window and colour. */
static char WinUIThemePopupCornerKey;

static void
WinUIThemeForgetPopupCorners(NSWindow *window)
{
  objc_setAssociatedObject(window, &WinUIThemePopupCornerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void
WinUIThemeWindowIntegrationRoundPopupWindow(NSWindow *window,
                                            BOOL small,
                                            NSColor *borderColor)
{
#ifdef _WIN32
  HWND hwnd = WinUIThemeWindowHandle(window);
  DWM_WINDOW_CORNER_PREFERENCE preference = small ? DWMWCP_ROUNDSMALL : DWMWCP_ROUND;
  COLORREF border = WinUIThemeColorRefFromColor(borderColor != nil ? borderColor
                                                                   : [NSColor windowFrameColor]);
  NSString *request = nil;

  if (hwnd == NULL)
    {
      return;
    }

  request = [NSString stringWithFormat: @"%p-%d-%lu", hwnd, (int)small, (unsigned long)border];
  if ([request isEqualToString: objc_getAssociatedObject(window, &WinUIThemePopupCornerKey)])
    {
      return;
    }

  WinUIThemeSetDwmAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &preference, sizeof(preference));
  WinUIThemeSetDwmAttribute(hwnd, DWMWA_BORDER_COLOR, &border, sizeof(border));
  objc_setAssociatedObject(window, &WinUIThemePopupCornerKey, request, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
#else
  (void)window;
  (void)small;
  (void)borderColor;
#endif
}
