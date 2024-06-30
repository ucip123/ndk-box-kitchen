APP_ABI := armeabi-v7a arm64-v8a
APP_PLATFORM := android-35
APP_CFLAGS := -Wall -fomit-frame-pointer -Ofast -mllvm -polly -mllvm -polly-parallel -fuse-ld=lld -flto
APP_LDFLAGS := -flto

ifeq ($(OS),Windows_NT)
APP_SHORT_COMMANDS := true
endif
