ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES = FreeFire

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = AudioCore

AudioCore_FILES = main.mm il2cpp.mm ESP.mm Aimbot.mm Menu.mm
AudioCore_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
AudioCore_CFLAGS = -fobjc-arc -std=c++17 -O2 -fvisibility=hidden -fno-exceptions
AudioCore_LDFLAGS = -undefined dynamic_lookup

include $(THEOS)/makefiles/library.mk