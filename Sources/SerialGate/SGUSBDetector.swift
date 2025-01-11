import IOKit.usb
import os

final class SGUSBDetector: Sendable {
    private let protectedNotificationPort = OSAllocatedUnfairLock<IONotificationPortRef>(
        uncheckedState: IONotificationPortCreate(kIOMainPortDefault)
    )
    private let protectedAddedIterator = OSAllocatedUnfairLock<io_iterator_t>(initialState: .zero)
    private let protectedAddedHandler = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)
    private let protectedRemovedIterator = OSAllocatedUnfairLock<io_iterator_t>(initialState: .zero)
    private let protectedRemovedHandler = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)

    var addedDeviceStream: AsyncStream<Void> {
        AsyncStream { continuation in
            protectedAddedHandler.withLock {
                $0 = { continuation.yield() }
            }
            continuation.onTermination = { [weak self] _ in
                self?.protectedAddedHandler.withLock { $0 = nil }
            }
        }
    }

    var removedDeviceStream: AsyncStream<Void> {
        AsyncStream { continuation in
            protectedRemovedHandler.withLock {
                $0 = { continuation.yield() }
            }
            continuation.onTermination = { [weak self] _ in
                self?.protectedRemovedHandler.withLock { $0 = nil }
            }
        }
    }

    deinit {
        print("deinit SGUSBDetector")
        protectedAddedIterator.withLock { _ = IOObjectRelease($0) }
        protectedRemovedIterator.withLock { _ = IOObjectRelease($0) }
        protectedNotificationPort.withLock { IONotificationPortDestroy($0) }
    }

    func start() {
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        let notificationPort = protectedNotificationPort.withLockUnchecked(\.self)
        let runLoop = IONotificationPortGetRunLoopSource(notificationPort)!.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, CFRunLoopMode.defaultMode)

        // MARK: Added Notification
        let addedCallback: IOServiceMatchingCallback = { (pointer, iterator) in
            let detector = Unmanaged<SGUSBDetector>.fromOpaque(pointer!).takeUnretainedValue()
            detector.protectedAddedHandler.withLock { $0?() }
            while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {
                IOObjectRelease(device)
            }
        }
        var addedIterator = protectedAddedIterator.withLock(\.self)
        IOServiceAddMatchingNotification(notificationPort,
                                         kIOPublishNotification,
                                         matchingDict,
                                         addedCallback,
                                         opaqueSelf,
                                         &addedIterator)
        while case let device = IOIteratorNext(addedIterator), device != IO_OBJECT_NULL {
            IOObjectRelease(device)
        }

        // MARK: Removed Notification
        let removedCallback: IOServiceMatchingCallback = { (pointer, iterator) in
            let detector = Unmanaged<SGUSBDetector>.fromOpaque(pointer!).takeUnretainedValue()
            detector.protectedRemovedHandler.withLock { $0?() }
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
}
