//
//  SmokeCounterWidgetIntent.swift
//  SmokeCounterWidget
//
//  ウィジェットの設定用Intent
//

import WidgetKit
import AppIntents
import SwiftData

/// ウィジェットの設定用Intent
struct SmokeCounterWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "喫煙カウンター"
    static var description = IntentDescription("今日の喫煙本数を表示します")
}

/// カウントアップ用のIntent
struct IncrementCountIntent: AppIntent {
    static var title: LocalizedStringResource = "喫煙を記録"
    static var description = IntentDescription("喫煙カウントを1増やします")
    
    /// ウィジェットからの実行時にアプリを開かない
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("🔵 ウィジェット: カウントアップ開始 - \(formatter.string(from: now))")
        
        // SwiftDataに直接記録を追加
        do {
            // App GroupのURLを確認
            if let url = SharedModelContainer.databaseURL {
                print("🔵 データベースURL: \(url.path)")
            } else {
                print("🔴 App Groupコンテナにアクセスできません")
            }
            
            let container = try SharedModelContainer.createContainer()
            print("🔵 ModelContainer作成成功")
            
            let context = ModelContext(container)
            
            // デフォルト銘柄を取得
            let defaultBrand = try getDefaultBrand(context: context)
            
            // 銘柄情報を含めて記録を作成
            let record = SmokingRecord(
                brandId: defaultBrand?.id,
                brandName: defaultBrand?.name,
                pricePerCigarette: defaultBrand?.pricePerCigarette
            )
            context.insert(record)
            print("🔵 レコード挿入完了 - timestamp: \(formatter.string(from: record.timestamp)), 銘柄: \(defaultBrand?.name ?? "なし")")
            
            try context.save()
            print("🔵 保存成功")
            
            // タイムラインは UserDefaults のキャッシュのみ参照するため、SwiftData の集計を App Group に反映する（メインアプリの refreshWidgetCacheFromSwiftData と同じ）
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: now)
            let endExclusive = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
            let predicate = #Predicate<SmokingRecord> { r in
                r.timestamp >= startOfToday && r.timestamp < endExclusive
            }
            let descriptor = FetchDescriptor<SmokingRecord>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let todayRecords = try context.fetch(descriptor)
            let aggregatedCount = todayRecords.reduce(0) { $0 + $1.count }
            let lastSmoke = todayRecords.first?.timestamp
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            let goal = try context.fetch(settingsDescriptor).first?.dailyGoal
            SharedDataManager.shared.updateSharedData(count: aggregatedCount, goal: goal, lastSmoke: lastSmoke)
            print("🔵 ウィジェット用キャッシュ更新完了: 本数=\(aggregatedCount), レコード件数=\(todayRecords.count), 目標=\(goal.map(String.init) ?? "なし")")
            
        } catch {
            print("🔴 ウィジェットからの記録保存に失敗: \(error)")
        }
        
        return .result()
    }
    
    /// デフォルト銘柄を取得
    private func getDefaultBrand(context: ModelContext) throws -> CigaretteBrand? {
        // 全銘柄を取得してデフォルト銘柄を探す
        let allDescriptor = FetchDescriptor<CigaretteBrand>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let allBrands = try context.fetch(allDescriptor)
        
        // isDefaultBrandがtrueの銘柄を探す
        if let defaultBrand = allBrands.first(where: { $0.isDefaultBrand }) {
            return defaultBrand
        }
        
        // デフォルト銘柄がない場合は最初の銘柄を返す
        return allBrands.first
    }
}
