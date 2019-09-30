//
//  SGUSBDetector.swift
//  SerialGate
//
//  Created by Takuto Nakamura on 2019/02/13.
//  Copyright © 2019 Takuto Nakamura. All rights reserved.
//

import Foundation
import IOKit
import IOKit.usb

protocol SGUSBDetectorDelegate: AnyObject {
    func deviceAdded(_ device: io_object_t)
    func deviceRemoved(_ device: io_object_t)
}

final class SGUSBDetector {
    
    weak var delegate: SGUSBDetectorDelegate?
    private let notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0

    func start() {
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        
        let runLoop = IONotificationPortGetRunLoopSource(notificationPort)!.takeRetainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoop, CFRunLoopMode.defaultMode)
        
        // ★★★ Added Notification ★★★ //
        let addedCallback: IOServiceMatchingCallback = { (pointer, iterator) in
            let detector = Unmanaged<SGUSBDetector>.fromOpaque(pointer!).takeUnretainedValue()
            detector.delegate?.deviceAdded(iterator)
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
        
        // ★★★ Removed Notification ★★★ //
        let removedCallback: IOServiceMatchingCallback = { (pointer, iterator) in
            let watcher = Unmanaged<SGUSBDetector>.fromOpaque(pointer!).takeUnretainedValue()
            watcher.delegate?.deviceRemoved(iterator)
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
    
    deinit {
        IOObjectRelease(addedIterator)
        IOObjectRelease(removedIterator)
        IONotificationPortDestroy(notificationPort)
    }
    
}

