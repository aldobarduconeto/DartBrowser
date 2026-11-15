#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Setup dart_browser/window method channel
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "dart_browser/window",
          &flutter::StandardMethodCodec::GetInstance());

  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HWND hwnd = GetHandle();
        if (call.method_name() == "setVideoFullscreen") {
          const auto* enabled = call.arguments()
              ? std::get_if<bool>(call.arguments()) : nullptr;
          if (enabled && SetVideoFullscreen(*enabled)) {
            result->Success();
          } else {
            result->Error("fullscreen", "Could not change window fullscreen");
          }
        } else if (call.method_name() == "startDragging") {
          ::ReleaseCapture();
          ::SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
        } else if (call.method_name() == "minimize") {
          ::ShowWindow(hwnd, SW_MINIMIZE);
          result->Success();
        } else if (call.method_name() == "maximize") {
          if (::IsZoomed(hwnd)) {
            ::ShowWindow(hwnd, SW_RESTORE);
          } else {
            ::ShowWindow(hwnd, SW_MAXIMIZE);
          }
          result->Success();
        } else if (call.method_name() == "close") {
          ::PostMessage(hwnd, WM_CLOSE, 0, 0);
          result->Success();
        } else if (call.method_name() == "isMaximized") {
          bool is_max = (::IsZoomed(hwnd) != FALSE);
          result->Success(flutter::EncodableValue(is_max));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

bool FlutterWindow::SetVideoFullscreen(bool enabled) {
  if (video_fullscreen_ == enabled) return true;
  HWND hwnd = GetHandle();
  if (enabled) {
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    if (!::GetWindowPlacement(hwnd, &restored_placement_) ||
        !::GetMonitorInfo(::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                          &monitor)) {
      return false;
    }
    restored_style_ = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    video_fullscreen_ = true;
    ::SetWindowLongPtr(hwnd, GWL_STYLE,
                       restored_style_ & ~(WS_OVERLAPPEDWINDOW | WS_MAXIMIZE));
    const RECT& bounds = monitor.rcMonitor;
    ::SetWindowPos(hwnd, HWND_TOP, bounds.left, bounds.top,
                   bounds.right - bounds.left, bounds.bottom - bounds.top,
                   SWP_FRAMECHANGED | SWP_NOOWNERZORDER);
  } else {
    video_fullscreen_ = false;
    ::SetWindowLongPtr(hwnd, GWL_STYLE, restored_style_);
    ::SetWindowPlacement(hwnd, &restored_placement_);
    ::SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                   SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                       SWP_NOACTIVATE);
  }
  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_NCCALCSIZE:
      if (video_fullscreen_ && wparam == TRUE) return 0;
      break;
    case WM_NCHITTEST:
      if (video_fullscreen_) return HTCLIENT;
      break;
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
