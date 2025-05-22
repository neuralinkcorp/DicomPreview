import Cocoa
import Quartz

class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    /*
     Use a QLPreviewProvider to provide data-based previews.
     */

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        // Parse DICOM file
        let parseResult: DicomParser.ParseResult

        do {
            parseResult = try DicomParser.parseFile(at: request.fileURL)
        } catch {
            // Return error HTML on failure
            let errorHTML = HTMLGenerator.generateErrorHTML(error: error)
            let data = Data(errorHTML.utf8)

            return QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 800, height: 600)) { _ in
                return data
            }
        }

        // Determine content size based on whether we have an image
        let contentSize: CGSize
        if !parseResult.previewImageData.isEmpty {
            contentSize = CGSize(width: 800, height: 800)  // Larger size for images
        } else {
            contentSize = CGSize(width: 800, height: 600)  // Smaller size for text-only
        }

        // Generate full HTML document
        let html = HTMLGenerator.generateFullHTML(parseResult: parseResult)
        let data = Data(html.utf8)

        return QLPreviewReply(dataOfContentType: .html, contentSize: contentSize) { _ in
            return data
        }
    }
}
