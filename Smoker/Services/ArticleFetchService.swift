//
//  ArticleFetchService.swift
//  SmokeCounter
//
//  節煙関連記事を取得するサービス
//

import Foundation
import Combine

/// 記事取得サービス
@MainActor
class ArticleFetchService: ObservableObject {
    /// 取得した記事一覧
    @Published private(set) var articles: [Article] = []
    
    /// 読み込み中かどうか
    @Published private(set) var isLoading = false
    
    /// エラーメッセージ
    @Published var errorMessage: String?
    
    /// Google News RSSのベースURL
    private let googleNewsRSSBaseURL = "https://news.google.com/rss/search"

    /// 現在のUI言語が英語かどうか
    /// Bundle.main.preferredLocalizations は実際にアプリが採用している言語を返す
    private var isEnglishUI: Bool {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        return lang.hasPrefix("en")
    }

    /// UI言語に応じた検索キーワード
    /// 英語圏向けには quit smoking / vaping 系の語彙を使う
    private var searchKeywords: [String] {
        if isEnglishUI {
            return ["quit smoking", "stop smoking", "vaping", "nicotine free", "heated tobacco", "IQOS", "PloomX", "tobacco history", "tobacco culture", "smoking cessation"]
        } else {
            return ["節煙", "禁煙", "ニコチンフリー", "加熱式タバコ", "喫煙", "IQOS", "PloomX", "タバコ 歴史", "タバコ 文化", "タバコ"]
        }
    }

    /// UI言語に応じた Google News RSS のクエリパラメータ
    /// 形式: hl=言語, gl=国, ceid=国:言語
    private var newsRegionParams: String {
        if isEnglishUI {
            return "hl=en-US&gl=US&ceid=US:en"
        } else {
            return "hl=ja&gl=JP&ceid=JP:ja"
        }
    }

    /// キャッシュ用のUserDefaultsキー（言語別にキャッシュを分ける）
    private var cacheKey: String {
        isEnglishUI ? "cachedArticles_en" : "cachedArticles_ja"
    }
    private var cacheTimestampKey: String {
        isEnglishUI ? "cachedArticlesTimestamp_en" : "cachedArticlesTimestamp_ja"
    }
    
    /// キャッシュの有効期限（1時間）
    private let cacheExpiration: TimeInterval = 3600
    
    /// 最大記事数
    private let maxArticleCount = 30
    
    /// 記事を取得
    func fetchArticles() async {
        print("📰 fetchArticles開始")
        isLoading = true
        errorMessage = nil
        
        // キャッシュを確認
        if let cachedArticles = loadCachedArticles(), !cachedArticles.isEmpty {
            // 最大件数に制限
            let limitedArticles = Array(cachedArticles.prefix(maxArticleCount))
            print("📰 キャッシュから\(limitedArticles.count)件の記事を取得")
            articles = limitedArticles
            isLoading = false
            
            // バックグラウンドで最新記事を取得
            Task {
                await fetchFromRSS()
            }
            return
        }
        
        // RSSから取得
        print("📰 RSSから記事を取得中...")
        await fetchFromRSS()
        
        // RSSが失敗した場合はサンプルデータを使用
        if articles.isEmpty {
            print("📰 RSSから取得できなかったため、サンプルデータを使用")
            articles = Article.sampleArticles
        }
        
        print("📰 fetchArticles完了: \(articles.count)件")
        isLoading = false
    }
    
