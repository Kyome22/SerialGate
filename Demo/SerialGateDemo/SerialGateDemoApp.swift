//
//  SerialGateDemoApp.swift
//  SerialGateDemo
//
//  Created by Takuto Nakamura on 2024/02/29.
//

import SwiftUI

@main
struct SerialGateDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                NavigationLink("Check", value: 0)
                    .navigationDestination(for: Int.self) { _ in
                        ContentView()
                    }
            }
        }
        .defaultSize(width: 400, height: 400)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
