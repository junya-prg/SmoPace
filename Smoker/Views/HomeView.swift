//
//  HomeView.swift
//  SmokeCounter
//
//  ホーム画面 - 今日のカウント表示、カウントアップボタン
//

import SwiftUI
import SwiftData

/// ホーム画面
@available(iOS 26.0, macOS 26.0, *)
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = HomeViewModel()
    
    /// 全画面リラックスモード
    @State private var isRelaxMode = false
    
    /// 実際に表示する背景タイプ（起動時にランダムで決定）
    @State private var actualBackgroundType: RelaxingBackgroundType = RelaxingBackgroundType.effectTypes.randomElement() ?? .campfire
    
    /// リラックスモードの案内表示
    @State private var showRelaxHint = false
    
    /// AIで生成した癒しメッセージ
    @State private var relaxMessage = "ゆっくりと..."
    
    /// ランダム位置に表示するAIの独り言
    @State private var floatingComment: String? = nil
    
    /// ランダムコメントの表示位置（X, Yの割合 0.0〜1.0）
    @State private var floatingCommentPosition: CGPoint = CGPoint(x: 0.5, y: 0.4)
    
    /// AI処理サービス
    @State private var aiService = FoundationModelsService()
    
    /// ハプティクスサービス
    @State private var hapticService = HapticService()
    
    var body: some View {
        ZStack {
            // 背景エフェクト（常に表示）
            RelaxingBackgroundView(
                type: actualBackgroundType,
                opacity: isRelaxMode ? 1.0 : 0.5
            )
            .ignoresSafeArea()
            
            // UI部分（リラックスモード時は非表示）
            if !isRelaxMode {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 銘柄タブ（銘柄が登録されている場合のみ表示）
                            if !viewModel.allBrands.isEmpty {
                                BrandTabView(
                                    brands: viewModel.allBrands,
                                    brandCounts: viewModel.brandCounts,
                                    selectedBrandId: $viewModel.selectedBrandId
                                )
                            }
                            
                            // 目標達成状況
                            if let goal = viewModel.dailyGoal {
                                GoalProgressView(
                                    current: viewModel.todayCount,
                                    goal: goal,
                                    isOverGoal: viewModel.isOverGoal
                                )
                            }
                            
                            // メインカウント表示（選択中の銘柄のカウント）
                            CountDisplayView(
                                count: viewModel.selectedBrandId == nil ? viewModel.todayCount : viewModel.selectedBrandCount,
                                isOverGoal: viewModel.isOverGoal && viewModel.selectedBrandId == nil
                            )
                            .padding(.vertical, 16)
                            
                            // 前回からの経過時間
                            TimeSinceLastView(timeText: viewModel.timeSinceLastSmokeText)
                            
                            // 金額表示（選択中の銘柄の金額）
                            if !viewModel.allBrands.isEmpty {
                                AmountDisplayView(
                                    amount: viewModel.selectedBrandId == nil ? viewModel.todayAmount : viewModel.selectedBrandAmount
                                )
                            }
                            
                            // カウント操作ボタン
                            CountButtonsView(
                                onIncrement: {
                                    // 選択中の銘柄でカウントアップ
                                    let brand = viewModel.selectedBrandId != nil
                                        ? viewModel.allBrands.first { $0.id == viewModel.selectedBrandId }
                                        : viewModel.currentBrand
                                    viewModel.addSmokingRecord(modelContext: modelContext, brand: brand)
                                },
                                onDecrement: {
                                    viewModel.removeLastRecord(modelContext: modelContext, brandId: viewModel.selectedBrandId)
                                },
                                canDecrement: viewModel.selectedBrandId == nil ? viewModel.todayCount > 0 : viewModel.selectedBrandCount > 0,
                                selectedBrandName: viewModel.selectedBrandId == nil
                                    ? nil
                                    : viewModel.allBrands.first { $0.id == viewModel.selectedBrandId }?.name
                            )
                            .padding(.vertical, 16)
                            
                            // 今日の履歴（コンパクト表示）
                            CompactHistoryView()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        enterRelaxMode()
                    }
                    .navigationTitle("今日の記録")
                }
            }
            
            // リラックスモード時のオーバーレイ
            if isRelaxMode {
                GeometryReader { geometry in
                    ZStack {
                        // タップ検出用
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture {
                                exitRelaxMode()
                            }
                        
                        // ランダムな位置に表示されるAIの独り言
                        if let comment = floatingComment {
                            Text(comment)
                                .font(.callout)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .foregroundStyle(.white.opacity(0.95))
                                .shadow(color: .black.opacity(0.2), radius: 10)
                                .position(
                                    x: geometry.size.width * floatingCommentPosition.x,
                                    y: geometry.size.height * floatingCommentPosition.y
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        
                        // 案内表示（下部）
                        VStack {
                            Spacer()
                            
                            if showRelaxHint {
                                VStack(spacing: 8) {
                                    // 癒しメッセージ
                                    Text(relaxMessage)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                    
                                    // 操作説明
                                    Text("タップで戻る")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.bottom, 60)
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
        }
        .toolbar(isRelaxMode ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(isRelaxMode)
        .onAppear {
            viewModel.loadSettings(modelContext: modelContext)
            viewModel.loadTodayRecords(modelContext: modelContext)
            // 表示時にランダムで背景を変更
            actualBackgroundType = RelaxingBackgroundType.effectTypes.randomElement() ?? .campfire
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // アプリがアクティブになった時にデータを再読み込み
            if newPhase == .active {
                // ModelContextをリフレッシュして最新データを取得
                modelContext.processPendingChanges()
                viewModel.loadSettings(modelContext: modelContext)
                viewModel.loadTodayRecords(modelContext: modelContext)
                // アクティブになるたびにランダムで背景を変更
                actualBackgroundType = RelaxingBackgroundType.effectTypes.randomElement() ?? .campfire
            }
        }
    }
    
    /// リラックスモードに入る
    private func enterRelaxMode() {
        // ハプティクスフィードバックで「呼吸」パターンを再生
        hapticService.playRelaxPattern()
        
        // AIで癒しメッセージを生成
        Task {
            await aiService.ensureAIReady()
            relaxMessage = await aiService.generateRelaxMessage()
            
            // ランダムコメントの生成と表示準備
            let userData = UserSmokingData(
                averageDailyCount: viewModel.todayCount,
                dailyGoal: viewModel.dailyGoal,
                isDecreasing: false
            )
            let comment = await aiService.generateRandomComment(userData: userData)
            
            // X: 0.2 ~ 0.8, Y: 0.2 ~ 0.6 の範囲で表示（下部のshowRelaxHintを避けるため）
            let randomX = CGFloat.random(in: 0.2...0.8)
            let randomY = CGFloat.random(in: 0.2...0.6)
            
            await MainActor.run {
                floatingCommentPosition = CGPoint(x: randomX, y: randomY)
            }
            
            // 出現タイミングを少し遅らせる（2.5秒）
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            
            // すでにリラックスモードを抜けていたら表示しない
            let stillInRelaxMode = await MainActor.run { isRelaxMode }
            guard stillInRelaxMode else { return }
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 1.5)) {
                    floatingComment = comment
                }
            }
            
            // 5秒表示してから消す
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            
            await MainActor.run {
                withAnimation(.easeIn(duration: 1.5)) {
                    floatingComment = nil
                }
            }
        }
        
        withAnimation(.easeInOut(duration: 0.4)) {
            isRelaxMode = true
        }
        
        // 少し遅れて案内を表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 1.0)) {
                showRelaxHint = true
            }
        }
        
        // 3秒後に案内を非表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 1.5)) {
                showRelaxHint = false
            }
        }
    }
    
    /// リラックスモードから戻る
    private func exitRelaxMode() {
        withAnimation(.easeOut(duration: 0.3)) {
            showRelaxHint = false
            floatingComment = nil
        }
        withAnimation(.easeInOut(duration: 0.4)) {
            isRelaxMode = false
        }
    }
}

