import Foundation

public enum SGError: LocalizedError {
    case couldNotOpenPort(String)
    case portIsNotOpen(String)
    case couldNotClosePort(String)
    case couldNotSetOptions(String)

    public var errorDescription: String? {
        switch self {
        case .couldNotOpenPort(let portName):
            return "Could not open port (\(portName))."
        case .portIsNotOpen(let portName):
            return "Port (\(portName)) is not open."
        case .couldNotClosePort(let portName):
            return "Could not close port (\(portName))."
        case .couldNotSetOptions(let portName):
            return "Could not set options to port (\(portName))."
        }
    }
}
