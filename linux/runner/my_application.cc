#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void window_method_call(FlMethodChannel* channel, FlMethodCall* call,
                               gpointer user_data) {
  FlValue* args = fl_method_call_get_args(call);
  if (g_strcmp0(fl_method_call_get_name(call), "setVideoFullscreen") != 0) {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_BOOL) {
    fl_method_call_respond_error(call, "fullscreen", "Expected a boolean",
                                 nullptr, nullptr);
    return;
  }
  GtkWindow* window = GTK_WINDOW(user_data);
  GdkWindow* surface = gtk_widget_get_window(GTK_WIDGET(window));
  if (fl_value_get_bool(args)) {
    if (!g_object_get_data(G_OBJECT(window), "video-fullscreen-owned") &&
        (surface == nullptr ||
         !(gdk_window_get_state(surface) & GDK_WINDOW_STATE_FULLSCREEN))) {
      g_object_set_data(G_OBJECT(window), "video-fullscreen-owned", GINT_TO_POINTER(1));
      gtk_window_fullscreen(window);
    }
  } else if (g_object_steal_data(G_OBJECT(window), "video-fullscreen-owned")) {
    gtk_window_unfullscreen(window);
  }
  fl_method_call_respond_success(call, nullptr, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gtk_window_set_title(window, "Dart Browser");
  gtk_window_set_default_size(window, 1280, 720);
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable != nullptr) {
    g_autofree gchar* directory = g_path_get_dirname(executable);
    g_autofree gchar* icon_path = g_build_filename(
        directory, "data", "flutter_assets", "assets", "app_icon.png", nullptr);
    gtk_window_set_icon_from_file(window, icon_path, nullptr);
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "dart_browser/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, window_method_call, window,
                                            nullptr);
  g_object_set_data_full(G_OBJECT(window), "window-channel",
                         g_steal_pointer(&channel), g_object_unref);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
