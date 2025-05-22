import Foundation

// Import C function via a bridging interface
@_silgen_name("parse_dicom_file")
func parseDicomFile(_ path: UnsafePointer<Int8>) -> DicomParseResult

@_silgen_name("free_dicom_parse_result")
func freeDicomParseResult(_ result: DicomParseResult)

// Matching the C struct
struct DicomParseResult {
    let jsonData: UnsafeMutablePointer<Int8>?
    let errorMessage: UnsafeMutablePointer<Int8>?
}

public enum AttributeValue: Codable {
    case string(String)
    case sequence([DicomAttribute])

    private enum CodingKeys: String, CodingKey {
        case type, content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "String":
            let content = try container.decode(String.self, forKey: .content)
            self = .string(content)
        case "Sequence":
            let content = try container.decode([DicomAttribute].self, forKey: .content)
            self = .sequence(content)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let str):
            try container.encode("String", forKey: .type)
            try container.encode(str, forKey: .content)
        case .sequence(let seq):
            try container.encode("Sequence", forKey: .type)
            try container.encode(seq, forKey: .content)
        }
    }
}

public struct DicomAttribute: Codable {
    public let depth: Int
    public let tag: String
    public let name: String
    public let vr: String
    public let value: AttributeValue

    public init(depth: Int, tag: String, name: String, vr: String, value: AttributeValue) {
        self.depth = depth
        self.tag = tag
        self.name = name
        self.vr = vr
        self.value = value
    }
}

public struct Dimensions: Codable {
    public let rows: Int
    public let columns: Int
}

public struct DicomDebugInfo: Codable {
    // File information
    public let fileSize: UInt64
    public let filePreamble: String
    public let dicomMagic: String
    public let transferSyntax: String?

    // General DICOM info
    public let attributeCount: Int
    public let sequenceCount: Int
    public let metaInfoPresent: Bool

    // Pixel data info
    public let hasPixelData: Bool
    public let pixelDataVr: String?
    public let imageDimensions: Dimensions?
    public let numberOfFrames: Int?
    public let bitsAllocated: Int?
    public let samplesPerPixel: Int?
    public let photometricInterpretation: String?
    public let pixelRepresentation: Int?

    // Error tracking
    public let parseError: String?
    public let pixelDecodeError: String?
    public let pixelConvertError: String?
    public let pixelEncodeError: String?

    private enum CodingKeys: String, CodingKey {
        case fileSize = "file_size"
        case filePreamble = "file_preamble"
        case dicomMagic = "dicom_magic"
        case transferSyntax = "transfer_syntax"
        case attributeCount = "attribute_count"
        case sequenceCount = "sequence_count"
        case metaInfoPresent = "meta_info_present"
        case hasPixelData = "has_pixel_data"
        case pixelDataVr = "pixel_data_vr"
        case imageDimensions = "image_dimensions"
        case numberOfFrames = "number_of_frames"
        case bitsAllocated = "bits_allocated"
        case samplesPerPixel = "samples_per_pixel"
        case photometricInterpretation = "photometric_interpretation"
        case pixelRepresentation = "pixel_representation"
        case parseError = "parse_error"
        case pixelDecodeError = "pixel_decode_error"
        case pixelConvertError = "pixel_convert_error"
        case pixelEncodeError = "pixel_encode_error"
    }
}

struct DicomParseOutput: Codable {
    let attributes: [DicomAttribute]
    let previewImages: [String]?
    public let debugInfo: DicomDebugInfo

    private enum CodingKeys: String, CodingKey {
        case attributes
        case previewImages = "preview_images"
        case debugInfo = "debug_info"
    }
}

public class DicomParser {
    public enum DicomParserError: LocalizedError {
        case fileError(String)
        case parsingError(String)
        case jsonDecodingError(Error)

        public var errorDescription: String? {
            switch self {
            case .fileError(let message):
                return "File Error: \(message)"
            case .parsingError(let message):
                return "DICOM Parsing Error: \(message)"
            case .jsonDecodingError(let error):
                return "JSON Decoding Error: \(error.localizedDescription)"
            }
        }

        public var failureReason: String? {
            switch self {
            case .fileError:
                return "The DICOM file could not be accessed or is invalid"
            case .parsingError:
                return "The file could not be parsed as a valid DICOM file"
            case .jsonDecodingError:
                return "The parsed DICOM data could not be decoded"
            }
        }

        public var recoverySuggestion: String? {
            switch self {
            case .fileError:
                return "Please check if the file exists and you have permission to access it"
            case .parsingError:
                return "Please ensure the file is a valid DICOM file and is not corrupted"
            case .jsonDecodingError:
                return "This is an internal error. Please report this issue"
            }
        }
    }

