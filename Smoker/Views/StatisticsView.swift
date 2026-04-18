//
//  StatisticsView.swift
//  SmokeCounter
//
//  統計画面 - ヘルスケアアプリ風UI
//  日/週/月/年の切り替え、スワイプページング、アニメーション付きグラフ
//

import SwiftUI
import SwiftData
import Charts

/// 統計期間
enum StatisticsPeriod: String, CaseIterable {
    case day = "日"
    case week = "週"
    case month = "月"
    case year = "年"
    
    var displayName: String { rawValue }
}

/// 銘柄別のカウント情報（統計用）
struct BrandStatData: Identifiable, Equatable {
    let id: UUID?  // nilは未分類
    let name: String
    var count: Int
    var amount: Decimal
    let color: Color
    
    static func == (lhs: BrandStatData, rhs: BrandStatData) -> Bool {
        lhs.id == rhs.id && lhs.count == rhs.count
    }
}

/// 統計画面
struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPeriod: StatisticsPeriod = .week
    @State private var pageIndex: Int = 0  // 現在のページ（0が最新）
    @State private var allBrands: [CigaretteBrand] = []
    @State private var dailyGoal: Int? = nil
    @State private var chartData: [ChartDataPoint] = []
    @State private var selectedBar: ChartDataPoint? = nil
    @State private var animateChart: Bool = false
    @State private var brandSummary: [BrandStatData] = []
    @State private var totalAmount: Decimal = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 期間選択セグメント
                    Picker("期間", selection: $selectedPeriod) {
                        ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 期間タイトル
                    PeriodHeaderView(
                        period: selectedPeriod,
                        pageIndex: pageIndex
                    )
                    
                    // グラフ部分のみスワイプ可能
                    SwipeableChartContainer(
                        period: selectedPeriod,
                        pageIndex: $pageIndex,
                        chartData: chartData,
                        selectedBar: $selectedBar,
                        animateChart: animateChart,
                        dailyGoal: dailyGoal,
                        allBrands: allBrands
                    )
                    .frame(height: 280)
                    .padding(.horizontal)
                    
                    // 選択した棒の詳細
                    if let selected = selectedBar {
                        SelectedBarDetailView(
                            dataPoint: selected,
                            period: selectedPeriod
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // サマリー（値だけがアニメーションで変化）
                    StatisticsSummaryView(
                        data: chartData,
                        brandSummary: brandSummary,
                        totalAmount: totalAmount,
                        dailyGoal: dailyGoal
                    )
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.3), value: chartData.map { $0.count })
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) {
                if AdConfiguration.showBannerInStatistics {
                    BannerAdView()
                }
            }
            .navigationTitle("統計")
            .onAppear {
                loadSettings()
                loadChartData()
                triggerAnimation()
            }
            .onChange(of: selectedPeriod) { _, _ in
                pageIndex = 0
                selectedBar = nil
                animateChart = false
                loadChartData()
                triggerAnimation()
            }
            .onChange(of: pageIndex) { _, _ in
                selectedBar = nil
                animateChart = false
                loadChartData()
                triggerAnimation()
            }
        }
    }
    
    /// アニメーションを開始
    private func triggerAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.6)) {
                animateChart = true
            }
        }
    }
    
    /// 設定を読み込む
    private func loadSettings() {
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        do {
            if let settings = try modelContext.fetch(settingsDescriptor).first {
                dailyGoal = settings.dailyGoal
            }
            
            // 全銘柄を取得
            let brandsDescriptor = FetchDescriptor<CigaretteBrand>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            allBrands = try modelContext.fetch(brandsDescriptor)
        } catch {
            print("設定の取得に失敗しました: \(error)")
        }
    }
    
    /// チャートデータを読み込む
    private func loadChartData() {
        let calendar = Calendar.current
        let today = Date()
        
        let (startDate, endDate) = calculateDateRange(for: selectedPeriod, offset: pageIndex, calendar: calendar, from: today)
        
        let predicate = #Predicate<SmokingRecord> { record in
            record.timestamp >= startDate && record.timestamp < endDate
        }
        
        let descriptor = FetchDescriptor<SmokingRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        do {
            let records = try modelContext.fetch(descriptor)
            chartData = aggregateData(records: records, period: selectedPeriod, startDate: startDate, endDate: endDate)
            
            // 銘柄別サマリーを計算
            calculateBrandSummary(records: records)
        } catch {
            print("データの取得に失敗しました: \(error)")
            chartData = []
            brandSummary = []
            totalAmount = 0
        }
    }
    
    /// 銘柄別サマリーを計算
    private func calculateBrandSummary(records: [SmokingRecord]) {
        var brandDict: [UUID: (count: Int, amount: Decimal, name: String)] = [:]
        var unclassifiedCount = 0
        var unclassifiedAmount: Decimal = 0
        var total: Decimal = 0
        
        for record in records {
            total += record.amount
            
            if let brandId = record.brandId {
                let existing = brandDict[brandId] ?? (count: 0, amount: 0, name: record.brandName ?? "不明")
                brandDict[brandId] = (
                    count: existing.count + record.count,
                    amount: existing.amount + record.amount,
                    name: record.brandName ?? existing.name
                )
            } else {
                unclassifiedCount += record.count
                unclassifiedAmount += record.amount
            }
        }
        
        totalAmount = total
        
        // BrandStatDataの配列を作成
        var summary: [BrandStatData] = []
        
        // 登録されている銘柄のデータを追加
        for brand in allBrands {
            if let data = brandDict[brand.id] {
                summary.append(BrandStatData(
                    id: brand.id,
                    name: brand.name,
                    count: data.count,
                    amount: data.amount,
                    color: brandColor(for: brand.id)
                ))
            }
        }
        
        // 削除された銘柄のデータも追加（brandDictにあるがallBrandsにない）
        for (brandId, data) in brandDict {
            if !allBrands.contains(where: { $0.id == brandId }) {
                summary.append(BrandStatData(
                    id: brandId,
                    name: data.name,
                    count: data.count,
                    amount: data.amount,
                    color: .gray
                ))
            }
        }
        
        // 未分類のデータを追加
        if unclassifiedCount > 0 {
            summary.append(BrandStatData(
                id: nil,
                name: "未分類",
                count: unclassifiedCount,
                amount: unclassifiedAmount,
                color: .gray.opacity(0.6)
            ))
        }
        
        // カウント順にソート
        brandSummary = summary.sorted { $0.count > $1.count }
    }
    
    /// 銘柄IDに基づいて色を返す（allBrands内のインデックスで決定し、衝突を防ぐ）
    private func brandColor(for id: UUID) -> Color {
        let colors: [Color] = [.orange, .green, .purple, .pink, .cyan, .indigo, .mint, .teal]
        if let brandIndex = allBrands.firstIndex(where: { $0.id == id }) {
            return colors[brandIndex % colors.count]
        }
        // allBrandsに存在しない（削除済み）銘柄はhashValueでフォールバック
        let index = abs(id.hashValue) % colors.count
        return colors[index]
    }
    
    /// 期間に応じた日付範囲を計算
    private func calculateDateRange(for period: StatisticsPeriod, offset: Int, calendar: Calendar, from today: Date) -> (Date, Date) {
        switch period {
        case .day:
            let targetDate = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let startOfDay = calendar.startOfDay(for: targetDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return (startOfDay, endOfDay)
            
        case .week:
            let currentWeekday = calendar.component(.weekday, from: today)
            let daysToSunday = currentWeekday - 1
            let thisSunday = calendar.date(byAdding: .day, value: -daysToSunday, to: calendar.startOfDay(for: today)) ?? today
            let targetSunday = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisSunday) ?? thisSunday
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: targetSunday) ?? targetSunday
            return (targetSunday, endOfWeek)
            
        case .month:
            let components = calendar.dateComponents([.year, .month], from: today)
            let thisMonthStart = calendar.date(from: components) ?? today
            let targetMonthStart = calendar.date(byAdding: .month, value: -offset, to: thisMonthStart) ?? thisMonthStart
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: targetMonthStart) ?? targetMonthStart
            return (targetMonthStart, endOfMonth)
            
        case .year:
            let components = calendar.dateComponents([.year], from: today)
            let thisYearStart = calendar.date(from: components) ?? today
            let targetYearStart = calendar.date(byAdding: .year, value: -offset, to: thisYearStart) ?? thisYearStart
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: targetYearStart) ?? targetYearStart
            return (targetYearStart, endOfYear)
        }
    }
    
    /// データを集計
    private func aggregateData(records: [SmokingRecord], period: StatisticsPeriod, startDate: Date, endDate: Date) -> [ChartDataPoint] {
        let calendar = Calendar.current
        var result: [ChartDataPoint] = []
        
        switch period {
        case .day:
            // 時間別累積（折れ線グラフ用）
            var cumulative = 0
            for hour in 0..<24 {
                guard let hourStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startDate) else { continue }
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
                
                let hourRecords = records.filter { record in
                    record.timestamp >= hourStart && record.timestamp < hourEnd
                }
                let count = hourRecords.reduce(0) { $0 + $1.count }
                
                cumulative += count
                
                result.append(ChartDataPoint(
                    date: hourStart,
                    count: cumulative,
                    rawCount: count,
                    label: "\(hour)",
                    brandSegments: aggregateBrandSegments(records: hourRecords)
                ))
            }
            
        case .week:
            for i in 0..<7 {
                guard let dayStart = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                
                let dayRecords = records.filter { record in
                    record.timestamp >= dayStart && record.timestamp < dayEnd
                }
                let count = dayRecords.reduce(0) { $0 + $1.count }
                
                let weekday = calendar.component(.weekday, from: dayStart)
                let weekdaySymbols = calendar.shortWeekdaySymbols
                let label = weekdaySymbols[weekday - 1]
                
                result.append(ChartDataPoint(
                    date: dayStart,
                    count: count,
                    rawCount: count,
                    label: label,
                    brandSegments: aggregateBrandSegments(records: dayRecords)
                ))
            }
            
        case .month:
            let daysInMonth = calendar.range(of: .day, in: .month, for: startDate)?.count ?? 30
            for i in 0..<daysInMonth {
                guard let dayStart = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                
                let dayRecords = records.filter { record in
                    record.timestamp >= dayStart && record.timestamp < dayEnd
                }
                let count = dayRecords.reduce(0) { $0 + $1.count }
                
                let day = calendar.component(.day, from: dayStart)
                
                result.append(ChartDataPoint(
                    date: dayStart,
                    count: count,
                    rawCount: count,
                    label: "\(day)",
                    brandSegments: aggregateBrandSegments(records: dayRecords)
                ))
            }
            
        case .year:
            for i in 0..<12 {
                guard let monthStart = calendar.date(byAdding: .month, value: i, to: startDate) else { continue }
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                
                let monthRecords = records.filter { record in
                    record.timestamp >= monthStart && record.timestamp < monthEnd
                }
                let count = monthRecords.reduce(0) { $0 + $1.count }
                
                let month = calendar.component(.month, from: monthStart)
                
                result.append(ChartDataPoint(
                    date: monthStart,
                    count: count,
                    rawCount: count,
                    label: "\(month)月",
                    brandSegments: aggregateBrandSegments(records: monthRecords)
                ))
            }
        }
        
        return result
    }
    
    /// レコードから銘柄別セグメントを集計
    private func aggregateBrandSegments(records: [SmokingRecord]) -> [BrandSegment] {
        var brandDict: [UUID: (count: Int, name: String)] = [:]
        var unclassifiedCount = 0
        
        for record in records {
            if let brandId = record.brandId {
                let existing = brandDict[brandId] ?? (count: 0, name: record.brandName ?? "不明")
                brandDict[brandId] = (
                    count: existing.count + record.count,
                    name: record.brandName ?? existing.name
                )
            } else {
                unclassifiedCount += record.count
            }
        }
        
        var segments: [BrandSegment] = []
        
        // 登録されている銘柄順にセグメントを追加
        for brand in allBrands {
            if let data = brandDict[brand.id] {
                segments.append(BrandSegment(
                    id: brand.id,
                    name: brand.name,
                    count: data.count,
                    color: brandColor(for: brand.id)
                ))
            }
        }
        
        // 削除された銘柄のデータも追加
        for (brandId, data) in brandDict {
            if !allBrands.contains(where: { $0.id == brandId }) {
                segments.append(BrandSegment(
                    id: brandId,
                    name: data.name,
                    count: data.count,
                    color: .gray
                ))
            }
        }
        
        // 未分類を追加
        if unclassifiedCount > 0 {
            segments.append(BrandSegment(
                id: nil,
                name: "未分類",
                count: unclassifiedCount,
                color: .gray.opacity(0.6)
            ))
        }
        
        return segments
    }
}

