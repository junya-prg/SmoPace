//
//  SharedModelContainer.swift
//  SmokeCounter
//
//  メインアプリとウィジェットで共有するModelContainer設定
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
            // 初回起動時はキーが存在しないのでデフォルトtrueを返す
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
    
    /// スキーマ
    static var schema: Schema {
        Schema([
            SmokingRecord.self,
            CigaretteBrand.self,
            AppSettings.self
        ])
    }
    
    /// 共有ModelContainerを作成
    /// - Returns: ModelContainer
    static func createContainer() throws -> ModelContainer {
        // App Groupのデータベースを使用（ウィジェットと共有するため必須）
        guard let url = databaseURL else {
            // App Groupが利用できない場合はデフォルトの場所を使用
            print("⚠️ App Groupが利用できません。デフォルトの場所を使用します。")
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        }
        
        // iCloud同期は新しいiCloudコンテナ(iCloud.jp.junya.SmoPace)がCloudKit Dashboardに
        // 登録されるまで無効化。登録後に .automatic に戻す。
        // let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = isICloudSyncEnabled ? .automatic : .none
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none
        
        print("✅ App Groupデータベースを使用: \(url.path)")
        print("☁️ iCloud同期: \(isICloudSyncEnabled ? "有効" : "無効")")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: cloudKitDatabase
        )
        
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
