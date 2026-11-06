CC ?= clang
CFLAGS ?= -O2 -Wall
all: test
test: tests/test_idle_logic tests/test_playback_control
	./tests/test_idle_logic
	./tests/test_playback_control
tests/test_idle_logic: tests/test_idle_logic.c idle_logic.c idle_logic.h
	$(CC) $(CFLAGS) -o $@ tests/test_idle_logic.c idle_logic.c
tests/test_playback_control: tests/test_playback_control.c playback_control.c playback_control.h
	$(CC) $(CFLAGS) -o $@ tests/test_playback_control.c playback_control.c
android:
	./build-android.sh
hosttest: android
	python3 -I tests/test_daemon_host.py
	python3 -I tests/test_playback_host.py
clean:
	rm -f tests/test_idle_logic tests/test_playback_control idle_dim
.PHONY: all test android hosttest clean
