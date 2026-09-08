#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

extern char **environ;

static const char *launch_environment_name = "__ISH_LAUNCH_ENVIRONMENT";
static const char *restored_environment_names[] = {
    "LD_LIBRARY_PATH",
    "DYLD_LIBRARY_PATH",
    "IDRIS2_INC_SRC",
    "__ISH_LAUNCH_ENVIRONMENT",
};

enum {
    decimal_radix = 10,
    encoded_presence_field_width = 2,
    decoded_input_extra_entries = 1,
    process_input_extra_entries = 2,
    overwrite_environment_value = 1,
};

typedef struct {
    bool present;
    char *value;
} environment_value;

/*
 * The Idriç/C boundary cannot pass a List Text directly. The private wire
 * format is:
 *
 *     input-count ':' byte-count ':' bytes ...
 *
 * Length framing preserves empty inputs and every non-NUL UTF-8 byte without
 * teaching the C primitive anything about shell source syntax.
 */

static int read_size(const char **cursor, size_t *result) {
    const unsigned char *at = (const unsigned char *)*cursor;
    size_t value = 0;

    if (!isdigit(*at)) {
        return EINVAL;
    }

    while (isdigit(*at)) {
        size_t digit = (size_t)(*at - '0');
        if (value > (SIZE_MAX - digit) / decimal_radix) {
            return EOVERFLOW;
        }
        value = value * decimal_radix + digit;
        at++;
    }

    if (*at != ':') {
        return EINVAL;
    }

    *cursor = (const char *)(at + 1);
    *result = value;
    return 0;
}

static void release_inputs(char **entries, size_t count) {
    if (entries == NULL) {
        return;
    }

    for (size_t index = 0; index < count; index++) {
        free(entries[index]);
    }
    free(entries);
}

static void release_environment(environment_value *values, size_t count) {
    for (size_t index = 0; index < count; index++) {
        free(values[index].value);
    }
}

/*
 * The native launcher temporarily adds paths needed by Chez. It stores the
 * caller's exact prior values in one reserved variable, including the prior
 * value of that variable itself. Restore all four before entering the
 * requested program.
 */
static int restore_launch_environment(void) {
    const char *state = getenv(launch_environment_name);
    if (state == NULL) {
        return 0;
    }

    const char *cursor = state;
    const size_t value_count =
        sizeof(restored_environment_names) / sizeof(restored_environment_names[0]);
    environment_value values[value_count];
    memset(values, 0, sizeof(values));

    for (size_t index = 0; index < value_count; index++) {
        if (*cursor == '0' && cursor[1] == ':') {
            cursor += encoded_presence_field_width;
            continue;
        }

        if (*cursor != '1') {
            release_environment(values, value_count);
            return EINVAL;
        }
        cursor++;

        size_t byte_count = 0;
        int error = read_size(&cursor, &byte_count);
        if (error != 0 || byte_count > strlen(cursor)) {
            release_environment(values, value_count);
            return error == 0 ? EINVAL : error;
        }

        values[index].value = malloc(byte_count + 1);
        if (values[index].value == NULL) {
            release_environment(values, value_count);
            return ENOMEM;
        }

        memcpy(values[index].value, cursor, byte_count);
        values[index].value[byte_count] = '\0';
        values[index].present = true;
        cursor += byte_count;
    }

    if (*cursor != '\0') {
        release_environment(values, value_count);
        return EINVAL;
    }

    int first_error = 0;
    for (size_t index = 0; index < value_count; index++) {
        int result = values[index].present
            ? setenv(
                restored_environment_names[index],
                values[index].value,
                overwrite_environment_value
            )
            : unsetenv(restored_environment_names[index]);
        if (result != 0 && first_error == 0) {
            first_error = errno;
        }
    }

    release_environment(values, value_count);
    return first_error;
}

static int decode_inputs(
    const char *encoded,
    char ***decoded,
    size_t *decoded_count
) {
    const char *cursor = encoded;
    size_t count = 0;
    int error = read_size(&cursor, &count);
    if (error != 0) {
        return error;
    }

    if (count > (SIZE_MAX / sizeof(char *)) - decoded_input_extra_entries) {
        return EOVERFLOW;
    }

    /* Keep one null terminator in the private decoded-input array. */
    char **entries = calloc(
        count + decoded_input_extra_entries,
        sizeof(char *)
    );
    if (entries == NULL) {
        return ENOMEM;
    }

    for (size_t index = 0; index < count; index++) {
        size_t byte_count = 0;
        error = read_size(&cursor, &byte_count);
        if (error != 0) {
            release_inputs(entries, index);
            return error;
        }

        size_t remaining = strlen(cursor);
        if (byte_count > remaining) {
            release_inputs(entries, index);
            return EINVAL;
        }

        entries[index] = malloc(byte_count + 1);
        if (entries[index] == NULL) {
            release_inputs(entries, index);
            return ENOMEM;
        }

        memcpy(entries[index], cursor, byte_count);
        entries[index][byte_count] = '\0';
        cursor += byte_count;
    }

    if (*cursor != '\0') {
        release_inputs(entries, count);
        return EINVAL;
    }

    *decoded = entries;
    *decoded_count = count;
    return 0;
}

/*
 * Success cannot return: execve replaces ish, preserving the current
 * environment, directory, and descriptor table. Failure returns errno.
 */
int ish_execve(const char *path, const char *encoded_inputs) {
    if (path == NULL || encoded_inputs == NULL || *path == '\0') {
        return EINVAL;
    }

    int error = restore_launch_environment();
    if (error != 0) {
        return error;
    }

    char **inputs = NULL;
    size_t input_count = 0;
    error = decode_inputs(encoded_inputs, &inputs, &input_count);
    if (error != 0) {
        return error;
    }

    char **process_inputs = calloc(
        input_count + process_input_extra_entries,
        sizeof(char *)
    );
    if (process_inputs == NULL) {
        release_inputs(inputs, input_count);
        return ENOMEM;
    }

    process_inputs[0] = (char *)path;
    for (size_t index = 0; index < input_count; index++) {
        process_inputs[index + 1] = inputs[index];
    }

    execve(path, process_inputs, environ);
    error = errno;

    free(process_inputs);
    release_inputs(inputs, input_count);
    return error;
}
