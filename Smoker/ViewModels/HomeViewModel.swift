//
//  HomeViewModel.swift
//  SmokeCounter
//
//  ホーム画面のViewModel
//

import Foundation
import SwiftUI
import SwiftData
import WidgetKit

/// 銘柄別のカウント情報
struct BrandCount: Identifiable, Equatable {
    let id: UUID?  // nilは「全体」を表す
    let name: String
    var count: Int
    var amount: Decimal
    
    /// 「全体」タブ用の特別なID
    static let allBrandsId: UUID? = nil
}

/// ホーム画面のViewModel
@Observable
class HomeViewModel {
    /// 今日の喫煙本数（全体）
    var todayCount: Int = 0
    
    /// 全期間の総喫煙本数
    var totalRecordsCount: Int = 0
    
    /// 1日の目標本数
    var dailyGoal: Int? = nil
    
    /// 前回の喫煙からの経過時間（秒）
    var timeSinceLastSmoke: TimeInterval? = nil
    
    /// 最後の喫煙時刻
    var lastSmokeTime: Date? = nil
    
    /// 現在使用中の銘柄
    var activeBrand: CigaretteBrand? = nil
    
    /// 登録されている全銘柄
    var allBrands: [CigaretteBrand] = []
    
    /// 銘柄別のカウント情報
    var brandCounts: [BrandCount] = []
    
    /// 現在選択中の銘柄ID（nilは全体表示）
    var selectedBrandId: UUID? = nil
    
    /// 今日の消費金額（記録時の価格を使用）
    var todayAmount: Decimal = 0
    
    /// 背景エフェクトの透明度
    var backgroundOpacity: Double = 0.4
    
    /// 選択中の銘柄のカウント
    var selectedBrandCount: Int {
        if selectedBrandId == nil {
            return todayCount
        }
        return brandCounts.first { $0.id == selectedBrandId }?.count ?? 0
    }
    
    /// 選択中の銘柄の金額
    var selectedBrandAmount: Decimal {
        if selectedBrandId == nil {
            return todayAmount
        }
        return brandCounts.first { $0.id == selectedBrandId }?.amount ?? 0
    }
    
    /// 目標に対する残り本数
    var remainingCount: Int? {
        guard let goal = dailyGoal else { return nil }
        return max(0, goal - todayCount)
    }
    
    /// 目標を超過しているかどうか
    var isOverGoal: Bool {
        guard let goal = dailyGoal else { return false }
        return todayCount > goal
    }
    
    /// 目標達成率（0.0〜1.0、超過時は1.0以上）
    var goalProgress: Double {
        guard let goal = dailyGoal, goal > 0 else { return 0 }
        return Double(todayCount) / Double(goal)
    }
    
    /// 選択中の銘柄（nilの場合はデフォルト銘柄を返す）
    var currentBrand: CigaretteBrand? {
        if let selectedId = selectedBrandId {
            return allBrands.first { $0.id == selectedId }
        }
        // 選択がない場合はデフォルト銘柄を返す
        return allBrands.first { $0.isDefaultBrand } ?? allBrands.first
    }
    