/// 銘柄別カウント（グラフ用）
struct BrandSegment: Identifiable, Equatable {
    let id: UUID?  // nilは未分類
    let name: String
    let count: Int
    let color: Color
    
    static func == (lhs: BrandSegment, rhs: BrandSegment) -> Bool {
        lhs.id == rhs.id && lhs.count == rhs.count
    }
}

/// グラフデータポイント
struct ChartDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let count: Int      // 表示用（日の場合は累積）
    let rawCount: Int   // その時間帯の実際の本数
    let label: String
    var brandSegments: [BrandSegment] = []  // 銘柄別の内訳
    
    static func == (lhs: ChartDataPoint, rhs: ChartDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

/// スワイプ可能なグラフコンテナ
struct SwipeableChartContainer: View {
    let period: StatisticsPeriod
    @Binding var pageIndex: Int
    let chartData: [ChartDataPoint]
    @Binding var selectedBar: ChartDataPoint?
    let animateChart: Bool
    let dailyGoal: Int?
    var allBrands: [CigaretteBrand] = []
    
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false
    private let maxPages = 52
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // グラフ表示
                if period == .day {
                    CumulativeLineChartView(
                        data: chartData,
                        selectedPoint: $selectedBar,
                        animate: animateChart,
                        dailyGoal: dailyGoal
                    )
                } else {
                    StackedBarChartView(
                        data: chartData,
                        period: period,
                        selectedBar: $selectedBar,
                        animate: animateChart,
                        dailyGoal: dailyGoal,
                        allBrands: allBrands
                    )
                }
            }
            .offset(x: dragOffset)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture()
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        // 水平方向のドラッグのみ処理
                        if abs(value.translation.width) > abs(value.translation.height) {
                            dragOffset = value.translation.width * 0.5
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            // 左スワイプで最新へ（pageIndex減少）
                            if value.translation.width < -threshold && pageIndex > 0 {
                                pageIndex -= 1
                            }
                            // 右スワイプで過去へ（pageIndex増加）
                            else if value.translation.width > threshold && pageIndex < maxPages - 1 {
                                pageIndex += 1
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
    }
}

/// 期間ヘッダービュー
struct PeriodHeaderView: View {
    let period: StatisticsPeriod
    let pageIndex: Int
    
    private var periodText: String {
        let calendar = Calendar.current
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        
        switch period {
        case .day:
            let targetDate = calendar.date(byAdding: .day, value: -pageIndex, to: today) ?? today
            dateFormatter.dateFormat = "M月d日(E)"
            return dateFormatter.string(from: targetDate)
            
        case .week:
            let currentWeekday = calendar.component(.weekday, from: today)
            let daysToSunday = currentWeekday - 1
            let thisSunday = calendar.date(byAdding: .day, value: -daysToSunday, to: calendar.startOfDay(for: today)) ?? today
            let targetSunday = calendar.date(byAdding: .weekOfYear, value: -pageIndex, to: thisSunday) ?? thisSunday
            let targetSaturday = calendar.date(byAdding: .day, value: 6, to: targetSunday) ?? targetSunday
            
            dateFormatter.dateFormat = "M/d"
            let startStr = dateFormatter.string(from: targetSunday)
            let endStr = dateFormatter.string(from: targetSaturday)
            return "\(startStr) - \(endStr)"
            
        case .month:
            let components = calendar.dateComponents([.year, .month], from: today)
            let thisMonthStart = calendar.date(from: components) ?? today
            let targetMonth = calendar.date(byAdding: .month, value: -pageIndex, to: thisMonthStart) ?? thisMonthStart
            
            dateFormatter.dateFormat = "yyyy年M月"
            return dateFormatter.string(from: targetMonth)
            
        case .year:
            let components = calendar.dateComponents([.year], from: today)
            let thisYearStart = calendar.date(from: components) ?? today
            let targetYear = calendar.date(byAdding: .year, value: -pageIndex, to: thisYearStart) ?? thisYearStart
            
            dateFormatter.dateFormat = "yyyy年"
            return dateFormatter.string(from: targetYear)
        }
    }
    
    var body: some View {
        HStack {
            if pageIndex < 51 {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundStyle(.clear)
            }
            
            Spacer()
            
            Text(periodText)
                .font(.headline)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: periodText)
            
            Spacer()
            
            if pageIndex > 0 {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.clear)
            }
        }
        .padding(.horizontal, 24)
    }
}

