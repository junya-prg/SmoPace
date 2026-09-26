//
//  RelaxingBackgroundView.swift
//  SmokeCounter
//
//  癒しの背景映像を表示するビュー
//  煙・炎・焚き火など複数のプリセットから選択可能
//

import SwiftUI

/// 背景エフェクトの種類
enum RelaxingBackgroundType: String, CaseIterable, Identifiable, Codable {
    case none = "なし"
    case random = "ランダム"
    case smoke = "煙"
    case fire = "炎"
    case campfire = "焚き火"
    case custom = "マイ背景"
    
    var id: String { rawValue }
    
    /// 表示名（rawValue は保存値なので変更せず、表示だけローカライズする）
    var displayName: String {
        switch self {
        case .none: return String(localized: "なし")
        case .random: return String(localized: "ランダム")
        case .smoke: return String(localized: "煙")
        case .fire: return String(localized: "炎")
        case .campfire: return String(localized: "焚き火")
        case .custom: return String(localized: "マイ背景")
        }
    }
    
    /// アイコン名
    var iconName: String {
        switch self {
        case .none: return "circle.slash"
        case .random: return "dice"
        case .smoke: return "cloud"
        case .fire: return "flame"
        case .campfire: return "flame.circle"
        case .custom: return "photo.on.rectangle.angled"
        }
    }
    
    /// 説明文
    var description: String {
        switch self {
        case .none: return "背景なし"
        case .random: return "起動時にランダム"
        case .smoke: return "ゆらめく煙"
        case .fire: return "温かな炎"
        case .campfire: return "キャンプの焚き火"
        case .custom: return "あなたが作った背景"
        }
    }
    
    /// ローカライズ済みの説明文
    var localizedDescription: String {
        switch self {
        case .none: return String(localized: "背景なし")
        case .random: return String(localized: "起動時にランダム")
        case .smoke: return String(localized: "ゆらめく煙")
        case .fire: return String(localized: "温かな炎")
        case .campfire: return String(localized: "キャンプの焚き火")
        case .custom: return String(localized: "あなたが作った背景")
        }
    }
    
    /// 実際に表示するエフェクトを取得（ランダムの場合はランダムに選択）
    var actualType: RelaxingBackgroundType {
        if self == .random {
            return Self.effectTypes.randomElement() ?? .campfire
        }
        return self
    }
    
    /// エフェクトのみ（none, random, custom以外）
    static var effectTypes: [RelaxingBackgroundType] {
        [.smoke, .fire, .campfire]
    }
    
    /// ランダム選択の候補（マイ背景があるときはそれも含める）
    static func randomPool(hasCustom: Bool) -> [RelaxingBackgroundType] {
        hasCustom ? effectTypes + [.custom] : effectTypes
    }
    
    /// 有効なエフェクトかどうか
    var isEffectEnabled: Bool {
        self != .none
    }
}

/// 癒しの背景を表示するビュー
struct RelaxingBackgroundView: View {
    /// 表示するエフェクトの種類
    let type: RelaxingBackgroundType
    
    /// 透明度（0.0〜1.0）
    var opacity: Double = 0.5
    
    var body: some View {
        Group {
            switch type {
            case .none, .random:
                // randomはHomeView側で解決されるので、ここではEmptyView
                Color.black
            case .smoke:
                SmokeParticleView()
            case .fire:
                FireParticleView()
            case .campfire:
                CampfireParticleView()
            case .custom:
                // 画像が無い場合は焚き火にフォールバック
                if let image = CustomBackgroundStore.shared.image {
                    CustomPhotoBackgroundView(image: image)
                } else {
                    CampfireParticleView()
                }
            }
        }
        .opacity(opacity)
    }
}

#Preview("Smoke") {
    RelaxingBackgroundView(type: .smoke, opacity: 1.0)
}

#Preview("Fire") {
    RelaxingBackgroundView(type: .fire, opacity: 1.0)
}

#Preview("Campfire") {
    RelaxingBackgroundView(type: .campfire, opacity: 1.0)
}
