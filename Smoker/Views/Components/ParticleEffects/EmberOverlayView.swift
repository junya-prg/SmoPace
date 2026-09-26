//
//  EmberOverlayView.swift
//  SmoPace
//
//  マイ背景の上に重ねる火の粉・ホタルのオーバーレイ
//  状態を持たず、時間の関数として各火の粉の位置を求める（Timer 不要・GPU 描画）
//

import SwiftUI

/// 火の粉とホタルを重ねるオーバーレイ
struct EmberOverlayView: View {
    /// 経過秒
    let time: Double

    /// 火の粉の発生源（0〜1 の正規化座標）
    var origin: CGPoint = CGPoint(x: 0.5, y: 0.78)

    /// 火の粉の数
    var emberCount: Int = 22

    var body: some View {
        ZStack {
            Canvas(rendersAsynchronously: true) { context, size in
                drawEmbers(in: &context, size: size)
            }
            .allowsHitTesting(false)

            FireflyLayer(size: .zero, time: time)
                .opacity(0.8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - 火の粉

    private func drawEmbers(in context: inout GraphicsContext, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let baseX = size.width * origin.x
        let baseY = size.height * origin.y

        for i in 0..<emberCount {
            let seed = Double(i)
            // 各火の粉の寿命（秒）と位相をずらして途切れなく発生させる
            let lifetime = 2.6 + fract(seed * 0.618) * 2.4
            let phase = fract(seed * 0.377) * lifetime
            let progress = fract((time + phase) / lifetime)   // 0→1 で上昇

            // 上昇（減速しながら）と横揺れ
            let rise = (1 - pow(1 - progress, 1.8)) * size.height * (0.32 + fract(seed * 0.913) * 0.28)
            let drift = sin(time * (0.9 + fract(seed * 0.271)) + seed) * (12 + fract(seed * 0.771) * 18)
            let spread = (fract(seed * 0.531) - 0.5) * size.width * 0.22 * progress

            let x = baseX + CGFloat(drift + spread)
            let y = baseY - CGFloat(rise)

            // 出現直後はフェードイン、終盤はフェードアウト
            let fadeIn = min(1, progress * 6)
            let fadeOut = 1 - pow(progress, 2.2)
            let flicker = 0.65 + sin(time * 17 + seed * 3.1) * 0.35
            let opacity = fadeIn * fadeOut * flicker
            guard opacity > 0.03 else { continue }

            let radius = CGFloat(1.8 + fract(seed * 0.197) * 2.6) * CGFloat(1 - progress * 0.4)
            let hue = 0.04 + fract(seed * 0.443) * 0.06

            // グロー
            let glowRadius = radius * 3.2
            let glowRect = CGRect(x: x - glowRadius, y: y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
            context.fill(
                Circle().path(in: glowRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hue: hue, saturation: 0.95, brightness: 1.0).opacity(opacity * 0.55),
                        Color(hue: hue, saturation: 1.0, brightness: 0.9).opacity(0)
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: glowRadius
                )
            )

            // コア
            let coreRect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(
                Circle().path(in: coreRect),
                with: .color(Color(hue: hue, saturation: 0.7, brightness: 1.0).opacity(opacity))
            )
        }
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}

#Preview("Embers") {
    ZStack {
        Color.black
        TimelineView(.animation) { timeline in
            EmberOverlayView(time: timeline.date.timeIntervalSinceReferenceDate)
        }
    }
    .ignoresSafeArea()
}
