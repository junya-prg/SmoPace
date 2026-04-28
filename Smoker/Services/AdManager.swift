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
    
    /// 広告の初期化完了フラグ（MobileAds SDK の start() 完了）
    private(set) var isInitialized = false

    /// ATT（App Tracking Transparency）の許可状態が確定したか
    /// .notDetermined → ダイアログ応答後 true、既に .authorized/.denied/.restricted なら初期化時に true
    var attResolved = false

    /// UMP（User Messaging Platform）同意フローが完了したか
    /// 同意フォーム表示が不要な地域でも、ConsentInfo の更新完了で true になる
    var consentResolved = false

    /// 広告をロードしてよい状態か（SDK初期化完了 かつ 同意確定 かつ ATT確定）
    var canLoadAds: Bool { isInitialized && consentResolved && attResolved }

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
        
        #if DEBUG
        // --- 一時的にコメントアウトして、テスト機でも本番広告をリクエストさせる ---
        // MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
        //     "GADSimulatorID"
        // ]
        #endif
        
        // Google Mobile Ads SDKの初期化
        Task { @MainActor in
            await MobileAds.shared.start()
            self.isInitialized = true
            logger.info("✅ AdMob初期化完了")
        }
    }

    /// ATT許可状態が確定したことを通知する
    /// ユーザーがダイアログに応答した直後、または初期化時に .notDetermined 以外だった場合に呼ぶ
    func markATTResolved() {
        attResolved = true
        logger.info("✅ ATT状態確定")
    }

    /// UMP 同意フローが完了したことを通知する
    func markConsentResolved() {
        consentResolved = true
        logger.info("✅ UMP同意フロー完了")
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
