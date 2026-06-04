#include "vulkan_renderer.h"

GtkWidget *vulkan_renderer_create_placeholder(void) {
    GtkWidget *frame = gtk_frame_new("Vulkan placeholder");
    GtkWidget *label = gtk_label_new("No renderer implemented yet");

    gtk_widget_set_hexpand(frame, TRUE);
    gtk_widget_set_vexpand(frame, TRUE);
    gtk_frame_set_child(GTK_FRAME(frame), label);

    return frame;
}

