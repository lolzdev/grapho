ROOT := ..
BUILD_DIR := $(ROOT)/build
LIB_DIR := $(BUILD_DIR)/lib
BIN_DIR := $(BUILD_DIR)/bin
TARGET := $(BIN_DIR)/grapho-linux

CC ?= cc
PKG_CONFIG ?= pkg-config
GTK_EXISTS := $(shell $(PKG_CONFIG) --exists gtk4 && echo yes)
GTK_CFLAGS := $(shell $(PKG_CONFIG) --cflags gtk4 2>/dev/null)
GTK_LIBS := $(shell $(PKG_CONFIG) --libs gtk4 2>/dev/null)

CFLAGS ?= -Wall -Wextra -O2
CPPFLAGS += -I$(ROOT)/ffi
LDFLAGS += -L$(LIB_DIR) -Wl,-rpath,$(abspath $(LIB_DIR))
LDLIBS += -lgrapho-core -lgrapho_runtime $(GTK_LIBS)

SRCS := \
	src/main.c \
	src/gtk_app.c \
	src/haskell_bridge.c \
	src/vulkan_renderer.c

OBJS := $(SRCS:src/%.c=$(BUILD_DIR)/linux/%.o)

.PHONY: all clean

all: $(TARGET)

ifeq ($(GTK_EXISTS),)
$(TARGET):
	$(error GTK4 development files were not found. Install gtk4 and ensure pkg-config can find gtk4.pc)
else

$(TARGET): $(OBJS)
	mkdir -p $(BIN_DIR)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LDLIBS)
endif

$(BUILD_DIR)/linux/%.o: src/%.c
	mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GTK_CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)/linux $(TARGET)
