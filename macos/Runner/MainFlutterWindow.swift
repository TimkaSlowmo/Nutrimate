import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // NutriMate is laid out for phones: phone-shaped default window, centered,
    // never smaller than 380x640 (on wide windows the app keeps a centered column).
    self.title = "NutriMate"
    self.contentMinSize = NSSize(width: 380, height: 640)
    let visible = (self.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 900)
    let height = min(860, visible.height - 40)
    let size = NSSize(width: 460, height: max(640, height))
    self.setContentSize(size)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
