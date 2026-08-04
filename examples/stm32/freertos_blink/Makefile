# Nucleo-F411RE FreeRTOS blink (issue 028).
# Default: emit-c + arm-none-eabi object compile against freertos_stubs.
# Full ELF: make elf FREERTOS_DIR=/path/to/FreeRTOS-Kernel (uses FreeRTOSConfig.h here).
# Overhead: make compare FREERTOS_DIR=… → overhead.md (Klin vs blink_ref.c).

CC := arm-none-eabi-gcc
CFLAGS := -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard \
	-ffreestanding -Os -ffunction-sections -fdata-sections
# nano/nosys for memset and friends used by the FreeRTOS heap/TCB paths
LDFLAGS := -T linker.ld -Wl,--gc-sections -specs=nano.specs -specs=nosys.specs

KLIN ?= ../../../bin/klin.dart
STUB_INC := freertos_stubs

# Path to FreeRTOS-Kernel root (include/, tasks.c, portable/GCC/ARM_CM4F, …).
FREERTOS_DIR ?=

FREERTOS_SRCS := \
	$(FREERTOS_DIR)/tasks.c \
	$(FREERTOS_DIR)/queue.c \
	$(FREERTOS_DIR)/list.c \
	$(FREERTOS_DIR)/portable/MemMang/heap_4.c \
	$(FREERTOS_DIR)/portable/GCC/ARM_CM4F/port.c

FREERTOS_INC := -I. -I$(FREERTOS_DIR)/include -I$(FREERTOS_DIR)/portable/GCC/ARM_CM4F

.PHONY: all clean emit elf ref compare

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

# Real kernel only — do NOT put freertos_stubs on -I (would shadow FreeRTOS.h).
elf: out/blink.c out/blink.link FreeRTOSConfig.h
	@test -n "$(FREERTOS_DIR)" || (echo "set FREERTOS_DIR to FreeRTOS-Kernel root"; exit 1)
	@test -f "$(FREERTOS_DIR)/include/FreeRTOS.h" || \
		(echo "FREERTOS_DIR missing include/FreeRTOS.h: $(FREERTOS_DIR)"; exit 1)
	$(CC) $(CFLAGS) $(FREERTOS_INC) $(LDFLAGS) \
		$$(cat out/blink.link) out/blink.c \
		$(FREERTOS_SRCS) \
		-o blink.elf
	@echo "ok: blink.elf"

# Hand-written C twin (same RTOS API surface as blink.kl).
ref: blink_ref.c startup.s FreeRTOSConfig.h
	@test -n "$(FREERTOS_DIR)" || (echo "set FREERTOS_DIR to FreeRTOS-Kernel root"; exit 1)
	$(CC) $(CFLAGS) $(FREERTOS_INC) $(LDFLAGS) \
		startup.s blink_ref.c \
		$(FREERTOS_SRCS) \
		-o blink_ref.elf
	@echo "ok: blink_ref.elf"

compare: elf ref
	chmod +x compare.sh
	./compare.sh blink.elf blink_ref.elf overhead.md
	@echo "ok: overhead.md"

clean:
	rm -rf out blink.elf blink_ref.elf
