import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Configura a janela sem barra de título nativa clássica (estilo Opera/Chrome/Edge no macOS)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isOpaque = false

    let channel = FlutterMethodChannel(
      name: "dart_browser/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "startDragging":
        if let event = NSApp.currentEvent {
          self.performDrag(with: event)
        }
        result(nil)
      case "minimize":
        self.miniaturize(nil)
        result(nil)
      case "maximize":
        self.zoom(nil)
        result(nil)
      case "close":
        self.performClose(nil)
        result(nil)
      case "isMaximized":
        result(self.isZoomed)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
