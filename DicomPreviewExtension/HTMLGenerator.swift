import Foundation
import Cocoa

/// A utility class for generating HTML content for the DICOM previewer
class HTMLGenerator {
    /// Generates an error HTML page
    /// - Parameter error: The error to display
    /// - Returns: The complete HTML content as a string
    static func generateErrorHTML(error: Error) -> String {
        let errorHTML = """
        <!DOCTYPE html>
        <html>
        \(ResourceLoader.generateHTMLHead(title: "DICOM Parse Error"))
        <body>
            <div class="error">Error parsing DICOM file: \(error.localizedDescription)</div>
        </body>
        </html>
        """

        return errorHTML
    }

    /// Generates HTML for a single DICOM attribute
    /// - Parameter attr: The DICOM attribute
    /// - Returns: The HTML for the attribute row
    static func renderAttribute(_ attr: DicomAttribute) -> String {
        let valueHtml: String
        switch attr.value {
        case .string(let str):
            valueHtml = str
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        case .sequence(let items):
            let itemCount = items.count
            valueHtml = """
                <div class="sequence">
                    <button class="sequence-toggle" onclick="toggleSequence(this)">▶ Sequence [\(itemCount) items]</button>
                    <div class="sequence-content" style="display: none;">
                        <table class="nested-table">
                            <tbody>
                                \(items.map(renderAttribute).joined(separator: "\n"))
                            </tbody>
                        </table>
                    </div>
                </div>
                """
        @unknown default:
            valueHtml = "[Unknown value type]"
        }

        // Add indentation based on depth
        let indentation = String(repeating: "&nbsp;&nbsp;&nbsp;&nbsp;", count: attr.depth)

        let valueCell = switch attr.value {
        case .string:
            """
            <td class="value">\(indentation)\(valueHtml)</td>
            """
        case .sequence:
            """
            <td class="value">\(indentation)\(valueHtml)</td>
            """
        @unknown default:
            """
            <td class="value">\(indentation)[Unknown value type]</td>
            """
        }

        return """
        <tr>
            <td class="tag-id">\(attr.tag)</td>
            <td class="tag-name">\(attr.name)</td>
            <td class="vr">\(attr.vr)</td>
            \(valueCell)
        </tr>
        """
    }

    /// Generates the file information section for the debug info
    /// - Parameter debugInfo: The debug information
    /// - Returns: HTML for the file information section
    private static func generateFileInfoHTML(debugInfo: DicomDebugInfo) -> String {
        """
        <tr>
            <th colspan="2">File Information</th>
        </tr>
        <tr>
            <td>File Size</td>
            <td>\(debugInfo.fileSize) bytes</td>
        </tr>
        <tr>
            <td>DICOM Magic</td>
            <td>\(debugInfo.dicomMagic)</td>
        </tr>
        <tr>
            <td>Transfer Syntax</td>
            <td>\(debugInfo.transferSyntax ?? "N/A")</td>
        </tr>
        """
    }
    
    /// Generates the DICOM structure section for the debug info
    /// - Parameter debugInfo: The debug information
    /// - Returns: HTML for the DICOM structure section
    private static func generateStructureInfoHTML(debugInfo: DicomDebugInfo) -> String {
        """
        <tr>
            <th colspan="2">DICOM Structure</th>
        </tr>
        <tr>
            <td>Total Attributes</td>
            <td>\(debugInfo.attributeCount)</td>
        </tr>
        <tr>
            <td>Sequence Count</td>
            <td>\(debugInfo.sequenceCount)</td>
        </tr>
        <tr>
            <td>Meta Info Present</td>
            <td>\(debugInfo.metaInfoPresent)</td>
        </tr>
        """
    }
    
    /// Generates the pixel data section for the debug info
    /// - Parameter debugInfo: The debug information
    /// - Returns: HTML for the pixel data section
    private static func generatePixelDataInfoHTML(debugInfo: DicomDebugInfo) -> String {
        """
        <tr>
            <th colspan="2">Pixel Data Information</th>
        </tr>
        <tr>
            <td>Has Pixel Data</td>
            <td>\(debugInfo.hasPixelData)</td>
        </tr>
        <tr>
            <td>Pixel Data VR</td>
            <td>\(debugInfo.pixelDataVr ?? "N/A")</td>
        </tr>
        <tr>
            <td>Dimensions</td>
            <td>\(debugInfo.imageDimensions.map { "\($0.rows) × \($0.columns)" } ?? "N/A")</td>
        </tr>
        <tr>
            <td>Number of Frames</td>
            <td>\(debugInfo.numberOfFrames ?? 1)</td>
        </tr>
        <tr>
            <td>Bits Allocated</td>
            <td>\(debugInfo.bitsAllocated ?? 0)</td>
        </tr>
        <tr>
            <td>Samples per Pixel</td>
            <td>\(debugInfo.samplesPerPixel ?? 0)</td>
        </tr>
        <tr>
            <td>Photometric Interpretation</td>
            <td>\(debugInfo.photometricInterpretation ?? "N/A")</td>
        </tr>
        <tr>
            <td>Pixel Representation</td>
            <td>\(debugInfo.pixelRepresentation ?? 0)</td>
        </tr>
        """
    }
    
