import IOKit.usb
import os

final class SGSerialDeviceDetector: Sendable {
    private let protectedRunLoop = OSAllocatedUnfairLock<CFRunLoop?>(uncheckedState: nil)
    private let protectedNotificationPort = OSAllocatedUnfairLock<IONotificationPortRef?>(uncheckedState: nil)
    private let protectedRunLoopSource = OSAllocatedUnfairLock<CFRunLoopSource?>(uncheckedState: nil)
    private let protectedAddedIterator = OSAllocatedUnfairLock<io_iterator_t>(initialState: .zero)
    private let protectedRemovedIterator = OSAllocatedUnfairLock<io_iterator_t>(initialState: .zero)
    private let protectedDevicesHandler = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)

    var devicesStream: AsyncStream<Void> {
        AsyncStream { continuation in
            protectedDevicesHandler.withLock {
                $0 = { continuation.yield() }
            }
            continuation.onTermination = { [weak self] _ in
                self?.protectedDevicesHandler.withLock { $0 = nil }
            }
        }
    }

    func start() {
        let runLoop = CFRunLoopGetCurrent()
        protectedRunLoop.withLockUnchecked { $0 = runLoop }
        let notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        protectedNotificationPort.withLockUnchecked { $0 = notificationPort }
        let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort)!.takeRetainedValue()
        protectedRunLoopSource.withLockUnchecked { $0 = runLoopSource }
        CFRunLoopAddSource(runLoop, runLoopSource, .defaultMode)

        let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        // MARK: Added Notification
        let addedCallback: IOServiceMatchingCallback = { (pointer, iterator) in
            let detector = Unmanaged<SGSerialDeviceDetector>.fromOpaque(pointer!).takeUnretainedValue()
            detector.protectedDevicesHandler.withLock { $0?() }
            while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {
                IOObjectRelease(device)
            }
        }
        var addedIterator = protectedAddedIterator.withLock(\.self)
        IOServiceAddMatchingNotification(notificationPort,
                                         kIOMatchedNotification,
                                         matchingDict,
                                         addedCallback,
                                         opaqueSelf,
                                         &addedIterator)
        while case let device = IOIteratorNext(addedIterator), device != IO_OBJECT_NULL {
            IOObjectRelease(device)
        }

        // MARK: Removed Notification
        let removedCallback: IOServiceMatchingCallback = { (pointer, iterator) in
            let detector = Unmanaged<SGSerialDeviceDetector>.fromOpaque(pointer!).takeUnretainedValue()
            detector.protectedDevicesHandler.withLock { $0?() }
            while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {
                IOObjectRelease(device)
            }
        }
        var removedIterator = protectedRemovedIterator.withLock(\.self)
        IOServiceAddMatchingNotification(notificationPort,
                                         kIOTerminatedNotification,
                                         matchingDict,
                                         removedCallback,
                                         opaqueSelf,
                                         &removedIterator)
        while case let device = IOIteratorNext(removedIterator), device != IO_OBJECT_NULL {
            IOObjectRelease(device)
        }
    }

    func stop() {
        guard let runLoop = protectedRunLoop.withLockUnchecked(\.self) else { return }
        CFRunLoopStop(runLoop)

        guard let runLoopSource = protectedRunLoopSource.withLockUnchecked(\.self) else { return }
        CFRunLoopRemoveSource(runLoop, runLoopSource, .defaultMode)

        protectedAddedIterator.withLock { _ = IOObjectRelease($0) }
        protectedRemovedIterator.withLock { _ = IOObjectRelease($0) }

        guard let notificationPort = protectedNotificationPort.withLockUnchecked(\.self) else { return }
        IONotificationPortDestroy(notificationPort)
    }
}
