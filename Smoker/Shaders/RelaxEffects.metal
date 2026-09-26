//
//  RelaxEffects.metal
//  SmoPace
//
//  リラックスモード「マイ背景」用のシェーダー
//  - heatHaze: 焚き火の陽炎（ヒートヘイズ）歪み。SwiftUI の distortionEffect から呼ぶ
//  - warmFlicker: 炎のちらつきを模した明度・色温度のゆらぎ。SwiftUI の colorEffect から呼ぶ
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - ノイズ

/// 2D ハッシュ（0〜1）
static inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// バリューノイズ（0〜1、滑らか）
static inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// MARK: - 陽炎（distortionEffect）

/// 画面下中央付近（origin）から立ち上る陽炎の歪み
/// - position: ピクセル座標
/// - size:     ビューのサイズ（ピクセル）
/// - time:     経過秒
/// - strength: 最大変位（ピクセル）。maxSampleOffset 以下にすること
/// - origin:   熱源の位置（0〜1 の正規化座標）
[[stitchable]] float2 heatHaze(float2 position,
                               float2 size,
                               float time,
                               float strength,
                               float2 origin) {
    float2 uv = position / max(size, float2(1.0, 1.0));

    // 熱源からの距離で減衰（横方向は広め、縦方向は上に伸びる）
    float2 delta = uv - origin;
    delta.x *= 1.4;
    delta.y = delta.y > 0.0 ? delta.y * 2.2 : delta.y * 0.9;
    float dist = length(delta);
    float falloff = smoothstep(0.85, 0.08, dist);

    // 上向きに流れる2層のノイズ
    float n1 = valueNoise(float2(uv.x * 12.0, uv.y * 9.0 + time * 1.7));
    float n2 = valueNoise(float2(uv.x * 26.0 + 7.3, uv.y * 19.0 + time * 2.9));

    float dx = (n1 - 0.5) * 1.6 + (n2 - 0.5) * 0.8;
    float dy = (n2 - 0.5) * 1.1;

    return position + float2(dx, dy) * strength * falloff;
}

// MARK: - 炎のちらつき（colorEffect）

/// 熱源付近の明るさと暖色をわずかに揺らす
/// - color は premultiplied alpha
[[stitchable]] half4 warmFlicker(float2 position,
                                 half4 color,
                                 float2 size,
                                 float time,
                                 float2 origin) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float dist = distance(uv, origin);
    float falloff = smoothstep(0.95, 0.0, dist);

    // 複数周波数の合成でランダムに見えるちらつき（-1〜1）
    float f = sin(time * 9.0) * 0.5
            + sin(time * 23.0 + 1.3) * 0.3
            + sin(time * 4.1 + 0.7) * 0.2;

    float gain = 1.0 + f * 0.04 * falloff;
    half3 rgb = color.rgb * half(gain);

    // 暖色をほんの少し足す（premultiplied なので alpha を掛ける）
    half warm = half(falloff * (0.5 + 0.5 * f) * 0.03) * color.a;
    rgb += half3(warm, warm * 0.45, 0.0h);

    return half4(min(rgb, half3(color.a)), color.a);
}
