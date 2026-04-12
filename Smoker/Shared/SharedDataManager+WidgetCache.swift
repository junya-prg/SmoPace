//
//  SharedDataManager+WidgetCache.swift
//  Smoker
//
//  ウィジェットは SQLite を直接開かず UserDefaults を参照するため、
//  SwiftData の状態を App Group に反映する。
//

import Foundation
import SwiftData

extension SharedDataManager {
    /// SwiftData の「今日の集計」と目標を App Group に書き込み、ウィジェットを更新する
    @MainActor
    func refreshWidgetCacheFromSwiftData(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return
        }
        do {
            let predicate = #Predicate<SmokingRecord> { record in
                record.timestamp >= startOfToday && record.timestamp < endExclusive
            }
            let descriptor = FetchDescriptor<SmokingRecord>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let records = try modelContext.fetch(descriptor)
            let count = records.reduce(0) { $0 + $1.count }
            let lastSmoke = records.first?.timestamp
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            let goal = try modelContext.fetch(settingsDescriptor).first?.dailyGoal
            updateSharedData(count: count, goal: goal, lastSmoke: lastSmoke)
        } catch {
            print("ウィジェット用キャッシュ更新に失敗: \(error.localizedDescription)")
        }
    }
}
