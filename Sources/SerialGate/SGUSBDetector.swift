import Combine
import IOKit.usb

final class SGUSBDetector {
    private let notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0

    private let addedDeviceSubject = PassthroughSubject<Void, Never>()
    var addedDevicePublisher: AnyPublisher<Void, Never> {
        return addedDeviceSubject.eraseToAnyPublisher()
    }

    private let removedDeviceSubject = PassthroughSubject<Void, Never>()
    var removedDevicePublisher: AnyPublisher<Void, Never> {
        return removedDeviceSubject.eraseToAnyPublisher()
    }

    deinit {
        IOObjectRelease(addedIterator)
        IOObjectRelease(removedIterator)
        IONotificationPortDestroy(notificationPort)
    }

    func start() {
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()

        let runLoop = IONotificationPortGetRunLoopSource(notificationPort)!.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, CFRunLoopMode.defaultMode)

        // MARK: Added Notification
        let addedCallback: IOServiceMatchingCallback = { (pointer, iterator) in
            let detector = Unmanaged<SGUSBDetector>.fromOpaque(pointer!).takeUnretainedValue()
            detector.addedDeviceSubject.send()
            while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {
                IOObjectRelease(device)
            }
        }
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
            detector.removedDeviceSubject.send()
            while case let device = IOIteratorNext(iterator), device != IO_OBJECT_NULL {
                IOObjectRelease(device)
            }
        }
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
