#define _GNU_SOURCE

#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/types.h>

enum {
    source_anonymous = 0,
    source_file = 1,
};

enum {
    permission_read = 1,
    permission_write = 2,
    permission_execute = 4,
    all_permissions = 7,
};

enum {
    sharing_private = 0,
    sharing_shared = 1,
};

struct mapping_entry {
    int token;
    void *address;
    size_t length;
    int permissions;
    struct mapping_entry *next;
};

static struct mapping_entry *mappings = NULL;
static int next_mapping_token = 1;

static int parse_unsigned_text(const char *text, uintmax_t *result) {
    if (text == NULL || text[0] == '\0') {
        return EINVAL;
    }

    for (const char *cursor = text; *cursor != '\0'; ++cursor) {
        if (*cursor < '0' || *cursor > '9') {
            return EINVAL;
        }
    }

    errno = 0;
    char *end = NULL;
    uintmax_t value = strtoumax(text, &end, 10);
    if (errno == ERANGE) {
        return EOVERFLOW;
    }
    if (end == NULL || *end != '\0') {
        return EINVAL;
    }

    *result = value;
    return 0;
}

static int parse_size(const char *text, size_t *result) {
    uintmax_t value = 0;
    int error = parse_unsigned_text(text, &value);
    if (error != 0) {
        return error;
    }

    size_t converted = (size_t)value;
    if ((uintmax_t)converted != value) {
        return EOVERFLOW;
    }

    *result = converted;
    return 0;
}

static int parse_offset(const char *text, off_t *result) {
    uintmax_t value = 0;
    int error = parse_unsigned_text(text, &value);
    if (error != 0) {
        return error;
    }

    off_t converted = (off_t)value;
    if (converted < 0 || (uintmax_t)converted != value) {
        return EOVERFLOW;
    }

    *result = converted;
    return 0;
}

static int protection_flags(int permissions, int *result) {
    if ((permissions & ~all_permissions) != 0) {
        return EINVAL;
    }

    int flags = PROT_NONE;
    if ((permissions & permission_read) != 0) {
        flags |= PROT_READ;
    }
    if ((permissions & permission_write) != 0) {
        flags |= PROT_WRITE;
    }
    if ((permissions & permission_execute) != 0) {
        flags |= PROT_EXEC;
    }

    *result = flags;
    return 0;
}

static int mapping_flags(int source_kind, int sharing, int *result) {
    int flags = 0;

    switch (sharing) {
        case sharing_private:
            flags = MAP_PRIVATE;
            break;
        case sharing_shared:
            flags = MAP_SHARED;
            break;
        default:
            return EINVAL;
    }

    switch (source_kind) {
        case source_anonymous:
            flags |= MAP_ANONYMOUS;
            break;
        case source_file:
            break;
        default:
            return EINVAL;
    }

    *result = flags;
    return 0;
}

static struct mapping_entry *find_mapping(int token) {
    for (struct mapping_entry *entry = mappings;
         entry != NULL;
         entry = entry->next) {
        if (entry->token == token) {
            return entry;
        }
    }
    return NULL;
}

static int register_mapping(
    void *address,
    size_t length,
    int permissions,
    int *token
) {
    if (next_mapping_token <= 0 || next_mapping_token == INT_MAX) {
        return EOVERFLOW;
    }

    struct mapping_entry *entry = malloc(sizeof(*entry));
    if (entry == NULL) {
        return ENOMEM;
    }

    entry->token = next_mapping_token++;
    entry->address = address;
    entry->length = length;
    entry->permissions = permissions;
    entry->next = mappings;
    mappings = entry;

    *token = entry->token;
    return 0;
}

/*
 * Idriç passes named selectors and decimal Number text. Linux/Bionic PROT_* and
 * MAP_* constants and the actual process address stay inside this Unix adapter.
 *
 * ish_mmap returns a positive registry token on success and -errno on failure.
 * The remaining operations return zero/byte values on success and errno (or
 * -errno for the byte reader) on failure.
 */
int ish_mmap(
    int source_kind,
    int descriptor,
    const char *offset_text,
    const char *length_text,
    int permissions,
    int sharing
) {
    size_t length = 0;
    int error = parse_size(length_text, &length);
    if (error != 0) {
        return -error;
    }
    if (length == 0) {
        return -EINVAL;
    }

    off_t offset = 0;
    error = parse_offset(offset_text, &offset);
    if (error != 0) {
        return -error;
    }

    int protections = 0;
    error = protection_flags(permissions, &protections);
    if (error != 0) {
        return -error;
    }

    int flags = 0;
    error = mapping_flags(source_kind, sharing, &flags);
    if (error != 0) {
        return -error;
    }

    int file_descriptor = descriptor;
    if (source_kind == source_anonymous) {
        if (offset != 0) {
            return -EINVAL;
        }
        file_descriptor = -1;
    } else if (descriptor < 0) {
        return -EINVAL;
    }

    void *address = mmap(
        NULL,
        length,
        protections,
        flags,
        file_descriptor,
        offset
    );
    if (address == MAP_FAILED) {
        return -errno;
    }

    int token = 0;
    error = register_mapping(address, length, permissions, &token);
    if (error != 0) {
        int saved = error;
        (void)munmap(address, length);
        return -saved;
    }

    return token;
}

int ish_mapping_read_byte(int token, const char *offset_text) {
    struct mapping_entry *entry = find_mapping(token);
    if (entry == NULL) {
        return -EINVAL;
    }
    if ((entry->permissions & permission_read) == 0) {
        return -EACCES;
    }

    size_t offset = 0;
    int error = parse_size(offset_text, &offset);
    if (error != 0) {
        return -error;
    }
    if (offset >= entry->length) {
        return -EINVAL;
    }

    const unsigned char *bytes = entry->address;
    return bytes[offset];
}

int ish_mapping_write_byte(
    int token,
    const char *offset_text,
    int value
) {
    struct mapping_entry *entry = find_mapping(token);
    if (entry == NULL) {
        return EINVAL;
    }
    if ((entry->permissions & permission_write) == 0) {
        return EACCES;
    }
    if (value < 0 || value > 255) {
        return EINVAL;
    }

    size_t offset = 0;
    int error = parse_size(offset_text, &offset);
    if (error != 0) {
        return error;
    }
    if (offset >= entry->length) {
        return EINVAL;
    }

    unsigned char *bytes = entry->address;
    bytes[offset] = (unsigned char)value;
    return 0;
}

int ish_msync(int token) {
    struct mapping_entry *entry = find_mapping(token);
    if (entry == NULL) {
        return EINVAL;
    }

    if (msync(entry->address, entry->length, MS_SYNC) == 0) {
        return 0;
    }
    return errno;
}

int ish_munmap(int token) {
    struct mapping_entry **cursor = &mappings;
    while (*cursor != NULL && (*cursor)->token != token) {
        cursor = &(*cursor)->next;
    }

    if (*cursor == NULL) {
        return EINVAL;
    }

    struct mapping_entry *entry = *cursor;
    if (munmap(entry->address, entry->length) != 0) {
        return errno;
    }

    *cursor = entry->next;
    free(entry);
    return 0;
}
