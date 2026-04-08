//
//  SharedModelContainer.swift
//  SmokeCounterWidget
//
//  メインアプリとウィジェットで共有するModelContainer設定（ウィジェット用）
//

import Foundation
import SwiftData

/// 共有ModelContainerの設定
enum SharedModelContainer {
    /// App Group識別子
    static let appGroupIdentifier = "group.jp.junya.smoker.data"
    
    /// iCloud同期設定のUserDefaultsキー
    private static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    
    /// App GroupのコンテナURL
    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    /// 共有データベースのURL
    static var databaseURL: URL? {
        appGroupContainerURL?.appendingPathComponent("SmokeCounter.sqlite")
    }
    
    /// App GroupのUserDefaults
    static var sharedUserDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    /// iCloud同期が有効かどうか（UserDefaultsから取得、デフォルトtrue）
    static var isICloudSyncEnabled: Bool {
        get {
            guard let defaults = sharedUserDefaults else { return true }
            if defaults.object(forKey: iCloudSyncEnabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: iCloudSyncEnabledKey)
        }
        set {
            sharedUserDefaults?.set(newValue, forKey: iCloudSyncEnabledKey)
        }
    }
    
    /// スキーマ（メインアプリと同一にする必要がある）
    static var schema: Schema {
        Schema([
            SmokingRecord.self,
            CigaretteBrand.self,
            AppSettings.self
        ])
    }
    
    /// 共有ModelContainerを作成（ウィジェット用）
    /// - Note: ウィジェットは短命プロセスのためCloudKit同期は常に無効化する。
    ///         CloudKitの初期化が完了する前にプロセスが終了し、
    ///         "store was removed from the coordinator" エラーが発生するため。
    ///         ウィジェットはデータの読み取り専用なのでCloudKit同期は不要。
    /// - Returns: ModelContainer
    static func createContainer() throws -> ModelContainer {
        guard let url = databaseURL else {
            throw NSError(domain: "SharedModelContainer", code: 1, userInfo: [NSLocalizedDescriptionKey: "App Groupのコンテナにアクセスできません"])
        }
        
        // ウィジェットではCloudKit同期を常に無効にする
        // （短命プロセスではCloudKit初期化が完了できずエラーになるため）
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
