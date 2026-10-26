//
//  UIImage+Orientation.swift
//  OrchardEye
//
//  Camera and photo-library images carry an `imageOrientation` flag rather than
//  rotated pixels. Every analysis path here reads `.cgImage` (the raw buffer),
//  which ignores that flag — so a normal portrait photo would be analyzed 90°
//  sideways. Normalizing once at ingestion keeps the quality gate, subject
//  detector, and Core ML model all seeing upright pixels.
//

import UIKit

extension UIImage {
    /// Returns an image whose pixel buffer is upright (`.up`). No-op when already upright.
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size, format: imageRendererFormat)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
