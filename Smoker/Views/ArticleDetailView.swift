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
                        article: article,
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
    let article: Article
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
            
            if let digest = article.summaryDigest {
                // 構造化要約のリッチカード表示
                DigestView(digest: digest, themeColor: themeColor)
            } else {
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
}

/// 構造化要約（digest）のリッチ表示
struct DigestView: View {
    let digest: ArticleDigest
    let themeColor: Color
    
    private let actionColor: Color = .green
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ひとことで言うと
            headlineCard
            
            // 3つのポイント
            if !digest.points.isEmpty {
                pointsCard
            }
            
            // 今日からできること
            if !digest.actionTip.isEmpty {
                actionCard
            }
            
            // 関連キーワード
            if !digest.keywords.isEmpty {
                keywordChips
            }
        }
    }
    
    /// ひとことで言うと（強調カード）
    private var headlineCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DigestLabel(title: String(localized: "ひとことで言うと"), iconName: "quote.opening", color: themeColor)
            
            Text(digest.headline)
                .font(.body)
                .fontWeight(.semibold)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    /// 3つのポイント（番号バッジ＋見出し＋説明）
    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            DigestLabel(title: String(localized: "要点のまとめ"), iconName: "list.bullet.indent", color: themeColor)
            
            ForEach(Array(digest.points.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 12) {
                    // 番号バッジ
                    Text("\(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(themeColor)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if !point.label.isEmpty {
                            Text(point.label)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(themeColor)
                        }
                        if !point.detail.isEmpty {
                            Text(point.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    /// 今日からできること（アクセントカード）
    private var actionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(actionColor)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("今日からできるアクション")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(actionColor)
                
                Text(digest.actionTip)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(actionColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    /// 関連キーワード
    private var keywordChips: some View {
        WrapChips(items: digest.keywords, color: themeColor)
    }
}

/// 各ブロックの見出しラベル
struct DigestLabel: View {
    let title: String
    let iconName: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
    }
}

/// 折り返し対応のキーワードチップ群
struct WrapChips: View {
    let items: [String]
    let color: Color
    
    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, keyword in
                Text("# \(keyword)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(color)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

/// 子ビューを横に並べ、横幅を超えたら折り返す簡易 Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let addition = currentRowWidth == 0 ? size.width : size.width + spacing
            if currentRowWidth + addition > maxWidth, currentRowWidth > 0 {
                rows.append([subview])
                currentRowWidth = size.width
            } else {
                rows[rows.count - 1].append(subview)
                currentRowWidth += addition
            }
        }

        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            let rowWidth = row.reduce(CGFloat(0)) { $0 + $1.sizeThatFits(.unspecified).width }
                + CGFloat(max(0, row.count - 1)) * spacing
            totalHeight += rowHeight
            totalWidth = max(totalWidth, rowWidth)
        }
        totalHeight += CGFloat(max(0, rows.count - 1)) * lineSpacing
        return CGSize(width: proposal.width ?? totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
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
