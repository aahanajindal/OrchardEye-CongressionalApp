//
//  Components.swift
//  OrchardEye
//
//  Small reusable views: cards, pills, the spectrum chart, and a camera picker.
//

import SwiftUI
import Charts
import UIKit

// MARK: - Layout

/// Caps content width and centers it so single-column layouts read well on
/// iPad and in landscape instead of stretching cards edge-to-edge.
extension View {
    func readableColumn(max width: CGFloat = 660) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.brandLeaf.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

struct Pill: View {
    let text: String
    var color: Color = .secondary
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

struct ConfidenceBar: View {
    let value: Double   // 0–1
    var tint: Color = .accentColor
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(tint)
                    .frame(width: max(6, geo.size.width * value))
            }
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel("Confidence")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}

// MARK: - Ripeness meter

/// Simple 0–100 ripeness bar (on-device colour estimate), replacing the old
/// external-sensor spectrum chart.
struct RipenessMeter: View {
    let score: Double        // 0–100
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(tint.gradient)
                        .frame(width: max(6, geo.size.width * CGFloat(max(0, min(100, score)) / 100)))
                }
            }
            .frame(height: 12)
            Text("\(Int(score))/100 ripeness (from colour)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ripeness")
        .accessibilityValue("\(Int(score)) out of 100, estimated from colour")
    }
}

// MARK: - Camera (device only; Simulator has no camera)

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}
