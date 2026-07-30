#include <stdint.h>

#define REG32(address) (*(volatile uint32_t *)(address))

#define RCC_AHB1ENR REG32(0x40023830u)
#define GPIOA_MODER REG32(0x40020000u)
#define GPIOA_ODR REG32(0x40020014u)
#define SYST_CSR REG32(0xE000E010u)
#define SYST_RVR REG32(0xE000E014u)
#define SYST_CVR REG32(0xE000E018u)

void SysTick_Handler(void) {
  if (GPIOA_ODR == 0) {
    GPIOA_ODR = 32;
  } else {
    GPIOA_ODR = 0;
  }
}

int main(void) {
  RCC_AHB1ENR = 1;
  GPIOA_MODER = 0x00000400;
  SYST_RVR = 7999999;
  SYST_CVR = 0;
  SYST_CSR = 7;
  while (1) {
    __asm volatile("wfi");
  }
}
