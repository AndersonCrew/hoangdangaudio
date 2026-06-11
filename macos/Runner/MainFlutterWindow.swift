import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let mobileSize = NSSize(width: 430, height: 860)
    self.setContentSize(mobileSize)
    self.minSize = mobileSize
    self.maxSize = mobileSize
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
