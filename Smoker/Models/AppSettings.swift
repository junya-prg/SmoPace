//
//  AppSettings.swift
//  SmokeCounter
//
//  アプリの設定を表すSwiftDataモデル
//

import Foundation
import SwiftData

/// アプリの設定を表すモデル
/// CloudKit互換のため、すべてのプロパティにデフォルト値を設定
@Model
final class AppSettings {
    /// 一意識別子
    var id: UUID = UUID()

    /// HealthKit連携の有効/無効
    var healthKitEnabled: Bool = false

    /// 現在選択中の銘柄ID
    var activeBrandId: UUID?

    /// 1日の目標本数（nilで目標未設定）
    var dailyGoal: Int?

    /// 背景エフェクトの種類（rawValue形式で保存）
    /// デフォルト値を指定してマイグレーション対応
    var backgroundTypeRawValue: String = "ランダム"

    /// 背景エフェクトの透明度（0.0〜1.0）
    /// デフォルト値を指定してマイグレーション対応
    var backgroundOpacity: Double = 0.4

    /// iCloud同期の有効/無効（デフォルトtrue）
    /// デフォルト値を指定してマイグレーション対応
    var iCloudSyncEnabled: Bool = true

    /// 通貨コード（ISO 4217、例: "JPY", "USD"）
    /// デフォルトは"JPY"。既存ユーザーは円のまま安全に移行される。
    /// 新規ユーザーはinit時にロケールから決定される。
    var currencyCode: String = "JPY"

    /// 背景エフェクトの種類（計算プロパティ）
    var backgroundType: RelaxingBackgroundType {
        get {
            RelaxingBackgroundType(rawValue: backgroundTypeRawValue) ?? .random
        }
        set {
            backgroundTypeRawValue = newValue.rawValue
        }
    }

    /// 初期化
    /// - Parameters:
    ///   - healthKitEnabled: HealthKit連携の有効/無効（デフォルトfalse）
    ///   - activeBrandId: 選択中の銘柄ID
    ///   - dailyGoal: 1日の目標本数
    ///   - backgroundType: 背景エフェクトの種類（デフォルト: ランダム）
    ///   - backgroundOpacity: 背景の透明度（デフォルト: 0.4）
    ///   - iCloudSyncEnabled: iCloud同期の有効/無効（デフォルトtrue）
    ///   - currencyCode: 通貨コード（nil時はLocaleから自動決定）
    init(
        healthKitEnabled: Bool = false,
        activeBrandId: UUID? = nil,
        dailyGoal: Int? = nil,
        backgroundType: RelaxingBackgroundType = .random,
        backgroundOpacity: Double = 0.4,
        iCloudSyncEnabled: Bool = true,
        currencyCode: String? = nil
    ) {
        self.id = UUID()
        self.healthKitEnabled = healthKitEnabled
        self.activeBrandId = activeBrandId
        self.dailyGoal = dailyGoal
        self.backgroundTypeRawValue = backgroundType.rawValue
        self.backgroundOpacity = backgroundOpacity
        self.iCloudSyncEnabled = iCloudSyncEnabled
        // currencyCodeが明示されない場合のみロケールから決定（新規ユーザー）
        // 既存ユーザーのDB読み込み時はinitを通らずプロパティのデフォルト"JPY"が使われる
        self.currencyCode = currencyCode ?? CurrencyFormatter.defaultCurrencyCode()
    }
}
