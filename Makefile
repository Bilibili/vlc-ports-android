# Sources and objects

ifeq ($(NO_NEON),)
ARCH = armeabi-v7a
else
ARCH = armeabi
endif

SRC=vlc-android
JAVA_SOURCES=$(SRC)/src/org/videolan/vlc/*.java
JNI_SOURCES=$(SRC)/jni/*.c $(SRC)/jni/*.h
VLC_APK=$(SRC)/bin/VLC-debug.apk
LIBVLCJNI=	\
	$(SRC)/obj/local/$(ARCH)/libvlcjni.so \
	$(SRC)/obj/local/$(ARCH)/libiomx-ics.so \
	$(SRC)/obj/local/$(ARCH)/libiomx-gingerbread.so \

LIBVLCJNI_H=$(SRC)/jni/libvlcjni.h

PRIVATE_LIBDIR=android-libs
PRIVATE_LIBS=$(PRIVATE_LIBDIR)/libstagefright.so $(PRIVATE_LIBDIR)/libmedia.so $(PRIVATE_LIBDIR)/libutils.so $(PRIVATE_LIBDIR)/libbinder.so

ifneq ($(V),)
ANT_OPTS += -v
VERBOSE =
GEN =
else
VERBOSE = @
GEN = @echo "Generating" $@;
endif

$(VLC_APK): $(LIBVLCJNI) $(JAVA_SOURCES)
	@echo
	@echo "=== Building $@ for $(ARCH) ==="
	@echo
	$(VERBOSE)cd $(SRC) && ant $(ANT_OPTS) debug

VLC_MODULES=`find $(VLC_BUILD_DIR)/modules -name 'lib*_plugin.a'|grep -v -E "stats|access_bd|oldrc|real|hotkeys|gestures|sap|dynamicoverlay|rss|logo|libball|bargraph|clone|access_shm|mosaic|logo|imem|osdmenu|puzzle|mediadirs|t140|ripple|motion|sharpen|grain|posterize|mirror|wall|scene|blendbench|psychedelic|alphamask|netsync|audioscrobbler|imem|motiondetect|export|smf|podcast|bluescreen|erase|record|speex_resampler|remoteosd|magnify|gradient|spdif" | tr \\\\n \ `

$(LIBVLCJNI_H):
	$(VERBOSE)if [ -z "$(VLC_BUILD_DIR)" ]; then echo "VLC_BUILD_DIR not defined" ; exit 1; fi
	$(GEN)modules="$(VLC_MODULES)" ; \
	if [ -z "$$modules" ]; then echo "No VLC modules found in $(VLC_BUILD_DIR)/modules"; exit 1; fi; \
	DEFINITION=""; \
	BUILTINS="const void *vlc_static_modules[] = {\n"; \
	for file in $$modules; do \
		name=`echo $$file | sed 's/.*\.libs\/lib//' | sed 's/_plugin\.a//'`; \
		DEFINITION=$$DEFINITION"int vlc_entry__$$name (int (*)(void *, void *, int, ...), void *);\n"; \
		BUILTINS="$$BUILTINS vlc_entry__$$name,\n"; \
	done; \
	BUILTINS="$$BUILTINS NULL\n};\n"; \
	printf "/* Autogenerated from the list of modules */\n $$DEFINITION\n $$BUILTINS\n" > $@

$(PRIVATE_LIBDIR)/%.so: $(PRIVATE_LIBDIR)/%.c
	$(GEN)arm-linux-androideabi-gcc $< -shared -o $@ --sysroot=$(ANDROID_NDK)/platforms/android-3/arch-arm

$(PRIVATE_LIBDIR)/%.c: $(PRIVATE_LIBDIR)/%.symbols
	$(VERBOSE)rm -f $@
	$(GEN)for s in `cat $<`; do echo "void $$s() {}" >> $@; done

$(LIBVLCJNI): $(JNI_SOURCES) $(LIBVLCJNI_H) $(PRIVATE_LIBS)
	@if [ -z "$(VLC_BUILD_DIR)" ]; then echo "VLC_BUILD_DIR not defined" ; exit 1; fi
	@if [ -z "$(ANDROID_NDK)" ]; then echo "ANDROID_NDK not defined" ; exit 1; fi
	@echo
	@echo "=== Building libvlcjni with$${NO_NEON:+out} neon ==="
	@echo
	$(VERBOSE)if [ -z "$(VLC_SRC_DIR)" ] ; then VLC_SRC_DIR=./vlc; fi ; \
	if [ -z "$(VLC_CONTRIB)" ] ; then VLC_CONTRIB="$$VLC_SRC_DIR/contrib/arm-linux-androideabi"; fi ; \
	vlc_modules="$(VLC_MODULES)" ; \
	if [ `echo "$(VLC_BUILD_DIR)" | head -c 1` != "/" ] ; then \
		vlc_modules="`echo $$vlc_modules|sed \"s|$(VLC_BUILD_DIR)|../$(VLC_BUILD_DIR)|g\"`" ; \
        VLC_BUILD_DIR="../$(VLC_BUILD_DIR)"; \
	fi ; \
	[ `echo "$$VLC_CONTRIB" | head -c 1` != "/" ] && VLC_CONTRIB="../$$VLC_CONTRIB"; \
	[ `echo "$$VLC_SRC_DIR" | head -c 1` != "/" ] && VLC_SRC_DIR="../$$VLC_SRC_DIR"; \
	$(ANDROID_NDK)/ndk-build -C $(SRC) \
		VLC_SRC_DIR="$$VLC_SRC_DIR" \
		VLC_CONTRIB="$$VLC_CONTRIB" \
		VLC_BUILD_DIR="$$VLC_BUILD_DIR" \
		VLC_MODULES="$$vlc_modules"

clean:
	cd $(SRC) && rm -rf gen libs obj bin $(VLC_APK)
	rm -f $(PRIVATE_LIBDIR)/*.so $(PRIVATE_LIBDIR)/*.c

distclean: clean
	rm -f $(LIBVLCJNI) $(LIBVLCJNI_H)

install: $(VLC_APK)
	@echo "=== Installing VLC on device ==="
	adb wait-for-device
	adb install -r $(VLC_APK)

run:
	@echo "=== Running VLC on device ==="
	adb wait-for-device
	adb shell monkey -p org.videolan.vlc -s 0 1

build-and-run: install run

.PHONY: clean distclean install run build-and-run
