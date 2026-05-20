//
//  ArticleDetailView.swift
//  SmokeCounter
//
//  記事詳細画面 - 記事の詳細情報とAI要約を表示
//

import SwiftUI

/// 記事詳細画面
struct ArticleDetailView: View {
    let article: Article
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー情報
                ArticleHeaderView(article: article)
                
                Divider()
                
                // タイトル
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // AI要約セクション（AI要約がない場合はdescriptionを表示）
                let displaySummary = article.aiSummary ?? article.description
                if let summary = displaySummary {
                    AISummarySection(
                        summary: summary,
                        isAIGenerated: article.isAIProcessed
                    )
                }
                
                // おすすめ度
                if let score = article.relevanceScore {
                    RelevanceScoreSection(score: score)
                }
                
                Divider()
                
                // 元記事を開くボタンと共有ボタン（AI豆知識記事の場合は非表示）
                if !article.isAIGenerated {
                    OpenArticleButton(url: article.url) {
                        openURL(article.url)
                    }
                    
                    // 共有ボタン
                    ShareButton(article: article)
                }
            }
            .padding()
        }
        .navigationTitle("記事詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if #available(iOS 26.0, *) {
                PaceNewsTracker.shared.markAsRead(article)
            }
        }
    }
}

// MARK: - サブビュー

/// 記事ヘッダー（カテゴリ・ソース・日時）
struct ArticleHeaderView: View {
    let article: Article
    
    var body: some View {
        HStack {
            if let category = article.category {
                CategoryBadge(category: category)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(article.source)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(article.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// AI要約セクション
struct AISummarySection: View {
    let summary: String
    /// AI生成の要約かどうか（falseの場合はRSSの説明文）
    var isAIGenerated: Bool = true
    
    private var headerTitle: String {
        isAIGenerated ? "AI要約" : "記事の概要"
    }
    
    private var headerIcon: String {
        isAIGenerated ? "brain" : "doc.text"
    }
    
    private var themeColor: Color {
        isAIGenerated ? .purple : .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダー
            HStack {
                Image(systemName: headerIcon)
                    .foregroundStyle(themeColor)
                Text(headerTitle)
                    .font(.headline)
                    .foregroundStyle(themeColor)
            }
            
            // 要約テキスト
            Text(summary)
                .font(.body)
                .lineSpacing(4)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// おすすめ度セクション
struct RelevanceScoreSection: View {
    let score: Double
    
    private var percentage: Int {
        Int(score * 100)
    }
    
    private var scoreColor: Color {
        switch percentage {
        case 80...100:
            return .green
        case 60..<80:
            return .blue
        case 40..<60:
            return .orange
        default:
            return .gray
        }
    }
    
    private var scoreDescription: String {
        switch percentage {
        case 80...100:
            return "この記事はあなたに非常におすすめです"
        case 60..<80:
            return "この記事はあなたに関連性が高いです"
        case 40..<60:
            return "この記事は参考になるかもしれません"
        default:
            return "この記事はあなたとの関連性が低めです"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダー
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("おすすめ度")
                    .font(.headline)
            }
            
            // スコア表示
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(percentage)%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(scoreColor)
                    
                    Spacer()
                }
                
                // プログレスバー
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        // スコアバー
                        RoundedRectangle(cornerRadius: 4)
                            .fill(scoreColor)
                            .frame(width: geometry.size.width * score, height: 8)
                    }
                }
                .frame(height: 8)
                
                Text(scoreDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 元記事を開くボタン
struct OpenArticleButton: View {
    let url: URL
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "safari")
                Text("元の記事を読む")
                Spacer()
                Image(systemName: "arrow.up.right.square")
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 共有ボタン
struct ShareButton: View {
    let article: Article
    
    var body: some View {
        ShareLink(
            item: article.url,
            subject: Text(article.title),
            message: Text("\(article.title)\n\n\(article.aiSummary ?? "")")
        ) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("記事を共有")
                Spacer()
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: Article.sample)
    }
}
