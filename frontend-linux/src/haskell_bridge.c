#include "grapho_api.h"

/* Kept as the Linux frontend's replacement point for richer core wrappers later. */
int haskell_bridge_smoke_test(void) {
    return grapho_add(2, 3);
}
