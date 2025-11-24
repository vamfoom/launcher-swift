import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let appItem = UTType(exportedAs: "com.launcher.appitem")
}

struct AppItem: Identifiable, Codable, Hashable, Transferable {
    var id = UUID()
    var path: String
    var name: String?
    
    enum CodingKeys: String, CodingKey {
        case path
        case name
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

struct Category: Identifiable, Codable {
    var id = UUID()
    var name: String
    var apps: [AppItem]
    var color: String
}

struct ConfigData: Codable {
    var categories: [String]
    var apps: [String: [AppItemWrapper]]
    var category_colors: [String: String]?
}

enum AppItemWrapper: Codable {
    case string(String)
    case object(AppItem)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(AppItem.self) {
            self = .object(x)
            return
        }
        throw DecodingError.typeMismatch(AppItemWrapper.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for AppItemWrapper"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x):
            try container.encode(x)
        case .object(let x):
            try container.encode(x)
        }
    }
}

@MainActor
class ColorPanelHelper: NSObject {
    weak var appState: AppState?
    
    @objc func colorPanelChanged(_ sender: NSColorPanel) {
        guard let appState = appState, let categoryName = appState.categoryBeingEdited else { return }
        let newColor = sender.color.hexString
        appState.updateCategoryColor(categoryName: categoryName, newColor: newColor)
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var categories: [Category] = []
    var categoryBeingEdited: String?
    private let colorHelper = ColorPanelHelper()
    private var configURL: URL?
    
    init() {
        colorHelper.appState = self
    }
    
    private func getConfigURL() -> URL {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let configDir = home.appendingPathComponent(".config/launcher")
        
        if !fileManager.fileExists(atPath: configDir.path) {
            try? fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        }
        
        return configDir.appendingPathComponent("config.json")
    }

    func loadConfig() {
        let url = getConfigURL()
        self.configURL = url
        
        var data: Data?
        
        if let loaded = try? Data(contentsOf: url) {
            data = loaded
        } else {
            // Create default config
            let defaultCategories = ["Utilities", "Productivity", "Development", "Media", "Social"]
            let config = ConfigData(categories: defaultCategories, apps: [:], category_colors: [:])
            
            if let encoded = try? JSONEncoder().encode(config) {
                try? encoded.write(to: url)
                data = encoded
            }
        }
        
        guard let configData = data else { return }
        
        do {
            let config = try JSONDecoder().decode(ConfigData.self, from: configData)
            
            self.categories = config.categories.map { catName in
                let appWrappers = config.apps[catName] ?? []
                let apps = appWrappers.map { wrapper -> AppItem in
                    switch wrapper {
                    case .string(let path):
                        return AppItem(path: path, name: nil)
                    case .object(let item):
                        return item
                    }
                }
                let color = config.category_colors?[catName] ?? "#3c3c3c"
                return Category(name: catName, apps: apps, color: color)
            }
        } catch {
            // Error handling ignored
        }
    }
    
    func openColorPanel(for categoryName: String) {
        categoryBeingEdited = categoryName
        let panel = NSColorPanel.shared
        panel.setTarget(colorHelper)
        panel.setAction(#selector(ColorPanelHelper.colorPanelChanged(_:)))
        panel.orderFront(nil)
        
        // Set initial color if possible
        if let cat = categories.first(where: { $0.name == categoryName }) {
            panel.color = NSColor(hex: cat.color)
        }
    }
    
    func renameApp(item: AppItem, newName: String) {
        guard let catIndex = categories.firstIndex(where: { $0.apps.contains(where: { $0.path == item.path }) }),
              let appIndex = categories[catIndex].apps.firstIndex(where: { $0.path == item.path }) else { return }
        
        categories[catIndex].apps[appIndex].name = newName

        saveConfig()
    }
    
    func updateAppPath(item: AppItem, newPath: String) {
        guard let catIndex = categories.firstIndex(where: { $0.apps.contains(where: { $0.path == item.path }) }),
              let appIndex = categories[catIndex].apps.firstIndex(where: { $0.path == item.path }) else { return }
        
        categories[catIndex].apps[appIndex].path = newPath

        saveConfig()
    }
    
    func updateCategoryColor(categoryName: String, newColor: String) {
        guard let index = categories.firstIndex(where: { $0.name == categoryName }) else { return }
        categories[index].color = newColor

        saveConfig()
    }
    
    func moveApp(item: AppItem, toCategory categoryName: String, before targetApp: AppItem?, isCopy: Bool = false) {

        
        // Find source category and index by PATH, not ID (because ID changes on decode)
        guard let sourceCatIndex = categories.firstIndex(where: { $0.apps.contains(where: { $0.path == item.path }) }) else { 

            return 
        }
        
        guard let sourceIndex = categories[sourceCatIndex].apps.firstIndex(where: { $0.path == item.path }) else { 

            return 
        }
        
        let app: AppItem
        if isCopy {
            // Create a copy (new ID is generated automatically if we init, but here we are moving the dropped item which is already a copy)
            // Actually, we should use the item passed in (droppedItem) as the new item, 
            // and just NOT remove the old one.
            // But wait, 'item' passed in is the 'droppedItem' which has a new ID.
            // The 'app' we found in source has the OLD ID.
            // If we are copying, we want to insert 'item' (the new one) into the target.
            // And leave the old one alone.
            app = item 
        } else {
            // If moving, we remove the old one.
            // And we can insert the old one (to keep ID?) or the new one.
            // If we want to preserve ID, we should use the one we removed.
            app = categories[sourceCatIndex].apps.remove(at: sourceIndex)
        }
        
        // Find target category
        guard let targetCatIndex = categories.firstIndex(where: { $0.name == categoryName }) else { 

            // Fallback: if we removed it, put it back
            if !isCopy {
                categories[sourceCatIndex].apps.insert(app, at: sourceIndex)
            }
            return 
        }
        
        // Insert at target
        if let targetApp = targetApp, let targetIndex = categories[targetCatIndex].apps.firstIndex(where: { $0.path == targetApp.path }) {
            categories[targetCatIndex].apps.insert(app, at: targetIndex)
        } else {
            // Append if no target (dropped on category)
            categories[targetCatIndex].apps.append(app)
        }
        

        saveConfig()
    }
    
    func saveConfig() {
        let categoryNames = categories.map { $0.name }
        var appsMap: [String: [AppItemWrapper]] = [:]
        var colorsMap: [String: String] = [:]
        
        for category in categories {
            let wrappers = category.apps.map { AppItemWrapper.object($0) }
            appsMap[category.name] = wrappers
            colorsMap[category.name] = category.color
        }
        
        let config = ConfigData(categories: categoryNames, apps: appsMap, category_colors: colorsMap)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            
            let url = getConfigURL()
            try data.write(to: url)
        } catch {
            
        }
    }
    
    func addCategory(name: String, color: String = "#3c3c3c") {
        let newCategory = Category(name: name, apps: [], color: color)
        categories.append(newCategory)
        saveConfig()
    }
    
    func addApp(to categoryName: String, item: AppItem) {
        guard let index = categories.firstIndex(where: { $0.name == categoryName }) else { return }
        categories[index].apps.append(item)
        saveConfig()
    }
    
    func deleteApp(item: AppItem) {
        guard let catIndex = categories.firstIndex(where: { $0.apps.contains(where: { $0.path == item.path }) }),
              let appIndex = categories[catIndex].apps.firstIndex(where: { $0.path == item.path }) else { return }
        
        categories[catIndex].apps.remove(at: appIndex)
        saveConfig()
    }
    
    func deleteCategory(name: String) {
        guard let index = categories.firstIndex(where: { $0.name == name }) else { return }
        categories.remove(at: index)
        saveConfig()
    }
}

extension NSColor {
    convenience init(hex: String) {
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
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        let a = Int(round(rgbColor.alphaComponent * 255))
        if a == 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return String(format: "#%02X%02X%02X%02X", a, r, g, b)
        }
    }
}
