//
//  FoundationModelsService.swift
//  SmokeCounter
//
//  Foundation Modelsフレームワークを使用したAI処理サービス
//  iOS 26以降でApple Intelligenceのオンデバイスモデルを使用
//

import Foundation
import Combine
import FoundationModels

/// ユーザーのデータ（おすすめ度計算用）
struct UserSmokingData {
    /// 1日の平均本数
    let averageDailyCount: Int
    
    /// 目標本数
    let dailyGoal: Int?
    
    /// 節煙傾向（減少中かどうか）
    let isDecreasing: Bool
    
    /// 今までの総本数
    let totalRecordsCount: Int?
}

// MARK: - エラー定義

/// Foundation Models関連のエラー
enum FoundationModelsError: LocalizedError {
    case modelNotAvailable
    case sessionNotAvailable
    case summarizationFailed(Error)
    case categorizationFailed(Error)
    case relevanceCalculationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Apple Intelligenceが利用できません。デバイスの設定を確認してください。"
        case .sessionNotAvailable:
            return "AIセッションが利用できません"
        case .summarizationFailed(let error):
            return "要約の生成に失敗しました: \(error.localizedDescription)"
        case .categorizationFailed(let error):
            return "カテゴリ分類に失敗しました: \(error.localizedDescription)"
        case .relevanceCalculationFailed(let error):
            return "おすすめ度の計算に失敗しました: \(error.localizedDescription)"
        }
    }
}

// MARK: - Foundation Models実装

/// Foundation Modelsを使用したAI処理サービス
@available(iOS 26.0, macOS 26.0, *)
@MainActor
class FoundationModelsService: ObservableObject {
    /// 処理中かどうか
    @Published private(set) var isProcessing = false
    
    /// エラーメッセージ
    @Published var errorMessage: String?
    
    /// isAvailableのキャッシュ（初回チェック後に保存）
    private var _isAvailableCache: Bool?
    
    /// Foundation Modelsが利用可能かどうか（初期値、UIの初期表示用）
    var isAvailable: Bool {
        // キャッシュがあればそれを返す
        if let cached = _isAvailableCache {
            return cached
        }
        // 初回は常にtrueを返し、実際の処理時にチェック
        return true
    }
    
    /// AIが実際に利用可能かどうか（ensureAIReady後に確定）
    var isActuallyAvailable: Bool {
        return _isAvailableCache ?? false
    }
    
    /// Foundation Modelsの利用可能性を実際にチェック（非同期）
    func checkAvailability() async -> Bool {
        print("🤖 Foundation Models利用可能性チェック中...")
        let available = SystemLanguageModel.default.isAvailable
        print("🤖 Foundation Models isAvailable: \(available)")
        _isAvailableCache = available
        return available
    }
    
    // MARK: - 要約生成
    
    /// 記事を要約
    /// - Parameter article: 要約対象の記事
    /// - Returns: 要約テキスト
    func summarize(article: Article) async -> String {
        guard _isAvailableCache == true else {
            return article.description ?? "要約を生成できません"
        }
        
        let content = article.description ?? article.title
        
        let session = LanguageModelSession(instructions: """
            あなたはニュース記事の要約を作成するアシスタントです。
            このアプリは節煙をサポートするアプリです。
            以下のルールに従って要約してください：
            - 日本語で2-3文で簡潔に要約
            - 減らしたい人の観点から重要なポイントを強調
            - 客観的な情報のみを含める
            """)
        
        do {
            let response = try await session.respond(to: """
                以下のニュース記事を要約してください。
                
                タイトル: \(article.title)
                内容: \(content)
                """)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("要約生成エラー: \(error)")
            return article.description ?? "要約を生成できませんでした"
        }
    }
    
    // MARK: - カテゴリ分類
    
