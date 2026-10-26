//
//  RipenessEstimator.swift
//  OrchardEye
//
//  On-device ripeness from the camera image only — no external NIR sensor.
//  Fruit ripens by shifting colour (green → gold/red); we read that shift from the
//  same `ImageStats` the disease head already computes. `score` is a 0–100 visual
//  ripeness proxy, NOT a lab °Brix reading — labelled as an estimate in the UI.
//

import Foundation

enum RipenessEstimator {

    static func estimate(from s: ImageStats, crop: Crop) -> RipenessReading {
        // Warmth: how red/gold the subject is. Red skin (redFraction) is the
        // strongest ripeness signal and survives white cut-flesh averaging the
        // means down — so a sliced red apple still reads ripe.
        // Yellow is a legitimate ripe-skin signal (Golden Delicious, Ginger Gold),
        // weighted alongside red so yellow apples don't read as unripe.
        let warmth = clamp01((s.avgR - s.avgG) * 1.4 + s.yellowFraction * 1.0 + s.redFraction * 1.0)
        // Greenness pulls toward "not ready".
        let greenPull = min(1, s.greenFraction * 1.4)

        var score = clamp01(warmth * 0.78 + (1 - greenPull) * 0.22) * 100

        // Dull / dark / heavily browned reads as past-peak.
        let dull = s.brightness < 0.28 || s.brownFraction > 0.35

        let ripeness: RipenessClass
        if dull && score > 55 {
            ripeness = .overripe
        } else if score >= 55 {
            ripeness = .ripe
        } else if score >= 38 {
            ripeness = warmth > greenPull ? .ripe : .unripe
        } else {
            ripeness = .unripe
        }
        // Keep the meter honest with the label — the bar shouldn't read half-empty
        // next to a "Ripe" pill (or full next to "Not ready").
        switch ripeness {
        case .ripe:     score = max(score, 60)
        case .overripe: score = max(score, 72)
        case .unripe:   score = min(score, 45)
        }

        // Confidence: how much of the frame reads as fruit/leaf colour vs neutral
        // background — a grey wall scores low, a full fruit scores high.
        let subject = min(1, s.greenFraction + s.yellowFraction + s.brownFraction
                            + max(0, s.avgR - s.avgG))
        var confidence = max(0.3, min(0.95, 0.35 + subject * 0.7))

        // Foliage guard: a green-dominant frame with almost no warm (ripening)
        // colour is a leaf, not fruit — ripeness doesn't apply. (A green apple can
        // trip this; that's the honest, safe direction to fail.)
        let warmFraction = s.yellowFraction + max(0, s.avgR - s.avgG)

        // Whole red/warm fruit dominates the frame → the leaf-trained disease model
        // is out of distribution, so disease is "not assessed" for these.
        let fruit = s.redFraction > 0.25 || (warmFraction > 0.20 && s.greenFraction < 0.22)

        // Foliage → ripeness N/A. Not just "very green": a pale/desaturated leaf still
        // reads as a non-warm, green-≥-red, mid-brightness subject (bright fruit-on-
        // white and warm fruit are excluded).
        let foliage = !fruit
            && s.redFraction < 0.06
            && warmFraction < 0.12
            && s.avgG >= s.avgR - 0.02
            && s.brightness < 0.62
        if foliage { confidence = min(confidence, 0.3) }

        return RipenessReading(ripeness: ripeness, score: score,
                               confidence: confidence, foliage: foliage, fruit: fruit)
    }

    private static func clamp01(_ x: Double) -> Double { max(0, min(1, x)) }
}
