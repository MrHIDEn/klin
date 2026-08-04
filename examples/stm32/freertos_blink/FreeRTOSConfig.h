/* Minimal FreeRTOSConfig for Nucleo-F411RE blink (issue 028).
 * Used by `make elf FREERTOS_DIR=…` — not by stub emit-c checks.
 * Tune heap / tick / clock to your board bring-up. */
#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

#include <stdint.h>

#define configUSE_PREEMPTION                         1
#define configUSE_PORT_OPTIMISED_TASK_SELECTION      1
#define configUSE_IDLE_HOOK                          0
#define configUSE_TICK_HOOK                          0
#define configCPU_CLOCK_HZ                           (16000000UL) /* HSI default; raise after PLL */
#define configTICK_RATE_HZ                           ((TickType_t)1000)
#define configMAX_PRIORITIES                         5
#define configMINIMAL_STACK_SIZE                     ((uint16_t)128)
#define configTOTAL_HEAP_SIZE                        ((size_t)(16 * 1024))
#define configMAX_TASK_NAME_LEN                      16
#define configUSE_16_BIT_TICKS                       0
#define configIDLE_SHOULD_YIELD                      1
#define configUSE_MUTEXES                            1
#define configUSE_COUNTING_SEMAPHORES                0
#define configUSE_RECURSIVE_MUTEXES                  0
#define configQUEUE_REGISTRY_SIZE                    0
#define configUSE_TIMERS                             0
#define configCHECK_FOR_STACK_OVERFLOW               0
#define configUSE_MALLOC_FAILED_HOOK                 0

#define configSUPPORT_STATIC_ALLOCATION              0
#define configSUPPORT_DYNAMIC_ALLOCATION             1

/* FreeRTOS-Kernel uses INCLUDE_* (not configINCLUDE_*). */
#define INCLUDE_vTaskDelay                           1
#define INCLUDE_vTaskDelete                          1
#define INCLUDE_xTaskGetSchedulerState               1
#define INCLUDE_vTaskPrioritySet                     0
#define INCLUDE_uxTaskPriorityGet                    0
#define INCLUDE_vTaskSuspend                         0
#define INCLUDE_xTaskDelayUntil                      0

/* Cortex-M4F: SysTick / PendSV / SVC provided by the FreeRTOS port. */
#ifdef __NVIC_PRIO_BITS
#define configPRIO_BITS                              __NVIC_PRIO_BITS
#else
#define configPRIO_BITS                              4
#endif
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY      15
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY 5
#define configKERNEL_INTERRUPT_PRIORITY \
    (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
#define configMAX_SYSCALL_INTERRUPT_PRIORITY \
    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))

#define xPortPendSVHandler    PendSV_Handler
#define vPortSVCHandler       SVC_Handler
#define xPortSysTickHandler   SysTick_Handler

#endif /* FREERTOS_CONFIG_H */