    /// 記事をカテゴリ分類
    /// - Parameter article: 分類対象の記事
    /// - Returns: 記事カテゴリ
    func categorize(article: Article) async -> ArticleCategory {
        guard _isAvailableCache == true else {
            return fallbackCategorize(article: article)
        }
        
        let content = article.description ?? article.title
        
        let session = LanguageModelSession(instructions: """
            あなたはニュース記事をカテゴリ分類するアシスタントです。
            以下のカテゴリのいずれかを選んで、カテゴリ名のみを回答してください：
            - 新商品（新製品、新デバイス、発売に関する記事）
            - 業界（税金、規制、市場、業界動向に関する記事）
            - 豆知識（タバコの歴史、豆知識、文化、トリビア、うんちくに関する記事）
            - 節煙（禁煙、減煙、節煙に関する記事）
            - その他（上記に該当しない記事）
            """)
        
        do {
            let response = try await session.respond(to: """
                以下の記事を最も適切なカテゴリに分類してください。
                
                タイトル: \(article.title)
                内容: \(content)
                
                カテゴリ名のみを回答してください。
                """)
            
            let categoryText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // レスポンスからカテゴリを特定
            for category in ArticleCategory.allCases {
                if categoryText.contains(category.rawValue) {
                    return category
                }
            }
            return .other
        } catch {
            print("カテゴリ分類エラー: \(error)")
            return fallbackCategorize(article: article)
        }
    }
    
    // MARK: - おすすめ度計算
    
    /// おすすめ度を計算
    /// - Parameters:
    ///   - article: 対象の記事
    ///   - userData: ユーザーの喫煙データ
    /// - Returns: おすすめ度（0.0〜1.0）
    func calculateRelevance(article: Article, userData: UserSmokingData?) async -> Double {
        guard _isAvailableCache == true, let userData = userData else {
            return fallbackCalculateRelevance(article: article, userData: userData)
        }
        
        let content = article.description ?? article.title
        let goalInfo = userData.dailyGoal.map { "目標本数: \($0)本/日" } ?? "目標未設定"
        let trendInfo = userData.isDecreasing ? "減少傾向" : "変化なし"
        
        let session = LanguageModelSession(instructions: """
            あなたは喫煙ペースをコントロールしたい人向けのニュースおすすめ度を評価するアシスタントです。
            以下の基準でユーザーの状況を考慮して、記事の関連性を0から100の数値で評価してください。
            
            【高スコア（70〜100）にすべき記事】
            - 節煙・ペースコントロールに役立つ情報
            - ニコチンフリー製品・代替製品の情報
            - 加熱式デバイスの新商品・レビュー
            - 喫煙量の管理・コントロールに関する記事
            - タバコの歴史・豆知識・トリビア
            - 業界の最新動向
            
            【中スコア（30〜60）にすべき記事】
            - タバコの税金・値上げ情報
            - 喫煙規制の動向
            - 一般的な統計情報
            
            【低スコア（0〜30）にすべき記事】
            - 具体的な内容に乏しい記事
            - ユーザーの自己管理に無関係な記事
            
            数値のみを回答してください。
            """)
        
        do {
            let response = try await session.respond(to: """
                以下のユーザーにとって、この記事がどれくらいおすすめか評価してください。
                
                【ユーザー情報】
                - 1日の平均喫煙本数: \(userData.averageDailyCount)本
                - \(goalInfo)
                - 喫煙傾向: \(trendInfo)
                
                【記事情報】
                タイトル: \(article.title)
                内容: \(content)
                
                0から100の数値のみで回答してください。
                """)
            
            let scoreText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 数値を抽出
            let numbers = scoreText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
                .filter { $0 >= 0 && $0 <= 100 }
            
            if let score = numbers.first {
                return Double(score) / 100.0
            }
            return 0.5
        } catch {
            print("おすすめ度計算エラー: \(error)")
            return fallbackCalculateRelevance(article: article, userData: userData)
        }
    }
    
    // MARK: - リラックスメッセージ生成
    
    /// リラックスモード用の癒しのメッセージを生成
    /// - Returns: 気の利いた癒しのメッセージ
    func generateRelaxMessage() async -> String {
        // フォールバックメッセージ
        let fallbackMessages = [
            "ゆっくりと深呼吸...",
            "この瞬間を味わって",
            "心を落ち着けて...",
            "ひと息つきましょう",
            "静かな時間を...",
            "穏やかなひとときを",
            "リラックス...",
            "今この瞬間に集中",
            "心を解き放って",
            "ゆったりと..."
        ]
        
        guard _isAvailableCache == true else {
            return fallbackMessages.randomElement() ?? "ゆっくりと..."
        }
        
        let session = LanguageModelSession(instructions: """
            あなたは吸いたい気持ちを落ち着かせるための癒しメッセージを作成するアシスタントです。
            以下のルールに従ってください：
            - 日本語で短い（10文字以内程度）癒しのフレーズを1つだけ生成
            - 穏やかで詩的な表現
            - 句読点は最小限に
            - 余計な説明は不要
            """)
        
        do {
            let response = try await session.respond(to: """
                吸いたい気持ちを落ち着かせたいときに表示する、短い癒しのフレーズを1つ生成してください。
                「深呼吸して...」「この波をやり過ごそう」のような感じで。
                """)
            let message = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🤖 生成されたリラックスメッセージ: \(message) (長さ: \(message.count))")
            // 長すぎる場合はフォールバック（英語の接頭辞等も考慮して緩和）
            if message.count <= 60 {
                return message
            }
            return fallbackMessages.randomElement() ?? "ゆっくりと..."
        } catch {
            print("リラックスメッセージ生成エラー: \(error)")
            return fallbackMessages.randomElement() ?? "ゆっくりと..."
        }
    }
    
