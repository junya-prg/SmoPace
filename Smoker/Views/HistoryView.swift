//
//  HistoryView.swift
//  SmokeCounter
//
//  履歴画面 - 今日の記録一覧
//

import SwiftUI
import SwiftData

/// 履歴画面
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todayRecords: [SmokingRecord]
    
    init() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        
        _todayRecords = Query(
            filter: #Predicate<SmokingRecord> { record in
                record.timestamp >= startOfToday && record.timestamp < endOfToday
            },
            sort: [SortDescriptor(\SmokingRecord.timestamp, order: .reverse)]
        )
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if todayRecords.isEmpty {
                    ContentUnavailableView(
                        "記録がありません",
                        systemImage: "list.bullet.clipboard",
                        description: Text("今日の記録がまだありません")
                    )
                } else {
                    List {
                        ForEach(todayRecords) { record in
                            HistoryRowView(record: record, previousRecord: previousRecord(for: record))
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("今日の履歴")
            .toolbar {
                if !todayRecords.isEmpty {
                    EditButton()
                }
            }
        }
    }
    
    /// 指定した記録の前の記録を取得
    private func previousRecord(for record: SmokingRecord) -> SmokingRecord? {
        guard let index = todayRecords.firstIndex(where: { $0.id == record.id }),
              index + 1 < todayRecords.count else {
            return nil
        }
        return todayRecords[index + 1]
    }
    
    /// 記録を削除
    private func deleteRecords(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(todayRecords[index])
        }
        
        do {
            try modelContext.save()
        } catch {
            print("記録の削除に失敗しました: \(error)")
        }
    }
}

/// 履歴行ビュー
struct HistoryRowView: View {
    let record: SmokingRecord
    let previousRecord: SmokingRecord?
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    /// 前回からの経過時間
    private var intervalText: String? {
        guard let previous = previousRecord else { return nil }
        let interval = record.timestamp.timeIntervalSince(previous.timestamp)
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "+\(hours)時間\(minutes)分"
        } else {
            return "+\(minutes)分"
        }
    }
    
    var body: some View {
        HStack {
            // 時刻
            Text(timeFormatter.string(from: record.timestamp))
                .font(.headline)
                .monospacedDigit()
            
            Spacer()
            
            // 前回からの経過時間
            if let interval = intervalText {
                Text(interval)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SmokingRecord.self, inMemory: true)
}
