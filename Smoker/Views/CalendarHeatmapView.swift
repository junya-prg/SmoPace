//
//  CalendarHeatmapView.swift
//  SmokeCounter
//
//  カレンダーヒートマップビュー
//  月ごとの喫煙本数をヒートマップ形式で表示
//

import SwiftUI
import SwiftData

/// カレンダーヒートマップの全画面ビュー
@available(iOS 26.0, macOS 26.0, *)
struct CalendarHeatmapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CalendarHeatmapViewModel()
    
    // 表示用フォーマッタ
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 今月に戻るボタン
                if !viewModel.isDateInCurrentMonth(Date()) {
                    Button(action: {
                        withAnimation {
                            viewModel.resetToCurrentMonth()
                            viewModel.loadData(modelContext: modelContext)
                        }
                    }) {
                        Text("今月に戻る")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                } else {
                    Spacer().frame(height: 24)
                }
                
                // 曜日ヘッダー
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(weekdaySymbols[index])
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(index == 0 ? .red : (index == 6 ? .blue : .secondary))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // カレンダーグリッド
                let days = viewModel.calendarDays
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(days, id: \.self) { date in
                        CalendarDayCell(
                            date: date,
                            isCurrentMonth: viewModel.isDateInCurrentMonth(date),
                            isToday: viewModel.isDateToday(date),
                            isSelected: viewModel.selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate!),
                            count: viewModel.countForDate(date),
                            color: viewModel.colorForDate(date),
                            scale: viewModel.circleScaleForDate(date)
                        )
                        .onTapGesture {
                            withAnimation {
                                viewModel.selectDate(date: date, modelContext: modelContext)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // 凡例（ヒートマップの説明）
                HeatmapLegendView(dailyGoal: viewModel.dailyGoal)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                
                Divider()
                
                // 選択された日の詳細リスト
                if let selectedDate = viewModel.selectedDate {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(dateFormatter.string(from: selectedDate))
                                .font(.headline)
                            Spacer()
                            Text("合計: \(viewModel.countForDate(selectedDate))本")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(viewModel.dailyGoal != nil && viewModel.countForDate(selectedDate) > viewModel.dailyGoal! ? .red : .primary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        
                        if viewModel.selectedDateRecords.isEmpty {
                            VStack {
                                Spacer().frame(height: 32)
                                Image(systemName: "smoke.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray.opacity(0.3))
                                    .padding(.bottom, 8)
                                Text("記録がありません")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer().frame(height: 32)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(viewModel.selectedDateRecords) { record in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(timeFormatter.string(from: record.timestamp))
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            if let brandName = record.brandName {
                                                Text(brandName)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                Text("未分類")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(record.count)本")
                                            .font(.body)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    
                                    Divider()
                                }
                            }
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    VStack {
                        Spacer().frame(height: 32)
                        Image(systemName: "calendar")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray.opacity(0.3))
                            .padding(.bottom, 8)
                        Text("日付をタップして詳細を表示")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer().frame(height: 32)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle(monthFormatter.string(from: viewModel.currentMonth))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    withAnimation {
                        viewModel.moveMonth(by: -1)
                        viewModel.loadData(modelContext: modelContext)
                    }
                }) {
                    Image(systemName: "chevron.up") // 前の月
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.moveMonth(by: 1)
                        viewModel.loadData(modelContext: modelContext)
                    }
                }) {
                    Image(systemName: "chevron.down") // 次の月
                }
                .disabled(isCurrentMonthMax())
            }
        }
        .onAppear {
            viewModel.loadData(modelContext: modelContext)
        }
    }
    
    // 未来の月には進めないようにする
    private func isCurrentMonthMax() -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(viewModel.currentMonth, equalTo: Date(), toGranularity: .month) && 
               calendar.compare(viewModel.currentMonth, to: Date(), toGranularity: .month) != .orderedAscending
    }
    
    // 日付フォーマッタ
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日(E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    // 時刻フォーマッタ
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

/// カレンダーの日付セル
struct CalendarDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let count: Int
    let color: Color
    let scale: CGFloat
    
    @State private var hasAppeared: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            // 日付テキスト
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 12, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(isToday ? .red : (isCurrentMonth ? .primary : .secondary))
                .frame(width: 22, height: 22)
                .background {
                    if isToday {
                        Circle().stroke(Color.red, lineWidth: 1.5)
                    }
                }
            
            // 円のヒートマップ
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                
                ZStack {
                    if count > 0 && isCurrentMonth {
                        Circle()
                            .fill(fitnessGradient(for: color))
                            // フィットネス風の光沢・シャドウ効果
                            .shadow(color: color.opacity(0.4), radius: 2, x: 0, y: 1)
                            .frame(width: size, height: size)
                            .scaleEffect((hasAppeared && count > 0) ? scale : 0.001) 
                            // 少しゆっくりとした（response: 0.8）アニメーション
                            .animation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0), value: hasAppeared)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0), value: scale)
                    } else if count == 0 && isCurrentMonth {
                        // 0本の場合は小さなグレーのドットのみ表示
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            // 円のエリアを正方形に保ち、画面幅に合わせて最大化する
            .aspectRatio(1.0, contentMode: .fit)
        }
        .padding(.vertical, 4)
        .background {
            // 選択時のみ背景をうっすらハイライト
            if isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            }
        }
        .opacity(isCurrentMonth ? 1.0 : 0.4)
        .onAppear {
            if isCurrentMonth {
                // 初期描画後にスケールアニメーションを発火させる
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    hasAppeared = true
                }
            }
        }
    }
    
    // Apple Fitness風のグラデーションを作成
    private func fitnessGradient(for baseColor: Color) -> LinearGradient {
        return LinearGradient(
            colors: [baseColor.opacity(0.6), baseColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// ヒートマップの凡例
struct HeatmapLegendView: View {
    let dailyGoal: Int?
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 6, height: 6)
            
            Circle()
                .fill(fitnessGradient(for: Color(hue: 0.6, saturation: 0.9, brightness: 1.0))) // Blue
                .frame(width: 8, height: 8)
            
            Circle()
                .fill(fitnessGradient(for: Color(hue: 0.45, saturation: 0.9, brightness: 1.0))) // Cyan
                .frame(width: 11, height: 11)
            
            Circle()
                .fill(fitnessGradient(for: Color(hue: 0.3, saturation: 0.9, brightness: 1.0))) // Green
                .frame(width: 14, height: 14)
            
            Circle()
                .fill(fitnessGradient(for: Color(hue: 0.15, saturation: 0.9, brightness: 1.0))) // Yellow
                .frame(width: 17, height: 17)
            
            Circle()
                .fill(fitnessGradient(for: Color(hue: 0.07, saturation: 0.9, brightness: 1.0))) // Orange
                .frame(width: 20, height: 20)
                
            Circle()
                .fill(fitnessGradient(for: Color(hue: 0.0, saturation: 0.9, brightness: 1.0))) // Red
                .frame(width: 24, height: 24)
        }
        .frame(height: 24)
    }
    
    private func fitnessGradient(for baseColor: Color) -> LinearGradient {
        return LinearGradient(
            colors: [baseColor.opacity(0.6), baseColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
#Preview {
    NavigationStack {
        CalendarHeatmapView()
            .modelContainer(for: [SmokingRecord.self, AppSettings.self], inMemory: true)
    }
}
