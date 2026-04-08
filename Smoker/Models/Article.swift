//
//  Article.swift
//  SmokeCounter
//
//  ニュース記事を表すモデル
//

import Foundation

/// 記事のカテゴリ
enum ArticleCategory: String, CaseIterable, Codable, Identifiable {
    case newProducts = "新商品"
    case industry = "業界"
    case trivia = "豆知識"
    case quitting = "節煙"
    case other = "その他"
    
    var id: String { rawValue }
    
    /// カテゴリに対応するSF Symbolsアイコン名
    var iconName: String {
        switch self {
        case .newProducts:
            return "sparkles"
        case .industry:
            return "building.2"
        case .trivia:
            return "book.fill"
        case .quitting:
            return "arrow.down.heart"
        case .other:
            return "doc.text"
        }
    }
    
    /// カテゴリの色
    var color: String {
        switch self {
        case .newProducts:
            return "blue"
        case .industry:
            return "orange"
        case .trivia:
            return "purple"
        case .quitting:
            return "green"
        case .other:
            return "gray"
        }
    }
}

/// ニュース記事を表すモデル
struct Article: Identifiable, Codable, Hashable {
    /// 一意識別子
    let id: UUID
    
    /// 記事タイトル
    let title: String
    
    /// 記事ソース（ニュースサイト名など）
    let source: String
    
    /// 公開日時
    let publishedAt: Date
    
    /// 記事URL
    let url: URL
    
    /// 記事の説明・抜粋（RSSから取得）
    let description: String?
    
    /// AI生成の要約
    var aiSummary: String?
    
    /// AIが判定したカテゴリ
    var category: ArticleCategory?
    
    /// おすすめ度（0.0〜1.0）
    var relevanceScore: Double?
    
    /// AIによる処理が行われたかどうか（falseの場合はフォールバック処理）
    var isAIProcessed: Bool = false
    
    /// 初期化
    /// - Parameters:
    ///   - title: 記事タイトル
    ///   - source: 記事ソース
    ///   - publishedAt: 公開日時
    ///   - url: 記事URL
    ///   - description: 記事の説明
    init(
        id: UUID = UUID(),
        title: String,
        source: String,
        publishedAt: Date,
        url: URL,
        description: String? = nil,
        aiSummary: String? = nil,
        category: ArticleCategory? = nil,
        relevanceScore: Double? = nil,
        isAIProcessed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.publishedAt = publishedAt
        self.url = url
        self.description = description
        self.aiSummary = aiSummary
        self.category = category
        self.relevanceScore = relevanceScore
        self.isAIProcessed = isAIProcessed
    }
    
    /// 公開日時のフォーマット済み文字列
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: publishedAt)
    }
    
    /// 公開日時の相対表示（「3時間前」など）
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }
    
    /// おすすめ度のパーセント表示
    var relevancePercentage: Int? {
        guard let score = relevanceScore else { return nil }
        return Int(score * 100)
    }
}

// MARK: - サンプルデータ

extension Article {
    /// プレビュー・テスト用のサンプル記事
    static let sampleArticles: [Article] = [
        Article(
            title: "2026年のタバコ税増税、喫煙者への影響は？",
            source: "日経新聞",
            publishedAt: Date().addingTimeInterval(-3600),
            url: URL(string: "https://example.com/article1")!,
            description: "政府は2026年度の税制改正でタバコ税の増税を検討。喫煙者の家計への影響を試算した。",
            aiSummary: "タバコ税の増税により、1箱あたり約50円の値上げが予想されます。年間で約2万円の負担増となる計算です。",
            category: .industry,
            relevanceScore: 0.85,
            isAIProcessed: true
        ),
        Article(
            title: "電子タバコの最新動向、業界の変化を追う",
            source: "朝日新聞",
            publishedAt: Date().addingTimeInterval(-7200),
            url: URL(string: "https://example.com/article2")!,
            description: "電子タバコ市場の最新動向について、業界の変化をまとめた。",
            aiSummary: "電子タバコ市場は急速に拡大中。各メーカーが新技術を投入し、競争が激化しています。",
            category: .industry,
            relevanceScore: 0.72,
            isAIProcessed: true
        ),
        Article(
            title: "禁煙成功率を高める新アプリが登場",
            source: "ITmedia",
            publishedAt: Date().addingTimeInterval(-14400),
            url: URL(string: "https://example.com/article3")!,
            description: "AIを活用した禁煙支援アプリが新登場。ユーザーの行動パターンを分析し、最適なタイミングでアドバイス。",
            aiSummary: "新しい禁煙支援アプリは、AIがユーザーの喫煙パターンを学習し、禁煙成功率を従来の2倍に向上させるとのこと。",
            category: .quitting,
            relevanceScore: 0.95,
            isAIProcessed: true
        ),
        Article(
            title: "JT、新しい加熱式タバコを発売",
            source: "読売新聞",
            publishedAt: Date().addingTimeInterval(-28800),
            url: URL(string: "https://example.com/article4")!,
            description: "日本たばこ産業（JT）が新型の加熱式タバコデバイスを発表。従来製品より30%小型化。",
            aiSummary: "JTの新製品は、従来モデルより30%小型化され、持ち運びやすくなりました。フレーバーも5種類追加されています。",
            category: .newProducts,
            relevanceScore: 0.68,
            isAIProcessed: true
        ),
        Article(
            title: "世界の喫煙率、過去最低に",
            source: "NHK",
            publishedAt: Date().addingTimeInterval(-43200),
            url: URL(string: "https://example.com/article5")!,
            description: "WHOの最新統計によると、世界全体の喫煙率が過去最低を記録。各国の禁煙政策が効果を発揮。",
            aiSummary: "世界の成人喫煙率は過去20年で約30%減少。日本も例外ではなく、特に若年層での喫煙離れが顕著です。",
            category: .industry,
            relevanceScore: 0.78,
            isAIProcessed: true
        ),
        Article(
            title: "タバコの歴史：コロンブスが持ち帰った一本から",
            source: "歴史チャンネル",
            publishedAt: Date().addingTimeInterval(-57600),
            url: URL(string: "https://example.com/article6")!,
            description: "タバコが世界に広まった歴史を紐解く。コロンブスの新大陸発見から現代まで。",
            aiSummary: "15世紀にコロンブスが新大陸でタバコを発見。当初は薬草としてヨーロッパに伝わり、その後嘉好品として世界中に広まりました。",
            category: .trivia,
            relevanceScore: 0.82,
            isAIProcessed: true
        )
    ]
    
    /// 単一のサンプル記事
    static let sample = sampleArticles[0]
}
