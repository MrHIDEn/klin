# := so a host CC from the environment (e.g. Homebrew/clang) does not win
CC := arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m4 -mthumb -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T linker.ld -Wl,--gc-sections -nostdlib
KLIN := ../../../bin/klin.dart
KLIN_SRCS := $(KLIN) $(wildcard ../../../lib/*.dart) $(wildcard ../../../lib/svd/*.dart)
REGS_H := stm32f411_regs.h
REGS_KL := stm32f411_regs.kl

.PHONY: all get clean

all: blink.elf

get:
	dart run $(KLIN) get

# @[link] paths land in out/blink.link (issue 022).
LINK_OBJS := $(shell test -f out/blink.link && cat out/blink.link)

out/blink.c out/blink.link $(REGS_H) $(REGS_KL): blink.kl klin.mod $(KLIN_SRCS)
	dart run $(KLIN) --emit-c blink.kl

blink.elf: linker.ld out/blink.c out/blink.link $(REGS_H) $(LINK_OBJS)
	$(CC) $(CFLAGS) -I. $(LDFLAGS) $$(cat out/blink.link) out/blink.c -o $@

clean:
	rm -rf out blink.elf $(REGS_H) $(REGS_KL)