// MARK: - サブビュー

/// 銘柄タブビュー
struct BrandTabView: View {
    let brands: [CigaretteBrand]
    let brandCounts: [BrandCount]
    @Binding var selectedBrandId: UUID?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全体タブ
                BrandTabButton(
                    name: "全体",
                    count: brandCounts.reduce(0) { $0 + $1.count },
                    isSelected: selectedBrandId == nil,
                    color: .blue
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedBrandId = nil
                    }
                }
                
                // 各銘柄タブ
                ForEach(brands) { brand in
                    let count = brandCounts.first { $0.id == brand.id }?.count ?? 0
                    BrandTabButton(
                        name: brand.name,
                        count: count,
                        isSelected: selectedBrandId == brand.id,
                        color: brandColor(for: brand.id)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedBrandId = brand.id
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// 銘柄IDに基づいて色を返す
    private func brandColor(for id: UUID) -> Color {
        let colors: [Color] = [.orange, .green, .purple, .pink, .cyan, .indigo, .mint, .teal]
        let index = abs(id.hashValue) % colors.count
        return colors[index]
    }
}

/// 銘柄タブボタン
struct BrandTabButton: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)本")
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
    }
}

/// 目標達成状況表示
struct GoalProgressView: View {
    let current: Int
    let goal: Int
    let isOverGoal: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("目標: \(goal)本")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if isOverGoal {
                    Text("超過: +\(current - goal)本")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                } else {
                    Text("残り: \(goal - current)本")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
            
            ProgressView(value: min(Double(current) / Double(goal), 1.0))
                .tint(isOverGoal ? .red : .blue)
        }
        .padding(.horizontal)
    }
}

/// カウント数表示
struct CountDisplayView: View {
    let count: Int
    let isOverGoal: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(isOverGoal ? .red : .primary)
            
            Text("本")
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
}

/// 前回からの経過時間表示
struct TimeSinceLastView: View {
    let timeText: String
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
            Text("前回から: \(timeText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// 金額表示
struct AmountDisplayView: View {
    let amount: Decimal
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "¥0"
    }
    
    var body: some View {
        HStack {
            Image(systemName: "yensign.circle")
                .foregroundStyle(.orange)
            Text("今日の金額: \(formattedAmount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// カウント操作ボタン
struct CountButtonsView: View {
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let canDecrement: Bool
    var selectedBrandName: String? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            // 選択中の銘柄名を表示
            if let brandName = selectedBrandName {
                Text("\(brandName)を記録")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 40) {
                // マイナスボタン
                Button(action: onDecrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(canDecrement ? .red : .gray)
                }
                .disabled(!canDecrement)
                
                // プラスボタン（メイン）
                Button(action: onIncrement) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
#Preview {
    HomeView()
        .modelContainer(for: [SmokingRecord.self, CigaretteBrand.self, AppSettings.self], inMemory: true)
}
