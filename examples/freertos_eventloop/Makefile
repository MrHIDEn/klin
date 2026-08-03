# Emit Klin → C with stub FreeRTOS headers on the include path.
# Real boards: replace STUB_INC with your FreeRTOS include dirs and link the kernel.

KLIN ?= ../../bin/klin.dart
STUB_INC := freertos_stubs
CC ?= gcc

.PHONY: all clean

all:
	mkdir -p out
	dart run $(KLIN) --emit-c app.kl
	@# Klin writes under ./out/ relative to CWD; keep artifacts here.
	$(CC) -c -I$(STUB_INC) -o out/app.o out/app.c
	@echo "ok: out/app.c out/app.o"

clean:
	rm -rf out
