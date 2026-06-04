ROOT := $(CURDIR)
BUILD_DIR := $(ROOT)/build
LIB_DIR := $(BUILD_DIR)/lib
CABAL_BUILD_DIR := $(BUILD_DIR)/cabal

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  DYLIB_EXT := dylib
else
  DYLIB_EXT := so
endif

GHC_LIBDIR := $(shell ghc --print-libdir 2>/dev/null)
GHC_INCLUDE := $(shell dirname "$$(find "$(GHC_LIBDIR)" -name HsFFI.h -print -quit 2>/dev/null)")
RUNTIME_OBJ := $(BUILD_DIR)/ffi/grapho_runtime.o
RUNTIME_LIB := $(LIB_DIR)/libgrapho_runtime.a

.PHONY: core macos linux run-macos run-linux clean

core: $(RUNTIME_LIB)
	cd core && cabal v2-build --builddir=$(CABAL_BUILD_DIR)
	mkdir -p $(LIB_DIR)
	find $(CABAL_BUILD_DIR) -name 'libgrapho-core*.$(DYLIB_EXT)' -exec cp {} $(LIB_DIR)/ \;

$(RUNTIME_LIB): ffi/grapho_runtime.c ffi/grapho_api.h
	mkdir -p $(BUILD_DIR)/ffi $(LIB_DIR)
	$(CC) -Iffi -I$(GHC_INCLUDE) -c ffi/grapho_runtime.c -o $(RUNTIME_OBJ)
	ar rcs $@ $(RUNTIME_OBJ)

macos: core
	cd frontend-macos && swift build
	./scripts/bundle-macos.sh

linux: core
	$(MAKE) -C frontend-linux

run-macos: macos
	open -n build/GraphoMac.app

run-linux: linux
	./build/bin/grapho-linux

clean:
	rm -rf $(BUILD_DIR)
	cd core && cabal v2-clean || true
	cd frontend-macos && swift package clean || true
	$(MAKE) -C frontend-linux clean || true
