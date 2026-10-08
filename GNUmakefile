# This file is part of the GNUstep WinUI theme.

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = WinUITheme
BUNDLE_NAME = WinUITheme
BUNDLE_EXTENSION = .theme
VERSION = 0.1.0-phase9

WinUITheme_PRINCIPAL_CLASS = WinUITheme
WinUITheme_INSTALL_DIR = $(GNUSTEP_LIBRARY)/Themes
# WinUIThemeInfo.plist (the theme's GSThemeDomain, images and details) is
# merged into the bundle's generated Info-gnustep.plist by gnustep-make. Listed
# as a resource instead, it raced the generated file: a clean build shipped a
# plist without GSThemeDomain.
WinUITheme_RESOURCE_FILES = \
	Resources/ThemeImages \
	Resources/ThemeTiles

WinUITheme_OBJC_FILES = \
	Source/WinUITheme.m \
	Source/Settings/WinUIThemeSettings.m \
	Source/Settings/WinUIThemeMetrics.m \
	Source/Rendering/WinUIThemePalette.m \
	Source/Rendering/WinUIThemeDrawing.m \
	Source/Rendering/WinUIThemeControls.m 	Source/Rendering/WinUIThemeLevelIndicator.m \
	Source/Rendering/WinUIThemeDatePicker.m \
	Source/Rendering/WinUIThemeBrowser.m \
	Source/Rendering/WinUIThemeColorWell.m \
	Source/Rendering/WinUIThemeBoxes.m \
	Source/Rendering/WinUIThemeMenusAndData.m \
	Source/Rendering/WinUIThemeMenuTracking.m \
	Source/Rendering/WinUIThemeApplicationMenu.m \
	Source/Rendering/WinUIThemeAlerts.m \
	Source/Rendering/WinUIThemeTemplateImages.m \
	Source/Rendering/WinUIThemeToolbar.m \
	Source/Rendering/WinUIThemeHover.m \
	Source/Rendering/WinUIThemeScrollers.m \
	Source/Rendering/WinUIThemeFocus.m \
	Source/Native/WinUIThemeShellDialogs.m \
	Source/Native/WinUIThemeWindowIntegration.m

WinUITheme_BUNDLE_LIBS += -luuid -lgdi32

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble
