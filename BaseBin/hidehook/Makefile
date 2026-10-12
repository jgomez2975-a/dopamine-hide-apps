TARGET = hidehook.dylib
CC = clang

CFLAGS = -I../.include -I./src -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -arch arm64 -arch arm64e -miphoneos-version-min=15.0 -install_name @loader_path/$(TARGET) -fobjc-arc -Wno-deprecated-declarations -Os
LDFLAGS = -dynamiclib -framework Foundation -framework UIKit -framework CoreFoundation -framework MobileCoreServices

sign: $(TARGET)
	@ldid -Cadhoc -S $^

$(TARGET): src/hidehook.m
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

clean:
	@rm -f $(TARGET)
