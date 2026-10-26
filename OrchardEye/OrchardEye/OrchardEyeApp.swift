//
//  OrchardEyeApp.swift
//  OrchardEye
//
//  On-device crop disease & ripeness scanner for apple growers.
//

import SwiftUI

@main
struct OrchardEyeApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(app.store)
        }
    }
}
