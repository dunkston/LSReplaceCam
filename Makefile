DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LSReplaceCam
LSReplaceCam_FILES = LSReplaceCam.xm

include $(THEOS_MAKE_PATH)/tweak.mk

export COPYFILE_DISABLE = 1

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"