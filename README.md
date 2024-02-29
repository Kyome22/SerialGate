# SerialGate

Serial Communication Library for macOS written in Swift.

## Requirements

- Development with Xcode 15.2+
- Written in Swift 5.9
- swift-tools-version: 5.9
- Compatible with macOS 11.0+

## Installation

1. DependencyList is available through [Swift Package Manager](https://github.com/apple/swift-package-manager).
2. Put a check mark for "USB" in Capabilities of Targets (SandBox)
   <img src="Screenshots/sandbox.png" alt="sandbox" width="540px" />
3. Edit the entitlements and add `com.apple.security.device.serial`
   <img src="Screenshots/entitlements.png" alt="entitlements" width="470px" />

## Demo

Serial Communication Demo App for Arduino or mbed is in this Project.

<img src="Screenshots/demo.png" alt="demo" width="432px" />

Sample Arduino code is [here](Arduino/TestForSerialGate.ino).

## Usage

- Get serial ports 

```swift
import Combine
import SerialGate

var cancellables = Set<AnyCancellable>()

SGPortManager.shared.availablePortsPublisher
    .sink { ports in
        // get ports
    }
    .store(in: &cancellables)
```

- Open a serial port

```swift
try? port.setBaudRate(B9600)
try? port.open()
```

- Close a serial port

```swift
try? port.close()
```

- Send a message

```swift
let text: String = "Hello World"
try? port.send(text)
```

- Read messages

```swift
port.receivedTextPublisher
    .sink { (error, text) in 
        if let text {
            Swift.print(text)
        }
    }
    .store(in: &cancellables)
```

- Notifications about Port

```swift
port.changedPortStatePublisher
    .sink { portState in 
        Swift.print(portState.rawValue)
    }
    .store(in: &cancellables)
```
