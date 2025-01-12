import Combine
import Foundation
import os

public final class SGPort: Hashable, Identifiable, Sendable {
    private let protectedFileDescriptor = OSAllocatedUnfairLock<Int32>(initialState: .zero)
    private let protectedReadTimer = OSAllocatedUnfairLock<(any DispatchSourceTimer)?>(uncheckedState: nil)
    private let protectedName: OSAllocatedUnfairLock<String>
    private let protectedPortState = OSAllocatedUnfairLock<SGPortState>(initialState: .closed)
    private let protectedBaudRate = OSAllocatedUnfairLock<Int32>(initialState: B9600)
    private let protectedParity = OSAllocatedUnfairLock<SGParity>(initialState: .none)
    private let protectedStopBits = OSAllocatedUnfairLock<UInt32>(initialState: 1)
    private let portStateSubject = PassthroughSubject<SGPortState, Never>()
    private let textSubject = PassthroughSubject<Result<String, SGError>, Never>()

    public var id: String { name }
    public var name: String { protectedName.withLock(\.self) }
    public var portState: SGPortState { protectedPortState.withLock(\.self) }
    public var baudRate: Int32 { protectedBaudRate.withLock(\.self) }
    public var parity: SGParity { protectedParity.withLock(\.self) }
    public var stopBits: UInt32 { protectedStopBits.withLock(\.self) }

