# This file is part of the GNUstep WinUI theme.

# A Gorm palette of controls at WinUI's sizes, for laying out apps that run
# with the theme's WinUI metrics (see the README).

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

PALETTE_NAME = WinUI
WinUI_PALETTE_ICON = WinUIPalette
WinUI_PRINCIPAL_CLASS = WinUIPalette
WinUI_OBJC_FILES = WinUIPalette.m
WinUI_RESOURCE_FILES = WinUIPalette.tiff palette.table

ADDITIONAL_OBJCFLAGS += -Wno-import

# A Windows DLL can't leave IBPalette to be found when Gorm loads it, so the
# palette links Gorm's InterfaceBuilder library, as Gorm's own palettes do.
# Against a Gorm that is built but not installed, add its source directory
# and library: ADDITIONAL_INCLUDE_DIRS=-I<gorm> and
# ADDITIONAL_LIB_DIRS=-L<gorm>/InterfaceBuilder/obj.
ifneq ($(findstring mingw,$(GNUSTEP_TARGET_OS))$(findstring cygwin,$(GNUSTEP_TARGET_OS))$(findstring windows,$(GNUSTEP_TARGET_OS)),)
ADDITIONAL_GUI_LIBS += -lInterfaceBuilder
endif

include $(GNUSTEP_MAKEFILES)/palette.make
