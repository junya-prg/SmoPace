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

/// Foundation Models に型付きで生成させる構造化要約 DTO
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedDigest {
    @Guide(description: "記事のいちばん大事な学びや節煙・健康上のメリットを、生活に取り入れやすいやさしい1文に")
    var headline: String

    @Guide(description: "節煙・禁煙・健康管理・生活習慣の観点での要点", .count(3))
    var points: [GeneratedPoint]

    @Guide(description: "今日から実践できる、前向きで具体的な節煙・健康アクションプラン")
    var actionTip: String

    @Guide(description: "記事に関係する短いキーワード", .maximumCount(4))
    var keywords: [String]
}

/// 構造化要約の1ポイント（生成専用）
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedPoint {
    @Guide(description: "5〜10文字程度の短い見出し（例: 吸いたい衝動、代替習慣、呼吸法など）")
    var label: String

    @Guide(description: "見出しを説明する、不安を煽らない具体的で前向きな1文")
    var detail: String
}

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
            return String(localized: "Apple Intelligenceが利用できません。デバイスの設定を確認してください。")
        case .sessionNotAvailable:
            return String(localized: "AIセッションが利用できません")
        case .summarizationFailed(let error):
            return String(format: String(localized: "要約の生成に失敗しました: %@"), error.localizedDescription)
        case .categorizationFailed(let error):
            return String(format: String(localized: "カテゴリ分類に失敗しました: %@"), error.localizedDescription)
        case .relevanceCalculationFailed(let error):
            return String(format: String(localized: "おすすめ度の計算に失敗しました: %@"), error.localizedDescription)
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

    /// 現在のUI言語が英語かどうかを判定
    /// Bundle.main.preferredLocalizationsで実際にアプリが使用している言語を取得
    private var isEnglishUI: Bool {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        return lang.hasPrefix("en")
    }
    
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
            return article.description ?? String(localized: "要約を生成できません")
        }

        let content = article.description ?? article.title

        let instructions: String
        let prompt: String
        if isEnglishUI {
            instructions = """
                You are an assistant that creates summaries of news articles.
                This app supports people trying to reduce or quit smoking.
                Follow these rules:
                - Summarize in 2-3 concise sentences in English
                - Highlight key points from the perspective of someone trying to cut down
                - Include only objective information
                """
            prompt = """
                Please summarize the following news article.

                Title: \(article.title)
                Content: \(content)
                """
        } else {
            instructions = """
                あなたはニュース記事の要約を作成するアシスタントです。
                このアプリは節煙をサポートするアプリです。
                以下のルールに従って要約してください：
                - 日本語で2-3文で簡潔に要約
                - 減らしたい人の観点から重要なポイントを強調
                - 客観的な情報のみを含める
                """
            prompt = """
                以下のニュース記事を要約してください。

                タイトル: \(article.title)
                内容: \(content)
                """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("要約生成エラー: \(error)")
            return article.description ?? String(localized: "要約を生成できませんでした")
        }
    }
    
    // MARK: - 構造化要約生成

    /// 記事を構造化要約（ひとこと要約＋3ポイント＋アクション＋キーワード）に変換
    /// - Parameter article: 要約対象の記事
    /// - Returns: 構造化要約。生成できない場合は nil。
    func generateDigest(article: Article) async -> ArticleDigest? {
        guard _isAvailableCache == true else {
            return nil
        }

        let content = article.description ?? article.title

        let instructions = """
            あなたは喫煙ペースの管理や節煙に関するニュース記事の要約を作成するアシスタントです。
            このアプリはユーザーの節煙や健康的な喫煙ペース管理をサポートすることを目的としています。
            記事を、ユーザーが直感的に読めて実践しやすい「構造化された要約」に整理してください。
            以下のルールに必ず従ってください：
            - すべて日本語で書く
            - 節煙のヒント、代替製品の情報、あるいは健康上のメリットや具体的な改善アクションを最優先で抽出
            - ユーザーにとってポジティブで前向きな表現を使う（不安や恐怖を煽る表現は避ける）
            - 客観的で信頼できる情報のみを含め、元記事に書かれていない事事実を付け足さない
            - headline は記事の最も大事な学びや節煙に役立つポイントを簡潔に表す1文
            - points は記事の要点を3つ。label は短い見出し（5〜10文字）、detail はやさしい説明1文
            - actionTip は日常生活で今日からすぐに実践できる前向きなアクション1文
            - keywords は記事に関係する短い語を最大4つ
            """
        let prompt = """
            以下のニュース記事を、構造化要約に整理してください。

            タイトル: \(article.title)
            内容: \(content)
            """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let generated = try await session.respond(
                to: prompt,
                generating: GeneratedDigest.self
            ).content
            return Self.convert(generated)
        } catch {
            print("🤖 構造化要約生成エラー: \(error)")
            return nil
        }
    }

    /// 生成専用 DTO を永続化・表示用の素の型へ変換
    private static func convert(_ generated: GeneratedDigest) -> ArticleDigest? {
        let headline = generated.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !headline.isEmpty else { return nil }

        let points: [DigestPoint] = generated.points.compactMap { point in
            let label = point.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = point.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty || !detail.isEmpty else { return nil }
            return DigestPoint(label: label, detail: detail)
        }
        guard !points.isEmpty else { return nil }

        let actionTip = generated.actionTip.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = generated.keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return ArticleDigest(
            headline: headline,
            points: points,
            actionTip: actionTip,
            keywords: keywords
        )
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

        // カテゴリは内部rawValueが日本語固定。AIにはrawValueをそのまま返してもらう。
        // 英語UIでは英訳カッコ書きを併記して曖昧さを減らす。
        let instructions: String
        let prompt: String
        if isEnglishUI {
            instructions = """
                You categorize news articles. Reply with exactly one of the following category names (Japanese keywords are the canonical IDs):
                - 新商品 (New products, new devices, releases)
                - 業界 (Industry: taxes, regulations, market, industry trends)
                - 豆知識 (Trivia: tobacco history, culture, fun facts)
                - 節煙 (Quitting / Cutting down)
                - その他 (Other; anything not above)

                Reply with the Japanese category keyword only, nothing else.
                """
            prompt = """
                Classify the following article into the most appropriate category.

                Title: \(article.title)
                Content: \(content)

                Reply with just the Japanese category keyword.
                """
        } else {
            instructions = """
                あなたはニュース記事をカテゴリ分類するアシスタントです。
                以下のカテゴリのいずれかを選んで、カテゴリ名のみを回答してください：
                - 新商品（新製品、新デバイス、発売に関する記事）
                - 業界（税金、規制、市場、業界動向に関する記事）
                - 豆知識（タバコの歴史、豆知識、文化、トリビア、うんちくに関する記事）
                - 節煙（禁煙、減煙、節煙に関する記事）
                - その他（上記に該当しない記事）
                """
            prompt = """
                以下の記事を最も適切なカテゴリに分類してください。

                タイトル: \(article.title)
                内容: \(content)

                カテゴリ名のみを回答してください。
                """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)

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

        let instructions: String
        let prompt: String
        if isEnglishUI {
            let goalInfo = userData.dailyGoal.map { "Daily cap: \($0) per day" } ?? "No cap set"
            let trendInfo = userData.isDecreasing ? "decreasing" : "stable"
            instructions = """
                You rate how useful a news article is for someone managing their smoking pace.
                Consider the user's situation and rate relevance on a 0-100 numeric scale.

                [High score (70-100)]
                - Tips for cutting down or controlling pace
                - Nicotine-free or alternative products
                - New heated-tobacco devices and reviews
                - Articles about managing/controlling consumption
                - Tobacco history, trivia, fun facts
                - Latest industry trends

                [Medium score (30-60)]
                - Tobacco tax / price hikes
                - Smoking regulation trends
                - General statistics

                [Low score (0-30)]
                - Articles thin on substance
                - Articles unrelated to the user's self-management

                Reply with the number only.
                """
            prompt = """
                Rate how relevant this article is to the following user.

                [User]
                - Average cigarettes today: \(userData.averageDailyCount)
                - \(goalInfo)
                - Trend: \(trendInfo)

                [Article]
                Title: \(article.title)
                Content: \(content)

                Reply with just a number from 0 to 100.
                """
        } else {
            let goalInfo = userData.dailyGoal.map { "目標本数: \($0)本/日" } ?? "目標未設定"
            let trendInfo = userData.isDecreasing ? "減少傾向" : "変化なし"
            instructions = """
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
                """
            prompt = """
                以下のユーザーにとって、この記事がどれくらいおすすめか評価してください。

                【ユーザー情報】
                - 1日の平均喫煙本数: \(userData.averageDailyCount)本
                - \(goalInfo)
                - 喫煙傾向: \(trendInfo)

                【記事情報】
                タイトル: \(article.title)
                内容: \(content)

                0から100の数値のみで回答してください。
                """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)

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
        // フォールバックメッセージ（言語別）
        let fallbackMessagesJa = [
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
        let fallbackMessagesEn = [
            "Take a slow breath...",
            "Savor this moment",
            "Calm your mind...",
            "Take a quiet pause",
            "A moment of stillness...",
            "Find your peace",
            "Just relax...",
            "Be present now",
            "Let go gently",
            "Slow it down..."
        ]
        let fallbackMessages = isEnglishUI ? fallbackMessagesEn : fallbackMessagesJa

        guard _isAvailableCache == true else {
            return fallbackMessages.randomElement() ?? fallbackMessages[0]
        }

        let instructions: String
        let prompt: String
        if isEnglishUI {
            instructions = """
                You are an assistant that creates short, soothing messages to help calm the urge to smoke.
                Follow these rules:
                - Generate exactly one short calming phrase (around 5-8 words) in English
                - Use gentle, poetic language
                - Minimal punctuation
                - No extra explanations
                """
            prompt = """
                Generate a short calming phrase to display when someone wants to settle a craving.
                Examples: "Take a deep breath...", "Let this wave pass".
                """
        } else {
            instructions = """
                あなたは吸いたい気持ちを落ち着かせるための癒しメッセージを作成するアシスタントです。
                以下のルールに従ってください：
                - 日本語で短い（10文字以内程度）癒しのフレーズを1つだけ生成
                - 穏やかで詩的な表現
                - 句読点は最小限に
                - 余計な説明は不要
                """
            prompt = """
                吸いたい気持ちを落ち着かせたいときに表示する、短い癒しのフレーズを1つ生成してください。
                「深呼吸して...」「この波をやり過ごそう」のような感じで。
                """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let message = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🤖 生成されたリラックスメッセージ: \(message) (長さ: \(message.count))")
            // 長すぎる場合はフォールバック
            if message.count <= 80 {
                return message
            }
            return fallbackMessages.randomElement() ?? fallbackMessages[0]
        } catch {
            print("リラックスメッセージ生成エラー: \(error)")
            return fallbackMessages.randomElement() ?? fallbackMessages[0]
        }
    }
    
    // MARK: - ランダムコメント生成
    
    /// ユーザーの状況を踏まえた何気ないポジティブなコメントを生成
    /// - Parameter userData: ユーザーの喫煙データ
    /// - Returns: ふわっと表示するコメント
    func generateRandomComment(userData: UserSmokingData?) async -> String {
        let fallbackCommentsJa = [
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
        let fallbackCommentsEn = [
            "Hope you're having a good day",
            "Take it at your own pace",
            "You're doing fine",
            "Let your shoulders drop a little",
            "Are you feeling relaxed?",
            "A peaceful moment",
            "No need to push yourself",
            "Take it easy today",
            "Thanks for showing up today",
            "Time for a little break"
        ]
        let fallbackComments = isEnglishUI ? fallbackCommentsEn : fallbackCommentsJa

        guard _isAvailableCache == true else {
            return fallbackComments.randomElement() ?? fallbackComments[0]
        }

        // ユーザーの状態に応じた少しのコンテキスト
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if isEnglishUI {
            formatter.setLocalizedDateFormatFromTemplate("MMMd EEE HHmm")
        } else {
            formatter.dateFormat = "M月d日(E) H時m分"
        }
        let nowString = formatter.string(from: Date())

        let userContext: String
        let instructions: String
        let prompt: String
        if isEnglishUI {
            var ctx = "Current time: \(nowString)\n"
            if let data = userData {
                ctx += "The user has smoked \(data.averageDailyCount) today. "
                if let total = data.totalRecordsCount {
                    ctx += "Their lifetime total recorded is \(total) cigarettes. "
                }
                if let goal = data.dailyGoal {
                    ctx += "Their daily upper limit is \(goal) (this is a cap to stay under, not a target to reach). "
                    if data.averageDailyCount < goal {
                        let remaining = goal - data.averageDailyCount
                        ctx += "They have \(remaining) more before reaching the cap. "
                    } else {
                        ctx += "They have already reached or exceeded the cap of \(goal). "
                    }
                }
            }
            userContext = ctx
            instructions = """
                You are a warm, supportive AI assistant.
                Follow these rules to generate exactly one very short remark (about 5-12 words):
                - Keep it concise — under about 12 words
                - Use only positive, gentle language
                - Never nag, lecture, or push the user
                - The "goal" is a cap (do-not-exceed), not a target to reach. Avoid framings like "X to go to your goal" — prefer "X under your cap" or "Nice pace".
                - Read the supplied current date/time and greet appropriately for morning/afternoon/evening and the actual weekday (do not reuse stale examples)
                - Occasional short poetic lines are welcome — no commentary needed
                - When the lifetime total reaches a round number (50, 100, 500), briefly acknowledge it
                - Reply in English
                """
            prompt = """
                Generate one casual, positive short message for the user.
                \(userContext)
                Lightly factor in the situation and offer warm words.
                """
        } else {
            var ctx = "現在の日時: \(nowString)\n"
            if let data = userData {
                ctx += "ユーザーは今日\(data.averageDailyCount)本吸っています。"
                if let total = data.totalRecordsCount {
                    ctx += "これまでの総喫煙記録数は\(total)本です。"
                }
                if let goal = data.dailyGoal {
                    ctx += "ユーザーの1日の上限目標は\(goal)本です（目標値に達することが目的ではなく、それ以内に抑えるための上限値です）。"
                    if data.averageDailyCount < goal {
                        let remaining = goal - data.averageDailyCount
                        ctx += "上限まであと\(remaining)本の余裕があります。"
                    } else {
                        ctx += "すでに上限の\(goal)本に達しているか、超えています。"
                    }
                }
            }
            userContext = ctx
            instructions = """
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
                """
            prompt = """
                ユーザー向けの何気ないポジティブな短いメッセージを1つ生成してください。
                \(userContext)
                状況を少しだけ加味しつつも、温かい言葉をかけてください。
                """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let message = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            print("🤖 生成されたランダムコメント: \(message) (長さ: \(message.count))")
            if message.count <= 200 {
                return message
            }
            return fallbackComments.randomElement() ?? fallbackComments[0]
        } catch {
            print("ランダムコメント生成エラー: \(error)")
            return fallbackComments.randomElement() ?? fallbackComments[0]
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
            
            // 構造化要約を優先して生成する
            if let digest = await generateDigest(article: article) {
                processedArticle.summaryDigest = digest
                processedArticle.aiSummary = digest.headline
            } else {
                // 失敗した場合は従来のプレーンテキスト要約にフォールバック
                processedArticle.aiSummary = await summarize(article: article)
            }
            
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
        
        // 構造化要約を優先して生成する
        if let digest = await generateDigest(article: article) {
            processedArticle.summaryDigest = digest
            processedArticle.aiSummary = digest.headline
        } else {
            // 失敗した場合は従来のプレーンテキスト要約にフォールバック
            processedArticle.aiSummary = await summarize(article: article)
        }
        
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
