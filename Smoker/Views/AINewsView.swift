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
            VStack(spacing: 0) {
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
            }
            .task {
                logger.notice("📱 AINewsView task開始")
                if viewModel.articles.isEmpty {
                    await viewModel.loadArticles(modelContext: modelContext)
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
                if let category = article.category {
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
                    Image(systemName: article.isAIProcessed ? "brain" : "doc.text")
                        .font(.caption)
                        .foregroundStyle(article.isAIProcessed ? .purple : .blue)
                    
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .padding(10)
                .background((article.isAIProcessed ? Color.purple : Color.blue).opacity(0.1))
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