    /// RSSから記事を取得
    private func fetchFromRSS() async {
        let googleQuery = searchKeywords.joined(separator: "+OR+")
        guard let encodedGoogleQuery = googleQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let googleURL = URL(string: "\(googleNewsRSSBaseURL)?q=\(encodedGoogleQuery)&\(newsRegionParams)") else {
            errorMessage = String(localized: "URLの生成に失敗しました")
            return
        }
        
        let hatenaQuery = isEnglishUI ? "quit smoking OR healthy habits" : "禁煙 OR 節煙 OR 呼吸法"
        guard let encodedHatenaQuery = hatenaQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let hatenaURL = URL(string: "https://b.hatena.ne.jp/q/\(encodedHatenaQuery)?mode=rss&sort=recent") else {
            return
        }
        
        // async let を使って並列取得
        async let googleData = fetchRawData(from: googleURL)
        async let hatenaData = fetchRawData(from: hatenaURL)
        
        let (googleRaw, hatenaRaw) = await (googleData, hatenaData)
        
        var allFetchedArticles: [Article] = []
        
        if let gData = googleRaw {
            let googleArticles = RSSParser().parse(data: gData)
            allFetchedArticles.append(contentsOf: googleArticles)
            print("📰 Google News RSSから \(googleArticles.count) 件取得")
        }
        
        if let hData = hatenaRaw {
            let hatenaArticles = RSSParser().parse(data: hData)
            // Hatenaの記事は source を "はてなブックマーク" もしくはドメインにセットする
            let customHatenaArticles = hatenaArticles.map { art in
                var modified = art
                if modified.source.isEmpty || modified.source.contains("b.hatena.ne.jp") {
                    modified = Article(
                        id: modified.id,
                        title: modified.title,
                        source: self.isEnglishUI ? "Hatena Bookmark" : "はてなブックマーク",
                        publishedAt: modified.publishedAt,
                        url: modified.url,
                        description: modified.description,
                        aiSummary: modified.aiSummary,
                        category: modified.category,
                        relevanceScore: modified.relevanceScore,
                        isAIProcessed: modified.isAIProcessed,
                        isAIGenerated: modified.isAIGenerated
                    )
                }
                return modified
            }
            allFetchedArticles.append(contentsOf: customHatenaArticles)
            print("📰 Hatena Bookmark RSSから \(customHatenaArticles.count) 件取得")
        }
        
        // 決定論的IDで重複排除してマージ
        var uniqueArticlesMap: [UUID: Article] = [:]
        for article in allFetchedArticles {
            if uniqueArticlesMap[article.id] == nil {
                uniqueArticlesMap[article.id] = article
            }
        }
        
        // 公開日時の新しい順にソート
        let sortedArticles = uniqueArticlesMap.values.sorted { $0.publishedAt > $1.publishedAt }
        
        if !sortedArticles.isEmpty {
            // 最大件数に制限
            let limitedArticles = Array(sortedArticles.prefix(maxArticleCount))
            articles = limitedArticles
            cacheArticles(limitedArticles)
        }
    }
    
    /// 指定されたURLからRawデータを非同期取得
    private func fetchRawData(from url: URL) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            print("URL読み込みエラー (\(url)): \(error)")
            return nil
        }
    }
    
    /// 記事をキャッシュに保存
    private func cacheArticles(_ articles: [Article]) {
        if let encoded = try? JSONEncoder().encode(articles) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
        }
    }
    
    /// キャッシュから記事を読み込み
    private func loadCachedArticles() -> [Article]? {
        let timestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
        let currentTime = Date().timeIntervalSince1970
        
        // キャッシュが期限切れの場合はnilを返す
        guard currentTime - timestamp < cacheExpiration else {
            return nil
        }
        
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let articles = try? JSONDecoder().decode([Article].self, from: data) else {
            return nil
        }
        
        return articles
    }
    
    /// キャッシュをクリア
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
    }
    
    /// 強制的に最新記事を取得
    func refreshArticles() async {
        clearCache()
        await fetchArticles()
    }
}

// MARK: - RSSパーサー

/// Google News RSSをパースするクラス
private class RSSParser: NSObject, XMLParserDelegate {
    private var articles: [Article] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentSource = ""
    private var currentDescription = ""
    private var isInItem = false
    
