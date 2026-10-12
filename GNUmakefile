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
	Source/Rendering/WinUIThemeCellSizes.m \
	Source/Rendering/WinUIThemeMenusAndData.m \
	Source/Rendering/WinUIThemeMenuTracking.m \
	Source/Rendering/WinUIThemeMenuBarKeyboard.m \
	Source/Rendering/WinUIThemeApplicationMenu.m \
	Source/Rendering/WinUIThemeAlerts.m \
	Source/Rendering/WinUIThemeTemplateImages.m \
	Source/Rendering/WinUIThemeToolbar.m \
	Source/Rendering/WinUIThemeHover.m \
	Source/Rendering/WinUIThemeScrollers.m \
	Source/Rendering/WinUIThemeFocus.m \
	Source/Native/WinUIThemeShellDialogs.m \
	Source/Native/WinUIThemeWindowIntegration.m \
	Source/Rendering/WinUIThemeWindowTabs.m

# Window tabs (#72): Apple's NSWindow tabbing API from the shared
# gnustep-window-tabbing code, copied into Source/WindowTabbing at the commit
# the README gives. The directory is relative (gnustep-make puts objects at
# obj/<target>.obj/<source path>), and the files are added before
# bundle.make reads the lists. The theme draws the bar (WinUIThemeWindowTabs.m).
GSWINDOWTABBING_DIR = Source/WindowTabbing
include $(GSWINDOWTABBING_DIR)/GSWindowTabbing.make
WinUITheme_OBJC_FILES += $(GSWINDOWTABBING_OBJC_FILES)
ADDITIONAL_INCLUDE_DIRS += $(GSWINDOWTABBING_INCLUDE_DIRS)

WinUITheme_BUNDLE_LIBS += -luuid -lgdi32

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.postamble

# The Gorm palette of controls at WinUI's sizes (see the README).
.PHONY: palette installpalette

palette:
	$(MAKE) -C Palettes/WinUI

installpalette:
	$(MAKE) -C Palettes/WinUI install
