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

public protocol SGPortDelegate: AnyObject {
    func received(_ text: String)
    func portWasOpened(_ port: SGPort)
    func portWasClosed(_ port: SGPort)
    func portWasRemoved(_ port: SGPort)
}

public class SGPort {
    
    private var fileDescriptor: Int32 = 0
    private var originalPortOptions = termios()
    private var readTimer: DispatchSourceTimer?
    
    public weak var delegate: SGPortDelegate?
    public private(set) var name: String = ""
    public private(set) var state: SGPortState = .close
    
    // You can change these properties while closed.
    private var innerBaudRate: Int32 = B9600
    public var baudRate: Int32 {
        get { return innerBaudRate }
        set { if state == .close { innerBaudRate = newValue } }
    }
    
    init(_ portName: String) {
        name = portName
    }
    
    deinit {
        close()
    }
    
    
    // ★★★ Public Function ★★★ //
    public func open() {
        var fileDescriptor: Int32 = -1
        var options = termios()
        
        func exitWithError(_ n: Int) {
            Swift.print("Error \(n)")
            Darwin.close(fileDescriptor)
        }
        
        func updateC_CC(_ n: Int32, v: UInt8) {
            switch n {
            case  0: options.c_cc.0  = v
            case  1: options.c_cc.1  = v
            case  2: options.c_cc.2  = v
            case  3: options.c_cc.3  = v
            case  4: options.c_cc.4  = v
            case  5: options.c_cc.5  = v
            case  6: options.c_cc.6  = v
            case  7: options.c_cc.7  = v
            case  8: options.c_cc.8  = v
            case  9: options.c_cc.9  = v
            case 10: options.c_cc.10 = v
            case 11: options.c_cc.11 = v
            case 12: options.c_cc.12 = v
            case 13: options.c_cc.13 = v
            case 14: options.c_cc.14 = v
            case 15: options.c_cc.15 = v
            case 16: options.c_cc.16 = v
            case 17: options.c_cc.17 = v
            case 18: options.c_cc.18 = v
            case 19: options.c_cc.19 = v
            default: break
            }
        }
        
        fileDescriptor = Darwin.open(name.cString(using: String.Encoding.ascii)!,
                                     O_RDWR | O_NOCTTY | O_NONBLOCK)
        if fileDescriptor == -1 { return exitWithError(1) }
        
        // ★★★ Set Options ★★★ //
        if ioctl(fileDescriptor, TIOCEXCL) == -1 { return exitWithError(2) }
        if fcntl(fileDescriptor, F_SETFL, 0) == -1 { return exitWithError(3) }
        if tcgetattr(fileDescriptor, &originalPortOptions) == -1 { return exitWithError(4) }
        options = originalPortOptions
        cfmakeraw(&options)
        updateC_CC(VMIN, v: 1)
        updateC_CC(VTIME, v: 3)
        cfsetspeed(&options, speed_t(baudRate))
        
        options.c_cflag |= UInt(CLOCAL | CREAD)
        options.c_cflag &= ~UInt(CSIZE)
        options.c_cflag |= UInt(CS8)
        options.c_lflag &= ~UInt(ICANON | ECHO | ECHOE | ISIG)
        
        if tcsetattr(fileDescriptor, TCSANOW, &options) == -1 { return exitWithError(5) }
        
        // ★★★ Start Communication ★★★ //
        self.fileDescriptor = fileDescriptor
        readTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        readTimer?.schedule(deadline: DispatchTime.now(),
                            repeating: DispatchTimeInterval.nanoseconds(Int(10 * NSEC_PER_MSEC)),
                            leeway: DispatchTimeInterval.nanoseconds(Int(5 * NSEC_PER_MSEC)))
        readTimer?.setEventHandler(handler: {
            self.read()
        })
        readTimer?.setCancelHandler(handler: {
            self.close()
        })
        readTimer?.resume()
        state = SGPortState.open
        delegate?.portWasOpened(self)
    }
    
    public func close() {
        readTimer?.cancel()
        readTimer = nil
        if tcdrain(fileDescriptor) == -1 { return }
        if tcsetattr(fileDescriptor, TCSADRAIN, &originalPortOptions) == -1 { return }
        Darwin.close(fileDescriptor)
        state = SGPortState.close
        delegate?.portWasClosed(self)
    }
    
    public func send(_ text: String) {
        if state == .open {
            var bytes: [UInt32] = text.unicodeScalars.map { (uni) -> UInt32 in
                return uni.value
            }
            Swift.print(bytes.count)
            Darwin.write(fileDescriptor, &bytes, bytes.count)
        }
    }
    
    
    // ★★★ Internal Function ★★★ //
    internal func removed() {
        readTimer?.cancel()
        readTimer = nil
        if tcdrain(fileDescriptor) == -1 { return }
        if tcsetattr(fileDescriptor, TCSADRAIN, &originalPortOptions) == -1 { return }
        Darwin.close(fileDescriptor)
        state = SGPortState.removed
        delegate?.portWasRemoved(self)
    }
    
    internal func fallSleep() {
        readTimer?.suspend()
        state = SGPortState.sleeping
    }
    
    internal func wakeUp() {
        readTimer?.resume()
        state = SGPortState.open
    }
    
    
    // ★★★ Private Function ★★★ //
    private func read() {
        let localFileDescriptor: Int32 = self.fileDescriptor
        var text: String = ""
        var buffer = [UInt8](repeating: 0, count: 1024)
        // wait until coming new lines.
        while case let readLength = Darwin.read(localFileDescriptor, &buffer, 1024), readLength > 0 {
            let readData = NSData(bytes: buffer, length: readLength) as Data
            text += String(data: readData, encoding: String.Encoding.ascii) ?? ""
            if text.contains("\r\n") || text.contains("\n") {
                text = text.trimmingCharacters(in: CharacterSet.newlines)
                break
            }
        }
        delegate?.received(text)
    }
    
}
