//
//  AINewsView.swift
//  SmokeCounter
//
//  AIニュース画面 - タバコ関連記事一覧とAI要約表示
//

import SwiftUI
import SwiftData
import Combine
import os

private let logger = Logger(subsystem: "SmokeCounter", category: "AINewsView")

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// AIニュース画面
@available(iOS 26.0, macOS 26.0, *)
struct AINewsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AINewsViewModel()
    @State private var selectedArticle: Article?
    @State private var transplantedTree: TransplantedTree?
    @State private var selectedSafariURL: IdentifiableURL?
    
    /// AmazonアソシエイトURL（カテゴリに応じた個別の動的検索URLを生成）
    private func dealsAmazonURL(for category: DealCategoryType? = nil) -> URL {
        let associateTag = "smopace-22"
        let keyword: String
        if let category = category {
            keyword = category.keyword
        } else {
            let queries = [
                "タバコ 携帯灰皿 密閉 おしゃれ タイムセール",
                "喫煙者 口臭ケア 消臭スプレー 衣類 タイムセール",
                "タバコ ケース ライター 節煙グッズ タイムセール",
                "タバコ ヤニ取り 歯磨き粉 タイムセール",
                "加熱式タバコ 紙巻きタバコ 周辺機器 タイムセール"
            ]
            let day = Calendar.current.component(.day, from: Date())
            let hour = Calendar.current.component(.hour, from: Date())
            let index = (day + hour) % queries.count
            keyword = queries[index]
        }
        
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.amazon.co.jp/s?k=\(encoded)&pct-off=10-&tag=\(associateTag)"
        return URL(string: urlString) ?? URL(string: "https://www.amazon.co.jp")!
    }
    
    /// AIステータスに応じた色
    private var aiStatusColor: Color {
        guard let available = viewModel.isAIActuallyAvailable else {
            // まだチェック中（グレー）
            return .gray
        }
        return available ? .green : .orange
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // 数秒おきに自動切替されるヘッダーバナー（苗木メーター / 節煙成果 / ガジェットタイムセール）
                    PaceCarouselHeaderBannerView(
                        onTransplant: { tree in
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                transplantedTree = tree
                            }
                        },
                        onOpenDeals: {
                            selectedSafariURL = IdentifiableURL(url: dealsAmazonURL())
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // カテゴリフィルター
                    CategoryFilterView(
                        categories: viewModel.allCategories,
                        selectedCategory: viewModel.selectedCategory,
                        onSelect: { category in
                            viewModel.selectedCategory = category
                        }
                    )
                    .padding(.vertical, 8)
                    
                    // AI処理状況インジケーター
                    if viewModel.isProcessingAI {
                        AIProcessingIndicatorView()
                    }
                    
                    // 記事リスト（広告＆周辺機器タイムセールカードを挿入）
                    if viewModel.filteredArticles.isEmpty && !viewModel.isLoading {
                        EmptyArticlesView(hasFilter: viewModel.selectedCategory != nil)
                    } else {
                        ArticleListView(
                            articles: viewModel.filteredArticles,
                            onSelect: { article in
                                selectedArticle = article
                            },
                            onSelectDealsCategory: { category in
                                selectedSafariURL = IdentifiableURL(url: dealsAmazonURL(for: category))
                            }
                        )
                    }
                }
                
                // レベルアップお祝い用ポップアップ
                if let pendingLevel = PaceNewsTracker.shared.pendingLevelUp {
                    LevelUpOverlayView(level: pendingLevel) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            PaceNewsTracker.shared.consumeLevelUp()
                        }
                    }
                }
                
                // 植樹完了お祝い用ポップアップ
                if let tree = transplantedTree {
                    TransplantCelebrationView(tree: tree) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            transplantedTree = nil
                        }
                    }
                }
            }
            .navigationTitle("AIニュース")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.refreshArticles(modelContext: modelContext)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                        if let available = viewModel.isAIActuallyAvailable {
                            Text(available ? "AI" : "")
                                .font(.caption2)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(aiStatusColor)
                }
            }
            .sheet(item: $selectedSafariURL) { item in
                SafariView(url: item.url)
                    .ignoresSafeArea()
            }
            .onAppear {
                logger.notice("📱 AINewsView onAppear")
                viewModel.resumeAIProcessingIfNeeded(modelContext: modelContext)
            }
            .task {
                logger.notice("📱 AINewsView task開始")
                if viewModel.articles.isEmpty {
                    await viewModel.loadArticles(modelContext: modelContext)
                } else {
                    viewModel.resumeAIProcessingIfNeeded(modelContext: modelContext)
                }
                logger.notice("📱 AINewsView task完了")
            }
            .refreshable {
                await viewModel.refreshArticles(modelContext: modelContext)
            }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailView(article: article)
            }
        }
    }
}

