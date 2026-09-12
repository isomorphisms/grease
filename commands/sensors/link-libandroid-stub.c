void *ASensorManager_getInstance(void) { return 0; }
int ASensorManager_getSensorList(void *manager, const void ***list) {
    (void)manager;
    (void)list;
    return 0;
}
const char *ASensor_getName(const void *sensor) { (void)sensor; return 0; }
const char *ASensor_getVendor(const void *sensor) { (void)sensor; return 0; }
int ASensor_getType(const void *sensor) { (void)sensor; return 0; }
int ASensor_getMinDelay(const void *sensor) { (void)sensor; return 0; }
