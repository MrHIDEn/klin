# 087 — `machine_gd32v`: GD32VF103 (Nuclei RISC-V) template → Pin…Adc

**Status:** 💭 template / stub (`@v0.0.0`); full MMIO after [086](086-machine-ch32v.md)  
**Depends on:** [061](061-micropython-machine-api.md), [062](062-targets-esp-rp.md), [086](086-machine-ch32v.md)

## Verdict

| Question | Answer |
|---|---|
| Change the Klin compiler? | **No** |
| Where does the code live? | External: [`klin-lang/machine_gd32v`](https://github.com/klin-lang/machine_gd32v) |
| Chip MVP | **GD32VF103** (Nuclei N205; Longan Nano–class) |
| Now | Repo **template**: stub `Pin` + `version()→0` + `examples/blink_pa1` emit-c |
| Next | Real MMIO Pin…Adc mirroring `machine_ch32v` shape (F1-style GPIO, Nuclei startup) |

## Why not one `machine_riscv`?

QingKe (CH32V) and Nuclei (GD32V) differ in vectors, CSR/ECLIC, and
toolchain ABI. Keep separate packages; share only the Klin API *names*.

## Order

1. Land [086](086-machine-ch32v.md) (`machine_ch32v` `@v0.1.0` published)
2. Create `klin-lang/machine_gd32v` and push stub
3. Implement Pin blink on Longan Nano (Nuclei gcc + OpenOCD)
4. Pwm → Uart → I2c → Spi → Adc

## Out of scope

- Combining with CH32V sources
- Full Nuclei SDK vendoring inside Klin
- Wi‑Fi GD32VW55x (later, separate if ever)

## Links

- CH32V full port: [086](086-machine-ch32v.md)
- API catalog: [061](061-micropython-machine-api.md)
