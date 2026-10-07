# This file is part of the GNUstep WinUI theme.

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = QuirkProbe
QuirkProbe_APPLICATION_ICON =
QuirkProbe_PRINCIPAL_CLASS = NSApplication

QuirkProbe_OBJC_FILES = \
	main.m \
	QuirkProbe.m

QuirkProbe_HEADER_FILES = \
	QuirkProbe.h

ADDITIONAL_LDFLAGS += -L/clang64/lib
ADDITIONAL_OBJCFLAGS += -Wno-import

include $(GNUSTEP_MAKEFILES)/application.make
