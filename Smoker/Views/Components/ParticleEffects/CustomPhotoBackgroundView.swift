//
//  CustomPhotoBackgroundView.swift
//  SmoPace
//
//  マイ背景（Image Playground で生成した画像や写真）を表示する背景ビュー
//  静止画の上に Metal シェーダーの陽炎・ちらつきと、火の粉・ホタルを重ねて「動く写真」にする
//

import SwiftUI

/// 写真ベースの癒し背景
struct CustomPhotoBackgroundView: View {
    /// 背景に敷く画像
    let image: UIImage

    /// 熱源（陽炎と火の粉の発生位置。0〜1 の正規化座標）
    var heatOrigin: CGPoint = CGPoint(x: 0.5, y: 0.74)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    /// 陽炎の最大変位（ポイント）
    private let hazeStrength: Float = 9
    private let maxSampleOffset = CGSize(width: 14, height: 14)

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                // 1. 写真 ＋ 陽炎・ちらつき（シェーダー）
                TimelineView(.animation(paused: reduceMotion)) { timeline in
                    let elapsed = Float(timeline.date.timeIntervalSince(startDate))
                    photoLayer(size: size, elapsed: elapsed)
                }
                .frame(width: size.width, height: size.height)

                // 2. 周辺を落として UI の可読性を上げるビネット
                RadialGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.45)],
                    center: .center,
                    startRadius: size.width * 0.35,
                    endRadius: max(size.width, size.height) * 0.75
                )
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

                // 3. 火の粉・ホタル
                if !reduceMotion {
                    TimelineView(.animation) { timeline in
                        EmberOverlayView(
                            time: timeline.date.timeIntervalSince(startDate),
                            origin: CGPoint(x: heatOrigin.x, y: heatOrigin.y + 0.04)
                        )
                    }
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
    }

    /// 写真にシェーダーを適用したレイヤー
    @ViewBuilder
    private func photoLayer(size: CGSize, elapsed: Float) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .distortionEffect(
                ShaderLibrary.heatHaze(
                    .float2(size),
                    .float(elapsed),
                    .float(hazeStrength),
                    .float2(heatOrigin)
                ),
                maxSampleOffset: maxSampleOffset,
                isEnabled: !reduceMotion
            )
            .colorEffect(
                ShaderLibrary.warmFlicker(
                    .float2(size),
                    .float(elapsed),
                    .float2(heatOrigin)
                ),
                isEnabled: !reduceMotion
            )
    }
}

#Preview("Custom Photo") {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 1200))
    let sample = renderer.image { ctx in
        let colors = [UIColor(red: 0.05, green: 0.02, blue: 0.1, alpha: 1).cgColor,
                      UIColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
        ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 1200), options: [])
    }
    return CustomPhotoBackgroundView(image: sample)
}