    /// 前回の喫煙からの経過時間を文字列で取得
    var timeSinceLastSmokeText: String {
        guard let interval = timeSinceLastSmoke else {
            return "記録なし"
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    /// 今日の喫煙記録を読み込む
    /// - Parameter modelContext: SwiftDataのModelContext（未使用、互換性のため残す）
    func loadTodayRecords(modelContext: ModelContext) {
        // 外部からの変更（ウィジェット）を検知するため、新しいコンテキストで取得
        loadTodayRecordsFromSharedContainer()
    }
    
    /// 共有コンテナから今日の喫煙記録を読み込む
    private func loadTodayRecordsFromSharedContainer() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        
        do {
            // 新しいModelContainerを作成して最新データを取得
            let container = try SharedModelContainer.createContainer()
            let context = ModelContext(container)
            
            let predicate = #Predicate<SmokingRecord> { record in
                record.timestamp >= startOfToday && record.timestamp < endOfToday
            }
            
            let descriptor = FetchDescriptor<SmokingRecord>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            let records = try context.fetch(descriptor)
            todayCount = records.reduce(0) { $0 + $1.count }
            
            // 全期間の総記録数を取得
            let allRecordsDescriptor = FetchDescriptor<SmokingRecord>()
            let allRecords = try context.fetch(allRecordsDescriptor)
            totalRecordsCount = allRecords.reduce(0) { $0 + $1.count }
            
            // 記録時の価格を使用して金額を計算
            todayAmount = records.reduce(Decimal(0)) { $0 + $1.amount }
            
            // 銘柄別のカウントを集計
            var brandCountDict: [UUID: (count: Int, amount: Decimal, name: String)] = [:]
            var unclassifiedCount = 0
            var unclassifiedAmount: Decimal = 0
            
            for record in records {
                if let brandId = record.brandId {
                    let existing = brandCountDict[brandId] ?? (count: 0, amount: 0, name: record.brandName ?? "不明")
                    brandCountDict[brandId] = (
                        count: existing.count + record.count,
                        amount: existing.amount + record.amount,
                        name: record.brandName ?? existing.name
                    )
                } else {
                    unclassifiedCount += record.count
                    unclassifiedAmount += record.amount
                }
            }
            
            // brandCountsを更新
            var newBrandCounts: [BrandCount] = []
            
            // 登録されている銘柄のカウントを追加
            for brand in allBrands {
                let data = brandCountDict[brand.id]
                newBrandCounts.append(BrandCount(
                    id: brand.id,
                    name: brand.name,
                    count: data?.count ?? 0,
                    amount: data?.amount ?? 0
                ))
            }
            
            // 未分類の記録がある場合は追加
            if unclassifiedCount > 0 {
                newBrandCounts.append(BrandCount(
                    id: nil,
                    name: "未分類",
                    count: unclassifiedCount,
                    amount: unclassifiedAmount
                ))
            }
            
            brandCounts = newBrandCounts
            
            // 最新の記録から経過時間を計算
            if let lastRecord = records.first {
                timeSinceLastSmoke = Date().timeIntervalSince(lastRecord.timestamp)
                lastSmokeTime = lastRecord.timestamp
            } else {
                timeSinceLastSmoke = nil
                lastSmokeTime = nil
            }
            
            // ウィジェット用の共有データを更新
            updateSharedData()
        } catch {
            print("記録の取得に失敗しました: \(error)")
        }
    }
    
