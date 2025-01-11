import AppKit
import Combine
import IOKit
import IOKit.serial
import os

public final class SGPortManager: Sendable {
    public static let shared = SGPortManager()

    private let detector = SGUSBDetector()
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

    deinit {
        logput("deinit SGPortManager")
        terminate()
    }

    // MARK: Notifications
    private func registerNotifications() {
        let task = Task {
            await withTaskGroup(of: Void.self) { group in
                // MARK: USB Detector
                group.addTask { [weak self, detector] in
                    for await _ in detector.addedDeviceStream {
                        self?.addedPorts()
                    }
                }
                group.addTask { [weak self, detector] in
                    for await _ in detector.removedDeviceStream {
                        self?.removedPorts()
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

    private func addedPorts() {
        let device = findDevice()
        let portList = getPortList(device)
        let currentPorts = availablePortsSubject.value
        let newPorts: [SGPort] = portList.compactMap { portName in
            if currentPorts.contains(where: { $0.name ==  portName }) {
                nil
            } else {
                SGPort(portName)
            }
        }
        guard !newPorts.isEmpty else { return }
        availablePortsSubject.value.insert(contentsOf: newPorts, at: 0)
    }

    private func removedPorts() {
        let device = findDevice()
        let portList = getPortList(device)
        let removedPorts = availablePortsSubject.value.filter { !portList.contains($0.name) }
        removedPorts.forEach { $0.removed() }
        availablePortsSubject.value.removeAll { removedPorts.contains($0) }
    }

    private func sleepPorts() {
        availablePortsSubject.value.forEach { $0.fallSleep() }
    }

    private func wakeUpPorts() {
        availablePortsSubject.value.forEach { $0.wakeUp() }
    }

    private func terminate() {
        availablePortsSubject.value.forEach { port in
            do {
                try port.close()
            } catch {
                logput(error.localizedDescription)
            }
        }
        availablePortsSubject.value.removeAll()

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
            let cfStr = IORegistryEntryCreateCFProperty(object, cfKey, kCFAllocatorDefault, .zero)!.takeUnretainedValue()
            ports.append(cfStr as! String)
            IOObjectRelease(object)
        }
        IOObjectRelease(iterator)
        return ports.reversed()
    }
}
