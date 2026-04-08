//
//  AdManager.swift
//  SmokeCounter
//
//  広告管理サービス
//  Google AdMobを使用したバナー広告・ネイティブ広告の管理
//

import Foundation
import SwiftUI
import GoogleMobileAds
import os

private let logger = Logger(subsystem: "SmokeCounter", category: "AdManager")

/// 広告管理サービス
@MainActor
@Observable
final class AdManager {
    /// シングルトンインスタンス
    static let shared = AdManager()
    
    /// 広告の初期化完了フラグ
    private(set) var isInitialized = false
    
    // MARK: - 広告ユニットID
    
    // テストモード: 新しいAdMobアプリ(SmoPace用)が作成されるまでtrueにしておく
    // AdMob管理画面で新しいアプリを作成後、Info.plistのGADApplicationIdentifierと
    // 各広告ユニットIDを更新してfalseに戻す
    private let useTestAds = false
    
    /// バナー広告ユニットID
    var bannerAdUnitId: String {
        if useTestAds {
            // Googleの公式テスト広告ID
            return "ca-app-pub-3940256099942544/2934735716"
        } else {
            // 本番用（SmoPace_Banner）
            return "ca-app-pub-2534039379765102/1698542350"
        }
    }
    
    /// ネイティブ広告ユニットID
    var nativeAdUnitId: String {
        if useTestAds {
            // Googleの公式テスト広告ID
            return "ca-app-pub-3940256099942544/3986624511"
        } else {
            // 本番用（SmoPace_Native）
            return "ca-app-pub-2534039379765102/3020835061"
        }
    }
    
    private init() {}
    
    /// AdMobを初期化する
    /// AppDelegate または App の初期化時に呼び出す
    func initialize() {
        guard !isInitialized else { return }
        
        // テストデバイスの設定（実機でテスト広告を表示するため）
        // シミュレーターは自動的にテストデバイスとして扱われます
        // 実機のデバイスIDはコンソールに出力されるので、それを追加してください
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "GADSimulatorID"  // シミュレーター用（自動）
            // 実機のデバイスIDをここに追加（コンソールで確認）
            // 例: "abc123def456..."
        ]
        
        // Google Mobile Ads SDKの初期化
        MobileAds.shared.start { _ in
            logger.info("✅ AdMob初期化完了")
            Task { @MainActor in
                self.isInitialized = true
            }
        }
    }
}

// MARK: - 広告表示の設定

/// 広告表示設定
struct AdConfiguration {
    /// 統計画面でバナー広告を表示するか
    static let showBannerInStatistics = true
    
    /// AIニュース画面でネイティブ広告を表示するか
    static let showNativeInAINews = true
    
    /// ネイティブ広告を表示する間隔（記事数）
    static let nativeAdInterval = 5
}
