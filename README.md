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
   <img src="/Screenshots/sandbox.png" alt="sandbox" width="330px" />
3. Edit the entitlements and add `com.apple.security.device.serial`
   <img src="/Screenshots/entitlements.png" alt="entitlements" width="255px" />

## Demo

Serial Communication Demo App for Arduino or mbed is in this Project.
<img src="/Screenshots/DemoApp.png" alt="demo" width="260px" />

## Usage

- Get serial ports 

```swift
let manager = SGPortManager.shared
let serialPorts = manager.availablePorts
```

- Open a serial port

```swift
port.baudRate = B9600
port.open()
```

- Close a serial port

```swift
port.close()
```

- Send a message

```swift
let text: String = "Hello World"
port.send(text)
```

- Read messages

```swift
port.receivedHandler = { text in
    Swift.print(text)
}
```

- Notifications about Port

```swift
port.portOpenedHandler = { port in
    Swift.print("Port: \(port.name) Opend")
}
port.portClosedHandler = { port in
    Swift.print("Port: \(port.name) Closed")
}
port.portClosedHandler = { port in
    Swift.print("Port: \(port.name) Removed")
}
port.failureOpenHandler = { port in
    Swift.print("Failure Open Port \(port.name)")
}
```

- Get notification of updated of availablePorts.

```swift
port.updatedAvailablePortsHandler = {
    // something to do
}
```