    /// Generates the error section for the debug info
    /// - Parameter debugInfo: The debug information
    /// - Returns: HTML for the error section, or empty string if no errors
    private static func generateErrorSectionHTML(debugInfo: DicomDebugInfo) -> String {
        if debugInfo.parseError == nil &&
           debugInfo.pixelDecodeError == nil &&
           debugInfo.pixelConvertError == nil &&
           debugInfo.pixelEncodeError == nil {
            return ""
        }
        
        return """
        <div class="error-section">
            <h3>Errors</h3>
            \(debugInfo.parseError.map { "<p class='error-item'><strong>Parse Error:</strong> \($0)</p>" } ?? "")
            \(debugInfo.pixelDecodeError.map { "<p class='error-item'><strong>Pixel Decode Error:</strong> \($0)</p>" } ?? "")
            \(debugInfo.pixelConvertError.map { "<p class='error-item'><strong>Pixel Convert Error:</strong> \($0)</p>" } ?? "")
            \(debugInfo.pixelEncodeError.map { "<p class='error-item'><strong>Pixel Encode Error:</strong> \($0)</p>" } ?? "")
        </div>
        """
    }

    /// Generates the debug information HTML section
    /// - Parameter debugInfo: The debug information
    /// - Returns: The HTML for the debug section
    static func generateDebugInfoHTML(debugInfo: DicomDebugInfo) -> String {
        """
        <div class="debug-container">
            <button class="debug-toggle" onclick="toggleDebug(this)">▶ Show Debug Information</button>
            <div class="debug-content" style="display: none;">
                <table class="debug-table">
                    \(generateFileInfoHTML(debugInfo: debugInfo))
                    \(generateStructureInfoHTML(debugInfo: debugInfo))
                    \(generatePixelDataInfoHTML(debugInfo: debugInfo))
                </table>
                \(generateErrorSectionHTML(debugInfo: debugInfo))
            </div>
        </div>
        """
    }

    /// Generates the preview image section HTML
    /// - Parameter imageData: Array of preview image data
    /// - Returns: The HTML for the preview section
    static func generatePreviewHTML(imageData: [Data]) -> String {
        if imageData.isEmpty {
            return """
            <div class="preview-container">
                <button class="preview-toggle" onclick="togglePreview(this)">▶ Preview Image</button>
                <div class="preview-content" style="display: none;">
                    <div class="no-preview-container">
                        <p class="error-message">No preview image available</p>
                    </div>
                </div>
            </div>
            """
        } else {
            return """
            <div class="preview-container">
                <button class="preview-toggle" onclick="togglePreview(this)">▼ Preview Image</button>
                <div class="preview-content">
                    <div class="preview-image-wrapper">
                        <img id="previewImage"
                             src="data:image/jpeg;base64,\(imageData[0].base64EncodedString())"
                             class="preview-image">
                    </div>
                    \(imageData.count > 1 ? """
                        <div class="slider-container">
                            <input type="range" id="frameSlider" min="0" max="\(imageData.count - 1)" value="0" class="frame-slider">
                            <div class="slider-label">Frame: <span id="frameNumber">1</span> / \(imageData.count)</div>
                        </div>
                        <script>
                            window.frameData = [
                                \(imageData.map {
                                    "'\($0.base64EncodedString())'"
                                }.joined(separator: ",\n                                "))
                            ];
                        </script>
                    """ : "")
                </div>
            </div>
            """
        }
    }

    /// Generates a complete HTML document for the DICOM file preview
    /// - Parameter parseResult: The DICOM parse result
    /// - Returns: The complete HTML content as a string
    static func generateFullHTML(parseResult: DicomParser.ParseResult) -> String {
        let tableRows = parseResult.attributes.map(renderAttribute).joined(separator: "\n")
        let debugInfoHtml = generateDebugInfoHTML(debugInfo: parseResult.debugInfo)
        let previewHtml = generatePreviewHTML(imageData: parseResult.previewImageData)

        return """
        <!DOCTYPE html>
        <html>
        \(ResourceLoader.generateHTMLHead(title: "DICOM File Preview"))
        <body>
            <div class="container">
                <h1>DICOM File Preview</h1>
                <div class="preview-section">
                    \(previewHtml)
                    \(debugInfoHtml)
                </div>
                <div class="attributes-section">
                    <div class="controls">
                        <button onclick="expandAll()">Expand All</button>
                        <button onclick="collapseAll()">Collapse All</button>
                    </div>
                    <div class="table-container">
                        <table>
                            <thead>
                                <tr>
                                    <th class="tag-id">Tag ID</th>
                                    <th class="tag-name">Tag Name</th>
                                    <th class="vr">VR</th>
                                    <th class="value">Value</th>
                                </tr>
                            </thead>
                            <tbody>
                                \(tableRows)
                            </tbody>
                        </table>
                    </div>
                    <div class="count">\(parseResult.attributes.count) DICOM attributes</div>
                </div>
            </div>
        </body>
        </html>
        """
    }
}
