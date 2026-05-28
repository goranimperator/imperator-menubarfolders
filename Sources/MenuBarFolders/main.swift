import AppKit

// Force red accent color regardless of system settings
// macOS AppleAccentColor: 0=Red, 1=Orange, 2=Yellow, 3=Green, 4=Blue, 5=Purple, 6=Pink
UserDefaults.standard.set(0, forKey: "AppleAccentColor")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