    public struct ParseResult {
        public let attributes: [DicomAttribute]
        public let previewImageData: [Data]
        public let debugInfo: DicomDebugInfo

        init(attributes: [DicomAttribute], previewImageBase64: [String]?, debugInfo: DicomDebugInfo) {
            self.attributes = attributes
            if let base64Strings = previewImageBase64 {
                self.previewImageData = base64Strings.compactMap { base64String in
                    Data(base64Encoded: base64String)
                }
            } else {
                self.previewImageData = []
            }
            self.debugInfo = debugInfo
        }
    }

    public static func parseFile(at url: URL) throws -> ParseResult {
        // Validate file and get path
        try validateFile(at: url)

        // Convert path to C string and call Rust parser
        let result = parseWithRustParser(path: url.path)

        // Process JSON result
        return try processJsonResult(from: result)
    }

    private static func validateFile(at url: URL) throws {
        // Ensure we have a file path
        guard url.isFileURL else {
            throw DicomParserError.fileError("URL is not a file URL")
        }

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DicomParserError.fileError("File does not exist at path: \(url.path)")
        }

        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw DicomParserError.fileError("File is not readable at path: \(url.path)")
        }
    }

    private static func parseWithRustParser(path: String) -> DicomParseResult {
        // Convert path to C string
        let pathCString = path.withCString { strdup($0) }
        defer { 
            if let pathCString = pathCString {
                free(pathCString) 
            }
        }

        // Check if memory allocation succeeded
        guard let pathCString = pathCString else {
            // Return an error result instead of crashing
            let errorMessage = strdup("Failed to allocate memory for file path")
            return DicomParseResult(jsonData: nil, errorMessage: errorMessage)
        }

        // Call Rust function
        let result = parseDicomFile(pathCString)
        return result
    }

    private static func processJsonResult(from result: DicomParseResult) throws -> ParseResult {
        defer { freeDicomParseResult(result) }

        // Check for error
        if let errorPtr = result.errorMessage {
            let errorMessage = String(cString: errorPtr)
            throw DicomParserError.parsingError(errorMessage)
        }

        // Get JSON data
        guard let jsonDataPtr = result.jsonData else {
            throw DicomParserError.parsingError("No data returned from parser")
        }

        let jsonString = String(cString: jsonDataPtr)

        // Parse JSON data
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw DicomParserError.parsingError("Could not convert JSON string to data")
        }

        return try decodeJsonData(jsonData)
    }

    private static func decodeJsonData(_ jsonData: Data) throws -> ParseResult {
        do {
            let decoder = JSONDecoder()
            let output = try decoder.decode(DicomParseOutput.self, from: jsonData)

            // Validate parsed data
            if output.attributes.isEmpty {
                throw DicomParserError.parsingError("No DICOM attributes found in the file")
            }

            return ParseResult(
                attributes: output.attributes,
                previewImageBase64: output.previewImages,
                debugInfo: output.debugInfo
            )
        } catch let decodingError as DecodingError {
            throw createDecodingError(decodingError)
        } catch {
            throw DicomParserError.jsonDecodingError(error)
        }
    }

    private static func createDecodingError(_ decodingError: DecodingError) -> DicomParserError {
        // Provide more specific error for JSON decoding failures
        switch decodingError {
        case .dataCorrupted(let context):
            return DicomParserError.jsonDecodingError(
                NSError(domain: "DicomParser",
                       code: 1,
                       userInfo: [NSLocalizedDescriptionKey: "Invalid JSON data: \(context.debugDescription)"])
            )
        case .keyNotFound(let key, let context):
            return DicomParserError.jsonDecodingError(
                NSError(domain: "DicomParser",
                       code: 2,
                       userInfo: [NSLocalizedDescriptionKey: "Missing key '\(key.stringValue)' in \(context.debugDescription)"])
            )
        case .typeMismatch(let type, let context):
            return DicomParserError.jsonDecodingError(
                NSError(domain: "DicomParser",
                       code: 3,
                       userInfo: [NSLocalizedDescriptionKey: "Type mismatch: expected \(type) in \(context.debugDescription)"])
            )
        case .valueNotFound(let type, let context):
            return DicomParserError.jsonDecodingError(
                NSError(domain: "DicomParser",
                       code: 4,
                       userInfo: [NSLocalizedDescriptionKey: "Value of type \(type) not found in \(context.debugDescription)"])
            )
        @unknown default:
            return DicomParserError.jsonDecodingError(decodingError)
        }
    }
}
