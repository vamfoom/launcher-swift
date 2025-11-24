import SwiftUI
import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {

        
        // Create the window manually
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.title = "macOS Launcher"
        window.isReleasedWhenClosed = false
        
        // Create the SwiftUI view
        let contentView = ContentView()
        
        // Set the window's content view
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        // Force activation
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

struct ContentView: View {
    @StateObject var appState = AppState()
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(appState.categories) { category in
                    CategoryView(category: category)
                        .environmentObject(appState)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            appState.loadConfig()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor)) // Ensure it has a background to click
        .contextMenu {
            Button("New Category") {
                showInputDialog(title: "New Category", prompt: "Enter category name:", defaultValue: "") { newName in
                    if !newName.isEmpty {
                        appState.addCategory(name: newName)
                    }
                }
            }
        }
    }
}
