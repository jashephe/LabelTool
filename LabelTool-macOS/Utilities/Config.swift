import Foundation
import Defaults

private let defaultsSuite = UserDefaults(suiteName: Config.suiteName)!

/// Dynamic application configuration
extension Defaults.Keys {
    static let printers = Key<[String: PrinterConfig]>("printers", default: [:], suite: defaultsSuite)
    static let labelValues = Key<[String: String]>("labelValues", default: [:], suite: defaultsSuite)
}

struct PrinterConfig: Codable, Hashable {
    /// The hostname of the print server
    var hostname: URL
    /// The JetDirect/AppSocket raw printer port to which print data should be sent
    var printPort: UInt16 = 9100
    /// The port to which JSON Set-Get-Do control codes can be sent
    var jsonControlPort: UInt16 = 9200
}

/// Static application configuration
struct Config {
    static var suiteName: String? {
        return Bundle.main.object(forInfoDictionaryKey: "DEFAULTS_SUITE") as? String
    }
}
