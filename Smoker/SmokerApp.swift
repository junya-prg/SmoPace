//
//  SmokerApp.swift
//  Smoker
//
//  Created by hondajunya on 2026/01/20.
//

import SwiftUI
import SwiftData
import AdSupport
import AppTrackingTransparency

@main
@available(iOS 26.0, macOS 26.0, *)
struct SmokerApp: App {
    /// SwiftDataのModelContainer（App Group経由で共有）
    var sharedModelContainer: ModelContainer = {
        do {
            let container = try SharedModelContainer.createContainer()
            
            // デバッグ: データベースの場所を出力
            #if DEBUG
            if let url = SharedModelContainer.databaseURL {
                print("📁 データベースURL: \(url.path)")
                print("📁 ファイル存在: \(FileManager.default.fileExists(atPath: url.path))")
            } else {
                print("⚠️ App Groupコンテナにアクセスできません")
            }
            #endif
            
            return container
        } catch {
            print("❌ ModelContainer作成エラー: \(error)")
            print("❌ エラー詳細: \(error.localizedDescription)")
            // フォールバック: インメモリのコンテナを使用（データは保存されない）
            do {
                let schema = Schema([SmokingRecord.self, CigaretteBrand.self, AppSettings.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("フォールバックModelContainerの作成にも失敗しました: \(error)")
            }
        }
    }()
    
    init() {
        // AdMob SDKを初期化
        AdManager.shared.initialize()
        
        // IDFA（広告ID）をコンソールに出力（テストデバイス登録用）
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
            print("📱 ========================================")
            print("📱 IDFA（広告ID）: \(idfa)")
            print("📱 このIDをAdMobのテストデバイスに登録してください")
            print("📱 ========================================")
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// ルートビュー - スプラッシュスクリーンとメイン画面を管理
@available(iOS 26.0, macOS 26.0, *)
struct RootView: View {
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            // メインコンテンツ
            MainTabView()
            
            // スプラッシュスクリーン（起動時のみ表示）
            if showSplash {
                SplashScreenView {
                    showSplash = false
                    // スプラッシュ終了後にトラッキング許可をリクエスト
                    requestTrackingPermission()
                }
                .transition(.opacity)
            }
        }
    }
    
    /// トラッキング許可をリクエスト
    private func requestTrackingPermission() {
        // すでに許可状態が決定している場合はスキップ
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                // 許可結果は特に処理しない（広告SDKが自動で対応）
            }
        }
    }
}