    /// RSSデータをパース
    func parse(data: Data) -> [Article] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            currentSource = ""
            currentDescription = ""
        }
        
        // ソース情報を取得
        if elementName == "source", let sourceUrl = attributeDict["url"] {
            // sourceタグの場合、URLからドメイン名を取得
            if let url = URL(string: sourceUrl) {
                currentSource = url.host ?? ""
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else { return }
        
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "link":
            currentLink += trimmed
        case "pubDate", "dc:date", "date":
            currentPubDate += trimmed
        case "source":
            if currentSource.isEmpty {
                currentSource = trimmed
            }
        case "description":
            currentDescription += trimmed
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInItem = false
            
            // 記事を作成
            let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmedLink) {
                let publishedDate = parseDate(currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
                
                // Google Newsの場合、タイトルから「- ソース名」を分離
                let (cleanTitle, extractedSource) = extractSourceFromTitle(currentTitle)
                let finalSource = currentSource.isEmpty ? extractedSource : currentSource
                
                let article = Article(
                    title: cleanTitle,
                    source: finalSource,
                    publishedAt: publishedDate,
                    url: url,
                    description: cleanDescription(currentDescription)
                )
                articles.append(article)
            }
        }
    }
    
    /// 日付文字列をパース
    private func parseDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // ISO8601フォールバック
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    /// タイトルからソース名を抽出
    private func extractSourceFromTitle(_ title: String) -> (cleanTitle: String, source: String) {
        // Google Newsのフォーマット: "記事タイトル - ニュースソース"
        if let range = title.range(of: " - ", options: .backwards) {
            let cleanTitle = String(title[..<range.lowerBound])
            let source = String(title[range.upperBound...])
            return (cleanTitle, source)
        }
        return (title, "")
    }
    
    /// 説明文をクリーンアップ
    private func cleanDescription(_ description: String) -> String? {
        // HTMLタグを除去
        var cleaned = description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // HTMLエンティティをデコード
        cleaned = decodeHTMLEntities(cleaned)
        
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    /// HTMLエンティティをデコード
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        
        // よく使われるHTMLエンティティを置換
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&#x27;", "'"),
            ("&#34;", "\""),
            ("&#x22;", "\""),
            ("&hellip;", "\u{2026}"),  // …
            ("&mdash;", "\u{2014}"),   // —
            ("&ndash;", "\u{2013}"),   // –
            ("&lsquo;", "\u{2018}"),   // '
            ("&rsquo;", "\u{2019}"),   // '
            ("&ldquo;", "\u{201C}"),   // "
            ("&rdquo;", "\u{201D}"),   // "
            ("&bull;", "\u{2022}"),    // •
            ("&copy;", "\u{00A9}"),    // ©
            ("&reg;", "\u{00AE}"),     // ®
            ("&trade;", "\u{2122}"),   // ™
            ("&yen;", "\u{00A5}"),     // ¥
            ("&euro;", "\u{20AC}"),    // €
            ("&pound;", "\u{00A3}"),   // £
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // 数値エンティティ（&#123; 形式）をデコード
        result = decodeNumericEntities(result)
        
        // 連続する空白を1つにまとめる
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        return result
    }
    
    /// 数値エンティティをデコード（&#123; または &#x1F; 形式）
    private func decodeNumericEntities(_ string: String) -> String {
        var result = string
        
        // 10進数エンティティ（&#123;）
        while let range = result.range(of: "&#\\d+;", options: .regularExpression) {
            let entity = String(result[range])
            let numberString = entity.dropFirst(2).dropLast(1)
            if let codePoint = Int(numberString),
               let scalar = Unicode.Scalar(codePoint) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            } else {
                break
            }
        }
        
        // 16進数エンティティ（&#x1F;）
        while let range = result.range(of: "&#[xX][0-9a-fA-F]+;", options: .regularExpression) {
            let entity = String(result[range])
            let hexString = entity.dropFirst(3).dropLast(1)
            if let codePoint = Int(hexString, radix: 16),
               let scalar = Unicode.Scalar(codePoint) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            } else {
                break
            }
        }
        
        return result
    }
}
