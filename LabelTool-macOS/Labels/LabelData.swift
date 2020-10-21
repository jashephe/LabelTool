import Foundation
import Defaults

struct LabelField {
    let descriptor: LabelFieldDescriptor
    let range: Range<String.Index>
    let isOptional: Bool

    private init(descriptor: LabelFieldDescriptor, range: Range<String.Index>, isOptional: Bool = false) {
        self.descriptor = descriptor
        self.range = range
        self.isOptional = isOptional
    }

    private init?(match: NSTextCheckingResult, in string: String) {
        guard
            let fieldFullRange = Range(match.range, in: string),
            let fieldTypeRange = Range(match.range(withName: "type"), in: string),
            let fieldType = LabelFieldType(typeCode: string[fieldTypeRange]),
            let fieldNameRange = Range(match.range(withName: "variableName"), in: string)
        else {
            return nil
        }
        let isOptional = match.range(withName: "optional") != NSRange(location: .max, length: 0)
        let descriptor = LabelFieldDescriptor(name: String(string[fieldNameRange]), type: fieldType)

        self = LabelField(descriptor: descriptor, range: fieldFullRange, isOptional: isOptional)
    }

    /// An `NSRegularExpression` matching label element variable fields
    private static let _FIELD_MATCHER = try! NSRegularExpression(pattern: ##"(?<type>\$|\#)(?<optional>\?)?\{(?<variableName>[^}]+)\}"##, options: [])

    /// Identify the variable fields in a string
    /// - Important: fields are returned in the order in which they occur in `string`, from the beginning to the end of the string
    /// - Returns: a list of zero or more `LabelField`s
    static func fields(in string: String) -> [Self] {
        return Self._FIELD_MATCHER.matches(in: string, options: [], range: NSRange(string.startIndex..., in: string)).compactMap { (match) -> Self? in
            return Self(match: match, in: string)
        }
    }

    /*
    /// Replace the variable fields in a string with the given field data
    /// - Parameter string: the string in which to substitute variable fields with data
    /// - Parameter data: the data to substitute for the fields in the label
    static func substituteFields(in string: String, withData data: LabelData) -> String {
        var substitutedString = string

        for field in Self.fields(in: string).reversed() {
            if let fieldValue = data.value(for: field.descriptor) {
                substitutedString.replaceSubrange(field.range, with: fieldValue)
            } else if field.isOptional {
                substitutedString.replaceSubrange(field.range, with: "")
            }
        }

        return substitutedString
    }*/
}

enum LabelFieldType: Comparable, CustomStringConvertible {
    case computed
    case userDefined

    var description: String {
        switch self {
        case .computed:
            return "#"
        case .userDefined:
            return "$"
        }
    }

    init?<S: StringProtocol>(typeCode: S) {
        switch typeCode {
        case "#":
            self = .computed
        case "$":
            self = .userDefined
        default:
            return nil
        }
    }

    static func < (lhs: LabelFieldType, rhs: LabelFieldType) -> Bool {
        if case .userDefined = lhs, case .computed = rhs {
            return true
        }
        return false
    }
}

struct LabelFieldDescriptor: Hashable, Comparable, CustomStringConvertible {
    let name: String
    let type: LabelFieldType

    var description: String {
        return "\(self.type)\(self.name)"
    }

    init(name: String, type: LabelFieldType) {
        self.name = name
        self.type = type
    }

    init?<S: StringProtocol>(string: S, defaultType: LabelFieldType? = nil) {
        guard string.count > 0 else { return nil }

        var trimmedString = String(string)
        if let type = LabelFieldType(typeCode: String(trimmedString.remove(at: string.startIndex))) {
            guard trimmedString.count > 0 else { return nil }
            self.init(name: trimmedString, type: type)
        } else {
            if let defaultType = defaultType {
                self.init(name: String(string), type: defaultType)
            } else {
                return nil
            }
        }
    }

    static func < (lhs: LabelFieldDescriptor, rhs: LabelFieldDescriptor) -> Bool {
        if lhs.type != rhs.type {
            return lhs.type < rhs.type
        } else {
            return lhs.name < rhs.name
        }
    }
}

struct LabelsData {
    private var data: [LabelFieldDescriptor: [String]]

    var fieldDescriptors: [LabelFieldDescriptor] {
        get {
            let array = Array(self.data.keys.sorted())
            return array
        }
    }

    var count: UInt {
        return UInt(self.data.first?.value.count ?? 0)
    }

    init(template: LabelTemplate) {
        self.init(fieldDescriptors: Set(template.labelElements.flatMap { (element) -> [LabelFieldDescriptor] in
            LabelField.fields(in: element.valuePrototype).map(\.descriptor)
        }))
    }

    init<S>(fieldDescriptors: S) where S: Sequence, S.Element == LabelFieldDescriptor {
        self.data = [:]
        for fieldDescriptor in fieldDescriptors {
            self.data[fieldDescriptor] = []
        }
    }

    func value(atIndex index: UInt, withDescriptor descriptor: LabelFieldDescriptor) -> String? {
        return self.data[descriptor]?[Int(index)]
    }

    func valueRendererWithData(atIndex index: UInt, fields maybeFields: [LabelField]? = nil) -> (String) -> String {
        return { (valuePrototype) -> String in
            var substitutedValue = valuePrototype
            for field in (maybeFields ?? LabelField.fields(in: valuePrototype)).reversed() {
                if let fieldValue = self.value(atIndex: index, withDescriptor: field.descriptor), fieldValue.count > 0 {
                    substitutedValue.replaceSubrange(field.range, with: fieldValue)
                } else if field.isOptional {
                    substitutedValue.replaceSubrange(field.range, with: "")
                }
            }
            return substitutedValue
        }
    }

    mutating func clear() {
        let fieldDescriptors = self.fieldDescriptors
        self.data = [:]
        for fieldDescriptor in fieldDescriptors {
            self.data[fieldDescriptor] = []
        }
    }

    mutating func add(values: [(LabelFieldDescriptor, String)]) {
        let countBefore = self.count
        for (descriptor, value) in values {
            self.data[descriptor]?.append(value)
        }
        for descriptor in self.fieldDescriptors {
            if UInt(self.data[descriptor]!.count) < countBefore + 1 {
                switch descriptor.type {
                case .computed:
                    self.data[descriptor]?.append(Self.computedValueForField(named: descriptor.name) ?? "")
                case .userDefined:
                    if let defaultValue = Defaults[.labelValues][descriptor.name]  {
                        self.data[descriptor]?.append(defaultValue)
                    } else {
                        self.data[descriptor]?.append("")
                    }
                }
            }
        }
    }

    mutating func importData(fromDelimited table: String, delimiter: Character = "\t") {
        var lines = table.split(whereSeparator: \.isNewline)
        let fields = lines.removeFirst().split(separator: delimiter).map({ LabelFieldDescriptor(string: String($0), defaultType: .userDefined) })

        for line in lines {
            self.add(values: zip(fields, line.split(separator: delimiter).map(String.init)).compactMap({ (maybeDescriptor, value) -> (LabelFieldDescriptor, String)? in
                if let descriptor = maybeDescriptor {
                    return (descriptor, value)
                } else {
                    return nil
                }
            }))
        }
    }

    private static func computedValueForField<S>(named fieldName: S) -> String? where S: StringProtocol {
        switch fieldName {
        case "today":
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.string(from: Date())
        case "uuid":
            return UUID().uuidString
        default:
            return nil
        }
    }
}
