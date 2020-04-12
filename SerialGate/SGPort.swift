//
//  SGPort.swift
//  SerialGate
//
//  Created by Takuto Nakamura on 2019/02/13.
//  Copyright © 2019 Takuto Nakamura. All rights reserved.
//

import Foundation

public enum SGPortState: Int {
    case open
    case close
    case sleeping
    case removed
}

public enum SGParity: Int {
    case none
    case even
    case odd
}

public final class SGPort {
    
    private var fileDescriptor: Int32 = 0
    private var originalPortOptions = termios()
    private var readTimer: DispatchSourceTimer?
    
    public private(set) var name: String = ""
    public private(set) var state: SGPortState = .close
    
    // You can change these properties while closed.
    public var baudRate: Int32 = B9600 {
        didSet { setOptions() }
    }
    public var parity: SGParity = .none {
        didSet { setOptions() }
    }
    public var stopBits: UInt32 = 1 {
        didSet { setOptions() }
    }
    
    //
    public var receivedHandler: ((_ texts: String) -> Void)?
    public var failureOpenHandler: ((_ port: SGPort) -> Void)?
    public var portOpenedHandler: ((_ port: SGPort) -> Void)?
    public var portClosedHandler: ((_ port: SGPort) -> Void)?
    public var portRemovedHandler: ((_ port: SGPort) -> Void)?
    
    init(_ portName: String) {
        name = portName
    }
    
    deinit {
        close()
    }
    
    private func exitWithError(_ n: Int) {
        logput("Error \(n)")
        failureOpenHandler?(self)
    }
    
    // ★★★ Public Function ★★★ //
    public func open() {
        var fd: Int32 = -1
        
        fd = Darwin.open(name.cString(using: String.Encoding.ascii)!, O_RDWR | O_NOCTTY | O_NONBLOCK)
        if fd == -1 { return exitWithError(1) }
        if fcntl(fd, F_SETFL, 0) == -1 { return exitWithError(2) }
        
        // ★★★ Start Communication ★★★ //
        fileDescriptor = fd
        setOptions()
        readTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        readTimer?.schedule(deadline: DispatchTime.now(),
                            repeating: DispatchTimeInterval.nanoseconds(Int(10 * NSEC_PER_MSEC)),
                            leeway: DispatchTimeInterval.nanoseconds(Int(5 * NSEC_PER_MSEC)))
        readTimer?.setEventHandler(handler: { [weak self] in
            self?.read()
        })
        readTimer?.setCancelHandler(handler: { [weak self] in
            self?.close()
        })
        readTimer?.resume()
        state = SGPortState.open
        portOpenedHandler?(self)
    }
    
    public func close() {
        readTimer?.cancel()
        readTimer = nil
        if tcdrain(fileDescriptor) == -1 { return }
        var options = termios()
        if tcsetattr(fileDescriptor, TCSADRAIN, &options) == -1 { return }
        Darwin.close(fileDescriptor)
        state = SGPortState.close
        fileDescriptor = -1
        portClosedHandler?(self)
    }
    
    public func send(_ text: String) {
        if state != .open { return }
        var bytes: [UInt32] = text.unicodeScalars.map { (uni) -> UInt32 in
            return uni.value
        }
        Darwin.write(fileDescriptor, &bytes, bytes.count)
    }
    
    // ★★★ Set Options ★★★ //
    private func setOptions() {
        if fileDescriptor < 1 { return }
        var options = termios()
        if tcgetattr(fileDescriptor, &options) == -1 {
            return exitWithError(3)
        }
        cfmakeraw(&options)
        options.updateC_CC(VMIN, v: 1)
        options.updateC_CC(VTIME, v: 2)

        // DataBits
        options.c_cflag &= ~UInt(CSIZE)
        options.c_cflag |= UInt(CS8)
        
        // StopBits
        if 1 < stopBits {
            options.c_cflag |= UInt(CSTOPB)
        } else {
            options.c_cflag &= ~UInt(CSTOPB)
        }
        
        // Parity
        switch parity {
        case .none:
            options.c_cflag &= ~UInt(PARENB)
        case .even:
            options.c_cflag |= UInt(PARENB)
            options.c_cflag &= ~UInt(PARODD)
        case .odd:
            options.c_cflag |= UInt(PARENB)
            options.c_cflag |= UInt(PARODD)
        }
        
        // EchoReceivedData
        options.c_cflag &= ~UInt(ECHO)
        // RTS CTS FlowControl
        options.c_cflag &= ~UInt(CRTSCTS)
        // DTR DSR FlowControl
        options.c_cflag &= ~UInt(CDTR_IFLOW | CDSR_OFLOW)
        // DCD OutputFlowControl
        options.c_cflag &= ~UInt(CCAR_OFLOW)
        
        options.c_cflag |= UInt(HUPCL)
        options.c_cflag |= UInt(CLOCAL)
        options.c_cflag |= UInt(CREAD)
        options.c_lflag &= ~UInt(ICANON | ISIG)
        
        cfsetspeed(&options, speed_t(baudRate))
        
        if tcsetattr(fileDescriptor, TCSANOW, &options) == -1 {
            return exitWithError(4)
        }
    }
    
    // ★★★ Internal Function ★★★ //
    func removed() {
        readTimer?.cancel()
        readTimer = nil
        if tcdrain(fileDescriptor) == -1 { return }
        if tcsetattr(fileDescriptor, TCSADRAIN, &originalPortOptions) == -1 { return }
        Darwin.close(fileDescriptor)
        state = SGPortState.removed
        portRemovedHandler?(self)
    }
    
    func fallSleep() {
        readTimer?.suspend()
        state = SGPortState.sleeping
    }
    
    func wakeUp() {
        readTimer?.resume()
        state = SGPortState.open
    }
    
    
    // ★★★ Private Function ★★★ //
    private func read() {
        if state != .open { return }
        var buffer = [UInt8](repeating: 0, count: 1024)
        let readLength = Darwin.read(fileDescriptor, &buffer, 1024)
        if  readLength < 1 { return }
        let data = Data(bytes: buffer, count: readLength)
        let text = String(data: data, encoding: String.Encoding.ascii)!
        receivedHandler?(text)
    }
    
}
