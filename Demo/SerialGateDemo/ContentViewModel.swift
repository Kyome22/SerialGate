/*
 ContentViewModel.swift
 SerialGateDemo

 Created by Takuto Nakamura on 2024/02/29.
 
*/

import Logput
import SwiftUI
import SerialGate

@MainActor
final class ContentViewModel: ObservableObject {
    private let portManager = SGPortManager.shared
    private var availablePortsTask: Task<Void, Never>?
    private var currentPortTask: Task<Void, Never>?

    @Published var portList = [SGPort]()
    @Published var port: SGPort?
    @Published var portIsOpening = false
    @Published var receivedText = ""
    @Published var inputText = ""
    @Published var stateText = "stand-by"

    init() {}

    func onAppear() {
        availablePortsTask = Task {
            for await portList in portManager.availablePortsStream {
                update(portList: portList)
            }
        }
    }

    func onDisappear() {
        closePort()
        availablePortsTask?.cancel()
        currentPortTask?.cancel()
    }

    private func update(portList: [SGPort]) {
        self.portList = portList
        if let port, !portList.contains(port) {
            select(port: nil)
        }
    }

    func select(port: SGPort?) {
        self.port = port
        if let port {
            currentPortTask = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { [weak self] in
                        for await portState in port.portStateStream {
                            guard let self else { return }
                            await MainActor.run {
                                stateText = "Port: \(port.name) - \(String(describing: portState))"
                            }
                        }
                    }
                    group.addTask { [weak self] in
                        for await result in port.textStream {
                            switch result {
                            case let .success(text):
                                guard let self else { return }
                                await MainActor.run {
                                    receivedText += text
                                }
                            case let .failure(error):
                                logput(error.localizedDescription)
                            }
                        }
                    }
                }
            }
        } else {
            currentPortTask?.cancel()
        }
    }

    func openPort() {
        guard let port, !portIsOpening else { return }
        do {
            try port.set(baudRate: B9600)
            try port.open()
            portIsOpening = true
            receivedText = ""
        } catch {
            logput(error.localizedDescription)
        }
    }

    func closePort() {
        guard let port, portIsOpening else { return }
        do {
            try port.close()
            portIsOpening = false
        } catch {
            logput(error.localizedDescription)
        }
    }

    func sendPort() {
        guard let port, portIsOpening else { return }
        do {
            try port.send(inputText)
        } catch {
            logput(error.localizedDescription)
        }
    }
}
