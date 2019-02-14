# SerialGate
Serial Communication Library for macOS written by Swift.

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
port.delegate = self      // SGPortDelegate is required
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

⚠️ SerialGate waits until gets a new line code ("\n" or "\r\n") and does not return values.

```swift
func received(_ texts: [String]) { }   // SGPortDelegate is required
```

- Get notification of updated of availablePorts.

```swift
func updatedAvailablePorts() { }    // SGPortManagerDelegate is required
```
