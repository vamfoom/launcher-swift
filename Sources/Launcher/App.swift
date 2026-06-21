import SwiftUI
import AppKit

@main
@MainActor
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
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        setupMenu()
    }
    
    func setupMenu() {
        let mainMenu = NSMenu()
        NSApplication.shared.mainMenu = mainMenu
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About macOS Launcher", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit macOS Launcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // Edit Menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: #selector(StandardEditActions.undo(_:)), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(StandardEditActions.redo(_:)), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(StandardEditActions.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(StandardEditActions.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(StandardEditActions.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(StandardEditActions.selectAll(_:)), keyEquivalent: "a")
        
        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
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

@objc protocol StandardEditActions {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
    func cut(_ sender: Any?)
    func copy(_ sender: Any?)
    func paste(_ sender: Any?)
    func selectAll(_ sender: Any?)
}

struct ContentView: View {
    @StateObject var appState = AppState()
    @State private var searchText = ""
    @State private var isSearchVisible = false
    
    let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]
    
    var body: some View {
        ZStack {
            ScrollView {
                let categories = appState.categories
                VStack(spacing: 0) {
                    ForEach(0..<max(1, (categories.count + 2) / 3), id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { colIndex in
                                let index = rowIndex * 3 + colIndex
                                if index < categories.count {
                                    CategoryView(category: categories[index])
                                        .environmentObject(appState)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .dropDestination(for: CategoryProxy.self) { items, location -> Bool in
                guard let droppedItem = items.first else { return false }
                withAnimation {
                    appState.moveCategory(item: droppedItem, before: nil)
                }
                return true
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
            
            if isSearchVisible {
                SearchView(searchText: $searchText, isVisible: $isSearchVisible)
                    .environmentObject(appState)
                    .transition(.opacity)
            }
        }
        .keyboardShortcut("f", modifiers: .command) // This might need to be attached to a hidden button or similar if it doesn't work on ZStack
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleSearch"))) { _ in
            withAnimation {
                isSearchVisible.toggle()
            }
        }
        // Global shortcut handler hack
        .background(
            Button("") {
                withAnimation {
                    isSearchVisible.toggle()
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .opacity(0)
        )
        .onExitCommand {
            if isSearchVisible {
                withAnimation {
                    isSearchVisible = false
                    searchText = ""
                }
            }
        }
    }
}
