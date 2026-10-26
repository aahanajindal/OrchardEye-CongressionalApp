//
//  SettingsView.swift
//  OrchardEye
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            Form {
                Section("Apple variety") {
                    Picker("Variety", selection: Binding(get: { app.selectedVariety },
                                                         set: { app.setVariety($0) })) {
                        ForEach(Variety.all) { v in
                            Text("\(v.crop.emoji)  \(v.name)").tag(v)
                        }
                    }
                    Text("Variety tunes the on-device disease and ripeness read.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Weather") {
                    if let w = app.currentWeather {
                        InfoRow(label: "Now", value: w.summary)
                        InfoRow(label: "Disease pressure", value: w.diseasePressure)
                    } else {
                        Text("Not loaded").foregroundStyle(.secondary)
                    }
                    Button("Refresh") { Task { await app.refreshWeather() } }
                }

                Section("About") {
                    Text("OrchardEye is an on-device apple scanner: photograph a leaf or fruit and get a disease or ripeness verdict in one tap.")
                        .font(.subheadline)
                    Text("Everything runs on your iPhone — a Core ML model flags apple disease from the photo, and ripeness is estimated from fruit colour. No external sensor, no upload.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView().environment(AppModel())
}
