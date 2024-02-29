/*
 ContentViewState.swift
 SerialGateDemo

 Created by Takuto Nakamura on 2024/02/29.
 
*/

import Combine
import SwiftUI
import SerialGate

class ContentViewState: ObservableObject {
    private let portManager = SGPortManager.shared
    private var availablePortsCancellable: AnyCancellable?
    private var portCancellables = Set<AnyCancellable>()

    @Published var portList = [SGPort]()
    @Published var port: SGPort?
    @Published var portIsOpening: Bool = false
    @Published var receivedText: String = ""
    @Published var inputText: String = ""
    @Published var stateText: String = "stand-by"

    init() {
        availablePortsCancellable = portManager
            .availablePortsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] portList in
                self?.updatePortList(portList)
            }
    }

    deinit {
        try? port?.close()
    }

    private func updatePortList(_ portList: [SGPort]) {
        self.portList = portList
        if let port, !portList.contains(port) {
            selectPort(nil)
        }
    }

    func selectPort(_ port: SGPort?) {
        self.port = port
        if port == nil {
            portCancellables.removeAll()
        } else {
            port?.changedPortStatePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    guard let self, let port else { return }
                    self.stateText = "Port: \(port.name) - \(state.rawValue)"
                }
                .store(in: &portCancellables)
            port?.receivedTextPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] (error, text) in
                    if let error {
                        Swift.print(error.localizedDescription)
                    } else if let text {
                        self?.receivedText += text
                    }
                }
                .store(in: &portCancellables)
        }
    }

    func openPort() {
        do {
            try port?.setBaudRate(B9600)
            try port?.open()
            portIsOpening = true
            receivedText = ""
        } catch {
            Swift.print(error.localizedDescription)
        }
    }

    func closePort() {
        do {
            try port?.close()
            portIsOpening = false
        } catch {
            Swift.print(error.localizedDescription)
        }
    }

    func sendPort() {
        do {
            try port?.send(inputText)
        } catch {
            Swift.print(error.localizedDescription)
        }
    }
}
