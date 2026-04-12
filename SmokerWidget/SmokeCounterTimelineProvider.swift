//
//  SmokeCounterTimelineProvider.swift
//  SmokeCounterWidget
//
//  ウィジェットのタイムラインを提供するプロバイダー
//

import WidgetKit
import AppIntents

/// ウィジェットのタイムラインを提供するプロバイダー
struct SmokeCounterTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = SmokeCounterEntry
    typealias Intent = SmokeCounterWidgetIntent
    
    /// プレースホルダーエントリーを返す
    func placeholder(in context: Context) -> SmokeCounterEntry {
        SmokeCounterEntry(date: Date(), count: 0, goal: 10)
    }
    
    /// ウィジェットギャラリーでのスナップショットを返す
    func snapshot(for configuration: SmokeCounterWidgetIntent, in context: Context) async -> SmokeCounterEntry {
        await getEntry()
    }
    
    /// タイムラインを返す
    func timeline(for configuration: SmokeCounterWidgetIntent, in context: Context) async -> Timeline<SmokeCounterEntry> {
        let currentEntry = await getEntry()
        
        // 現在のエントリーと、次の日の0時用のエントリーを作成
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        
        // 次の日の0時にカウントを0にリセットしたエントリー
        let midnightEntry = SmokeCounterEntry(
            date: tomorrow,
            count: 0,
            goal: currentEntry.goal,
            timeSinceLastSmoke: nil
        )
        
        return Timeline(entries: [currentEntry, midnightEntry], policy: .atEnd)
    }
    
    /// App Group の UserDefaults からエントリーを取得（メインアプリと SQLite を二重オープンしない）
    @MainActor
    private func getEntry() -> SmokeCounterEntry {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("🟢 Timeline: エントリー取得（UserDefaults）- \(formatter.string(from: now))")
        
        let shared = SharedDataManager.shared
        let todayCount = shared.todayCount
        let dailyGoal = shared.dailyGoal
        let lastSmokeTime = shared.lastSmokeTime
        
        print("🟢 取得成功: カウント=\(todayCount), 目標=\(dailyGoal ?? -1)")
        
        var timeSinceLastSmoke: TimeInterval? = nil
        if let lastSmoke = lastSmokeTime {
            timeSinceLastSmoke = Date().timeIntervalSince(lastSmoke)
        }
        
        return SmokeCounterEntry(
            date: now,
            count: todayCount,
            goal: dailyGoal,
            timeSinceLastSmoke: timeSinceLastSmoke
        )
    }
}
