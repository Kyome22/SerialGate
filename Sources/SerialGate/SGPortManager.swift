import AppKit
import Combine
import IOKit
import IOKit.serial

public final class SGPortManager {
    public static let shared = SGPortManager()

    private let detector = SGUSBDetector()
    private var cancellables = Set<AnyCancellable>()

    private let availablePortsSubject = CurrentValueSubject<[SGPort], Never>([])
    public var availablePortsPublisher: AnyPublisher<[SGPort], Never> {
        return availablePortsSubject.eraseToAnyPublisher()
    }

    private init() {
        registerNotifications()
        setAvailablePorts()
    }

    // MARK: Notifications
    private func registerNotifications() {
        // MARK: USB Detector
        detector.addedDevicePublisher
            .delay(for: .seconds(1), scheduler: RunLoop.current)
            .sink { [weak self] in
                self?.addedPorts()
            }
            .store(in: &cancellables)
        detector.removedDevicePublisher
            .delay(for: .seconds(1), scheduler: RunLoop.current)
            .sink { [weak self] in
                self?.removedPorts()
            }
            .store(in: &cancellables)
        detector.start()

        // MARK: Sleep/Wake
        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                availablePortsSubject.value.forEach { port in
                    if port.state == .open {
                        port.fallSleep()
                    }
                }
            }
            .store(in: &cancellables)

        wsnc.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                availablePortsSubject.value.forEach { port in
                    if port.state == .sleeping {
                        port.wakeUp()
                    }
                }
            }
            .store(in: &cancellables)

        // MARK: Terminate
        let nc = NotificationCenter.default
        nc.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                availablePortsSubject.value.forEach { port in
                    try? port.close()
                }
                availablePortsSubject.value.removeAll()
            }
            .store(in: &cancellables)
    }

    // MARK: Serial Ports
    private func setAvailablePorts() {
        let device = findDevice()
        let portList = getPortList(device)
        portList.forEach { portName in
            availablePortsSubject.value.append(SGPort(portName))
        }
    }

    private func addedPorts() {
        let device = findDevice()
        let portList = getPortList(device)
        let newPorts = portList.compactMap { portName -> SGPort? in
            if availablePortsSubject.value.contains(where: { $0.name == portName }) {
                return nil
            } else {
                return SGPort(portName)
            }
        }
        if !newPorts.isEmpty {
            availablePortsSubject.value.insert(contentsOf: newPorts, at: 0)
        }
    }

    private func removedPorts() {
        let device = findDevice()
        let portList = getPortList(device)
        let removedPorts = availablePortsSubject.value.filter { port in
            return !portList.contains(port.name)
        }
        removedPorts.forEach { port in
            port.removed()
        }
        availablePortsSubject.value.removeAll { port in
            return removedPorts.contains(where: { $0.name == port.name })
        }
    }

    private func findDevice() -> io_iterator_t {
        var portIterator: io_iterator_t = 0
        let matchingDict: CFMutableDictionary = IOServiceMatching(kIOSerialBSDServiceValue)
        let typeKey_cf: CFString = kIOSerialBSDTypeKey as NSString
        let allTypes_cf: CFString = kIOSerialBSDAllTypes as NSString
        let typeKey = Unmanaged.passRetained(typeKey_cf).autorelease().toOpaque()
        let allTypes = Unmanaged.passRetained(allTypes_cf).autorelease().toOpaque()
        CFDictionarySetValue(matchingDict, typeKey, allTypes)
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &portIterator)
        if result != KERN_SUCCESS {
            logput("Error: IOServiceGetMatchingServices")
            return 0
        }
        return portIterator
    }

    private func getPortList(_ iterator: io_iterator_t) -> [String] {
        var ports = [String]()
        while case let object = IOIteratorNext(iterator), object != IO_OBJECT_NULL {
            let cfKey: CFString = kIOCalloutDeviceKey as NSString
            let cfStr = IORegistryEntryCreateCFProperty(object, cfKey, kCFAllocatorDefault, 0)!.takeUnretainedValue()
            ports.append(cfStr as! String)
            IOObjectRelease(object)
        }
        IOObjectRelease(iterator)
        return ports.reversed()
    }
}
