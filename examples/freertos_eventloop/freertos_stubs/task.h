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

#endif
