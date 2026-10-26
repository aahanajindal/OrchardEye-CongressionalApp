//
//  RootView.swift
//  OrchardEye
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if app.hasOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task { await app.refreshWeather() }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ScanFlowView()
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(.brandLeaf)
    }
}

#Preview {
    RootView().environment(AppModel()).environment(AppModel().store)
}
