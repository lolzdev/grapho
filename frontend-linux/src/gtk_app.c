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
}

static void on_activate(GtkApplication *app, gpointer user_data) {
    (void)user_data;

    AppState *state = g_new0(AppState, 1);
    GtkWidget *window = gtk_application_window_new(app);
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
    GtkWidget *title = gtk_label_new("Grapho");
    GtkWidget *renderer = vulkan_renderer_create_placeholder();

    gtk_window_set_title(GTK_WINDOW(window), "Grapho");
    gtk_window_set_default_size(GTK_WINDOW(window), 520, 360);
    gtk_window_set_child(GTK_WINDOW(window), box);

    gtk_box_append(GTK_BOX(box), title);
    gtk_box_append(GTK_BOX(box), renderer);

    g_object_set_data_full(G_OBJECT(window), "app-state", state, g_free);

    gtk_window_present(GTK_WINDOW(window));
}

int gtk_app_run(int argc, char **argv) {
    grapho_runtime_init();

    GtkApplication *app = gtk_application_new("com.grapho.Grapho", G_APPLICATION_DEFAULT_FLAGS);
    g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);

    int status = g_application_run(G_APPLICATION(app), argc, argv);

    g_object_unref(app);
    grapho_runtime_shutdown();
    return status;
}
