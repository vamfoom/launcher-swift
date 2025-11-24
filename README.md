# Launcher (Swift)

A native macOS launcher application built with Swift and SwiftUI. This project is a migration of a Python-based launcher to a native macOS experience, offering improved performance and better integration with the system.

## Features

- **App & Web Launching**: Quickly launch your favorite applications and web links.
- **Categorization**: Organize your items into customizable categories.
- **Customization**: Change category colors to suit your preference.
- **Drag & Drop**: Easily reorder apps and categories using drag and drop.
- **Context Menus**: Right-click on items to rename, edit URLs (for web apps), or delete them.
- **Native Experience**: Built with SwiftUI for a smooth and responsive user interface.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16.0+ (for building from source)
- Swift 6.0+

## Installation

### Building from Source

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd launcher-swift
    ```

2.  **Build and Package:**
    The easiest way to build the application and create an installable disk image (`.dmg`) is to use the provided script:
    ```bash
    ./package.sh
    ```
    This script will:
    - Build the project in release mode.
    - Create a `Launcher.app` bundle.
    - Package it into `Launcher.dmg`.

3.  **Install:**
    Open the generated `Launcher.dmg` and drag the `Launcher` app to your `Applications` folder.

### Development

You can also open the project directly in Xcode by opening the `Package.swift` file or the folder itself.

```bash
open Package.swift
```

Or build using Swift Package Manager directly:

```bash
swift build -c release
```

The executable will be located in `.build/release/Launcher`. Note that running the executable directly might not have the full application bundle structure (Icon, Info.plist) unless you use the `package.sh` script.

## Usage

- **Launch Item**: Click on an icon to launch the app or open the web link.
- **Edit Item**: Right-click on an item to access options like Rename, Edit URL, or Delete.
- **Reorder**: Click and drag an icon to move it to a new position or category.
- **Customize Category**: Right-click on a category header (if implemented) or use the settings to change colors.

## License

[MIT License](LICENSE) (Assuming MIT, or you can add the appropriate license)
