import Foundation

/// Represents a label template, with associated dimensions
struct LabelTemplate: Codable {
    /// The manufacturer of the label
    var manufacturer: String?
    /// The product name of the label, e.g. the manufacturer's catalog number
    var productName: String?
    
    /// The width of the label, in dots
    var width: UInt
    /// The height of the label, in dots
    var height: UInt
    /// The bounds rect of the label
    var bounds: CGRect {
        get {
            CGRect(x: 0, y: 0, width: Int(self.width), height: Int(self.height))
        }
    }
    
    /// The various fields that make up the content of the label
    var labelElements: [LabelElement] = []
    
    // MARK: Codable Conformance
    
    enum SectionCodingKeys: String, CodingKey {
        case metadata
        case physicalProperties
        case elements
    }
    
    enum MetadataKeys: String, CodingKey {
        case version
    }
    
    enum PhysicalPropertiesKeys: String, CodingKey {
        case manufacturer
        case productName
        case width
        case height
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SectionCodingKeys.self)
        
        let metadataContainer = try container.nestedContainer(keyedBy: MetadataKeys.self, forKey: .metadata)
        let version = try metadataContainer.decode(UInt.self, forKey: .version)
        if version != 1 {
            throw LabelFileError.invalidVersion(version)
        }
        
        let physicalPropertiesContainer = try container.nestedContainer(keyedBy: PhysicalPropertiesKeys.self, forKey: .physicalProperties)
        self.manufacturer = try physicalPropertiesContainer.decode(String.self, forKey: .manufacturer)
        self.productName = try physicalPropertiesContainer.decode(String.self, forKey: .productName)
        self.width = try physicalPropertiesContainer.decode(UInt.self, forKey: .width)
        self.height = try physicalPropertiesContainer.decode(UInt.self, forKey: .height)
        
        self.labelElements = try container.decode([LabelElementCoder].self, forKey: .elements).map(\.labelElement)
    }
    
    //FIXME: Implement
    func encode(to encoder: Encoder) throws {
        Foundation.exit(1)
    }
    
    // MARK: Implementation
    
    /// Create a new label template
    /// - Parameter description: An optional manufacturer of the label
    /// - Parameter name: The name of the label (such as the product name or catalog number)
    /// - Parameter width: The width of the label, in dots
    /// - Parameter height: The height of the label, in dots
    init(manufacturer: String? = nil, productName: String?, width: UInt, height: UInt) {
        self.manufacturer = manufacturer
        self.productName = productName
        self.width = width
        self.height = height
    }
}

// MARK: - Utilities

enum LabelFileError: LocalizedError {
    case invalidVersion(_ foundVersion: UInt)
    case unknownType(_ type: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidVersion(let foundVersion):
            return "File version is unacceptable (file has version \"\(foundVersion)\")"
        case .unknownType(let type):
            return "Encountered a type that is unknown (\"\(type)\")"
        }
    }
}
