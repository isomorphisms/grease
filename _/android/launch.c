#define _POSIX_C_SOURCE 200809L
#define _XOPEN_SOURCE 700

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *launch_environment_name = "__ISH_LAUNCH_ENVIRONMENT";
static const int compiled_program_could_not_start_status = 126;
static const char *saved_environment_names[] = {
    "LD_LIBRARY_PATH",
    "DYLD_LIBRARY_PATH",
    "IDRIS2_INC_SRC",
    "__ISH_LAUNCH_ENVIRONMENT",
};

enum {
    decimal_radix = 10,
    absent_environment_field_width = 2,
    present_environment_fixed_width = 2,
    overwrite_environment_value = 1,
};

static size_t decimal_digits(size_t value) {
    size_t digits = 1;
    while (value >= decimal_radix) {
        value /= decimal_radix;
        digits++;
    }
    return digits;
}

static char *capture_environment(void) {
    const size_t value_count =
        sizeof(saved_environment_names) / sizeof(saved_environment_names[0]);
    size_t total = 0;

    for (size_t index = 0; index < value_count; index++) {
        const char *value = getenv(saved_environment_names[index]);
        if (value == NULL) {
            total += absent_environment_field_width;
        } else {
            size_t length = strlen(value);
            total += present_environment_fixed_width + decimal_digits(length) + length;
        }
    }

    char *state = malloc(total + 1);
    if (state == NULL) {
        return NULL;
    }

    char *at = state;
    size_t remaining = total + 1;
    for (size_t index = 0; index < value_count; index++) {
        const char *value = getenv(saved_environment_names[index]);
        if (value == NULL) {
            memcpy(at, "0:", absent_environment_field_width);
            at += absent_environment_field_width;
            remaining -= absent_environment_field_width;
        } else {
            size_t length = strlen(value);
            int written = snprintf(at, remaining, "1%zu:", length);
            if (written < 0 || (size_t)written >= remaining) {
                free(state);
                return NULL;
            }
            at += written;
            remaining -= (size_t)written;
            memcpy(at, value, length);
            at += length;
            remaining -= length;
        }
    }
    *at = '\0';
    return state;
}

static char *join_path(const char *directory, const char *suffix) {
    size_t directory_length = strlen(directory);
    size_t suffix_length = strlen(suffix);
    char *result = malloc(directory_length + 1 + suffix_length + 1);
    if (result == NULL) {
        return NULL;
    }

    memcpy(result, directory, directory_length);
    result[directory_length] = '/';
    memcpy(result + directory_length + 1, suffix, suffix_length + 1);
    return result;
}

static char *prepend_path(const char *directory, const char *previous) {
    if (previous == NULL || *previous == '\0') {
        return strdup(directory);
    }

    size_t directory_length = strlen(directory);
    size_t previous_length = strlen(previous);
    char *result = malloc(directory_length + 1 + previous_length + 1);
    if (result == NULL) {
        return NULL;
    }

    memcpy(result, directory, directory_length);
    result[directory_length] = ':';
    memcpy(result + directory_length + 1, previous, previous_length + 1);
    return result;
}

static int fail(const char *operation) {
    int error = errno;
    fprintf(stderr, "ish launcher: %s: %s\n", operation, strerror(error));
    return compiled_program_could_not_start_status;
}

int main(int count, char **values) {
    char *launcher = realpath(values[0], NULL);
    if (launcher == NULL) {
        return fail("could not resolve its executable path");
    }

    char *bin_slash = strrchr(launcher, '/');
    if (bin_slash == NULL) {
        free(launcher);
        errno = EINVAL;
        return fail("could not find its executable directory");
    }
    *bin_slash = '\0';

    char *root_slash = strrchr(launcher, '/');
    if (root_slash == NULL) {
        free(launcher);
        errno = EINVAL;
        return fail("could not find its package root");
    }
    *root_slash = '\0';

    char *runtime = join_path(launcher, "libexec/ish");
    char *scheme = runtime == NULL ? NULL : join_path(runtime, "scheme");
    char *petite_boot = runtime == NULL ? NULL : join_path(runtime, "petite.boot");
    char *scheme_boot = runtime == NULL ? NULL : join_path(runtime, "scheme.boot");
    char *program = runtime == NULL ? NULL : join_path(runtime, "ish-backend.so");
    char *library_path = runtime == NULL
        ? NULL
        : prepend_path(runtime, getenv("LD_LIBRARY_PATH"));
    char *environment_state = capture_environment();

    if (runtime == NULL || scheme == NULL || petite_boot == NULL ||
        scheme_boot == NULL || program == NULL || library_path == NULL ||
        environment_state == NULL) {
        errno = ENOMEM;
        return fail("could not prepare the Android runtime");
    }

    if (setenv(
            launch_environment_name,
            environment_state,
            overwrite_environment_value
        ) != 0 ||
        setenv("LD_LIBRARY_PATH", library_path, overwrite_environment_value) != 0 ||
        setenv("IDRIS2_INC_SRC", runtime, overwrite_environment_value) != 0) {
        return fail("could not prepare the Chez environment");
    }

    size_t child_count = (size_t)count + 7;
    char **child_values = calloc(child_count, sizeof(char *));
    if (child_values == NULL) {
        errno = ENOMEM;
        return fail("could not prepare the Chez argument vector");
    }

    size_t at = 0;
    child_values[at++] = scheme;
    child_values[at++] = "-B";
    child_values[at++] = petite_boot;
    child_values[at++] = "-B";
    child_values[at++] = scheme_boot;
    child_values[at++] = "--program";
    child_values[at++] = program;
    for (int index = 1; index < count; index++) {
        child_values[at++] = values[index];
    }
    child_values[at] = NULL;

    execv(scheme, child_values);
    return fail("could not start the compiled Idriç program");
}
