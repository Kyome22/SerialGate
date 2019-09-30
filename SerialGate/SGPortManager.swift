//
//  SGPortManager.swift
//  SerialGate
//
//  Created by Takuto Nakamura on 2019/02/13.
//  Copyright © 2019 Takuto Nakamura. All rights reserved.
//

import AppKit
import IOKit
import IOKit.serial

public protocol SGPortManagerDelegate: AnyObject {
    func updatedAvailablePorts()
}

public final class SGPortManager {
    
    public static let shared = SGPortManager()
    public private(set) var availablePorts = [SGPort]()
    private let detector = SGUSBDetector()
    private var terminateObserver: NSObjectProtocol?
    public weak var delegate: SGPortManagerDelegate?
    
    private init() {
        detector.delegate = self
        registerNotifications()
        setAvailablePorts()
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        
        let nc = NotificationCenter.default
        if terminateObserver != nil {
            nc.removeObserver(terminateObserver!)
        }
        nc.removeObserver(self)
    }
    
    // ★★★ Notifications ★★★ //
    private func registerNotifications() {
        // ★★★ USB Detector ★★★ //
        detector.delegate = self
        detector.start()
        
        // ★★★ Sleep/Wake ★★★ //
        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(self, selector: #selector(self.systemWillSleep),
                         name: NSWorkspace.willSleepNotification, object: nil)
        wsnc.addObserver(self, selector: #selector(self.systemDidWake),
                         name: NSWorkspace.didWakeNotification, object: nil)
        
        // ★★★ Terminate ★★★ //
        let nc = NotificationCenter.default
        let name = NSApplication.willTerminateNotification
        terminateObserver = nc.addObserver(forName: name, object: nil, queue: nil) { (notification) in
            self.availablePorts.forEach({ (port) in
                port.close()
            })
            self.availablePorts.removeAll()
        }
    }
    
    @objc func systemWillSleep() {
        availablePorts.forEach { (port) in
            if port.state == .open {
                port.fallSleep()
            }
        }
    }
    
    @objc func systemDidWake() {
        availablePorts.forEach { (port) in
            if port.state == .sleeping {
                port.wakeUp()
            }
        }
    }
    
    // ★★★ Serial Ports ★★★ //
    private func setAvailablePorts() {
        let device = findDevice()
        let portList = getPortList(device)
        portList.forEach { (portName) in
            availablePorts.append(SGPort(portName))
        }
    }
    
    private func addedPorts() {
        let device = findDevice()
        let portList = getPortList(device)
        portList.forEach { (portName) in
            if !availablePorts.contains(where: { (port) -> Bool in
                return port.name == portName
            }) {
                availablePorts.insert(SGPort(portName), at: 0)
            }
        }
        delegate?.updatedAvailablePorts()
    }
    
    private func removedPorts() {
        let device = findDevice()
        let portList = getPortList(device)
        let removedPorts: [SGPort] = availablePorts.filter { (port) -> Bool in
            return !portList.contains(port.name)
        }
        removedPorts.forEach { (port) in
            port.removed()
            availablePorts = availablePorts.filter({ (availablePort) -> Bool in
                return port.name != availablePort.name
            })
        }
        delegate?.updatedAvailablePorts()
    }
    
    private func findDevice() -> io_iterator_t {
        var portIterator: io_iterator_t = 0
        let matchingDict: CFMutableDictionary = IOServiceMatching(kIOSerialBSDServiceValue)
        let typeKey_cf: CFString = kIOSerialBSDTypeKey as NSString
        let allTypes_cf: CFString = kIOSerialBSDAllTypes as NSString
        let typeKey = Unmanaged.passRetained(typeKey_cf).autorelease().toOpaque()
        let allTypes = Unmanaged.passRetained(allTypes_cf).autorelease().toOpaque()
        CFDictionarySetValue(matchingDict, typeKey, allTypes)
        let result = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                  matchingDict,
                                                  &portIterator)
        if result != KERN_SUCCESS {
            Swift.print("Error: IOServiceGetMatchingServices")
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

extension SGPortManager: SGUSBDetectorDelegate {
    
    func deviceAdded(_ device: io_object_t) {
        // It is necessary to wait for a while to be updated.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
            self.addedPorts()
        }
    }
    
    func deviceRemoved(_ device: io_object_t) {
        removedPorts()
    }
    
}
