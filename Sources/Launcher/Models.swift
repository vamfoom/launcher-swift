import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let appItem = UTType(exportedAs: "com.launcher.appitem", conformingTo: .json)
    static let categoryItem = UTType(exportedAs: "com.launcher.categoryitem", conformingTo: .json)
}

struct AppItem: Identifiable, Codable, Hashable, Transferable {
    var id = UUID()
    var path: String
    var name: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case path
        case name
    }
    
    init(id: UUID = UUID(), path: String, name: String? = nil) {
        self.id = id
        self.path = path
        self.name = name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try container.decode(String.self, forKey: .path)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(name, forKey: .name)
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .appItem)
    }
    
    func launch() {
        if path.hasPrefix("http") || path.hasPrefix("https") {
            if let url = URL(string: path) {
                NSWorkspace.shared.open(url)
            }
        } else {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.open(url)
        }
    }
}

struct CategoryProxy: Codable, Transferable {
    var id: UUID
    var name: String
    var isCategory: Bool = true
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .categoryItem)
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
    var recent_apps: [AppItemWrapper]?
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
    @Published var recentApps: [AppItem] = []
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
            let config = ConfigData(categories: defaultCategories, apps: [:], category_colors: [:], recent_apps: [])
            
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
            
            if let recentWrappers = config.recent_apps {
                self.recentApps = recentWrappers.map { wrapper -> AppItem in
                    switch wrapper {
                    case .string(let path):
                        return AppItem(path: path, name: nil)
                    case .object(let item):
                        return item
                    }
                }
            }
        } catch {
            // Error handling ignored
        }
    }
    
    func launchApp(item: AppItem) {
        item.launch()
        addToRecents(item: item)
    }
    
    func addToRecents(item: AppItem) {
        // Remove existing if present (deduplicate)
        recentApps.removeAll { $0.path == item.path }
        
        // Prepend new
        recentApps.insert(item, at: 0)
        
        // Limit to 12
        if recentApps.count > 12 {
            recentApps = Array(recentApps.prefix(12))
        }
        
        saveConfig()
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
        guard let catIndex = categories.firstIndex(where: { $0.apps.contains(where: { $0.id == item.id }) }),
              let appIndex = categories[catIndex].apps.firstIndex(where: { $0.id == item.id }) else { return }
        
        categories[catIndex].apps[appIndex].name = newName

        saveConfig()
    }
    
    func updateAppPath(item: AppItem, newPath: String) {
        guard let catIndex = categories.firstIndex(where: { $0.apps.contains(where: { $0.id == item.id }) }),
              let appIndex = categories[catIndex].apps.firstIndex(where: { $0.id == item.id }) else { return }
        
        categories[catIndex].apps[appIndex].path = newPath

        saveConfig()
    }
    
    func updateCategoryColor(categoryName: String, newColor: String) {
        guard let index = categories.firstIndex(where: { $0.name == categoryName }) else { return }
        categories[index].color = newColor

        saveConfig()
    }
    
    func renameCategory(oldName: String, newName: String) {
        guard let index = categories.firstIndex(where: { $0.name == oldName }) else { return }
        categories[index].name = newName
        saveConfig()
    }
    
    func moveApp(item: AppItem, toCategory categoryName: String, before targetApp: AppItem?, isCopy: Bool = false) {

        
        // Find source category and index by ID
        guard let sourceCatIndex = categories.firstIndex(where: { $0.apps.contains(where: { $0.id == item.id }) }) else { 

            return 
        }
        
        guard let sourceIndex = categories[sourceCatIndex].apps.firstIndex(where: { $0.id == item.id }) else { 

            return 
        }
        
        let actualIsCopy = (categories[sourceCatIndex].name == categoryName) ? false : isCopy
        
        let app: AppItem
        if actualIsCopy {
            app = AppItem(id: UUID(), path: item.path, name: item.name)
        } else {
            app = categories[sourceCatIndex].apps.remove(at: sourceIndex)
        }
        
        // Find target category
        guard let targetCatIndex = categories.firstIndex(where: { $0.name == categoryName }) else { 

            // Fallback: if we removed it, put it back
            if !actualIsCopy {
                categories[sourceCatIndex].apps.insert(app, at: sourceIndex)
            }
            return 
        }
        
        // Insert at target
        if let targetApp = targetApp, let targetIndex = categories[targetCatIndex].apps.firstIndex(where: { $0.id == targetApp.id }) {
            categories[targetCatIndex].apps.insert(app, at: targetIndex)
        } else {
            // Append if no target (dropped on category)
            categories[targetCatIndex].apps.append(app)
        }
        
        

        saveConfig()
        saveConfig()
    }
    
    func moveCategory(item: CategoryProxy, before targetCategory: Category?) {
        // Find source by ID or Name (since ID might change if reloaded, but here we use proxy ID which should match if session is same)
        // Actually, let's try to match by ID first, then Name
        guard let sourceIndex = categories.firstIndex(where: { $0.id == item.id || $0.name == item.name }) else { return }
        
        let category = categories.remove(at: sourceIndex)
        
        if let targetCategory = targetCategory, let targetIndex = categories.firstIndex(where: { $0.id == targetCategory.id }) {
            categories.insert(category, at: targetIndex)
        } else {
            categories.append(category)
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
        
        let recentWrappers = recentApps.map { AppItemWrapper.object($0) }
        
        let config = ConfigData(categories: categoryNames, apps: appsMap, category_colors: colorsMap, recent_apps: recentWrappers)
        
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
        guard let catIndex = categories.firstIndex(where: { $0.apps.contains(where: { $0.id == item.id }) }),
              let appIndex = categories[catIndex].apps.firstIndex(where: { $0.id == item.id }) else { return }
        
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