    public var portStateStream: AsyncStream<SGPortState> {
        AsyncStream { continuation in
            let cancellable = portStateSubject.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    public var textStream: AsyncStream<Result<String, SGError>> {
        AsyncStream { continuation in
            let cancellable = textSubject.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    init(_ portName: String) {
        protectedName = .init(initialState: portName)
    }

    deinit {
        try? close()
    }

    // MARK: Public Function
    public func open() throws {
        let name = protectedName.withLock(\.self)
        guard protectedPortState.withLock({ $0 == .closed }) else {
            throw SGError.couldNotOpenPort(name)
        }
        let fd = Darwin.open(name.cString(using: .ascii)!, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd != -1, fcntl(fd, F_SETFL, .zero) != -1 else {
            throw SGError.couldNotOpenPort(name)
        }

        // ★★★ Start Communication ★★★ //
        protectedFileDescriptor.withLock { [fd] in $0 = fd }
        try setOptions()
        let readTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        readTimer.schedule(
            deadline: DispatchTime.now(),
            repeating: DispatchTimeInterval.nanoseconds(Int(10 * NSEC_PER_MSEC)),
            leeway: DispatchTimeInterval.nanoseconds(Int(5 * NSEC_PER_MSEC))
        )
        readTimer.setEventHandler { [weak self] in
            self?.read()
        }
        readTimer.resume()
        protectedReadTimer.withLockUnchecked { $0 = readTimer }
        protectedPortState.withLock { $0 = .open }
        portStateSubject.send(.open)
    }

    public func close() throws {
        guard protectedPortState.withLock({ [.open, .sleeping].contains($0) }) else {
            let name = protectedName.withLock(\.self)
            throw SGError.portIsNotOpen(name)
        }
        protectedReadTimer.withLockUnchecked {
            $0?.cancel()
            $0 = nil
        }
        let fileDescriptor = protectedFileDescriptor.withLock(\.self)
        var options = termios()
        guard tcdrain(fileDescriptor) != -1,
              tcsetattr(fileDescriptor, TCSADRAIN, &options) != -1 else {
            let name = protectedName.withLock(\.self)
            throw SGError.couldNotClosePort(name)
        }
        Darwin.close(fileDescriptor)
        protectedFileDescriptor.withLock { $0 = -1 }
        protectedPortState.withLock { $0 = .closed }
        portStateSubject.send(.closed)
    }

    public func send(_ text: String) throws {
        guard protectedPortState.withLock({ $0 == .open }) else {
            let name = protectedName.withLock(\.self)
            throw SGError.portIsNotOpen(name)
        }
        let fileDescriptor = protectedFileDescriptor.withLock(\.self)
        var bytes = text.unicodeScalars.map(\.value)
        Darwin.write(fileDescriptor, &bytes, bytes.count)
    }

    // MARK: Set Options
    private func setOptions() throws {
        let fileDescriptor = protectedFileDescriptor.withLock(\.self)
        guard fileDescriptor > 0 else { return }
        var options = termios()
        guard tcgetattr(fileDescriptor, &options) != -1 else {
            let name = protectedName.withLock(\.self)
            throw SGError.couldNotSetOptions(name)
        }
        cfmakeraw(&options)
        options.updateC_CC(VMIN, v: 1)
        options.updateC_CC(VTIME, v: 2)

        // DataBits
        options.c_cflag &= ~UInt(CSIZE)
        options.c_cflag |= UInt(CS8)

        // StopBits
        if protectedStopBits.withLock({ $0 > 1 }) {
            options.c_cflag |= UInt(CSTOPB)
        } else {
            options.c_cflag &= ~UInt(CSTOPB)
        }

        // Parity
        switch protectedParity.withLock(\.self) {
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

        let baudRate = protectedBaudRate.withLock(\.self)
        guard cfsetspeed(&options, speed_t(baudRate)) != -1,
              tcsetattr(fileDescriptor, TCSANOW, &options) != -1 else {
            let name = protectedName.withLock(\.self)
            throw SGError.couldNotSetOptions(name)
        }
    }

    public func set(baudRate: Int32) throws {
        let previousBaudRate = protectedBaudRate.withLock(\.self)
        protectedBaudRate.withLock { $0 = baudRate }
        do {
            try setOptions()
        } catch {
            protectedBaudRate.withLock { $0 = previousBaudRate }
            throw error
        }
    }

    public func set(parity: SGParity) throws {
        let previousParity = protectedParity.withLock(\.self)
        protectedParity.withLock { $0 = parity }
        do {
            try setOptions()
        } catch {
            protectedParity.withLock { $0 = previousParity }
            throw error
        }
    }

    public func set(stopBits: UInt32) throws {
        let previousStopBits = protectedStopBits.withLock(\.self)
        protectedStopBits.withLock { $0 = stopBits }
        do {
            try setOptions()
        } catch {
            protectedStopBits.withLock { $0 = previousStopBits }
            throw error
        }
    }

    // MARK: Internal Function
    func removed() {
        protectedReadTimer.withLockUnchecked {
            $0?.cancel()
            $0 = nil
        }
        let fileDescriptor = protectedFileDescriptor.withLock(\.self)
        var options = termios()
        if tcdrain(fileDescriptor) != -1,
           tcsetattr(fileDescriptor, TCSADRAIN, &options) != -1 {
            Darwin.close(fileDescriptor)
        }
        protectedPortState.withLock { $0 = .removed }
        portStateSubject.send(.removed)
    }

    func fallSleep() {
        guard protectedPortState.withLock({ $0 == .open }) else { return }
        protectedReadTimer.withLockUnchecked { $0?.suspend() }
        protectedPortState.withLock { $0 = .sleeping }
    }

    func wakeUp() {
        guard protectedPortState.withLock({ $0 == .sleeping }) else { return }
        protectedReadTimer.withLockUnchecked { $0?.resume() }
        protectedPortState.withLock { $0 = .open }
    }

    // MARK: Private Function
    private func read() {
        guard protectedPortState.withLock({ $0 == .open }) else {
            let name = protectedName.withLock(\.self)
            textSubject.send(.failure(.portIsNotOpen(name)))
            return
        }
        var buffer = [UInt8](repeating: .zero, count: 1024)
        let fileDescriptor = protectedFileDescriptor.withLock(\.self)
        let readLength = Darwin.read(fileDescriptor, &buffer, buffer.count)
        guard readLength > 0 else { return }
        let data = Data(bytes: buffer, count: readLength)
        guard let text = String(data: data, encoding: .ascii) else {
            let name = protectedName.withLock(\.self)
            textSubject.send(.failure(.couldNotDecodeText(name)))
            return
        }
        textSubject.send(.success(text))
    }

    // MARK: Equatable
    public static func == (lhs: SGPort, rhs: SGPort) -> Bool {
        lhs === rhs
    }

    // MARK: Hashable
    public func hash(into hasher: inout Hasher) {
        ObjectIdentifier(self).hash(into: &hasher)
    }
}