    /// 設定を読み込む
    /// - Parameter modelContext: SwiftDataのModelContext
    func loadSettings(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        
        do {
            let settings = try modelContext.fetch(descriptor)
            if let setting = settings.first {
                dailyGoal = setting.dailyGoal
                backgroundOpacity = setting.backgroundOpacity
                
                // アクティブな銘柄を取得
                if let brandId = setting.activeBrandId {
                    let brandPredicate = #Predicate<CigaretteBrand> { brand in
                        brand.id == brandId
                    }
                    let brandDescriptor = FetchDescriptor<CigaretteBrand>(predicate: brandPredicate)
                    activeBrand = try modelContext.fetch(brandDescriptor).first
                }
                
                // 全銘柄を取得
                let allBrandsDescriptor = FetchDescriptor<CigaretteBrand>(
                    sortBy: [SortDescriptor(\.createdAt)]
                )
                allBrands = try modelContext.fetch(allBrandsDescriptor)
                
                // ウィジェット用の共有データを更新
                updateSharedData()
            }
        } catch {
            print("設定の取得に失敗しました: \(error)")
        }
    }
    
    /// 喫煙を記録する
    /// - Parameter modelContext: SwiftDataのModelContext（未使用、互換性のため残す）
    /// - Parameter brand: 記録する銘柄（nilの場合は選択中の銘柄またはデフォルト銘柄を使用）
    func addSmokingRecord(modelContext: ModelContext, brand: CigaretteBrand? = nil) {
        do {
            // 共有コンテナに直接保存
            let container = try SharedModelContainer.createContainer()
            let context = ModelContext(container)
            
            // 使用する銘柄を決定
            let targetBrand = brand ?? currentBrand
            
            let record = SmokingRecord(
                brandId: targetBrand?.id,
                brandName: targetBrand?.name,
                pricePerCigarette: targetBrand?.pricePerCigarette
            )
            context.insert(record)
            try context.save()
            
            // 表示を即座に更新
            todayCount += 1
            timeSinceLastSmoke = 0
            lastSmokeTime = record.timestamp
            
            // 金額を更新
            if let price = targetBrand?.pricePerCigarette {
                todayAmount += price
            }
            
            // 銘柄別カウントを更新
            if let brandId = targetBrand?.id {
                if let index = brandCounts.firstIndex(where: { $0.id == brandId }) {
                    brandCounts[index].count += 1
                    brandCounts[index].amount += targetBrand?.pricePerCigarette ?? 0
                }
            }
            
            // ウィジェット用の共有データを更新＆タイムライン更新
            updateSharedData()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("記録の保存に失敗しました: \(error)")
        }
    }
    
    /// 喫煙記録を1つ減らす（誤操作時用）
    /// - Parameter modelContext: SwiftDataのModelContext（未使用、互換性のため残す）
    /// - Parameter brandId: 削除対象の銘柄ID（nilの場合は全体から最新を削除）
    func removeLastRecord(modelContext: ModelContext, brandId: UUID? = nil) {
        guard todayCount > 0 else { return }
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        
        do {
            // 共有コンテナから直接削除
            let container = try SharedModelContainer.createContainer()
            let context = ModelContext(container)
            
            let predicate: Predicate<SmokingRecord>
            if let targetBrandId = brandId {
                // 特定の銘柄の記録のみを対象にする
                predicate = #Predicate<SmokingRecord> { record in
                    record.timestamp >= startOfToday && record.timestamp < endOfToday && record.brandId == targetBrandId
                }
            } else {
                // 全体から最新の記録を対象にする
                predicate = #Predicate<SmokingRecord> { record in
                    record.timestamp >= startOfToday && record.timestamp < endOfToday
                }
            }
            
            let descriptor = FetchDescriptor<SmokingRecord>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            let records = try context.fetch(descriptor)
            if let lastRecord = records.first {
                context.delete(lastRecord)
                try context.save()
                
                // 最新データを再取得
                loadTodayRecordsFromSharedContainer()
                
                // ウィジェット更新
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            print("記録の削除に失敗しました: \(error)")
        }
    }
    
    // MARK: - ウィジェット連携
    
    /// ウィジェット用の共有データを更新する
    private func updateSharedData() {
        SharedDataManager.shared.updateSharedData(
            count: todayCount,
            goal: dailyGoal,
            lastSmoke: lastSmokeTime
        )
    }
    
    /// ウィジェットからの変更を同期する
    /// アプリがフォアグラウンドに戻った時に呼び出す
    /// - Parameter modelContext: SwiftDataのModelContext
    func syncFromWidget(modelContext: ModelContext) {
        let sharedManager = SharedDataManager.shared
        let sharedCount = sharedManager.todayCount
        
        // 共有データのカウントがSwiftDataより多い場合、差分を追加
        if sharedCount > todayCount {
            let difference = sharedCount - todayCount
            
            // 差分の分だけ記録を追加
            for _ in 0..<difference {
                let record = SmokingRecord()
                // 最後の喫煙時刻を使用（ウィジェットで更新された場合）
                if let lastSmoke = sharedManager.lastSmokeTime {
                    record.timestamp = lastSmoke
                }
                modelContext.insert(record)
            }
            
            do {
                try modelContext.save()
                // 再読み込みして状態を更新
                loadTodayRecords(modelContext: modelContext)
            } catch {
                print("ウィジェットからの同期に失敗しました: \(error)")
            }
        }
    }
}
