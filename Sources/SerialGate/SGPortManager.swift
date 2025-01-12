import AppKit
import Combine
import IOKit
import IOKit.serial
import Logput
import os

public final class SGPortManager: Sendable {
    public static let shared = SGPortManager()

    private let detector = SGSerialDeviceDetector()
    private let protectedTask = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    private let availablePortsSubject = CurrentValueSubject<[SGPort], Never>([])
    public var availablePortsStream: AsyncStream<[SGPort]> {
        AsyncStream { continuation in
            let cancellable = availablePortsSubject.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    private init() {
        registerNotifications()
        setAvailablePorts()
    }

    // MARK: Notifications
    private func registerNotifications() {
        let task = Task {
            await withTaskGroup(of: Void.self) { group in
                // MARK: USB Detector
                group.addTask { [weak self, detector] in
                    for await _ in detector.devicesStream {
                        self?.updatePorts()
                    }
                }
                // MARK: Sleep/WakeUp
                group.addTask { [weak self] in
                    let notification = NSWorkspace.willSleepNotification
                    for await _ in NSWorkspace.shared.notificationCenter.publisher(for: notification).values {
                        self?.sleepPorts()
                    }
                }
                group.addTask { [weak self] in
                    let notification = NSWorkspace.didWakeNotification
                    for await _ in NSWorkspace.shared.notificationCenter.publisher(for: notification).values {
                        self?.wakeUpPorts()
                    }
                }
                // MARK: Terminate
                group.addTask { [weak self] in
                    let notification = NSApplication.willTerminateNotification
                    for await _ in NotificationCenter.default.publisher(for: notification).values {
                        self?.terminate()
                    }
                }
            }
        }
        protectedTask.withLock { $0 = task }
        detector.start()
    }

    // MARK: Serial Ports
    private func setAvailablePorts() {
        let device = findDevice()
        let portList = getPortList(device)
        availablePortsSubject.value.append(contentsOf: portList.map(SGPort.init))
    }

    private func updatePorts() {
        let device = findDevice()
        let portList = getPortList(device)
        var ports = availablePortsSubject.value
        let removedPorts = ports.filter { !portList.contains($0.name) } // [0]
        removedPorts.forEach { $0.removed() }
        ports.removeAll { removedPorts.contains($0) }
        let addedPorts = portList.compactMap { portName in
            ports.contains(where: { $0.name == portName }) ? nil : SGPort(portName)
        }
        if !addedPorts.isEmpty {
            ports.insert(contentsOf: addedPorts, at: .zero)
        }
        availablePortsSubject.send(ports)
    }

    private func sleepPorts() {
        availablePortsSubject.value.forEach { $0.fallSleep() }
    }

    private func wakeUpPorts() {
        availablePortsSubject.value.forEach { $0.wakeUp() }
    }

    private func terminate() {
        availablePortsSubject.value.removeAll()
        protectedTask.withLock { $0?.cancel() }
        detector.stop()
    }

    private func findDevice() -> io_iterator_t {
        var portIterator: io_iterator_t = .zero
        let matchingDict: CFMutableDictionary = IOServiceMatching(kIOSerialBSDServiceValue)
        let typeKey_cf: CFString = kIOSerialBSDTypeKey as NSString
        let allTypes_cf: CFString = kIOSerialBSDAllTypes as NSString
        let typeKey = Unmanaged.passRetained(typeKey_cf).autorelease().toOpaque()
        let allTypes = Unmanaged.passRetained(allTypes_cf).autorelease().toOpaque()
        CFDictionarySetValue(matchingDict, typeKey, allTypes)
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &portIterator)
        guard result == KERN_SUCCESS else {
            logput("Error: IOServiceGetMatchingServices")
            return .zero
        }
        return portIterator
    }

    private func getPortList(_ iterator: io_iterator_t) -> [String] {
        var ports = [String]()
        while case let object = IOIteratorNext(iterator), object != IO_OBJECT_NULL {
            let cfKey: CFString = kIOCalloutDeviceKey as NSString
            if let cfStr = IORegistryEntryCreateCFProperty(object, cfKey, kCFAllocatorDefault, .zero) {
                ports.append(cfStr.takeUnretainedValue() as! String)
            }
            IOObjectRelease(object)
        }
        IOObjectRelease(iterator)
        return ports.reversed()
    }
}
