import AppKit

// Force red accent color regardless of system settings
UserDefaults.standard.set(0, forKey: "AppleAccentColor")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Force dark mode (brand book §14.1)
app.appearance = NSAppearance(named: .darkAqua)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
