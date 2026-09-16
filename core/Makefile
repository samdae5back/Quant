# Standalone build of the C kernels. cabal compiles the same sources for the
# Haskell packages; this Makefile exists for C-only unit tests, sanitizer runs,
# and producing a shared library that other languages (e.g. Python) can load.

CC      ?= cc
CFLAGS  ?= -std=c11 -O2 -Wall -Wextra -Werror -Iinclude
SRC     := $(wildcard cbits/*.c)
OBJ     := $(SRC:cbits/%.c=build/%.o)
TESTSRC := $(wildcard ctest/*.c)

ifeq ($(shell uname -s),Darwin)
  SHARED  := build/libqcore.dylib
  SHFLAGS := -dynamiclib
else
  SHARED  := build/libqcore.so
  SHFLAGS := -shared
endif

.PHONY: all static shared test asan clean

all: static shared

static: build/libqcore.a
shared: $(SHARED)

build/%.o: cbits/%.c include/qcore/*.h
	@mkdir -p build
	$(CC) $(CFLAGS) -fPIC -c $< -o $@

build/libqcore.a: $(OBJ)
	ar rcs $@ $^

$(SHARED): $(OBJ)
	$(CC) $(SHFLAGS) -o $@ $^ -lm

test: $(OBJ)
	$(CC) $(CFLAGS) -Ictest $(TESTSRC) $(OBJ) -lm -o build/ctest
	./build/ctest

asan:
	@mkdir -p build
	$(CC) -std=c11 -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer \
	    -Iinclude -Ictest $(TESTSRC) $(SRC) -lm -o build/ctest-asan
	./build/ctest-asan

clean:
	rm -rf build
