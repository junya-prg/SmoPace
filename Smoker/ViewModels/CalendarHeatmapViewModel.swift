//
//  CalendarHeatmapViewModel.swift
//  SmokeCounter
//
//  カレンダーヒートマップのビューモデル
//

import SwiftUI
import SwiftData

@MainActor
@Observable
final class CalendarHeatmapViewModel {
    /// 現在表示している月
    var currentMonth: Date = Date()
    
    /// 日ごとの喫煙データ（辞書型で日付の開始時刻をキーにする）
    var dailyCounts: [Date: Int] = [:]
    
    /// その月の最大本数（ヒートマップの色計算用）
    var maxCountInMonth: Int = 1
    
    /// 日次目標値（設定されていれば）
    var dailyGoal: Int?
    
    /// 選択された日付（詳細表示用）
    var selectedDate: Date?
    
    /// 選択された日のレコード
    var selectedDateRecords: [SmokingRecord] = []
    
    /// カレンダーの表示用の日（当月分 + 前後月の埋め合わせ）
    var calendarDays: [Date] {
        let calendar = Calendar.current
        
        // 当月の初日
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components) else { return [] }
        
        // 当月の最終日
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else { return [] }
        
        // 初日の曜日 (日曜日=1, 月曜日=2...)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        
        // 前月から表示する日数 (日曜日始まりとする)
        let daysFromPreviousMonth = firstWeekday - 1
        
        // カレンダーの開始日
        guard let startDate = calendar.date(byAdding: .day, value: -daysFromPreviousMonth, to: startOfMonth) else { return [] }
        
        // 合計42日分（6週分）を生成して常にカレンダーの枠を一定にする
        var days: [Date] = []
        for i in 0..<42 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }
        
        return days
    }
    
    /// 指定した月を移動する
    func moveMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            // 月が切り替わったら選択はリセット
            selectedDate = nil
            selectedDateRecords = []
        }
    }
    
    /// 今月に戻る
    func resetToCurrentMonth() {
        currentMonth = Date()
        selectedDate = nil
        selectedDateRecords = []
    }
    
    /// データを読み込む
    func loadData(modelContext: ModelContext) {
        let calendar = Calendar.current
        
        // アプリ設定の読み込み（目標値）
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        if let settings = try? modelContext.fetch(settingsDescriptor).first {
            dailyGoal = settings.dailyGoal
        }
        
        // 表示範囲（カレンダーの最初の日から最後の日まで）
        let days = calendarDays
        guard let startDate = days.first, let endDate = days.last else { return }
        // 終了日の23:59:59までを含める
        guard let actualEndDate = calendar.date(byAdding: .day, value: 1, to: endDate) else { return }
        
        // レコードを取得
        let predicate = #Predicate<SmokingRecord> { record in
            record.timestamp >= startDate && record.timestamp < actualEndDate
        }
        
        let descriptor = FetchDescriptor<SmokingRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        do {
            let records = try modelContext.fetch(descriptor)
            
            var counts: [Date: Int] = [:]
            var maxCount = 0
            
            // 日ごとに集計
            for record in records {
                let dayStart = calendar.startOfDay(for: record.timestamp)
                counts[dayStart, default: 0] += record.count
            }
            
            self.dailyCounts = counts
            
            // その月の中で最も本数が多い日を見つける（前後の月のはみ出し分は除外）
            let components = calendar.dateComponents([.year, .month], from: currentMonth)
            guard let monthStart = calendar.date(from: components),
                  let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { return }
            
            for (date, count) in counts {
                if date >= monthStart && date <= monthEnd {
                    if count > maxCount {
                        maxCount = count
                    }
                }
            }
            
            // 目標値が設定されている場合は、目標値を基準とする（目標値を超えた場合は赤くするなどの表現のため）
            if let goal = dailyGoal, goal > 0 {
                // 目標値または実際の最大値のどちらか大きい方を使用する
                self.maxCountInMonth = max(maxCount, goal, 1)
            } else {
                self.maxCountInMonth = max(maxCount, 1) // 0除算防止
            }
            
            // 選択中の日付があれば、その日のレコードも更新する
            if let selected = selectedDate {
                loadRecordsForDate(date: selected, records: records)
            }
            
        } catch {
            print("カレンダーデータの取得に失敗しました: \(error)")
        }
    }
    
    /// 特定の日のレコードを読み込む（取得済みの配列からフィルタリング、またはデータベースから取得）
    func selectDate(date: Date, modelContext: ModelContext) {
        selectedDate = date
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }
        
        let predicate = #Predicate<SmokingRecord> { record in
            record.timestamp >= startOfDay && record.timestamp < endOfDay
        }
        
        let descriptor = FetchDescriptor<SmokingRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            selectedDateRecords = try modelContext.fetch(descriptor)
        } catch {
            print("日別レコードの取得に失敗しました: \(error)")
        }
    }
    
    /// すでに取得済みのレコード配列から特定の日のものを抽出
    private func loadRecordsForDate(date: Date, records: [SmokingRecord]) {
        let calendar = Calendar.current
        selectedDateRecords = records.filter {
            calendar.isDate($0.timestamp, inSameDayAs: date)
        }.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    /// 日付が当月かどうかを判定
    func isDateInCurrentMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    /// 日付が今日かどうかを判定
    func isDateToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// 指定された日の喫煙本数を取得
    func countForDate(_ date: Date) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return dailyCounts[startOfDay] ?? 0
    }
    
    /// 指定された日の色（ヒートマップ用）を取得
    func colorForDate(_ date: Date) -> Color {
        let count = countForDate(date)
        
        // 0本ならベースカラー（グレーなど）
        if count == 0 {
            return Color(.systemGray6)
        }
        
        let ratio: Double
        if let goal = dailyGoal, goal > 0 {
            ratio = min(Double(count) / Double(goal), 1.5) / 1.5
        } else {
            ratio = Double(count) / Double(maxCountInMonth)
        }
        
        // Apple Fitnessのような鮮やかでカッコいいグラデーション（青 -> 緑 -> 黄色 -> 赤）
        // Hue 0.6 (青) から 0.0 (赤) へ変化
        let hue = 0.6 * (1.0 - ratio)
        return Color(hue: hue, saturation: 0.9, brightness: 1.0)
    }
    
    /// 指定された日の円のサイズ（0.0 ~ 1.0のスケール）を取得
    func circleScaleForDate(_ date: Date) -> CGFloat {
        let count = countForDate(date)
        
        if count == 0 {
            return 0.0
        }
        
        let minScale: CGFloat = 0.3
        let maxScale: CGFloat = 0.95
        
        if let goal = dailyGoal, goal > 0 {
            // 目標に対する割合（1.5倍で最大サイズとする）
            let ratio = min(Double(count) / Double(goal), 1.5)
            let scale = minScale + (maxScale - minScale) * (ratio / 1.5)
            return min(scale, maxScale)
        } else {
            // 最大値に対する割合
            let ratio = Double(count) / Double(maxCountInMonth)
            let scale = minScale + (maxScale - minScale) * ratio
            return min(max(scale, minScale), maxScale)
        }
    }
}
