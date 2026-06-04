#include <gtk/gtk.h>
#include <stdio.h>

#include "grapho_api.h"
#include "vulkan_renderer.h"

typedef struct {
    GtkWidget *tick_label;
} AppState;

static void on_tick_clicked(GtkButton *button, gpointer user_data) {
    (void)button;
    AppState *state = user_data;
    int32_t tick = grapho_tick();

    char text[64];
    snprintf(text, sizeof(text), "grapho_tick() = %d", tick);
    gtk_label_set_text(GTK_LABEL(state->tick_label), text);
}

static void on_activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;

    AppState *state = g_new0(AppState, 1);
    GtkWidget *window = gtk_application_window_new(app);
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    GtkWidget *title = gtk_label_new("Grapho: GTK4 C -> C ABI -> Haskell");
    GtkWidget *button = gtk_button_new_with_label("Tick");
    GtkWidget *renderer = vulkan_renderer_create_placeholder();

    char *hello = grapho_hello();
    GtkWidget *hello_label = gtk_label_new(hello != NULL ? hello : "(null)");
    grapho_free_string(hello);

    char add_text[64];
    snprintf(add_text, sizeof(add_text), "grapho_add(2, 3) = %d", grapho_add(2, 3));
    GtkWidget *add_label = gtk_label_new(add_text);

    state->tick_label = gtk_label_new("grapho_tick() = 0");

    gtk_window_set_title(GTK_WINDOW(window), "Grapho Linux");
    gtk_window_set_default_size(GTK_WINDOW(window), 520, 360);
    gtk_window_set_child(GTK_WINDOW(window), box);

    gtk_box_append(GTK_BOX(box), title);
    gtk_box_append(GTK_BOX(box), hello_label);
    gtk_box_append(GTK_BOX(box), add_label);
    gtk_box_append(GTK_BOX(box), state->tick_label);
    gtk_box_append(GTK_BOX(box), button);
    gtk_box_append(GTK_BOX(box), renderer);

    g_signal_connect(button, "clicked", G_CALLBACK(on_tick_clicked), state);
    g_object_set_data_full(G_OBJECT(window), "app-state", state, g_free);

    gtk_window_present(GTK_WINDOW(window));
}

int gtk_app_run(int argc, char **argv) {
    grapho_runtime_init();

    GtkApplication *app = gtk_application_new("dev.grapho.skeleton", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);

    int status = g_application_run(G_APPLICATION(app), argc, argv);

    g_object_unref(app);
    grapho_runtime_shutdown();
    return status;
}
