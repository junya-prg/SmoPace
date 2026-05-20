//
//  AINewsView.swift
//  SmokeCounter
//
//  AIニュース画面 - タバコ関連記事一覧とAI要約表示
//

import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "SmokeCounter", category: "AINewsView")

/// AIニュース画面
@available(iOS 26.0, macOS 26.0, *)
struct AINewsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = AINewsViewModel()
    @State private var selectedArticle: Article?
    
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
                    // グラスモルフィズム風のレベルメーターを上部に配置
                    PaceLevelMeterView()
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    // カテゴリフィルター
                    CategoryFilterView(
                        categories: viewModel.allCategories,
                        selectedCategory: viewModel.selectedCategory,
                        onSelect: { category in
                            viewModel.selectCategory(category)
                        }
                    )
                    .padding(.vertical, 8)
                    
                    // AI処理状況インジケーター
                    if viewModel.isProcessingAI {
                        AIProcessingIndicatorView()
                    }
                    
                    // 記事一覧
                    Group {
                        if viewModel.isLoading && viewModel.articles.isEmpty {
                            LoadingView()
                        } else if viewModel.filteredArticles.isEmpty {
                            EmptyArticlesView(hasFilter: viewModel.selectedCategory != nil)
                        } else {
                            ArticleListView(
                                articles: viewModel.filteredArticles,
                                onSelect: { article in
                                    selectedArticle = article
                                }
                            )
                        }
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
                // 全て表示ボタン
                FilterChip(
                    title: String(localized: "すべて"),
                    isSelected: selectedCategory == nil,
                    color: .blue
                ) {
                    onSelect(nil)
                }
                
                // 各カテゴリボタン
                ForEach(categories) { category in
                    FilterChip(
                        title: category.displayName,
                        icon: category.iconName,
                        isSelected: selectedCategory == category,
                        color: categoryColor(for: category)
                    ) {
                        onSelect(category)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func categoryColor(for category: ArticleCategory) -> Color {
        switch category {
        case .newProducts: return .blue
        case .industry: return .orange
        case .trivia: return .purple
        case .quitting: return .green
        case .other: return .gray
        }
    }
}

/// フィルターチップ
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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

/// 記事一覧ビュー
struct ArticleListView: View {
    let articles: [Article]
    let onSelect: (Article) -> Void
    
    /// 広告が挿入されたリストアイテム
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
            }
        }
        .listStyle(.plain)
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
            
            // 要約（AI処理済みの場合はAI要約、そうでない場合は記事概要）
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

// MARK: - 新規UIコンポーネント（レベルメーター ＆ お祝いポップアップ）

/// ペースの苗木レベルメーター（グラスモルフィズム風）
struct PaceLevelMeterView: View {
    @MainActor
    private var tracker: PaceNewsTracker {
        PaceNewsTracker.shared
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // レベルアイコン（グラデーション背景つき）
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tracker.currentLevel.color.opacity(0.2), tracker.currentLevel.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: tracker.currentLevel.color.opacity(0.3), radius: 5, x: 0, y: 3)
                    
                    Image(systemName: tracker.currentLevel.iconName)
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
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
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            // 進捗バー
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景レール
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 6)
                        
                        // ゲージ
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.mint, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * tracker.levelProgress, height: 6)
                            .shadow(color: Color.mint.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("既読数: \(tracker.totalReadCount) 記事")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if let nextLevel = tracker.currentLevel.next {
                        Text("次のレベルまであと \(tracker.articlesUntilNextLevel) 記事")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("MAX レベル")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
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

@available(iOS 26.0, macOS 26.0, *)
#Preview {
    AINewsView()
        .modelContainer(for: [SmokingRecord.self, AppSettings.self], inMemory: true)
}
