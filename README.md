# SerialGate
Serial Communication Library for macOS written in Swift.

## Installation

1.For installation with [CocoaPods](http://cocoapods.org), simply add the following to your `Podfile`:

```ruby
pod 'SerialGate'
```

2.Put a check mark for "USB" in Capabilities of Targets (SandBox)

![sandbox](https://github.com/Kyome22/SerialGate/blob/master/images/sandbox.png)


3.Edit the entitlements and add `com.apple.security.device.serial`

![entitlements](https://github.com/Kyome22/SerialGate/blob/master/images/entitlements.png)


## Demo
Serial Communication Demo App for Arduino or mbed is in this Project.
![entitlements](https://github.com/Kyome22/SerialGate/blob/master/images/DemoApp.png)


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
port.receivedHandler = { (text) in
    Swift.print(text)
}
```

- Notifications about Port

```swift
port.portOpenedHandler = { (port) in
    Swift.print("Port: \(port.name) Opend")
}
port.portClosedHandler = { (port) in
    Swift.print("Port: \(port.name) Closed")
}
port.portClosedHandler = { (port) in
    Swift.print("Port: \(port.name) Removed")
}
port.failureOpenHandler = { (port) in
    Swift.print("Failure Open Port \(port.name)")
}
```

- Get notification of updated of availablePorts.

```swift
port.updatedAvailablePortsHandler = {
    // something to do
}
```
