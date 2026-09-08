#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const int observed_process_contract_status = 73;
static const int incoming_data_could_not_be_read_status = 74;

static void print_environment(const char *name) {
    const char *value = getenv(name);
    if (value == NULL) {
        printf("environment[%s]=absent\n", name);
    } else {
        size_t length = strlen(value);
        printf("environment[%s]=%zu:", name, length);
        fwrite(value, 1, length, stdout);
        putchar('\n');
    }
}

int main(int count, char **values) {
    printf("argv-count=%d\n", count);
    for (int index = 0; index < count; index++) {
        size_t length = strlen(values[index]);
        printf("argv[%d]=%zu:", index, length);
        fwrite(values[index], 1, length, stdout);
        putchar('\n');
    }
    print_environment("ISH_ACCEPTANCE_VALUE");
    print_environment("LD_LIBRARY_PATH");
    print_environment("DYLD_LIBRARY_PATH");
    print_environment("IDRIS2_INC_SRC");
    print_environment("__ISH_LAUNCH_ENVIRONMENT");

    unsigned char incoming[128];
    size_t incoming_count = fread(incoming, 1, sizeof(incoming), stdin);
    if (ferror(stdin)) {
        return incoming_data_could_not_be_read_status;
    }
    printf("incoming=%zu:", incoming_count);
    fwrite(incoming, 1, incoming_count, stdout);
    putchar('\n');
    return observed_process_contract_status;
}
