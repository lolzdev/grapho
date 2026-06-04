#ifndef GRAPHO_API_H
#define GRAPHO_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void grapho_runtime_init(void);
void grapho_runtime_shutdown(void);

int32_t grapho_add(int32_t a, int32_t b);
int32_t grapho_tick(void);
char *grapho_hello(void);
void grapho_free_string(char *ptr);

#ifdef __cplusplus
}
#endif

#endif
