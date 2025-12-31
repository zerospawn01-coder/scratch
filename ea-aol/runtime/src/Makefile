# EA-AOL Runtime Makefile
# Simple build system for v0.1

CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -I../include -I../../runtime/include
LDFLAGS = -lm -lpthread

# Source files
SRCS = ea_ir_loader.c \
       ea_runtime_core.c \
       hal/ea_hal_nvidia.c

OBJS = $(SRCS:.c=.o)

# Targets
TARGET = ea_runtime_test

# Build rules
all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) -o $@ $^ $(LDFLAGS) -DEA_RUNTIME_STANDALONE
	@echo "Build complete: $(TARGET)"

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Clean
clean:
	rm -f $(OBJS) $(TARGET)
	@echo "Clean complete"

# Test
test: $(TARGET)
	@echo "Running runtime test..."
	./$(TARGET) ../../output/mixtral_secure.ir.json

# Install
install: $(TARGET)
	install -m 755 $(TARGET) /usr/local/bin/

.PHONY: all clean test install
