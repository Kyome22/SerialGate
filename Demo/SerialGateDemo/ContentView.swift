//
//  ContentView.swift
//  SerialGateDemo
//
//  Created by Takuto Nakamura on 2024/02/29.
//

import SwiftUI
import SerialGate

struct ContentView: View {
    @StateObject var viewState = ContentViewState()

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker(selection: Binding<SGPort?>(
                    get: { viewState.port },
                    set: { viewState.selectPort($0) }
                )) {
                    Text(verbatim: "Select port")
                        .tag(SGPort?.none)
                    ForEach(viewState.portList) { port in
                        Text(verbatim: port.name)
                            .tag(SGPort?.some(port))
                    }
                } label: {
                    Text(verbatim: "Available ports:")
                }
                .disabled(viewState.portIsOpening)
                Button {
                    viewState.openPort()
                } label: {
                    Text(verbatim: "Open")
                }
                .disabled(viewState.portIsOpening)
                Button {
                    viewState.closePort()
                } label: {
                    Text(verbatim: "Close")
                }
                .disabled(!viewState.portIsOpening)
            }
            HStack {
                TextField(text: $viewState.inputText) {
                    Text(verbatim: "Text you want to send to the port")
                }
                Button {
                    viewState.sendPort()
                } label: {
                    Text(verbatim: "Send")
                }
                .disabled(!viewState.portIsOpening)
            }
            LabeledContent {
                Text(verbatim: viewState.stateText)
                    .foregroundStyle(Color.secondary)
            } label: {
                Text(verbatim: "Port state:")
            }
            Divider()
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    Text(verbatim: viewState.receivedText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                    Spacer()
                        .frame(maxWidth: .infinity)
                        .id("bottomSpacer")
                }
                .border(Color.gray)
                .onChange(of: viewState.receivedText) { _ in
                    withAnimation {
                        proxy.scrollTo("bottomSpacer")
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .padding()
    }
}

#Preview {
    ContentView()
}
