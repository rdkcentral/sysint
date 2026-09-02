/*
 * Copyright 2026 RDK Management
 *
 * Licensed under the Apache License, Version 2.0.
 */

#include "common_device_api.h"

/*
 * Checks whether secure debug services are unlocked.
 *
 * Exit status:
 *   0 - debug services are unlocked
 *   1 - debug services are locked
 */
int main(void)
{
    return RDK_isDbgSrvUnlocked() ? 0 : 1;
}
