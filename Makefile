TARGET := iphone:clang:latest:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AlanyGram

AlanyGram_FILES = Tweak/AlanyGram.x Tweak/AlanyGramSettings.m
AlanyGram_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
AlanyGram_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