    // MARK: - ランダムコメント生成
    
    /// ユーザーの状況を踏まえた何気ないポジティブなコメントを生成
    /// - Parameter userData: ユーザーの喫煙データ
    /// - Returns: ふわっと表示するコメント
    func generateRandomComment(userData: UserSmokingData?) async -> String {
        let fallbackComments = [
            "今日はいい天気ですね",
            "マイペースでいきましょう",
            "あなたのペースで大丈夫です",
            "少し肩の力を抜いて",
            "リラックスできていますか？",
            "穏やかな時間ですね",
            "無理せずいきましょう",
            "ゆったり過ごしましょう",
            "今日も一日お疲れ様です",
            "ひと休み、ひと休み"
        ]
        
        guard _isAvailableCache == true else {
            return fallbackComments.randomElement() ?? "マイペースでいきましょう"
        }
        
        // ユーザーの状態に応じた少しのコンテキスト
        var userContext = ""
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E) H時m分"
        let nowString = formatter.string(from: Date())
        userContext += "現在の日時: \(nowString)\n"
        
        if let data = userData {
            userContext += "ユーザーは今日\(data.averageDailyCount)本吸っています。"
            if let total = data.totalRecordsCount {
                userContext += "これまでの総喫煙記録数は\(total)本です。"
            }
            if let goal = data.dailyGoal {
                userContext += "ユーザーの1日の上限目標は\(goal)本です（目標値に達することが目的ではなく、それ以内に抑えるための上限値です）。"
                if data.averageDailyCount < goal {
                    let remaining = goal - data.averageDailyCount
                    userContext += "上限まであと\(remaining)本の余裕があります。"
                } else {
                    userContext += "すでに上限の\(goal)本に達しているか、超えています。"
                }
            }
        }
        
        let session = LanguageModelSession(instructions: """
            あなたはユーザーに寄り添うAIアシスタントです。
            以下のルールに従って、全体で10〜20文字程度の非常に短い独り言やコメントを1つだけ生成してください：
            - 文字数はなるべく20文字以内に収めること（簡潔に）
            - ポジティブな表現のみを使用する
            - ユーザーに何かを催促したり、説教したりしない
            - 「目標」は到達すべきノルマではなく、「これ以上は吸わない」という上限を意味します。「目標まであと〇本」という表現はノルマのように聞こえるため避け、「上限まであと〇本」や「良いペースですね」といった表現にしてください
            - コンテキストに渡された「現在の日時」を正しく読み取り、朝・昼・夜や実際の曜日に合った挨拶をすること（過去の例文などをそのまま使わないでください）
            - たまに短い俳句を生成しても良いですが、その場合も解説は不要です
            - 喫煙総本数が50本、100本、500本などのキリの良い数字の時は、短くお祝いする
            - 日本語で回答する
            """)
        
