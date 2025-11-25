import AppKit
import SwiftUI

struct AppIconView: View {
    let item: AppItem
    @State private var faviconID = UUID()
    
    func launchApp() {

        if item.path.hasPrefix("http") || item.path.hasPrefix("https") {
            if let url = URL(string: item.path) {
                NSWorkspace.shared.open(url)
            }
        } else {
            let url = URL(fileURLWithPath: item.path)
            NSWorkspace.shared.open(url)
        }
    }

    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 2) {
            if item.path.hasPrefix("http") || item.path.hasPrefix("https") {
                // Web Icon
                // Web Icon
                FaviconView(url: item.path)
                    .id(faviconID)
                    .frame(width: 48, height: 48)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "globe")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.blue))
                            .offset(x: 4, y: -4)
                    }
            } else {
                // Local App Icon
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                    .resizable()
                    .frame(width: 48, height: 48)
            }
            
            Text(displayName)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
        .frame(width: 80, height: 100)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            launchApp()
        }
        .draggable(item)
        .draggable(item)
        .contextMenu {
            Button("Rename") {
                showInputDialog(title: "Rename App", prompt: "Enter new name:", defaultValue: item.name ?? "") { newName in
                    appState.renameApp(item: item, newName: newName)
                }
            }
            
            if item.path.hasPrefix("http") || item.path.hasPrefix("https") {
                Button("Edit URL") {
                    showInputDialog(title: "Edit URL", prompt: "Enter new URL:", defaultValue: item.path) { newURL in
                        appState.updateAppPath(item: item, newPath: newURL)
                    }
                }
                
                Button("Refetch Icon") {
                    faviconID = UUID()
                }
            }
            
            Divider()
            
            Button("Delete") {
                appState.deleteApp(item: item)
            }
        }
    }
    
    var displayName: String {
        if let name = item.name { return name }
        if item.path.hasPrefix("http") || item.path.hasPrefix("https") {
            return URL(string: item.path)?.host ?? item.path
        }
        return URL(fileURLWithPath: item.path).deletingPathExtension().lastPathComponent
    }
    
    func getFaviconURL(for urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              let host = url.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }
}

extension View {
    func showInputDialog(title: String, prompt: String, defaultValue: String, completion: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = defaultValue
        alert.accessoryView = input
        
        if alert.runModal() == .alertFirstButtonReturn {
            completion(input.stringValue)
        }
    }
    
    func pickApplication(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.prompt = "Add"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }
}

struct CategoryView: View {
    let category: Category
    @EnvironmentObject var appState: AppState
    @State private var isTargeted = false
    
