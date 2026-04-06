include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = ThemeDemo

# Prefer the clang64 GNUstep import libraries so the demo links against the
# same gnustep-base generation as gnustep-gui-0.dll on this machine.
ADDITIONAL_LDFLAGS += -L/clang64/lib

ThemeDemo_OBJC_FILES = \
	main.m \
	TDAppDelegate.m \
	TDContractLoader.m

ThemeDemo_RESOURCE_FILES = \
	../Shared/PageContract/theme-demo-pages.json

include $(GNUSTEP_MAKEFILES)/application.make

# pl2link is unreliable in this Windows/MSYS GNUstep setup, but the demo only
# needs a minimal launcher entry for bundle completeness.
$(APP_DIR)/Resources/$(GNUSTEP_INSTANCE).desktop: $(APP_INFO_PLIST_FILE)
	echo "[Desktop Entry]" > $@
	echo "Type=Application" >> $@
	echo "Categories=X-GNUstep;" >> $@
	echo "Exec=$(GNUSTEP_SYSTEM_TOOLS)/openapp $(GNUSTEP_INSTANCE)" >> $@
	chmod a+x $@
