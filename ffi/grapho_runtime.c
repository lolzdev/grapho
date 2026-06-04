#include <HsFFI.h>
#include <stddef.h>
#include "grapho_api.h"

static int runtime_started = 0;

void grapho_runtime_init(void) {
    if (runtime_started) {
        return;
    }

    int argc = 1;
    char *argv[] = { "grapho", NULL };
    char **pargv = argv;
    hs_init(&argc, &pargv);
    runtime_started = 1;
}

void grapho_runtime_shutdown(void) {
    if (!runtime_started) {
        return;
    }

    hs_exit();
    runtime_started = 0;
}
