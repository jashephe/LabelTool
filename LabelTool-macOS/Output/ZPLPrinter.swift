import Foundation
import Network
import Combine

/// Exposes functions for interfacing with a networked label printer that communicates via ZPL II
/// over AppSocket/JetDirect
struct ZPLPrinter {
    let printingEndpoint: NWEndpoint
    let jsonControlEndpoint: NWEndpoint
    
    init(host rawHost: String, printingPort rawPrintingPort: UInt16 = 9100, jsonControlPort rawJsonControlPort: UInt16 = 9200) throws {
        guard let printingPort = NWEndpoint.Port(rawValue: rawPrintingPort) else {
            throw ZPLPrinter.Error.invalidPort(rawPrintingPort)
        }
        guard let jsonControlPort = NWEndpoint.Port(rawValue: rawJsonControlPort) else {
            throw ZPLPrinter.Error.invalidPort(rawJsonControlPort)
        }
        self.printingEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(rawHost), port: printingPort)
        self.jsonControlEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(rawHost), port: jsonControlPort)
    }

    init(printerConfig: PrinterConfig) throws {
        try self.init(host: printerConfig.hostname.path, printingPort: printerConfig.printPort, jsonControlPort: printerConfig.jsonControlPort)
    }
    
    /// Query the printer for information such as model name and print status
    /// - Returns: A Combine `Publisher` that resolves to a populated `PrinterInformation` struct
    func getPrinterInformation() -> AnyPublisher<PrinterInformation, ZPLPrinter.Error> {
        return self.send(message: PrinterInformation.PRINTER_INFORMATION_QUERY, toEndpoint: self.jsonControlEndpoint).decode(type: PrinterInformation.self, decoder: JSONDecoder()).mapError { (error) -> ZPLPrinter.Error in
            switch error {
            case _ as Swift.DecodingError:
                return .invalidResponse
            case let error as ZPLPrinter.Error:
                return error
            default:
                return .unknownError
            }
        }.eraseToAnyPublisher()
    }
    
    /// Generate the ZPL instructions for printing the given pixels on the printer as a `^GF` (Graphic Field) element
    /// - Parameter pixelData: The pixel data of the image to print
    /// - Parameter width: The width of the image, in pixels
    /// - Parameter zplPrefix: A series of ZPL commands that will be added to the ZPL string before the `^GF` element
    /// - Important: `pixelData` should be an array of length `(width * `[the height of the image]`)`, with _one_ `UInt8` _per pixel_
    func generateZPLForPrinting(pixelData: [UInt8], width: UInt, zplPrefix: String? = nil) -> String {
        let height = UInt(pixelData.count) / width
        let bitMatrixWidth = width / 8 + 1
        var bitMatrix = Array<UInt8>(repeating: 0, count: Int(bitMatrixWidth * height))
        
        for pixelY in 0..<height {
            for pixelX in 0..<width {
                let pixelIndex = pixelY * width + pixelX
                let bitMatrixIndex = pixelY * bitMatrixWidth + pixelX / 8
                let bitOffset = 7 - pixelX % 8
                bitMatrix[Int(bitMatrixIndex)].setBit(at: bitOffset, to: pixelData[Int(pixelIndex)] < UInt8.max/2)
            }
        }
        
        var asciiBitString = ""
        
        for bitY in 0..<height {
            for bitX in 0..<bitMatrixWidth {
                if bitMatrix[Int(bitY * bitMatrixWidth + bitX)..<Int((bitY + 1) * bitMatrixWidth)].map(UInt.init).reduce(UInt(0), +) == 0 {
                    asciiBitString += ","
                    break
                } else {
                    asciiBitString += String(format:"%02X", bitMatrix[Int(bitY * bitMatrixWidth + bitX)])
                }
            }
        }
        // For reference, see https://github.com/apple/cups/blob/master/filter/rastertolabel.c
        let zplCommand = "^XA^POI^LH0,0\(zplPrefix ?? "")^FO0,0^GFA,\(bitMatrix.count),\(bitMatrix.count),\(bitMatrixWidth),\(asciiBitString)^FS^XZ"
        print(zplCommand)
        return zplCommand
    }
    
    /// Send a message to the printer endpoint, and return a Combine `Publisher` that resolves to the response, or
    /// any errors recieved.
    /// - Parameter message: The message to send to the printer
    /// - Parameter endpoint: The endpoint to which the message should be sent
    /// - Returns: A Combine `Publisher` that either returns the response data to the message and completes
    ///            or returns a `PrinterError`
    func send(message: Data, toEndpoint endpoint: NWEndpoint) -> AnyPublisher<Data, ZPLPrinter.Error> {
        let subject = PassthroughSubject<Data, ZPLPrinter.Error>()
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        
        connection.send(content: message, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed({ (error) in
            if let error = error {
                subject.send(completion: .failure(.networkError(source: error)))
            }
        }))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { (data, context, isComplete, error) in
            if let error = error {
                subject.send(completion: .failure(.networkError(source: error)))
            }
            if let data = data {
                subject.send(data)
            }
            if isComplete {
                subject.send(completion: .finished)
            }
        }
        return subject.eraseToAnyPublisher()
    }
    
    // MARK: - Printer Properties
    
    enum PrinterState: CustomStringConvertible {
        // Errors
        case unknownError
        case thermistorOpen
        case invalidFirmwareConfiguration
        case printheadDetectionError
        case badPrintheadElement
        case motorOverTemperature
        case printheadOverTemperature
        case cutterFault
        case headOpen
        case ribbonOut
        case mediaOut
        
        // Warnings
        case unknownWarning
        case replacePrinthead
        case cleanPrinthead
        case needToCalibrateMedia
        
        var description: String {
            switch self {
            case .unknownError:
                return "The printer has an unknown error"
            case .thermistorOpen:
                return "The thermistor is open"
            case .invalidFirmwareConfiguration:
                return "The firmware configuration is invalid"
            case .printheadDetectionError:
                return "The printhead could not be detected"
            case .badPrintheadElement:
                return "The printhead element is bad"
            case .motorOverTemperature:
                return "The motor has overheated"
            case .printheadOverTemperature:
                return "The printhead has overheated"
            case .cutterFault:
                return "There is a problem with the cutter"
            case .headOpen:
                return "The printer is open"
            case .ribbonOut:
                return "The thermal transfer ribbon is out"
            case .mediaOut:
                return "The media is out"
            case .unknownWarning:
                return "The printer has an unknown warning"
            case .replacePrinthead:
                return "The printhead should be replaced"
            case .cleanPrinthead:
                return "The printhead should be cleaned"
            case .needToCalibrateMedia:
                return "The media needs to be calibrated"
            }
        }
    }
    
    struct PrinterInformation: Decodable {
        /// The name of the printer
        let name: String
        /// The unique ID of the printer
        let id: String
        /// The product name of the printer
        let productName: String
        /// The location of the printer
        let location: String
        /// The resolution of the printer in dots per inch
        let resolution: UInt
        /// The elapsed time since the printer was powered on
        let uptime: String
        /// A flag indicating whether or not the printer is busy
        let isBusy: Bool
        /// A flag indicating whether or not the printer is paused
        let isPaused: Bool
        /// A list of zero or more printer warnings or errors
        let state: [PrinterState]
        
        enum CodingKeys: String, CodingKey {
            case name = "device.friendly_name"
            case id = "device.unique_id"
            case productName = "device.product_name"
            case location = "device.location"
            case resolution = "head.resolution.in_dpi"
            case uptime = "device.uptime"
            case isBusy = "device.status"
            case state = "zpl.system_status"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.name = try container.decode(String.self, forKey: .name)
            self.id = try container.decode(String.self, forKey: .id)
            self.productName = try container.decode(String.self, forKey: .productName)
            self.location = try container.decode(String.self, forKey: .location)
            if let resolution = UInt(try container.decode(String.self, forKey: .resolution)) {
                self.resolution = resolution
            } else {
                throw Error.invalidResponse
            }
            self.uptime = try container.decode(String.self, forKey: .uptime)
            self.isBusy = try container.decode(String.self, forKey: .isBusy) == "busy"
            (self.isPaused, self.state) = try ZPLPrinter.PrinterInformation.parseSystemStatus(container.decode(String.self, forKey: .state))
        }
        
        /// Parse the flags returned by the `zpl.system_status` SGD instruction into zero or more states
        /// - Parameter flags: The textual response from a ZPLII printer to the `! U1 getvar "zpl.system_status"` command
        /// - Note: The format of `flags` should resemble:
        /// ```
        /// 0,0,00000000,00000000,0,00000000,00000000
        /// ```
        private static func parseSystemStatus(_ statusString: String) throws -> (Bool, [PrinterState]) {
            var states: [PrinterState] = []
            
            let parts = statusString.components(separatedBy: ",")
            guard parts.count == 7 else {
                throw ZPLPrinter.Error.invalidSystemStatus(statusString)
            }
            
            func parseNibble(_ nibble: UInt8, possibleValues: [PrinterState]) -> [PrinterState] {
                var nibble = nibble
                var states: [PrinterState] = []
                
                var threshold:UInt8 = 1 << possibleValues.count - 1
                
                for possibleValue in possibleValues {
                    if nibble >= threshold {
                        states.append(possibleValue)
                        threshold = threshold/2
                        nibble -= threshold
                    }
                }
                
                return states
            }
            
            let isPaused = parts[0] != "0"
            if parts[1] != "0" { // Error flag is set
                let errorNibbles = try parts[3].map { (character) -> UInt8 in
                    guard let parsedValue = UInt8(String(character)) else {
                        throw ZPLPrinter.Error.invalidSystemStatus(statusString)
                    }
                    return parsedValue
                }
                
                var errors: [PrinterState] = []
                errors.append(contentsOf: parseNibble(errorNibbles[8 - 1], possibleValues: [.cutterFault, .headOpen, .ribbonOut, .mediaOut]))
                errors.append(contentsOf: parseNibble(errorNibbles[8 - 2], possibleValues: [.printheadDetectionError, .badPrintheadElement, .motorOverTemperature, .printheadOverTemperature]))
                errors.append(contentsOf: parseNibble(errorNibbles[8 - 3], possibleValues: [.thermistorOpen, .invalidFirmwareConfiguration]))
                if errors.count <= 0 {
                    errors.append(.unknownError)
                }
                states.append(contentsOf: errors)
            }

            if parts[4] != "0" { // Warning flag is set
                let warningNibbles = try parts[3].map { (character) -> UInt8 in
                    guard let parsedValue = UInt8(String(character)) else {
                        throw ZPLPrinter.Error.invalidSystemStatus(statusString)
                    }
                    return parsedValue
                }
                
                var warnings: [PrinterState] = []
                warnings.append(contentsOf: parseNibble(warningNibbles[8 - 1], possibleValues: [.replacePrinthead, .cleanPrinthead, .needToCalibrateMedia]))
                if warnings.count <= 0 {
                    warnings.append(.unknownWarning)
                }
                states.append(contentsOf: warnings)
            }

            return (isPaused, states)
        }
        
        static let PRINTER_INFORMATION_QUERY = #"{}{"device.friendly_name": null, "device.unique_id": null, "device.product_name": null, "device.location": null, "head.resolution.in_dpi": null, "device.uptime": null, "device.status": null, "zpl.system_status": null}"#.data(using: .ascii)!
    }
    
    // MARK: - Utilities
    
    enum Error: LocalizedError {
        case invalidPort(_ portValue: UInt16)
        case networkError(source: NWError)
        case invalidResponse
        case invalidSystemStatus(_ statusString: String)
        case unknownError
        
        var errorDescription: String? {
            switch self {
            case .invalidPort(let portValue):
                return "\"\(portValue)\" is an invalid port value"
            case .networkError(let sourceError):
                return "A network error occurred: \(sourceError.localizedDescription)"
            case .invalidResponse:
                return "Received uninterpretable response data from the printer"
            case .invalidSystemStatus(let statusString):
                return "Could not interpret the given printer system status: \"\(statusString)\""
            case .unknownError:
                return "An unknown error occurred"
            }
        }
    }
}
