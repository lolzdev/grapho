#ifndef GRAPHO_API_H
#define GRAPHO_API_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void grapho_runtime_init(void);
void grapho_runtime_shutdown(void);

typedef struct {
    uint32_t glyph_id;
    float x;
    float y;
    float x_advance;
    float y_advance;
    float reserved;
} GraphoGlyph;

typedef struct {
    GraphoGlyph *glyphs;
    int32_t glyph_count;
    float width;
    float height;
    float baseline;
    float origin_x;
    float origin_y;
    char *font_name;
    float font_size;
} GraphoTextLayout;

int32_t grapho_layout_text(GraphoTextLayout *output);

void grapho_free_layout(GraphoTextLayout *layout);
float grapho_zoom_in(void);
float grapho_zoom_out(void);

#ifdef __cplusplus
}
#endif

#endif