        do {
            let response = try await session.respond(to: """
                ユーザー向けの何気ないポジティブな短いメッセージを1つ生成してください。
                \(userContext)
                状況を少しだけ加味しつつも、温かい言葉をかけてください。
                """)
            let message = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("🤖 生成されたランダムコメント: \(message) (長さ: \(message.count))")
            // あまりに長い場合はフォールバック（俳句やポエム、英語の接頭辞等も考慮して大幅に緩和）
            if message.count <= 120 {
                return message
            }
            return fallbackComments.randomElement() ?? "マイペースでいきましょう"
        } catch {
            print("ランダムコメント生成エラー: \(error)")
            return fallbackComments.randomElement() ?? "マイペースでいきましょう"
        }
    }
    
    // MARK: - 一括処理
    
    /// 複数の記事を一括処理
    /// - Parameters:
    ///   - articles: 処理対象の記事配列
    ///   - userData: ユーザーの喫煙データ
    /// - Returns: AI処理済みの記事配列
    func processArticles(_ articles: [Article], userData: UserSmokingData?) async -> [Article] {
        isProcessing = true
        defer { isProcessing = false }
        
        print("🤖 processArticles開始: \(articles.count)件の記事")
        
        // AIの準備（初回のみテスト実行）
        await ensureAIReady()
        
        guard _isAvailableCache == true else {
            print("🤖 AIが利用できないため、フォールバック処理を使用します")
            return processArticlesWithFallback(articles, userData: userData)
        }
        
        print("🤖 Foundation Modelsを使用してAI処理を開始")
        var processedArticles: [Article] = []
        
        for (index, article) in articles.enumerated() {
            print("🤖 記事 \(index + 1)/\(articles.count) を処理中: \(article.title.prefix(30))...")
            var processedArticle = article
            
            // カテゴリ分類
            processedArticle.category = await categorize(article: article)
            
            // 要約生成
            processedArticle.aiSummary = await summarize(article: article)
            
            // おすすめ度計算
            processedArticle.relevanceScore = await calculateRelevance(article: article, userData: userData)
            
            processedArticles.append(processedArticle)
        }
        
        print("🤖 processArticles完了")
        // おすすめ度でソート
        return processedArticles.sorted { ($0.relevanceScore ?? 0) > ($1.relevanceScore ?? 0) }
    }
    
    // MARK: - 1件ずつ処理（ストリーミング用）
    
    /// 1件の記事をAI処理
    /// - Parameters:
    ///   - article: 処理対象の記事
    ///   - userData: ユーザーの喫煙データ
    /// - Returns: AI処理済みの記事
    func processOneArticle(_ article: Article, userData: UserSmokingData?) async -> Article {
        // AIが利用できない場合はフォールバック
        guard _isAvailableCache == true else {
            return processOneArticleWithFallback(article, userData: userData)
        }
        
        var processedArticle = article
        
        // カテゴリ分類
        processedArticle.category = await categorize(article: article)
        
        // 要約生成
        processedArticle.aiSummary = await summarize(article: article)
        
        // おすすめ度計算
        processedArticle.relevanceScore = await calculateRelevance(article: article, userData: userData)
        
        // AI処理済みフラグを設定
        processedArticle.isAIProcessed = true
        
        return processedArticle
    }
    
    /// 1件の記事をフォールバック処理
    private func processOneArticleWithFallback(_ article: Article, userData: UserSmokingData?) -> Article {
        var processedArticle = article
        processedArticle.category = fallbackCategorize(article: article)
        processedArticle.aiSummary = nil  // フォールバック時はaiSummaryをnilにして、descriptionを使う
        processedArticle.relevanceScore = fallbackCalculateRelevance(article: article, userData: userData)
        processedArticle.isAIProcessed = false  // フォールバック処理
        return processedArticle
    }
    
    /// AIの初期チェックを実行（最初の1回だけ）
    /// 注意: isAvailableチェックをスキップして直接テストする（日本語環境対応）
    func ensureAIReady() async {
        if _isAvailableCache == nil {
            // isAvailableチェックをスキップして直接テスト
            // （日本語環境でisAvailable=falseでも実際には動作する可能性があるため）
            print("🤖 AI準備チェック開始（isAvailableスキップ方式）")
            let systemAvailable = SystemLanguageModel.default.isAvailable
            print("🤖 SystemLanguageModel.default.isAvailable: \(systemAvailable)（参考値）")
            
            // 直接テスト実行
            let testResult = await testAIAvailability()
            _isAvailableCache = testResult
            print("🤖 AI実際の動作テスト結果: \(testResult)")
        }
    }
    
    /// Foundation Modelsが実際に動作するかテスト（タイムアウト付き）
    /// 日本語でテストを実行して、日本語環境での動作を確認
    private func testAIAvailability() async -> Bool {
        print("🤖 AIテスト開始（日本語プロンプト）")
        
        do {
            // withThrowingTaskGroupでタイムアウトを実装
            return try await withThrowingTaskGroup(of: Bool.self) { group in
                // AIリクエストタスク
                group.addTask {
                    do {
                        // 日本語のinstructionsでセッションを作成
                        let session = LanguageModelSession(instructions: "日本語で簡潔に回答してください。")
                        let response = try await session.respond(to: "「了解」と返答してください。")
                        print("🤖 AIテスト成功: \(response.content.prefix(30))...")
                        return true
                    } catch {
                        print("🤖 AIテストエラー: \(error)")
                        return false
                    }
                }
                
                // タイムアウトタスク（8秒に延長）
                group.addTask {
                    try await Task.sleep(nanoseconds: 8_000_000_000)
                    print("🤖 AIテストタイムアウト（8秒）")
                    throw CancellationError()
                }
                
                // 最初に完了したタスクの結果を使用
                guard let result = try await group.next() else {
                    return false
                }
                group.cancelAll()
                return result
            }
        } catch {
            print("🤖 AIテスト失敗: \(error)")
            return false
        }
    }
    
    /// フォールバック処理で記事を一括処理（AI不使用）
    private func processArticlesWithFallback(_ articles: [Article], userData: UserSmokingData?) -> [Article] {
        var processedArticles: [Article] = []
        
        for article in articles {
            var processedArticle = article
            
            // キーワードベースでカテゴリ分類
            processedArticle.category = fallbackCategorize(article: article)
            
            // descriptionを要約として使用
            processedArticle.aiSummary = article.description
            
            // シンプルなおすすめ度計算
            processedArticle.relevanceScore = fallbackCalculateRelevance(article: article, userData: userData)
            
            processedArticles.append(processedArticle)
        }
        
        // おすすめ度でソート
        return processedArticles.sorted { ($0.relevanceScore ?? 0) > ($1.relevanceScore ?? 0) }
    }
    
    // MARK: - フォールバック処理
    
    /// キーワードベースのカテゴリ分類（フォールバック）
    private func fallbackCategorize(article: Article) -> ArticleCategory {
        let text = (article.title + " " + (article.description ?? "")).lowercased()
        
        if text.contains("新") || text.contains("発売") || text.contains("新商品") || text.contains("製品") || text.contains("デバイス") {
            return .newProducts
        } else if text.contains("税") || text.contains("値上げ") || text.contains("業界") || text.contains("市場") || text.contains("規制") {
            return .industry
        } else if text.contains("歴史") || text.contains("文化") || text.contains("豆知識") || text.contains("トリビア") || text.contains("うんちく") || text.contains("起源") {
            return .trivia
        } else if text.contains("禁煙") || text.contains("節煙") || text.contains("減煙") || text.contains("やめ") {
            return .quitting
        }
        return .other
    }
    
    /// シンプルなおすすめ度計算（フォールバック）
    /// 喫煙ペース管理者向けにスコアリング
    private func fallbackCalculateRelevance(article: Article, userData: UserSmokingData?) -> Double {
        var score = 0.5
        let text = (article.title + " " + (article.description ?? "")).lowercased()
        
        // 節煙・コントロール関連に最高加点
        if text.contains("禁煙") || text.contains("節煙") || text.contains("コントロール") || text.contains("管理") || text.contains("減らす") {
            score += 0.3
        }
        if text.contains("ニコチンフリー") || text.contains("代替") || text.contains("置き換え") {
            score += 0.25
        }
        // 関連性の高い情報に加点
        if text.contains("新商品") || text.contains("新製品") || text.contains("発売") || text.contains("新型") {
            score += 0.2
        }
        if text.contains("レビュー") || text.contains("比較") || text.contains("おすすめ") {
            score += 0.15
        }
        if text.contains("iqos") || text.contains("ploom") || text.contains("glo") {
            score += 0.15
        }
        if text.contains("文化") || text.contains("歴史") || text.contains("豆知識") {
            score += 0.1
        }
        if text.contains("健康被害") || text.contains("リスク") || text.contains("警告") || text.contains("有害") {
            score -= 0.1
        }
        
        // 新しい記事に加点
        let hoursSincePublished = Date().timeIntervalSince(article.publishedAt) / 3600
        if hoursSincePublished < 24 {
            score += 0.1
        }
        
        return min(max(score, 0.0), 1.0)
    }
}

// MARK: - サービスファクトリ

/// AI処理サービスのファクトリ
@available(iOS 26.0, macOS 26.0, *)
struct AIServiceFactory {
    /// AI処理サービスを取得
    @MainActor
    static func createService() -> FoundationModelsService {
        return FoundationModelsService()
    }
}
