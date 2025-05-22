import Foundation

/// A utility class for loading resources for the DICOM previewer
class ResourceLoader {
    /// Loads a resource file as a string
    /// - Parameter name: The file name without extension
    /// - Parameter ext: The file extension
    /// - Returns: The resource content as a string, or nil if the file couldn't be loaded
    static func loadResource(name: String, withExtension ext: String) -> String? {
        guard let bundleURL = Bundle.main.url(forResource: name, withExtension: ext) else {
            return nil
        }

        do {
            return try String(contentsOf: bundleURL, encoding: .utf8)
        } catch {
            print("Error loading resource \(name).\(ext): \(error)")
            return nil
        }
    }

    /// Returns the CSS content as a string
    static var css: String {
        loadResource(name: "styles", withExtension: "css") ?? ""
    }

    /// Returns the JavaScript content as a string
    static var javascript: String {
        loadResource(name: "scripts", withExtension: "js") ?? ""
    }

    /// Generates the HTML head section with CSS and JavaScript
    static func generateHTMLHead(title: String) -> String {
        """
        <head>
            <meta charset="utf-8">
            <title>\(title)</title>
            <style>
            \(css)
            </style>
            <script>
            \(javascript)
            </script>
        </head>
        """
    }
}
