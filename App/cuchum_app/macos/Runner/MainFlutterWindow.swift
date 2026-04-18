import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    
    // Set initial window size to 1080x1920 (portrait)
    let initialSize = NSSize(width: 480, height: 1024)
    self.setContentSize(initialSize)
    
    // Center window on screen
    self.center()
    
    // Set minimum window size
    self.minSize = NSSize(width: 480, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
