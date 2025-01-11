//
//  ContentView.swift
//  SerialGateDemo
//
//  Created by Takuto Nakamura on 2024/02/29.
//

import SwiftUI
import SerialGate

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker(selection: Binding<SGPort?>(
                    get: { viewModel.port },
                    set: { viewModel.select(port: $0) }
                )) {
                    Text("Select port")
                        .tag(SGPort?.none)
                    ForEach(viewModel.portList) { port in
                        Text(port.name)
                            .tag(SGPort?.some(port))
                    }
                } label: {
                    Text("Available ports:")
                }
                .disabled(viewModel.portIsOpening)
                Button {
                    viewModel.openPort()
                } label: {
                    Text("Open")
                }
                .disabled(viewModel.portIsOpening)
                Button {
                    viewModel.closePort()
                } label: {
                    Text("Close")
                }
                .disabled(!viewModel.portIsOpening)
            }
            HStack {
                TextField(text: $viewModel.inputText) {
                    Text("Text you want to send to the port")
                }
                Button {
                    viewModel.sendPort()
                } label: {
                    Text("Send")
                }
                .disabled(!viewModel.portIsOpening)
            }
            LabeledContent {
                Text(viewModel.stateText)
                    .foregroundStyle(Color.secondary)
            } label: {
                Text(verbatim: "Port state:")
            }
            Divider()
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Text(verbatim: viewModel.receivedText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                    Spacer()
                        .frame(maxWidth: .infinity)
                        .id("bottomSpacer")
                }
                .border(Color.gray)
                .onChange(of: viewModel.receivedText) { _ in
                    withAnimation {
                        proxy.scrollTo("bottomSpacer")
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .padding()
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

#Preview {
    ContentView()
}
