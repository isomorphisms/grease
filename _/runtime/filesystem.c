#define _FILE_OFFSET_BITS 64
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

#if defined(__linux__)
#include <linux/falloc.h>
#endif

enum {
    location_absolute = 0,
    location_working_directory = 1,
    location_open_directory = 2,
};

enum {
    access_read_only = 0,
    access_write_only = 1,
    access_read_and_write = 2,
};

enum {
    presence_existing_only = 0,
    presence_create_if_missing = 1,
    presence_create_new = 2,
};

enum {
    choice_append = 1,
    choice_truncate = 2,
    choice_close_on_exec = 4,
    choice_reject_final_symbolic_link = 8,
    choice_nonblocking = 16,
    choice_synchronous_writes = 32,
    choice_synchronous_data_writes = 64,
    all_open_choices = 127,
};

enum {
    link_named_object = 0,
    link_follow_source_symbolic_link = 1,
};

enum {
    remove_nondirectory_name = 0,
    remove_directory = 1,
};

static int directory_descriptor(
    int location_kind,
    int descriptor,
    const char *path,
    int *result
) {
    if (path == NULL) {
        return EINVAL;
    }

    switch (location_kind) {
        case location_absolute:
            if (path[0] != '/') {
                return EINVAL;
            }
            *result = AT_FDCWD;
            return 0;

        case location_working_directory:
            if (path[0] == '/') {
                return EINVAL;
            }
            *result = AT_FDCWD;
            return 0;

        case location_open_directory:
            if (path[0] == '/' || descriptor < 0) {
                return EINVAL;
            }
            *result = descriptor;
            return 0;

        default:
            return EINVAL;
    }
}

static int nonnegative_offset(const char *text, off_t *result) {
    if (text == NULL || text[0] == '\0') {
        return EINVAL;
    }

    errno = 0;
    char *end = NULL;
    long long parsed = strtoll(text, &end, 10);
    if (errno == ERANGE) {
        return EOVERFLOW;
    }
    if (end == text || *end != '\0' || parsed < 0) {
        return EINVAL;
    }

    off_t converted = (off_t)parsed;
    if ((long long)converted != parsed) {
        return EOVERFLOW;
    }

    *result = converted;
    return 0;
}

static int open_flags(
    int access_kind,
    int presence_kind,
    int choices,
    int require_directory,
    int *result
) {
    if ((choices & ~all_open_choices) != 0 ||
        (require_directory != 0 && require_directory != 1)) {
        return EINVAL;
    }

    int flags = 0;
    switch (access_kind) {
        case access_read_only:
            flags = O_RDONLY;
            break;
        case access_write_only:
            flags = O_WRONLY;
            break;
        case access_read_and_write:
            flags = O_RDWR;
            break;
        default:
            return EINVAL;
    }

    switch (presence_kind) {
        case presence_existing_only:
            break;
        case presence_create_if_missing:
            flags |= O_CREAT;
            break;
        case presence_create_new:
            flags |= O_CREAT | O_EXCL;
            break;
        default:
            return EINVAL;
    }

    if (require_directory != 0) {
        if (presence_kind != presence_existing_only) {
            return EINVAL;
        }
        flags |= O_DIRECTORY;
    }

    if ((choices & choice_truncate) != 0 &&
        access_kind == access_read_only) {
        return EINVAL;
    }

    if ((choices & choice_append) != 0) {
        flags |= O_APPEND;
    }
    if ((choices & choice_truncate) != 0) {
        flags |= O_TRUNC;
    }
    if ((choices & choice_close_on_exec) != 0) {
        flags |= O_CLOEXEC;
    }
    if ((choices & choice_reject_final_symbolic_link) != 0) {
        flags |= O_NOFOLLOW;
    }
    if ((choices & choice_nonblocking) != 0) {
        flags |= O_NONBLOCK;
    }
    if ((choices & choice_synchronous_writes) != 0) {
        flags |= O_SYNC;
    }
    if ((choices & choice_synchronous_data_writes) != 0) {
        flags |= O_DSYNC;
    }

    *result = flags;
    return 0;
}

