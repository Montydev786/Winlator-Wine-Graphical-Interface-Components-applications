# Cross-compile MontyShell.exe with mingw-w64 (Linux/macOS/WSL) or MSYS2.
#   make            -> 64-bit build/MontyShell.exe
#   make ARCH=i686  -> 32-bit build (use this one if your Winlator container is 32-bit)
#   make installer  -> build/MontyShell-Setup-ARCH.exe (needs NSIS: makensis)
ARCH   ?= x86_64
CC      = $(ARCH)-w64-mingw32-gcc
WINDRES = $(ARCH)-w64-mingw32-windres
CFLAGS  = -std=gnu11 -O2 -Wall -Wno-unused-function -Wno-unused-variable -DUNICODE -D_UNICODE \
          -D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -ffunction-sections -fdata-sections
LDFLAGS = -mwindows -s -Wl,--gc-sections -static-libgcc
LIBS    = -lgdi32 -luser32 -lmsimg32 -lcomdlg32 -lshell32 -lole32 -luuid -liphlpapi -lws2_32 -ladvapi32 -lcomctl32

SRC = $(wildcard src/*.c)
OBJ = $(patsubst src/%.c,build/%.o,$(SRC))

all: build/MontyShell.exe

build/%.o: src/%.c src/*.h | build
	$(CC) $(CFLAGS) -c $< -o $@

build/MontyShell.exe: $(OBJ)
	$(CC) $(OBJ) -o $@ $(LDFLAGS) $(LIBS)

build:
	mkdir -p build

installer: build/MontyShell.exe
	makensis -DARCH=$(ARCH) installer/setup.nsi

clean:
	rm -rf build

.PHONY: all installer clean