    let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 0)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Menu {
                    Button("Add App...") {
                        pickApplication { url in
                            let item = AppItem(path: url.path, name: nil)
                            appState.addApp(to: category.name, item: item)
                        }
                    }
                    Button("Add Web Link...") {
                        showInputDialog(title: "Add Web Link", prompt: "Enter URL:", defaultValue: "https://") { url in
                            if !url.isEmpty {
                                let name = extractName(from: url)
                                let item = AppItem(path: url, name: name)
                                appState.addApp(to: category.name, item: item)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
                .menuStyle(.borderlessButton)
                .fixedSize() // Prevent expansion
            }
            .padding(8)
            
            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                ForEach(category.apps) { app in
                    AppIconView(item: app)
                        .dropDestination(for: AppItem.self) { items, location -> Bool in

                            guard let droppedItem = items.first else { 

                                return false
                            }
                            let isCopy = NSEvent.modifierFlags.contains(.shift)

                            withAnimation {
                                appState.moveApp(item: droppedItem, toCategory: category.name, before: app, isCopy: isCopy)
                            }
                            return true
                        }
                }
            }
            .padding(0)
            
            Spacer()
        }
        .background(Color(hex: category.color))
        .cornerRadius(10)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTargeted ? Color.white : Color.white.opacity(0.1), lineWidth: isTargeted ? 3 : 1)
        )
        .contextMenu {
            Button("Add App...") {
                pickApplication { url in
                    let item = AppItem(path: url.path, name: nil)
                    appState.addApp(to: category.name, item: item)
                }
            }
            Button("Add Web Link...") {
                showInputDialog(title: "Add Web Link", prompt: "Enter URL:", defaultValue: "https://") { url in
                    if !url.isEmpty {
                        let name = extractName(from: url)
                        let item = AppItem(path: url, name: name)
                        appState.addApp(to: category.name, item: item)
                    }
                }
            }
            
            Divider()
            
            Text("Colors")
            Button("🔴 Red") { appState.updateCategoryColor(categoryName: category.name, newColor: "#FF3B30") }
            Button("🟠 Orange") { appState.updateCategoryColor(categoryName: category.name, newColor: "#FF9500") }
            Button("🟡 Yellow") { appState.updateCategoryColor(categoryName: category.name, newColor: "#FFCC00") }
            Button("🟢 Green") { appState.updateCategoryColor(categoryName: category.name, newColor: "#28CD41") }
            Button("🔵 Blue") { appState.updateCategoryColor(categoryName: category.name, newColor: "#007AFF") }
            Button("🟣 Purple") { appState.updateCategoryColor(categoryName: category.name, newColor: "#AF52DE") }
            Button("🩶 Gray") { appState.updateCategoryColor(categoryName: category.name, newColor: "#8E8E93") }
            Button("⬛️ Default") { appState.updateCategoryColor(categoryName: category.name, newColor: "#3c3c3c") }
            Button("🩷 Pink") { appState.updateCategoryColor(categoryName: category.name, newColor: "#FF2D55") }
            Button("🩵 Teal") { appState.updateCategoryColor(categoryName: category.name, newColor: "#5AC8FA") }
            Button("💜 Indigo") { appState.updateCategoryColor(categoryName: category.name, newColor: "#5856D6") }
            Button("🟤 Brown") { appState.updateCategoryColor(categoryName: category.name, newColor: "#A2845E") }
            Button("🍃 Mint") { appState.updateCategoryColor(categoryName: category.name, newColor: "#00C7BE") }
            Button("🟦 Cyan") { appState.updateCategoryColor(categoryName: category.name, newColor: "#32ADE6") }
            Button("💗 Magenta") { appState.updateCategoryColor(categoryName: category.name, newColor: "#FF0090") }
            Button("🌑 Navy") { appState.updateCategoryColor(categoryName: category.name, newColor: "#000080") }
            
            Divider()
            
            Button("Custom Color...") {
                appState.openColorPanel(for: category.name)
            }
            
            Divider()
            
            Button("Rename Category") {
                showInputDialog(title: "Rename Category", prompt: "Enter new name:", defaultValue: category.name) { newName in
                    if !newName.isEmpty {
                        appState.renameCategory(oldName: category.name, newName: newName)
                    }
                }
            }
            
            if category.apps.isEmpty {
                Divider()
                Button("Delete Category") {
                    appState.deleteCategory(name: category.name)
                }
            }
        }
        .dropDestination(for: AppItem.self) { items, location -> Bool in
            guard let droppedItem = items.first else { return false }
            let isCopy = NSEvent.modifierFlags.contains(.shift)
            // Append to end if dropped on background
            withAnimation {
                appState.moveApp(item: droppedItem, toCategory: category.name, before: nil, isCopy: isCopy)
            }
            return true
        }
        .padding(10)
        .contentShape(Rectangle())
        .draggable(CategoryProxy(id: category.id, name: category.name))
        .dropDestination(for: CategoryProxy.self) { items, location -> Bool in
            guard let droppedItem = items.first else { return false }
            withAnimation {
                appState.moveCategory(item: droppedItem, before: category)
            }
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
    
    func extractName(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else { return "Web App" }
        var name = host
        
        // Remove TLD (everything after last dot)
        if let lastDotIndex = name.lastIndex(of: ".") {
            name = String(name[..<lastDotIndex])
        }
        
        // If remaining string has a dot, remove everything before the first dot (e.g. www.taskade -> taskade)
        if let firstDotIndex = name.firstIndex(of: ".") {
            name = String(name[name.index(after: firstDotIndex)...])
        }
        
        // Capitalize first letter
        return name.prefix(1).capitalized + name.dropFirst()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct FaviconView: View {
    let url: String
    @State private var currentImage: SwiftUI.Image?
    
    var body: some View {
        Group {
            if let image = currentImage {
                image
                    .resizable()
            } else {
                // Loading / Fallback state
                SwiftUI.Image(systemName: "globe")
                    .resizable()
                    .foregroundColor(.blue)
                    .onAppear {
                        loadFavicon(index: 0)
                    }
            }
        }
    }
    
    private func loadFavicon(index: Int) {
        guard let host = URL(string: url)?.host else { return }
        
        // Helper to get base domain (e.g., "straico.com" from "platform.straico.com")
        let components = host.components(separatedBy: ".")
        let baseDomain = components.count > 2 ? components.suffix(2).joined(separator: ".") : host
        
        let sources = [
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128",
            "https://icons.duckduckgo.com/ip3/\(host).ico",
            "https://www.google.com/s2/favicons?domain=\(baseDomain)&sz=128",
            "https://icons.duckduckgo.com/ip3/\(baseDomain).ico",
            "https://www.google.com/s2/favicons?domain=\(host)&sz=64"
        ]
        
        guard index < sources.count else { return }
        
        guard let sourceUrl = URL(string: sources[index]) else {
            loadFavicon(index: index + 1)
            return
        }
        
        let task = URLSession.shared.dataTask(with: sourceUrl) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let data = data, let nsImage = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.currentImage = SwiftUI.Image(nsImage: nsImage)
                }
            } else {
                DispatchQueue.main.async {
                    self.loadFavicon(index: index + 1)
                }
            }
        }
        task.resume()
    }
}
