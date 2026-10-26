//
//  ColorDiseaseClassifier.swift
//  OrchardEye
//
//  Fully on-device, OS-independent apple disease classifier. A multinomial
//  logistic-regression head over 12 colour/texture features, trained offline on
//  PlantVillage apple images (healthy / scab / black rot / cedar apple rust,
//  ~88% held-out accuracy). Unlike a CreateML scenePrint model, this depends on NO
//  OS feature extractor, so it behaves identically in the Simulator and on device.
//  Feature extraction below must stay byte-for-byte aligned with train_color.py.
//

import UIKit

/// Trained weights + the matching feature extractor.
enum ColorDiseaseModel {

    static let labels = ["healthy", "scab", "blackrot", "rust"]

    static let mean: [Double] = [0.434995, 0.465390, 0.441131, 0.230144, 0.453537, 0.149498, 0.369970, 0.032012, 0.000453, 0.067839, 0.096688, 0.027516]
    static let std: [Double]  = [0.070579, 0.065475, 0.072986, 0.060438, 0.065261, 0.037425, 0.120648, 0.052052, 0.002545, 0.082540, 0.083863, 0.069867]
    static let bias: [Double] = [1.245895, 0.516241, 0.815983, -2.578118]
    static let weight: [[Double]] = [
        [-2.381867, -0.191066, 2.282091, -0.925229, -0.591779, 0.430505, -0.497339, -0.241933, -0.905691, 0.111002, 0.143054, 1.008221],
        [1.187804, -2.652227, 2.428846, 1.603152, -0.868200, -0.701428, 1.313604, 0.625341, -1.742498, -0.131004, 0.659717, 0.439939],
        [0.848384, 0.151764, -0.523834, 0.585014, 0.296928, 0.548425, -0.204539, -0.875469, 3.264863, -1.096094, -0.537384, -0.838508],
        [0.345678, 2.691529, -4.187104, -1.262936, 1.163051, -0.277503, -0.611727, 0.492061, -0.616674, 1.116096, -0.265386, -0.609652]
    ]

    /// 12 colour/texture features on a 48×48 render — identical spec to training.
    static func features(from image: UIImage) -> [Double]? {
        let n = 48
        guard let cg = image.cgImage else { return nil }
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        px.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: n, height: n,
                                      bitsPerComponent: 8, bytesPerRow: n * 4, space: cs,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.interpolationQuality = .low
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        }
        var sR = 0.0, sG = 0.0, sB = 0.0, sSat = 0.0, sLum = 0.0, sLum2 = 0.0
        var green = 0, yellow = 0, orange = 0, brown = 0, dark = 0, bright = 0
        let total = n * n
        for i in 0..<total {
            let r = Double(px[i*4]) / 255, g = Double(px[i*4+1]) / 255, b = Double(px[i*4+2]) / 255
            let lum = 0.299*r + 0.587*g + 0.114*b
            let mx = max(r, max(g, b)), mn = min(r, min(g, b))
            let sat = mx > 1e-6 ? (mx - mn) / mx : 0
            sR += r; sG += g; sB += b; sSat += sat; sLum += lum; sLum2 += lum*lum
            if g > r && g > b && g > 0.25 { green += 1 }
            if r > 0.40 && g > 0.40 && b < 0.40 && abs(r - g) < 0.20 { yellow += 1 }
            if r > 0.45 && g >= 0.20 && g <= 0.55 && b < 0.35 && r > g && (r - g) > 0.12 { orange += 1 }
            if r >= 0.18 && r <= 0.62 && g >= 0.10 && g <= 0.50 && b < 0.42 && r >= g && lum < 0.5 { brown += 1 }
            if lum < 0.22 { dark += 1 }
            if lum > 0.75 { bright += 1 }
        }
        let t = Double(total)
        let meanLum = sLum / t
        let varLum = max(0, sLum2 / t - meanLum * meanLum)
        return [sR/t, sG/t, sB/t, sSat/t, meanLum, varLum.squareRoot(),
                Double(green)/t, Double(yellow)/t, Double(orange)/t,
                Double(brown)/t, Double(dark)/t, Double(bright)/t]
    }

    /// Standardize → linear → softmax; returns (labelIndex, confidence), or nil if the
    /// feature vector doesn't match the trained shape — so a drifted model falls back to
    /// the honest heuristic instead of silently reporting "healthy, confidence 0".
    static func predict(_ f: [Double]) -> (index: Int, confidence: Double)? {
        guard f.count == mean.count, f.count == std.count,
              weight.allSatisfy({ $0.count == f.count }) else { return nil }
        var z = [Double](repeating: 0, count: labels.count)
        for k in 0..<labels.count {
            var s = bias[k]
            for d in 0..<f.count { s += weight[k][d] * ((f[d] - mean[d]) / std[d]) }
            z[k] = s
        }
        let mx = z.max() ?? 0
        let e = z.map { Foundation.exp($0 - mx) }
        let sum = e.reduce(0, +)
        let p = e.map { $0 / sum }
        var best = 0
        for k in 1..<p.count where p[k] > p[best] { best = k }
        return (best, p[best])
    }

    static func disease(forIndex i: Int) -> DiseaseInfo {
        switch labels[i] {
        case "scab":     return .appleScab
        case "blackrot": return .appleBlackRot
        case "rust":     return .appleRust
        default:         return .healthy
        }
    }
}

/// Injected disease classifier: the trained apple colour model, with a transparent
/// heuristic for frames the model cannot read.
final class ColorDiseaseClassifier: DiseaseClassifier {

    func classify(image: UIImage, crop: Crop) async -> DiseaseClassification {
        var detection = await AppleDetector.detect(image)
        let stats = ImageAnalysis.stats(for: image)
        let health = HeuristicDiseaseClassifier.cropHealth(from: stats, crop: crop)

        var disease: DiseaseInfo
        var confidence: Double
        var alternatives: [String]

        if let f = ColorDiseaseModel.features(from: image),
           let pred = ColorDiseaseModel.predict(f) {
            disease = ColorDiseaseModel.disease(forIndex: pred.index)
            confidence = pred.confidence
            let candidates = DiseaseInfo.candidates(for: crop)
            alternatives = disease.isHealthy ? []
                : Array(candidates.filter { $0 != disease }.map { $0.name }.prefix(2))
        } else {
            // No readable colour features for this frame → honest heuristic.
            let r = HeuristicDiseaseClassifier.classify(stats: stats, crop: crop)
            disease = r.disease; confidence = r.confidence; alternatives = r.alternatives
        }

        // Subject gate: only an apple leaf / apple fruit is a valid subject. The colour
        // gate is authoritative — the logistic head has no "not-apple" class, so a
        // confident colour reading is NOT evidence of a subject (that self-confirming
        // logic hallucinated "leaf detected" on laptops, buildings, etc.). A frame that
        // isn't plausibly an apple leaf/fruit is rejected outright.
        let subjectOK = ImageAnalysis.appleSubjectValid(stats) || detection.isApple
        if !subjectOK {
            // Reject parity with CoreMLDiseaseClassifier: neutralize the disease verdict
            // and cap confidence, not just the detection — so no confident false diagnosis
            // can ride along even if a downstream guard is ever missed.
            detection = .none
            disease = .healthy
            alternatives = []
            confidence = min(confidence, 0.35)
        } else if !detection.subjectValid {
            detection = detection.confirming(label: "\(crop.displayName.lowercased()) leaf/fruit",
                                             confidence: max(detection.confidence, 0.6))
        }

        return DiseaseClassification(disease: disease, confidence: confidence,
                                     alternatives: alternatives, health: health, detection: detection)
    }
}