/// 目標ラインビュー（共通コンポーネント）
struct GoalLineView: View {
    let goal: Int
    let effectiveMax: Int
    let chartHeight: CGFloat
    let chartWidth: CGFloat
    var labelText: String = "目標"
    
    private var goalY: CGFloat {
        let goalRatio = CGFloat(goal) / CGFloat(effectiveMax)
        return chartHeight * (1 - goalRatio)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 破線
            Path { path in
                path.move(to: CGPoint(x: 0, y: goalY))
                path.addLine(to: CGPoint(x: chartWidth, y: goalY))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            .foregroundStyle(.red.opacity(0.7))
            
            // ラベル
            Text(labelText)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.red)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(4)
                .offset(x: 4, y: goalY - 8)
        }
        .frame(width: chartWidth, height: chartHeight, alignment: .topLeading)
    }
}

/// 累積折れ線グラフ（日表示用）
struct CumulativeLineChartView: View {
    let data: [ChartDataPoint]
    @Binding var selectedPoint: ChartDataPoint?
    let animate: Bool
    let dailyGoal: Int?
    
    private var maxCount: Int {
        let dataMax = data.map { $0.count }.max() ?? 0
        // 目標値も考慮して最大値を決定
        if let goal = dailyGoal {
            return max(dataMax, goal, 1)
        }
        return max(dataMax, 1)
    }
    
