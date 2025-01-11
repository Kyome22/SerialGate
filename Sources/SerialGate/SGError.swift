import Foundation

public enum SGError: LocalizedError, Sendable {
    case couldNotOpenPort(String)
    case portIsNotOpen(String)
    case couldNotClosePort(String)
    case couldNotSetOptions(String)
    case couldNotDecodeText(String)

    public var errorDescription: String? {
        switch self {
        case let .couldNotOpenPort(portName):
            "Could not open port (\(portName))."
        case let .portIsNotOpen(portName):
            "Port (\(portName)) is not open."
        case let .couldNotClosePort(portName):
            "Could not close port (\(portName))."
        case let .couldNotSetOptions(portName):
            "Could not set options to port (\(portName))."
        case let .couldNotDecodeText(portName):
            "Could not decode received data to string (port \(portName))."
        }
    }
}