/*
 * The exported functions accept only the adapter selectors above. Linux/Bionic
 * O_* and AT_* values never cross into Ish.Filesystem.Meaning.
 *
 * openat returns a nonnegative descriptor on success and -errno on failure.
 * The other operations return zero on success and errno on failure. Those
 * private representations are consumed immediately by the Idriç adapter.
 */
int ish_openat(
    int location_kind,
    int descriptor,
    const char *path,
    int access_kind,
    int presence_kind,
    int permissions,
    int choices,
    int require_directory
) {
    int directory = 0;
    int error = directory_descriptor(
        location_kind,
        descriptor,
        path,
        &directory
    );
    if (error != 0) {
        return -error;
    }

    int flags = 0;
    error = open_flags(
        access_kind,
        presence_kind,
        choices,
        require_directory,
        &flags
    );
    if (error != 0) {
        return -error;
    }

    if (permissions < 0 || permissions > 0777) {
        return -EINVAL;
    }

    int opened = openat(directory, path, flags, (mode_t)permissions);
    if (opened < 0) {
        return -errno;
    }
    return opened;
}

int ish_allocate_keep_size(
    int descriptor,
    const char *offset_text,
    const char *length_text
) {
    off_t offset = 0;
    int error = nonnegative_offset(offset_text, &offset);
    if (error != 0) {
        return error;
    }

    off_t length = 0;
    error = nonnegative_offset(length_text, &length);
    if (error != 0) {
        return error;
    }
    if (length == 0) {
        return EINVAL;
    }

#if defined(__linux__) && defined(FALLOC_FL_KEEP_SIZE)
    if (fallocate(descriptor, FALLOC_FL_KEEP_SIZE, offset, length) == 0) {
        return 0;
    }
    return errno;
#else
    (void)descriptor;
    (void)offset;
    (void)length;
    return ENOTSUP;
#endif
}

int ish_close(int descriptor) {
    if (close(descriptor) == 0) {
        return 0;
    }
    return errno;
}

int ish_linkat(
    int source_location_kind,
    int source_descriptor,
    const char *source_path,
    int destination_location_kind,
    int destination_descriptor,
    const char *destination_path,
    int source_resolution
) {
    int source_directory = 0;
    int error = directory_descriptor(
        source_location_kind,
        source_descriptor,
        source_path,
        &source_directory
    );
    if (error != 0) {
        return error;
    }

    int destination_directory = 0;
    error = directory_descriptor(
        destination_location_kind,
        destination_descriptor,
        destination_path,
        &destination_directory
    );
    if (error != 0) {
        return error;
    }

    int flags = 0;
    switch (source_resolution) {
        case link_named_object:
            break;
        case link_follow_source_symbolic_link:
            flags = AT_SYMLINK_FOLLOW;
            break;
        default:
            return EINVAL;
    }

    if (linkat(
        source_directory,
        source_path,
        destination_directory,
        destination_path,
        flags
    ) == 0) {
        return 0;
    }
    return errno;
}

int ish_symlinkat(
    const char *target,
    int location_kind,
    int descriptor,
    const char *path
) {
    if (target == NULL) {
        return EINVAL;
    }

    int directory = 0;
    int error = directory_descriptor(
        location_kind,
        descriptor,
        path,
        &directory
    );
    if (error != 0) {
        return error;
    }

    if (symlinkat(target, directory, path) == 0) {
        return 0;
    }
    return errno;
}

int ish_unlinkat(
    int location_kind,
    int descriptor,
    const char *path,
    int removal_kind
) {
    int directory = 0;
    int error = directory_descriptor(
        location_kind,
        descriptor,
        path,
        &directory
    );
    if (error != 0) {
        return error;
    }

    int flags = 0;
    switch (removal_kind) {
        case remove_nondirectory_name:
            break;
        case remove_directory:
            flags = AT_REMOVEDIR;
            break;
        default:
            return EINVAL;
    }

    if (unlinkat(directory, path, flags) == 0) {
        return 0;
    }
    return errno;
}