    /// Y軸の目盛り値を計算
    private var yAxisValues: [Int] {
        let step = calculateStep(for: maxCount)
        var values: [Int] = []
        var current = 0
        while current <= maxCount {
            values.append(current)
            current += step
        }
        // 最後の値がmaxCountを超えていたら追加
        if values.last ?? 0 < maxCount {
            values.append(current)
        }
        return values
    }
    
    /// 適切なステップ値を計算
    private func calculateStep(for max: Int) -> Int {
        if max <= 5 { return 1 }
        if max <= 10 { return 2 }
        if max <= 20 { return 5 }
        if max <= 50 { return 10 }
        if max <= 100 { return 20 }
        return 50
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Y軸ラベル
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(yAxisValues.reversed(), id: \.self) { value in
                    Text("\(value)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 30)
            
            // グラフ本体
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height - 30
                let effectiveMax = yAxisValues.last ?? maxCount
                
                ZStack {
                    // グリッドライン
                    VStack(spacing: 0) {
                        ForEach(yAxisValues.reversed(), id: \.self) { value in
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 1)
                            if value != yAxisValues.first {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: height)
                    .padding(.bottom, 30)
                    
                    // 折れ線グラフ
                    if !data.isEmpty {
                        // エリア（塗りつぶし）
                        Path { path in
                            let stepX = width / CGFloat(max(data.count - 1, 1))
                            
                            path.move(to: CGPoint(x: 0, y: height))
                            
                            for (index, point) in data.enumerated() {
                                let x = CGFloat(index) * stepX
                                let ratio = animate ? CGFloat(point.count) / CGFloat(effectiveMax) : 0
                                let y = height - (ratio * height)
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            
                            path.addLine(to: CGPoint(x: width, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .animation(.easeOut(duration: 0.8), value: animate)
                        
                        // ライン
                        Path { path in
                            let stepX = width / CGFloat(max(data.count - 1, 1))
                            
                            for (index, point) in data.enumerated() {
                                let x = CGFloat(index) * stepX
                                let ratio = animate ? CGFloat(point.count) / CGFloat(effectiveMax) : 0
                                let y = height - (ratio * height)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .animation(.easeOut(duration: 0.8), value: animate)
                        
                        // 選択ポイントの表示
                        if let selected = selectedPoint,
                           let index = data.firstIndex(where: { $0.id == selected.id }) {
                            let stepX = width / CGFloat(max(data.count - 1, 1))
                            let x = CGFloat(index) * stepX
                            let ratio = CGFloat(selected.count) / CGFloat(effectiveMax)
                            let y = height - (ratio * height)
                            
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .fill(.blue)
                                        .frame(width: 8, height: 8)
                                )
                                .shadow(color: .blue.opacity(0.5), radius: 4)
                                .position(x: x, y: y)
                                .animation(.spring(response: 0.2), value: selected.id)
                        }
                    }
                    
                    // タップ用の透明なレイヤー
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                            let index = Int(round(location.x / stepX))
                            let clampedIndex = max(0, min(data.count - 1, index))
                            
                            withAnimation(.spring(response: 0.2)) {
                                if selectedPoint?.id == data[clampedIndex].id {
                                    selectedPoint = nil
                                } else {
                                    selectedPoint = data[clampedIndex]
                                }
                            }
                        }
                    
                    // 目標ライン（折れ線グラフの上に表示）
                    if let goal = dailyGoal, goal > 0 {
                        GoalLineView(
                            goal: goal,
                            effectiveMax: effectiveMax,
                            chartHeight: height,
                            chartWidth: width
                        )
                    }
                    
                    // X軸ラベル
                    HStack(spacing: 0) {
                        ForEach([0, 6, 12, 18, 23], id: \.self) { hour in
                            if hour > 0 {
                                Spacer()
                            }
                            Text("\(hour)時")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

/// 積み上げ棒グラフ（銘柄別）
struct StackedBarChartView: View {
    let data: [ChartDataPoint]
    let period: StatisticsPeriod
    @Binding var selectedBar: ChartDataPoint?
    let animate: Bool
    let dailyGoal: Int?
    var allBrands: [CigaretteBrand] = []
    
    /// 期間に応じた目標値を計算
    private var periodGoal: Int? {
        guard let goal = dailyGoal else { return nil }
        switch period {
        case .day:
            return goal
        case .week:
            return goal  // 1日あたりの目標
        case .month:
            return goal  // 1日あたりの目標
        case .year:
            return goal * 30  // 月あたりの目標（日目標×30日）
        }
    }
    
    private var maxCount: Int {
        let dataMax = data.map { $0.count }.max() ?? 0
        // 目標値も考慮して最大値を決定
        if let goal = periodGoal {
            return max(dataMax, goal, 1)
        }
        return max(dataMax, 1)
    }
    
    /// Y軸の目盛り値を計算
    private var yAxisValues: [Int] {
        let step = calculateStep(for: maxCount)
        var values: [Int] = []
        var current = 0
        while current <= maxCount {
            values.append(current)
            current += step
        }
        if values.last ?? 0 < maxCount {
            values.append(current)
        }
        return values
    }
    
    private func calculateStep(for max: Int) -> Int {
        if max <= 5 { return 1 }
        if max <= 10 { return 2 }
        if max <= 20 { return 5 }
        if max <= 50 { return 10 }
        if max <= 100 { return 20 }
        return 50
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Y軸ラベル
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(yAxisValues.reversed(), id: \.self) { value in
                    Text("\(value)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 30)
            
            // グラフ本体
            GeometryReader { geometry in
                let barWidth = calculateBarWidth(totalWidth: geometry.size.width)
                let spacing = calculateSpacing(totalWidth: geometry.size.width, barWidth: barWidth)
                let effectiveMax = yAxisValues.last ?? maxCount
                let chartHeight = geometry.size.height - 24
                
                ZStack(alignment: .bottom) {
                    // グリッドライン
                    VStack(spacing: 0) {
                        ForEach(yAxisValues.reversed(), id: \.self) { value in
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 1)
                            if value != yAxisValues.first {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: chartHeight)
                    .padding(.bottom, 24)
                    
                    // 目標ライン（全期間で表示）
                    if let goal = periodGoal, goal > 0 {
                        GoalLineView(
                            goal: goal,
                            effectiveMax: effectiveMax,
                            chartHeight: chartHeight,
                            chartWidth: geometry.size.width,
                            labelText: period == .year ? "目標/月" : "目標"
                        )
                        .padding(.bottom, 24)
                    }
                    
                    // 積み上げ棒グラフ
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(data) { item in
                            VStack(spacing: 4) {
                                StackedBarView(
                                    segments: item.brandSegments,
                                    totalCount: item.count,
                                    maxCount: effectiveMax,
                                    maxHeight: chartHeight,
                                    width: barWidth,
                                    isSelected: selectedBar?.id == item.id,
                                    animate: animate,
                                    isOverGoal: periodGoal != nil && item.count > (periodGoal ?? 0)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedBar?.id == item.id {
                                            selectedBar = nil
                                        } else {
                                            selectedBar = item
                                        }
                                    }
                                }
                                
                                Text(displayLabel(for: item))
                                    .font(.system(size: labelFontSize))
                                    .foregroundStyle(selectedBar?.id == item.id ? .blue : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(height: 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
    
    private func displayLabel(for item: ChartDataPoint) -> String {
        if period == .month {
            if let day = Int(item.label), day % 5 == 1 || day == 1 {
                return item.label
            }
            return ""
        }
        return item.label
    }
    
    private var labelFontSize: CGFloat {
        switch period {
        case .day: return 8
        case .week: return 11
        case .month: return 8
        case .year: return 10
        }
    }
    
    private func calculateBarWidth(totalWidth: CGFloat) -> CGFloat {
        let count = CGFloat(max(data.count, 1))
        let availableWidth = totalWidth - 16
        let minSpacing: CGFloat = period == .month ? 1 : 4
        return max((availableWidth - (count - 1) * minSpacing) / count, 4)
    }
    
    private func calculateSpacing(totalWidth: CGFloat, barWidth: CGFloat) -> CGFloat {
        let count = CGFloat(max(data.count, 1))
        let availableWidth = totalWidth - 16
        return max((availableWidth - count * barWidth) / max(count - 1, 1), 1)
    }
}

/// 積み上げ棒グラフの1本
struct StackedBarView: View {
    let segments: [BrandSegment]
    let totalCount: Int
    let maxCount: Int
    let maxHeight: CGFloat
    let width: CGFloat
    let isSelected: Bool
    let animate: Bool
    var isOverGoal: Bool = false
    
    private var totalHeight: CGFloat {
        guard maxCount > 0 else { return 0 }
        let ratio = CGFloat(totalCount) / CGFloat(maxCount)
        return max(ratio * maxHeight, totalCount > 0 ? 4 : 0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if segments.isEmpty {
                // セグメントがない場合は単色の棒
                RoundedRectangle(cornerRadius: width / 3)
                    .fill(
                        LinearGradient(
                            colors: isOverGoal ? [.red, .red.opacity(0.7)] : [.blue.opacity(0.8), .blue.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: animate ? totalHeight : 0)
                    // 高さのみアニメーション（fillの後ではなくframeの後に付けることで色はアニメーション対象外）
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animate)
            } else {
                // 銘柄別に積み上げ
                ForEach(segments.reversed()) { segment in
                    let segmentHeight = totalCount > 0 ? (CGFloat(segment.count) / CGFloat(totalCount)) * totalHeight : 0
                    
                    Rectangle()
                        .fill(segment.color)  // 色はアニメーション対象外（即座に反映）
                        .frame(width: width, height: animate ? segmentHeight : 0)
                        // 高さのみアニメーション
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animate)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: width / 3))
        .shadow(color: isSelected ? (isOverGoal ? Color.red : Color.blue).opacity(0.5) : .clear, radius: 4, x: 0, y: 2)
        // VStack全体にanimationを付けると色もアニメーション対象になるため削除
    }
}

/// アニメーション付き棒グラフ（旧バージョン、互換性のため残す）
struct AnimatedBarChartView: View {
    let data: [ChartDataPoint]
    let period: StatisticsPeriod
    @Binding var selectedBar: ChartDataPoint?
    let animate: Bool
    let dailyGoal: Int?
    
    /// 期間に応じた目標値を計算
    private var periodGoal: Int? {
        guard let goal = dailyGoal else { return nil }
        switch period {
        case .day:
            return goal
        case .week:
            return goal  // 1日あたりの目標
        case .month:
            return goal  // 1日あたりの目標
        case .year:
            return goal * 30  // 月あたりの目標（日目標×30日）
        }
    }
    
    private var maxCount: Int {
        let dataMax = data.map { $0.count }.max() ?? 0
        // 目標値も考慮して最大値を決定
        if let goal = periodGoal {
            return max(dataMax, goal, 1)
        }
        return max(dataMax, 1)
    }
    
    /// Y軸の目盛り値を計算
    private var yAxisValues: [Int] {
        let step = calculateStep(for: maxCount)
        var values: [Int] = []
        var current = 0
        while current <= maxCount {
            values.append(current)
            current += step
        }
        if values.last ?? 0 < maxCount {
            values.append(current)
        }
        return values
    }
    
    private func calculateStep(for max: Int) -> Int {
        if max <= 5 { return 1 }
        if max <= 10 { return 2 }
        if max <= 20 { return 5 }
        if max <= 50 { return 10 }
        if max <= 100 { return 20 }
        return 50
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Y軸ラベル
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(yAxisValues.reversed(), id: \.self) { value in
                    Text("\(value)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 30)
            
            // グラフ本体
            GeometryReader { geometry in
                let barWidth = calculateBarWidth(totalWidth: geometry.size.width)
                let spacing = calculateSpacing(totalWidth: geometry.size.width, barWidth: barWidth)
                let effectiveMax = yAxisValues.last ?? maxCount
                let chartHeight = geometry.size.height - 24
                
                ZStack(alignment: .bottom) {
                    // グリッドライン
                    VStack(spacing: 0) {
                        ForEach(yAxisValues.reversed(), id: \.self) { value in
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 1)
                            if value != yAxisValues.first {
                                Spacer()
                            }
                        }
                    }
                    .frame(height: chartHeight)
                    .padding(.bottom, 24)
                    
                    // 目標ライン（全期間で表示）
                    if let goal = periodGoal, goal > 0 {
                        GoalLineView(
                            goal: goal,
                            effectiveMax: effectiveMax,
                            chartHeight: chartHeight,
                            chartWidth: geometry.size.width,
                            labelText: period == .year ? "目標/月" : "目標"
                        )
                        .padding(.bottom, 24)
                    }
                    
                    // 棒グラフ
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(data) { item in
                            VStack(spacing: 4) {
                                BarView(
                                    count: item.count,
                                    maxCount: effectiveMax,
                                    maxHeight: chartHeight,
                                    width: barWidth,
                                    isSelected: selectedBar?.id == item.id,
                                    animate: animate,
                                    isOverGoal: periodGoal != nil && item.count > (periodGoal ?? 0)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedBar?.id == item.id {
                                            selectedBar = nil
                                        } else {
                                            selectedBar = item
                                        }
                                    }
                                }
                                
                                Text(displayLabel(for: item))
                                    .font(.system(size: labelFontSize))
                                    .foregroundStyle(selectedBar?.id == item.id ? .blue : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(height: 16)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
    
    private func displayLabel(for item: ChartDataPoint) -> String {
        if period == .month {
            if let day = Int(item.label), day % 5 == 1 || day == 1 {
                return item.label
            }
            return ""
        }
        return item.label
    }
    
    private var labelFontSize: CGFloat {
        switch period {
        case .day: return 8
        case .week: return 11
        case .month: return 8
        case .year: return 10
        }
    }
    
    private func calculateBarWidth(totalWidth: CGFloat) -> CGFloat {
        let count = CGFloat(max(data.count, 1))
        let availableWidth = totalWidth - 16
        let minSpacing: CGFloat = period == .month ? 1 : 4
        return max((availableWidth - (count - 1) * minSpacing) / count, 4)
    }
    
    private func calculateSpacing(totalWidth: CGFloat, barWidth: CGFloat) -> CGFloat {
        let count = CGFloat(max(data.count, 1))
        let availableWidth = totalWidth - 16
        return max((availableWidth - count * barWidth) / max(count - 1, 1), 1)
    }
}

/// 棒グラフの1本
struct BarView: View {
    let count: Int
    let maxCount: Int
    let maxHeight: CGFloat
    let width: CGFloat
    let isSelected: Bool
    let animate: Bool
    var isOverGoal: Bool = false
    
    private var barHeight: CGFloat {
        guard maxCount > 0 else { return 0 }
        let ratio = CGFloat(count) / CGFloat(maxCount)
        return max(ratio * maxHeight, count > 0 ? 4 : 0)
    }
    
    private var barColors: [Color] {
        if isOverGoal {
            return isSelected ? [.red, .red.opacity(0.7)] : [.red.opacity(0.8), .red.opacity(0.5)]
        }
        return isSelected ? [.blue, .blue.opacity(0.7)] : [.blue.opacity(0.8), .blue.opacity(0.5)]
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: width / 3)
            .fill(
                LinearGradient(
                    colors: barColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            // 高さのみアニメーション（fillの後ではなくframeの後に付けることで色はアニメーション対象外）
            .frame(width: width, height: animate ? barHeight : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animate)
            .shadow(color: isSelected ? (isOverGoal ? Color.red : Color.blue).opacity(0.5) : .clear, radius: 4, x: 0, y: 2)
    }
}

/// 選択した棒の詳細表示
struct SelectedBarDetailView: View {
    let dataPoint: ChartDataPoint
    let period: StatisticsPeriod
    
    private var detailText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        
        switch period {
        case .day:
            dateFormatter.dateFormat = "H時台"
            return dateFormatter.string(from: dataPoint.date)
        case .week:
            dateFormatter.dateFormat = "M月d日(E)"
            return dateFormatter.string(from: dataPoint.date)
        case .month:
            dateFormatter.dateFormat = "M月d日"
            return dateFormatter.string(from: dataPoint.date)
        case .year:
            dateFormatter.dateFormat = "yyyy年M月"
            return dateFormatter.string(from: dataPoint.date)
        }
    }
    
    private var countText: String {
        if period == .day {
            return "累計 \(dataPoint.count)本（この時間帯: \(dataPoint.rawCount)本）"
        } else {
            return "\(dataPoint.count)本"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(detailText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(countText)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .animation(.spring(response: 0.3), value: dataPoint.id)
    }
}

/// サマリービュー
struct StatisticsSummaryView: View {
    let data: [ChartDataPoint]
    let brandSummary: [BrandStatData]
    let totalAmount: Decimal
    let dailyGoal: Int?
    
    private var totalCount: Int {
        data.reduce(0) { $0 + $1.rawCount }
    }
    
    private var averageCount: Double {
        let nonZeroDays = data.filter { $0.rawCount > 0 }.count
        guard nonZeroDays > 0 else { return 0 }
        return Double(totalCount) / Double(nonZeroDays)
    }
    
    private var maxCount: Int {
        data.map { $0.rawCount }.max() ?? 0
    }
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: totalAmount as NSDecimalNumber) ?? "¥0"
    }
    
    /// 目標達成日数
    private var goalAchievedDays: Int {
        guard let goal = dailyGoal else { return 0 }
        return data.filter { $0.rawCount > 0 && $0.rawCount <= goal }.count
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AnimatedStatisticCard(
                    title: "合計",
                    value: "\(totalCount)本",
                    icon: "sum",
                    color: .blue
                )
                
                AnimatedStatisticCard(
                    title: "平均",
                    value: String(format: "%.1f本", averageCount),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
            }
            
            HStack(spacing: 12) {
                AnimatedStatisticCard(
                    title: "最大",
                    value: "\(maxCount)本",
                    icon: "arrow.up.circle",
                    color: .orange
                )
                
                AnimatedStatisticCard(
                    title: "金額",
                    value: formattedAmount,
                    icon: "yensign.circle",
                    color: .purple
                )
            }
            
            // 銘柄別内訳（銘柄がある場合のみ表示）
            if !brandSummary.isEmpty {
                BrandBreakdownView(brandSummary: brandSummary)
            }
        }
    }
}

/// 銘柄別内訳ビュー
struct BrandBreakdownView: View {
    let brandSummary: [BrandStatData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("銘柄別内訳")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 6) {
                ForEach(brandSummary) { brand in
                    HStack {
                        Circle()
                            .fill(brand.color)
                            .frame(width: 10, height: 10)
                        
                        Text(brand.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(brand.count)本")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(formatAmount(brand.amount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "¥0"
    }
}

/// 値がアニメーションで変化する統計カード
struct AnimatedStatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [SmokingRecord.self, CigaretteBrand.self, AppSettings.self], inMemory: true)
}

/// 銘柄の凡例ビュー
struct BrandLegendView: View {
    let brands: [CigaretteBrand]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(brands) { brand in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(brandColor(for: brand.id))
                            .frame(width: 8, height: 8)
                        Text(brand.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 未分類
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("未分類")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func brandColor(for id: UUID) -> Color {
        let colors: [Color] = [.orange, .green, .purple, .pink, .cyan, .indigo, .mint, .teal]
        if let brandIndex = brands.firstIndex(where: { $0.id == id }) {
            return colors[brandIndex % colors.count]
        }
        let index = abs(id.hashValue) % colors.count
        return colors[index]
    }
}
