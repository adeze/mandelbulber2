// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import SwiftUI

@main
struct MandelbulberMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("Mandelbulber · Native Preview") {
            ContentView()
        }
        .defaultSize(width: 1100, height: 760)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
