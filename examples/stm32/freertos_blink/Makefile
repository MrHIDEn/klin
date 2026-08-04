# Nucleo-F411RE FreeRTOS blink (issue 028).
# Default: emit-c + arm-none-eabi object compile against freertos_stubs.
# Full ELF needs a real FreeRTOS tree — see README (FREERTOS_DIR).

CC := arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m4 -mthumb -ffreestanding -Os -ffunction-sections -fdata-sections
LDFLAGS := -T linker.ld -Wl,--gc-sections -nostdlib

KLIN ?= ../../../bin/klin.dart
STUB_INC := freertos_stubs

# Optional: path to FreeRTOS kernel root (contains include/, tasks.c, portable/…).
FREERTOS_DIR ?=

.PHONY: all clean emit elf

all: out/blink.o
	@echo "ok: out/blink.c out/blink.o (stubs). For board ELF: make elf FREERTOS_DIR=…"

emit: out/blink.c

out:
	mkdir -p out

out/blink.c out/blink.link: blink.kl klin.mod klin.lock | out
	case "$(KLIN)" in \
	  *.dart) dart run "$(KLIN)" --emit-c blink.kl ;; \
	  *) "$(KLIN)" --emit-c blink.kl ;; \
	esac

out/blink.o: out/blink.c
	$(CC) $(CFLAGS) -c -I$(STUB_INC) -o out/blink.o out/blink.c

# Link only when FREERTOS_DIR points at a kernel + ARM_CM4F port.
# Expects include/, tasks.c, queue.c, list.c, timers.c (optional), heap_4.c,
# and portable/GCC/ARM_CM4F/{port.c,portmacro.h}. Adjust SRC list to your tree.
elf: out/blink.c out/blink.link
	@test -n "$(FREERTOS_DIR)" || (echo "set FREERTOS_DIR to FreeRTOS kernel root"; exit 1)
	$(CC) $(CFLAGS) -I. -I$(STUB_INC) -I$(FREERTOS_DIR)/include \
		-I$(FREERTOS_DIR)/portable/GCC/ARM_CM4F $(LDFLAGS) \
		$$(cat out/blink.link) out/blink.c \
		$(FREERTOS_DIR)/tasks.c \
		$(FREERTOS_DIR)/queue.c \
		$(FREERTOS_DIR)/list.c \
		$(FREERTOS_DIR)/portable/MemMang/heap_4.c \
		$(FREERTOS_DIR)/portable/GCC/ARM_CM4F/port.c \
		-o blink.elf
	@echo "ok: blink.elf"

clean:
	rm -rf out blink.elf