// MARK: - サブビュー

/// カテゴリフィルターバー
struct CategoryFilterView: View {
    let categories: [ArticleCategory]
    let selectedCategory: ArticleCategory?
    let onSelect: (ArticleCategory?) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // すべて
                FilterChip(
                    title: "すべて",
                    isSelected: selectedCategory == nil,
                    action: { onSelect(nil) }
                )
                
                // 各カテゴリ
                ForEach(categories, id: \.self) { category in
                    FilterChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        action: { onSelect(category) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

/// フィルターチップ
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

/// AI処理中インジケーター
struct AIProcessingIndicatorView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("AIが記事を分析中...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

/// 読み込み中ビュー
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("記事を取得中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 記事がない場合のビュー
struct EmptyArticlesView: View {
    let hasFilter: Bool
    
    var body: some View {
        ContentUnavailableView(
            hasFilter ? "該当する記事がありません" : "記事がありません",
            systemImage: "newspaper",
            description: Text(hasFilter ? "他のカテゴリを選択してください" : "プルダウンで更新してください")
        )
    }
}

/// 記事リストビュー
struct ArticleListView: View {
    let articles: [Article]
    let onSelect: (Article) -> Void
    let onSelectDealsCategory: (DealCategoryType) -> Void
    
    /// 広告および周辺機器カードが挿入されたリストアイテム
    private var listItems: [ArticleListItem] {
        insertAdsIntoArticles(articles)
    }
    
    var body: some View {
        List(listItems) { item in
            switch item {
            case .article(let article):
                ArticleCardView(article: article)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(article)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                
            case .ad:
                NativeAdView()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    
            case .gadgetDealsCard(_, let category):
                GadgetDealsInfeedCardView(category: category, onTap: {
                    onSelectDealsCategory(category)
                })
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

/// タバコ周辺機器・便利グッズのインフィードカード（ネイビー系・枠線なし・極小コンパクト帯デザイン）
struct GadgetDealsInfeedCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let category: DealCategoryType
    let onTap: () -> Void
    
    private var navyGradientColors: [Color] {
        if colorScheme == .dark {
            // ダークモード用: 前回の深みのあるシックなネイビー
            return [
                Color(red: 0.08, green: 0.12, blue: 0.24),
                Color(red: 0.14, green: 0.20, blue: 0.35)
            ]
        } else {
            // ライトモード用: 重くならない爽やかで洗練されたネイビー
            return [
                Color(red: 0.12, green: 0.22, blue: 0.42),
                Color(red: 0.18, green: 0.30, blue: 0.52)
            ]
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: category.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                // メインタイトル
                Text(category.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Amazon 表示
                HStack(spacing: 4) {
                    Text("Amazon")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: navyGradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// 記事カードビュー
struct ArticleCardView: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー（カテゴリ・ソース・日時）
            HStack {
                // 既読トラッカーと連携して未読ならミント色のドットを表示
                if !PaceNewsTracker.shared.isRead(article) {
                    Circle()
                        .fill(Color.mint)
                        .frame(width: 8, height: 8)
                }
                
                if article.isAIGenerated {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AI豆知識")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                } else if let category = article.category {
                    CategoryBadge(category: category)
                }
                
                Spacer()
                
                Text(article.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("・")
                    .foregroundStyle(.secondary)
                
                Text(article.relativeDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // タイトル
            Text(article.title)
                .font(.headline)
                .lineLimit(2)
            
            //要約（AI処理済みの場合はAI要約、そうでない場合は記事概要）
            let displaySummary = article.aiSummary ?? article.description
            if let summary = displaySummary {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: article.isAIGenerated ? "sparkles" : (article.isAIProcessed ? "brain" : "doc.text"))
                        .font(.caption)
                        .foregroundStyle(article.isAIGenerated ? .purple : (article.isAIProcessed ? .purple : .blue))
                    
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding(10)
                .background((article.isAIGenerated ? Color.purple : (article.isAIProcessed ? Color.purple : Color.blue)).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // おすすめ度
            if let percentage = article.relevancePercentage {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("おすすめ度: \(percentage)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(article.isAIGenerated ? Color.purple.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: article.isAIGenerated ? Color.purple.opacity(0.06) : Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 新規UIコンポーネント（レベルメーター・カルーセルバナー ＆ お祝いポップアップ）

/// 数秒おきに自動切替されるヘッダーバナー（Slide 0: 苗木メーター / Slide 1: 周辺機器タイムセール）
struct PaceCarouselHeaderBannerView: View {
    let onTransplant: (TransplantedTree) -> Void
    let onOpenDeals: () -> Void
    
    @State private var currentPage = 0
    private let timer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 6) {
            TabView(selection: $currentPage) {
                // Slide 0: 苗木レベルメーター
                PaceLevelMeterView(onTransplant: onTransplant)
                    .tag(0)
                
                // Slide 1: タバコ周辺機器・便利グッズタイムセール
                GadgetDealsHeaderCard(onTap: onOpenDeals)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 94)
            
            // ドットインジケーター（2枚構成）
            HStack(spacing: 5) {
                ForEach(0..<2) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.mint : Color.gray.opacity(0.3))
                        .frame(width: currentPage == index ? 14 : 5, height: 5)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPage = (currentPage + 1) % 2
            }
        }
    }
}



/// ガジェット＆周辺機器タイムセールヘッダーカード（インフィードカードとトーン統一したネイビーデザイン・94ptスリム版）
struct GadgetDealsHeaderCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let onTap: () -> Void
    
    private var navyGradientColors: [Color] {
        if colorScheme == .dark {
            // ダークモード用: 前回の深みのあるシックなネイビー
            return [
                Color(red: 0.08, green: 0.12, blue: 0.24),
                Color(red: 0.14, green: 0.20, blue: 0.35)
            ]
        } else {
            // ライトモード用: 重くならない爽やかで洗練されたネイビー
            return [
                Color(red: 0.12, green: 0.22, blue: 0.42),
                Color(red: 0.18, green: 0.30, blue: 0.52)
            ]
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("周辺機器・便利グッズ")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("タイムセール")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.25))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                    
                    Text("携帯灰皿・ケース・消臭スプレー・ヤニ取り")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(spacing: 3) {
                        Text("Amazonでお得なセール品をチェック")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(height: 94)
            .background(
                LinearGradient(
                    colors: navyGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

/// ペースの苗木レベルメーター（全体タップで「森」へ遷移・94ptスリム版）
struct PaceLevelMeterView: View {
    let onTransplant: (TransplantedTree) -> Void
    
    @MainActor
    private var tracker: PaceNewsTracker {
        PaceNewsTracker.shared
    }
    
    @State private var showForest = false
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // レベルアイコン（グラデーション背景つき）
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tracker.currentLevel.color.opacity(0.25), tracker.currentLevel.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: tracker.currentLevel.color.opacity(0.25), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: tracker.currentLevel.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .bottom, spacing: 6) {
                        Text(tracker.currentLevel.title)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("Lv.\(tracker.currentLevel.displayLevel)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(tracker.currentLevel.levelDescription)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                // マイフォレスト（森）表示
                HStack(spacing: 3) {
                    Image(systemName: "tree.fill")
                        .font(.system(size: 11))
                    Text("森")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.mint.opacity(0.12))
                .clipShape(Capsule())
            }
            
            // コンパクト進捗バーと情報 / 植樹ボタン
            HStack(spacing: 8) {
                // ゲージバー
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.mint, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * tracker.levelProgress, height: 6)
                    }
                }
                .frame(height: 6)
                
                if tracker.currentLevel.next != nil {
                    Text("次のレベルまであと\(tracker.articlesUntilNextLevel)記事")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    // 植樹可能時ボタン
                    Button(action: {
                        if let tree = tracker.transplantCurrentTree() {
                            onTransplant(tree)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                            Text("植樹する 🌲")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.mint)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(height: 94)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            showForest = true
        }
        .sheet(isPresented: $showForest) {
            MyForestView()
        }
    }
}

/// レベルアップお祝い用ポップアップ
struct LevelUpOverlayView: View {
    let level: PaceLevel
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // 背景の暗転
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .transition(.opacity)
            
            // お祝いカード
            VStack(spacing: 24) {
                // キラキラエフェクトとアイコン
                ZStack {
                    Circle()
                        .fill(level.color.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.2)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Image(systemName: level.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(level.color)
                                .frame(width: 70, height: 70)
                                .shadow(color: level.color.opacity(0.6), radius: 10, x: 0, y: 5)
                        )
                }
                
                VStack(spacing: 8) {
                    Text("ランクアップ！")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.mint, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(level.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("あなたの苗木が大きく成長しました！")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text(level.levelDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Button(action: onDismiss) {
                    Text("これからもクリアな呼吸を続ける")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.mint, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .mint.opacity(0.4), radius: 6, x: 0, y: 3)
                }
            }
            .padding(30)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// カテゴリバッジ
struct CategoryBadge: View {
    let category: ArticleCategory

    private var color: Color {
        switch category {
        case .newProducts: return .blue
        case .industry: return .orange
        case .trivia: return .purple
        case .quitting: return .green
        case .other: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.iconName)
                .font(.caption2)
            Text(category.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - 植樹成功お祝い用ポップアップ

@available(iOS 26.0, macOS 26.0, *)
struct TransplantCelebrationView: View {
    let tree: TransplantedTree
    let onDismiss: () -> Void
    
    private var gradientColors: [Color] {
        tree.colorsHex.map { Color(hex: $0) }
    }
    
    var body: some View {
        ZStack {
            // 背景の暗転
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)
            
            // お祝いカード
            VStack(spacing: 28) {
                // キラキラエフェクトとツリーアイコン
                ZStack {
                    Circle()
                        .fill(gradientColors.first?.opacity(0.2) ?? .clear)
                        .frame(width: 140, height: 140)
                        .scaleEffect(1.2)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: gradientColors.first?.opacity(0.5) ?? .clear, radius: 12, x: 0, y: 6)
                    
                    Image(systemName: tree.iconName)
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 12) {
                    Text("祝・植樹完了！")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.mint, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("第\(tree.cycleIndex)代目の大樹")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text(tree.title)
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("苗木が最高レベルまで成長し、無事に「マイフォレスト」へ移植されました！")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("これでマイフォレストに新たな息吹が加わりました。新しい種を植えて、さらにクリアな呼吸と健康の旅を続けましょう。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button(action: onDismiss) {
                    Text("新しい種を植える 🌱")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.mint, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .mint.opacity(0.4), radius: 6, x: 0, y: 3)
                }
            }
            .padding(32)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 25, x: 0, y: 12)
            .padding(.horizontal, 30)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
#Preview {
    AINewsView()
        .modelContainer(for: [SmokingRecord.self, AppSettings.self], inMemory: true)
}
