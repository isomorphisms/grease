#include <android/sensor.h>

#include <stdio.h>

int main(void) {
    ASensorManager *manager = ASensorManager_getInstance();
    if (manager == NULL) {
        fputs("sensors: Android sensor manager is unavailable\n", stderr);
        return 1;
    }

    ASensorList sensors = NULL;
    int count = ASensorManager_getSensorList(manager, &sensors);
    if (count < 0) {
        fputs("sensors: Android sensor list failed\n", stderr);
        return 1;
    }

    puts("type\tname\tvendor\tresolution\tmin_delay_us");

    for (int i = 0; i < count; ++i) {
        const ASensor *sensor = sensors[i];
        const char *name = ASensor_getName(sensor);
        const char *vendor = ASensor_getVendor(sensor);

        printf("%d\t%s\t%s\t%.9g\t%d\n",
               ASensor_getType(sensor),
               name == NULL ? "" : name,
               vendor == NULL ? "" : vendor,
               ASensor_getResolution(sensor),
               ASensor_getMinDelay(sensor));
    }

    return 0;
}
