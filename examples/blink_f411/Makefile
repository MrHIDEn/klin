CC ?= arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m4 -mthumb -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T linker.ld -Wl,--gc-sections -nostdlib
KLIN := ../../bin/klin.dart
KLIN_SRCS := $(KLIN) $(wildcard ../../lib/*.dart)

.PHONY: all ref clean

all: blink.elf

out/blink.c: blink.kl $(KLIN_SRCS)
	dart run $(KLIN) --emit-c blink.kl

blink.elf: startup.s linker.ld out/blink.c
	$(CC) $(CFLAGS) $(LDFLAGS) startup.s out/blink.c -o $@

ref: startup.s linker.ld blink_ref.c
	$(CC) $(CFLAGS) $(LDFLAGS) startup.s blink_ref.c -o blink_ref.elf

clean:
	rm -rf out blink.elf blink_ref.elf
