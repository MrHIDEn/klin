# := so a host CC from the environment (e.g. Homebrew/clang) does not win
CC := arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m4 -mthumb -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T linker.ld -Wl,--gc-sections -nostdlib
KLIN := ../../bin/klin.dart
KLIN_SRCS := $(KLIN) $(wildcard ../../lib/*.dart)
REGS_H := stm32f411_regs.h
REGS_KL := stm32f411_regs.kl
SVD := ../../third_party/svd/stm32f411.svd

.PHONY: all ref clean

all: blink.elf

$(REGS_H) $(REGS_KL): $(SVD) $(wildcard ../../lib/svd/*.dart) ../../bin/svd2klin.dart
	dart run ../../bin/svd2klin.dart --svd $(SVD) --out-h $(REGS_H) --out-kl $(REGS_KL) --peripherals RCC,GPIOA,STK

out/blink.c: blink.kl $(REGS_KL) $(REGS_H) $(KLIN_SRCS)
	dart run $(KLIN) --emit-c blink.kl

blink.elf: startup.s linker.ld out/blink.c $(REGS_H)
	$(CC) $(CFLAGS) -I. $(LDFLAGS) startup.s out/blink.c -o $@

ref: startup.s linker.ld blink_ref.c $(REGS_H)
	$(CC) $(CFLAGS) -I. $(LDFLAGS) startup.s blink_ref.c -o blink_ref.elf

clean:
	rm -rf out blink.elf blink_ref.elf $(REGS_H) $(REGS_KL)
