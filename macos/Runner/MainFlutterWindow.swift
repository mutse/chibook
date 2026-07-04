import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = NSRect(x: 0, y: 0, width: 1440, height: 920)
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 1180, height: 780)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.setFrame(windowFrame, display: true)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
