import Foundation

public enum SGError: LocalizedError, Sendable {
    case failedToOpenPort(String)
    case portIsNotOpen(String)
    case failedToClosePort(String)
    case failedToSetOptions(String)
    case failedToEncodeText(String)
    case failedToEncodeData(String)
    case failedToWriteData(String)

    public var errorDescription: String? {
        switch self {
        case let .failedToOpenPort(portName):
            "Failed to open port (\(portName))."
        case let .portIsNotOpen(portName):
            "Port (\(portName)) is not open."
        case let .failedToClosePort(portName):
            "Failed to close port (\(portName))."
        case let .failedToSetOptions(portName):
            "Failed to set options (port \(portName))."
        case let .failedToEncodeText(portName):
            "Failed to encode received data to string (port \(portName))."
        case let .failedToEncodeData(portName):
            "Failed to encode received string to data (port \(portName))."
        case let .failedToWriteData(portName):
            "Failed to write data (port \(portName))."
        }
    }
}
