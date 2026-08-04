#ifndef TASK_H
#define TASK_H

#include "FreeRTOS.h"

BaseType_t xTaskCreate(
    TaskFunction_t pvTaskCode,
    const char *pcName,
    uint32_t usStackDepth,
    void *pvParameters,
    uint32_t uxPriority,
    TaskHandle_t *pxCreatedTask
);

void vTaskDelay(TickType_t xTicksToDelay);
void vTaskStartScheduler(void);
void vTaskDelete(TaskHandle_t xTaskToDelete);

/* Real FreeRTOS: macro → portYIELD_FROM_ISR. Stub is a no-op function-like macro. */
#ifndef taskYIELD_FROM_ISR
#define taskYIELD_FROM_ISR(x) do { (void)(x); } while (0)
#endif

#endif
