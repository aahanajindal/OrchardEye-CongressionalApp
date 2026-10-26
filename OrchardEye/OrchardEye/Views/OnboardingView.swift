//
//  OnboardingView.swift
//  OrchardEye
//
//  First-run flow: welcome, then pick the variety. No sensor pairing — everything
//  runs on the iPhone (camera + on-device models).
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var step = 0
    @State private var variety = Variety.default

    private let lastStep = 1

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(step + 1), total: Double(lastStep + 1))
                .tint(.brandLeaf)
                .padding(.horizontal)

            Spacer()

            switch step {
            case 0: welcome
            default: varietyStep
            }

            Spacer()

            Button(action: advance) {
                Text(step >= lastStep ? "Start scanning" : "Continue")
            }
            .buttonStyle(BrandButtonStyle())
            .padding(.horizontal)
        }
        .readableColumn(max: 520)
        .padding(.vertical)
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            BrandMark(size: hSize == .regular ? 150 : 104)
            Eyebrow(text: "On-device orchard scanner")
            VStack(spacing: 6) {
                Text("Welcome to OrchardEye")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("One photo. Two answers.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.brandLeafDark)
            }
            Text("Is it diseased, and is it ripe? Point your camera at a leaf or fruit — all analysis runs on your iPhone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private var varietyStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill").font(.system(size: 48)).foregroundStyle(Color.accentColor)
            Text("Pick your apple variety").font(.title2.bold())
            Text("Tunes the disease and ripeness read to the variety you grow.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Picker("Variety", selection: $variety) {
                ForEach(Variety.all) { v in
                    Text("\(v.crop.emoji)  \(v.name)").tag(v)
                }
            }
            .pickerStyle(.wheel)
        }
        .padding(.horizontal)
    }

    // MARK: Flow

    private func advance() {
        if step >= lastStep {
            app.completeOnboarding(variety: variety)
        } else {
            withAnimation { step += 1 }
        }
    }
}

#Preview {
    OnboardingView().environment(AppModel())
}
