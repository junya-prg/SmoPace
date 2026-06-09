//
//  PaceTriviaGenerator.swift
//  Smoker
//
//  今日の節煙・健康豆知識を Foundation Models（Apple Intelligence）で生成するサービス
//  - シード辞書（テーマ × 切り口）から日替わりで組み合わせを選び、AIにオリジナル記事を書かせる
//  - 生成結果はその日の分だけ UserDefaults にキャッシュし、同日内は常に同じ内容が表示されるようにする
//  - AIが利用できない場合は、高品質な英語・日本語のプリセット記事から日替わりでフォールバック表示する
//

import Foundation
import os
import FoundationModels

private let logger = Logger(subsystem: "jp.junya.SmoPace", category: "PaceTriviaGenerator")

// MARK: - 豆知識のテーマ・切り口シード辞書

/// 節煙・健康習慣に関する普遍的なテーマ（日英対応）
private struct TriviaTopic {
    let ja: String
    let en: String
}

private let triviaTopics: [TriviaTopic] = [
    // 習慣・行動コントロール系
    TriviaTopic(ja: "深呼吸による自律神経の整え方と吸いたい衝動の緩和", en: "How deep breathing regulates the autonomic nervous system and eases cravings"),
    TriviaTopic(ja: "吸いたくなったときに効果的な1分間マインドフルネス呼吸法", en: "An effective 1-minute mindfulness breathing technique for sudden cravings"),
    TriviaTopic(ja: "朝一番のコップ一杯の水がもたらす清涼感と体内リセット", en: "The refreshing reset of drinking a glass of water first thing in the morning"),
    TriviaTopic(ja: "有酸素運動（早歩き）が肺活量と脳のすっきりに与える好影響", en: "The positive impact of aerobic exercise (brisk walking) on lung capacity and mood"),
    TriviaTopic(ja: "タバコの代わりになる爽快なミントハーブティーの選び方", en: "Choosing refreshing mint herbal teas as a healthy smoking alternative"),
    TriviaTopic(ja: "「吸いたい」波が通り過ぎるまでの時間はわずか3〜5分という事実", en: "The scientific fact that a smoking craving wave passes in just 3 to 5 minutes"),
    TriviaTopic(ja: "口寂しさを解消するための健康的シュガーレスガムの効能", en: "The cognitive benefits of sugar-free gum for managing oral fixation"),
    TriviaTopic(ja: "節煙を強力にサポートする良質な睡眠環境の整え方", en: "How to set up a sleep environment to strongly support pacing smoking"),
    TriviaTopic(ja: "タバコを持っていた「手の習慣」を代替するおすすめストレスボール", en: "Replacing the 'hand habit' of holding a cigarette with a stress ball"),
    TriviaTopic(ja: "冷たい炭酸水が喉を刺激して吸いたい気持ちを吹き飛ばす仕組み", en: "How cold sparkling water stimulates the throat to blow away cravings"),

    // 身体・健康メカニズム系
    TriviaTopic(ja: "ニコチンが完全に体（血液）から抜けきるまでに必要な時間", en: "The timeline of how long it takes for nicotine to completely leave the bloodstream"),
    TriviaTopic(ja: "タバコを控えて20分後から始まる血圧・脈拍の健康的な正常化", en: "How blood pressure and pulse normalize starting just 20 minutes after reduction"),
    TriviaTopic(ja: "節煙によって肺の繊毛運動が回復し呼吸が楽になるサイクル", en: "The recovery of lung cilia and easier breathing through reducing smoking"),
    TriviaTopic(ja: "一酸化炭素が減ることで全身の細胞に酸素が生き渡る爽快感", en: "The refreshing energy of oxygen reaching all cells as carbon monoxide drops"),
    TriviaTopic(ja: "タバコを減らすと味覚・嗅覚が研ぎ澄まされご飯が美味しくなる理由", en: "Why reducing cigarettes sharpens taste and smell, making food taste amazing"),
    TriviaTopic(ja: "ニコチンが脳の報酬系に与える一時的なすっきりの錯覚の正体", en: "The truth behind the temporary stress-relief illusion nicotine creates in the brain"),
    TriviaTopic(ja: "節煙が進むことで肌の血行が劇的に良くなりツヤが戻るスピード", en: "How skin circulation dramatically improves and glow returns with lower smoking"),
    TriviaTopic(ja: "タバコと自律神経：タバコが実際にはストレスを増やしている真実", en: "Cigarettes and nerves: The truth that smoking actually increases internal stress"),
    TriviaTopic(ja: "肺年齢を若く保つことが将来のスタミナと若々しさに直結する理由", en: "Why keeping lungs young directly affects your future stamina and youthfulness"),
    TriviaTopic(ja: "ビタミンCがニコチンによって破壊されるのを防ぐための緑黄色野菜", en: "Eating colorful vegetables to protect Vitamin C from being depleted by nicotine"),

    // お金・社会的メリット・歴史系
    TriviaTopic(ja: "タバコを1日5本減らすことで1年間に浮く具体的な金額と使い道", en: "The concrete annual savings of cutting down 5 cigarettes a day and fun ways to spend it"),
    TriviaTopic(ja: "節約できたタバコ代で自分にご褒美（ちょっと高級なコーヒーや本）", en: "Rewarding yourself with premium coffee or books using saved cigarette money"),
    TriviaTopic(ja: "欧米の先住民とタバコの歴史：元々は儀式用の清らかな神聖なハーブだった", en: "The history of native cultures and tobacco: Originally a sacred herb for ceremony"),
    TriviaTopic(ja: "世界の美しいクリーンエア都市と禁煙先進国の取り組み", en: "Beautiful clean-air cities around the world and their wellness initiatives"),
    TriviaTopic(ja: "オフィスや家の中にタバコの臭いがないことによる第一印象の向上", en: "Improving first impressions by keeping your office and clothes entirely odor-free"),
    TriviaTopic(ja: "節煙ペースを誰かと共有することで達成率が劇的にアップする心理学", en: "The psychology of sharing your pacing progress to dramatically boost success rate"),
    TriviaTopic(ja: "タバコのパッケージデザインの歴史と消費者を惹きつける色彩科学", en: "The history of cigarette package designs and the color science behind them"),
    TriviaTopic(ja: "禁煙・節煙がもたらす『自己コントロール感』が自信を育む仕組み", en: "How the sense of self-control from smoking reduction builds strong confidence")
]

/// 豆知識の切り口・プロンプトスタイル
private struct TriviaAngle {
    let ja: String
    let en: String
}

private let triviaAngles: [TriviaAngle] = [
    TriviaAngle(ja: "科学的なデータや数字をやさしく紹介して", en: "friendly scientific data and concrete numbers"),
    TriviaAngle(ja: "朝のセルフケアに今すぐ活かせる実践的な形で", en: "a practical tip that can be used immediately in morning self-care"),
    TriviaAngle(ja: "夜のリラックスタイムに思い出すと心が落ち着くお話として", en: "a soothing story that calms the mind during night relaxation"),
    TriviaAngle(ja: "問いかけから始まり、答えを解説するQ&A形式で", en: "a Q&A format starting with an engaging question followed by a clear answer"),
    TriviaAngle(ja: "優しく背中を押す、温かい応援メッセージを込めて", en: "a warm, encouraging message that gently cheers the user on"),
    TriviaAngle(ja: "歴史や異文化の意外な面白いエピソードとして", en: "a surprising and fascinating historical or cultural episode"),
    TriviaAngle(ja: "吸いたい衝動をゲームのようにクリアするハックとして", en: "a fun, gamified life hack to overcome sudden cravings"),
    TriviaAngle(ja: "体に起こる素晴らしいメリットを具体的にイメージさせて", en: "a vivid description of the wonderful physical benefits happening inside")
]

// MARK: - キャッシュ構造

@MainActor
private final class PaceTriviaCache {
    private struct Stored: Codable {
        let dateKey: String
        let articles: [Article]
    }

    private let storageKey = "paceNews.triviaCache.v1"

    /// 今日の日付キー（端末ローカル時刻）
    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// 当日分のキャッシュを取得
    func loadToday() -> [Article]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return nil
        }
        guard stored.dateKey == Self.todayKey() else { return nil }
        
        // マイグレーション: 古いテキスト版のキャッシュ（summaryDigest が nil）は破棄して再生成を促す
        if stored.articles.contains(where: { $0.summaryDigest == nil }) {
            return nil
        }
        
        return stored.articles
    }

    /// 当日分として保存
    func save(_ articles: [Article]) {
        let stored = Stored(dateKey: Self.todayKey(), articles: articles)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - 生成サービス

/// ペース豆知識記事を生成する構造化 DTO
@available(iOS 26.0, macOS 26.0, *)
@Generable
struct GeneratedTrivia {
    @Guide(description: "豆知識の魅力的なタイトル（日本語で22文字以内、英語なら40文字以内）")
    var title: String

    @Guide(description: "豆知識の要約（ひとこと、3つの要点、実践アクション、キーワード）")
    var digest: GeneratedDigest
}

/// ペース豆知識記事を生成するサービス
@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class PaceTriviaGenerator {
    static let shared = PaceTriviaGenerator()

    /// AI利用可否を確認するための FoundationModelsService
    private let aiService = FoundationModelsService()
    
    /// 当日分の豆知識キャッシュ
    private let cache = PaceTriviaCache()

    private var isEnglishUI: Bool {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        return lang.hasPrefix("en")
    }

    private init() {}

    /// 今日の豆知識記事を取得（キャッシュがあればそれを返し、なければ生成）
    func generateDailyTrivia() async -> [Article] {
        // キャッシュ確認
        if let cached = cache.loadToday(), !cached.isEmpty {
            logger.notice("🧠 当日分の節煙豆知識キャッシュを利用: \(cached.count)件")
            return cached
        }

        // AI 利用可否を確認
        await aiService.ensureAIReady()
        guard aiService.isActuallyAvailable else {
            logger.notice("🧠 AI が利用できないため、プリセットから今日の豆知識を生成")
            let fallback = generateFallbackTrivia()
            cache.save(fallback)
            return fallback
        }

        // 日付シードで組み合わせを1組決定論的に選出
        let seed = Self.dailySeed()
        var rng = SeededRandomNumberGenerator(seed: seed)
        
        let topicIndex = Int(rng.next() % UInt64(triviaTopics.count))
        let angleIndex = Int(rng.next() % UInt64(triviaAngles.count))
        
        let topic = triviaTopics[topicIndex]
        let angle = triviaAngles[angleIndex]

        do {
            let article = try await generateOne(topic: topic, angle: angle, seed: seed)
            let result = [article]
            cache.save(result)
            return result
        } catch {
            logger.notice("🧠 AI 豆知識生成エラー: \(error.localizedDescription)。プリセットにフォールバックします。")
            let fallback = generateFallbackTrivia()
            cache.save(fallback)
            return fallback
        }
    }

    // MARK: - 内部処理

    /// 1件の豆知識を Apple Intelligence に生成させる
    private func generateOne(topic: TriviaTopic, angle: TriviaAngle, seed: UInt64) async throws -> Article {
        let now = Date()
        
        let instructions: String
        let prompt: String
        
        if isEnglishUI {
            instructions = """
                You are a supportive, high-end lifestyle coach helper for "SmoPace", a smoking reduction app.
                Write a short and extremely engaging wellness tip for people pacing or reducing smoking.
                Follow these rules:
                - Output in English
                - title should be an engaging title within 40 characters
                - digest.headline should summarize the main point in 1 sentence
                - digest.points should have 3 key takeaways with short labels and details
                - digest.actionTip should be a practical lifestyle tip to do today
                - digest.keywords should contain up to 4 tags
                """
            prompt = """
                Please write a short pacing smoking trivia article.
                Topic: \(topic.en)
                Tone/Angle: Write in \(angle.en)
                """
        } else {
            instructions = """
                あなたは節煙・健康管理アプリ「SmoPace」の心強いパーソナルコーチです。
                喫煙ペースを上手くコントロールしたいと取り組んでいるユーザー向けに、モチベーションが上がって役に立つ豆知識を1つ書いてください。
                以下のルールに厳密に従ってください：
                - すべて日本語で書く
                - title は魅力的なタイトル（22文字以内）
                - digest.headline は豆知識の最も大事なメッセージを簡潔に表す1文
                - digest.points は豆知識の要点を3つ（見出しは5〜10文字、説明はやさしい1文）
                - digest.actionTip は日常生活で今日からすぐに実践できる前向きなアクション1文
                - digest.keywords は関連する短い語を最大4つ
                """
            prompt = """
                次のテーマと切り口で、節煙豆知識を1つ書いてください。
                テーマ: \(topic.ja)
                切り口: \(angle.ja)
                """
        }

        let session = LanguageModelSession(instructions: instructions)
        let generated = try await session.respond(
            to: prompt,
            generating: GeneratedTrivia.self
        ).content
        
        let title = generated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = Self.convert(generated.digest)
        let body = digest?.headline ?? (isEnglishUI ? topic.en : topic.ja)

        let dateKey = PaceTriviaCache.todayKey()
        let urlString = "smopace://trivia/\(dateKey)/\(Double(seed))"
        let url = URL(string: urlString) ?? URL(string: "smopace://trivia/\(UUID().uuidString)")!

        return Article(
            title: title,
            source: isEnglishUI ? "Pace Coach AI" : "ペースコーチAI",
            publishedAt: now,
            url: url,
            description: body,
            aiSummary: body,
            summaryDigest: digest,
            category: .trivia,
            relevanceScore: 1.0,
            isAIProcessed: true,
            isAIGenerated: true
        )
    }

    // MARK: - プリセット・フォールバック豆知識

    /// AI非搭載または失敗時に日替わりで表示するプリセット豆知識
    private func generateFallbackTrivia() -> [Article] {
        let seed = Self.dailySeed()
        var rng = SeededRandomNumberGenerator(seed: seed)
        
        let index = Int(rng.next() % UInt64(presets.count))
        let preset = presets[index]
        
        let dateKey = PaceTriviaCache.todayKey()
        let urlString = "smopace://trivia/preset/\(dateKey)/\(index)"
        let url = URL(string: urlString)!
        
        let title = isEnglishUI ? preset.titleEn : preset.titleJa
        let body = isEnglishUI ? preset.bodyEn : preset.bodyJa
        
        let article = Article(
            title: title,
            source: isEnglishUI ? "Pace Coach" : "ペースコーチ",
            publishedAt: Date(),
            url: url,
            description: body,
            aiSummary: body,
            summaryDigest: fallbackDigest(forIndex: index, isEnglish: isEnglishUI),
            category: .trivia,
            relevanceScore: 1.0,
            isAIProcessed: true,
            isAIGenerated: true
        )
        return [article]
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

    private func fallbackDigest(forIndex index: Int, isEnglish: Bool) -> ArticleDigest {
        if isEnglish {
            switch index {
            case 0:
                return ArticleDigest(
                    headline: "Craving peaks last only 3-5 minutes. Ride them out with the 4-7-8 breathing method.",
                    points: [
                        DigestPoint(label: "Craving Peak", detail: "The intense urge to smoke usually subsides naturally within 3 to 5 minutes."),
                        DigestPoint(label: "4-7-8 Method", detail: "Inhale for 4 seconds, hold for 7, and exhale for 8 to calm your nerves."),
                        DigestPoint(label: "Mental Rest", detail: "Repeating this three times helps restore deep relaxation and focus.")
                    ],
                    actionTip: "Close your eyes and take three slow, deep breaths next time you feel a craving.",
                    keywords: ["Breathing", "Craving Control", "Relaxation", "Mindfulness"]
                )
            case 1:
                return ArticleDigest(
                    headline: "Your body begins restoring and healing itself starting just 20 minutes after your last cigarette.",
                    points: [
                        DigestPoint(label: "20 Minutes", detail: "Your heart rate and blood pressure drop back to normal levels."),
                        DigestPoint(label: "8 Hours", detail: "Carbon monoxide levels decrease by half, restoring oxygen levels."),
                        DigestPoint(label: "Self-Healing", detail: "Your body starts cleansing itself immediately without you realizing it.")
                    ],
                    actionTip: "Reflect on how your body gets cleaner with every passing minute since your last smoke.",
                    keywords: ["Recovery", "Blood Pressure", "Oxygen Levels", "Cleansing"]
                )
            case 2:
                return ArticleDigest(
                    headline: "Saving just 5 cigarettes a day accumulates to over $540 of savings in a single year.",
                    points: [
                        DigestPoint(label: "Daily Pacing", detail: "Reducing your daily count by just 5 is achievable and stress-free."),
                        DigestPoint(label: "Annual Savings", detail: "You will save around $540 annually by cutting down just a bit."),
                        DigestPoint(label: "Reward Yourself", detail: "Use the saved money on books, premium coffee, or a special dinner.")
                    ],
                    actionTip: "Write down one reward you want to buy with your saved tobacco money.",
                    keywords: ["Savings", "Self-Investment", "Rewards", "Motivation"]
                )
            case 3:
                return ArticleDigest(
                    headline: "Quench sudden cravings by stimulating your throat with cold sparkling water.",
                    points: [
                        DigestPoint(label: "Cold Carbonation", detail: "Ice-cold carbonated water provides a sharp throat kick that replaces smoking sensory cues."),
                        DigestPoint(label: "Oral Fixation", detail: "The fizzy sensation satisfies the mouth-feel urge directly."),
                        DigestPoint(label: "Sensory Reset", detail: "The carbonated kick overrides and resets craving signals in the brain.")
                    ],
                    actionTip: "Keep a bottle of extra-fizzy carbonated water in your fridge or grab one nearby.",
                    keywords: ["Sparkling Water", "Throat Kick", "Sensory Reset", "Fidgeting"]
                )
            case 4:
                return ArticleDigest(
                    headline: "Satisfy fidgeting hands by replacing the holding habit with a stress ball.",
                    points: [
                        DigestPoint(label: "Hand Memory", detail: "Cravings are often just physical habits of wanting to hold a cigarette."),
                        DigestPoint(label: "Alternative Action", detail: "Try spinning a pen or squeezing a tactile stress ball instead."),
                        DigestPoint(label: "Habit Rewriting", detail: "Engaging your hands in a different physical activity weakens the urge.")
                    ],
                    actionTip: "Put a stress ball or tactile toy in your bag so it is always within reach.",
                    keywords: ["Hand Habit", "Stress Ball", "Habit Replacement", "Tactile"]
                )
            case 5:
                return ArticleDigest(
                    headline: "Reducing cigarettes for just 2-3 days regenerates taste buds and sharpens smell.",
                    points: [
                        DigestPoint(label: "Taste Regeneration", detail: "Your taste buds start rebuilding in just a couple of days."),
                        DigestPoint(label: "Better Smell", detail: "Your sense of smell recovers, revealing subtle food aromas."),
                        DigestPoint(label: "Delicious Meals", detail: "Enjoy the true sweetness of rice or the aroma of tea like never before.")
                    ],
                    actionTip: "Take a moment to slowly chew and consciously taste your next meal.",
                    keywords: ["Taste Buds", "Better Smell", "Delicious Food", "Savoring"]
                )
            default:
                return ArticleDigest(
                    headline: "Tobacco was historically used as a sacred purifying herb, not a daily habit.",
                    points: [
                        DigestPoint(label: "Ancient Roots", detail: "Native Americans used tobacco in rare, sacred peace-making ceremonies."),
                        DigestPoint(label: "Not a Daily Routine", detail: "It was never smoked constantly throughout the day in ancient times."),
                        DigestPoint(label: "Sacred Breath", detail: "Respect your lungs and prioritize keeping your breathing clear and pure.")
                    ],
                    actionTip: "Think of tobacco's history and take a moment to keep your breathing clean and clear.",
                    keywords: ["History", "Sacred Herb", "Pure Breathing", "Wellness"]
                )
            }
        } else {
            switch index {
            case 0:
                return ArticleDigest(
                    headline: "吸いたい衝動のピークは3〜5分。4-7-8呼吸法で乗り越えましょう。",
                    points: [
                        DigestPoint(label: "衝動のピーク", detail: "吸いたい気持ちは通常3〜5分で自然と減衰します。"),
                        DigestPoint(label: "4-7-8呼吸法", detail: "4秒吸い、7秒止め、8秒かけて吐く呼吸を行います。"),
                        DigestPoint(label: "自律神経の安定", detail: "これを3回繰り返すことで自律神経が整い、落ち着きを取り戻せます。")
                    ],
                    actionTip: "吸いたくなったら、目を閉じてゆっくり深呼吸を3回繰り返しましょう。",
                    keywords: ["深呼吸", "4-7-8呼吸法", "自律神経", "衝動コントロール"]
                )
            case 1:
                return ArticleDigest(
                    headline: "タバコを控えて20分後から、体は健やかな状態へと回復を始めます。",
                    points: [
                        DigestPoint(label: "20分後の変化", detail: "血圧や脈拍が正常値に戻り始めます。"),
                        DigestPoint(label: "8時間後の変化", detail: "血液中の酸素濃度が回復し、一酸化炭素が減少します。"),
                        DigestPoint(label: "自動的な回復", detail: "体が自動的に本来のクリアな状態へとリセットされ始めます。")
                    ],
                    actionTip: "最後の一本から数分経つたびに、体がきれいになっていることを実感しましょう。",
                    keywords: ["体の回復", "時間経過", "酸素濃度", "脈拍正常化"]
                )
            case 2:
                return ArticleDigest(
                    headline: "1日5本セーブするだけで、年間で約54,000円の節約につながります。",
                    points: [
                        DigestPoint(label: "無理ない節約", detail: "毎日5本減らすだけでストレスなく続けられます。"),
                        DigestPoint(label: "年間の節約額", detail: "年間で約54,000円が浮く計算になります。"),
                        DigestPoint(label: "自分へのご褒美", detail: "浮いたお金で本や高級コーヒーなど、自分にご褒美をあげられます。")
                    ],
                    actionTip: "節約したタバコ代で手に入れたいご褒美を一つリストアップしてみましょう。",
                    keywords: ["節約", "ご褒美", "自己投資", "モチベーション"]
                )
            case 3:
                return ArticleDigest(
                    headline: "吸いたくなったときは、強炭酸水で喉を刺激してリセットしましょう。",
                    points: [
                        DigestPoint(label: "喉へのキック感", detail: "冷たい強炭酸水が喉を通り、吸いたい感覚の代わりになります。"),
                        DigestPoint(label: "口寂しさの解消", detail: "シュワシュワとした感触が口寂しさを満たします。"),
                        DigestPoint(label: "脳のリセット", detail: "炭酸の刺激によって、吸いたい衝動を上書きリセットします。")
                    ],
                    actionTip: "冷蔵庫や近くのコンビニで強炭酸水を用意しておきましょう。",
                    keywords: ["強炭酸水", "喉の刺激", "口寂しさ解消", "感覚上書き"]
                )
            case 4:
                return ArticleDigest(
                    headline: "手の寂しさを解消するために、ストレスボールなどの握力運動を取り入れましょう。",
                    points: [
                        DigestPoint(label: "手の記憶", detail: "吸いたい衝動は、手元にタバコを持つ習慣の記憶からも発生します。"),
                        DigestPoint(label: "代替の動き", detail: "ペンを回したり、お気に入りの握力ボールを動かします。"),
                        DigestPoint(label: "習慣の書き換え", detail: "手の寂しさを別の動作に置き換えることで衝動が和らぎます。")
                    ],
                    actionTip: "カバンの中にストレスボールやスクイーズを一つ入れておきましょう。",
                    keywords: ["手の寂しさ", "ストレスボール", "手の運動", "習慣の書き換え"]
                )
            case 5:
                return ArticleDigest(
                    headline: "喫煙を控えて2〜3日で味蕾が再生し、食事が格段に美味しくなります。",
                    points: [
                        DigestPoint(label: "味蕾の再生", detail: "わずか数日で舌の味蕾が再生し始めます。"),
                        DigestPoint(label: "嗅覚の改善", detail: "嗅覚も劇的に良くなり、食べ物の繊細な香りが分かります。"),
                        DigestPoint(label: "食事の喜び", detail: "ご飯やお茶の甘み、繊細な出汁の香りが実感できるようになります。")
                    ],
                    actionTip: "今日の食事の香りと味を、一口一口ゆっくりと意識して味わってみましょう。",
                    keywords: ["味覚改善", "味蕾", "食事の香り", "美味しさ実感"]
                )
            default:
                return ArticleDigest(
                    headline: "タバコは元々、ネイティブアメリカンが儀式で用いた神聖な薬草でした。",
                    points: [
                        DigestPoint(label: "神聖なルーツ", detail: "昔は場を清め平和を祈るために使われていました。"),
                        DigestPoint(label: "儀式用のハーブ", detail: "現代のように1日に何十回も習慣的に吸うものではありませんでした。"),
                        DigestPoint(label: "清らかな呼吸", detail: "自分の呼吸を清らかに保つ時間を大切にしましょう。")
                    ],
                    actionTip: "タバコのルーツに思いを馳せ、自分の呼吸をクリアに保つ時間を作りましょう。",
                    keywords: ["タバコの歴史", "聖なる薬草", "ネイティブアメリカン", "清らかな呼吸"]
                )
            }
        }
    }

    /// 日付シード
    private static func dailySeed() -> UInt64 {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        let s = formatter.string(from: Date())
        return UInt64(s) ?? 20260521
    }
}

// MARK: - プリセット豆知識データ

private struct PresetTrivia {
    let titleJa: String
    let titleEn: String
    let bodyJa: String
    let bodyEn: String
}

private let presets: [PresetTrivia] = [
    PresetTrivia(
        titleJa: "深呼吸で吸いたい波を乗り越える",
        titleEn: "Ride Cravings Out with Deep Breathing",
        bodyJa: "タバコを吸いたい衝動のピークは3〜5分と言われています。その波が来たら、目を閉じてゆっくり4秒吸い、7秒止め、8秒かけて息を吐く『4-7-8呼吸法』を3回繰り返してみましょう。驚くほど落ち着きを取り戻せます。",
        bodyEn: "The peak of a cigarette craving lasts only 3 to 5 minutes. When a craving strikes, try repeating the '4-7-8 breathing method' three times: breathe in slowly for 4 seconds, hold for 7 seconds, and exhale for 8 seconds. It dramatically calms your nervous system."
    ),
    PresetTrivia(
        titleJa: "20分で始まる体のクリア化",
        titleEn: "Body Cleansing Begins in 20 Minutes",
        bodyJa: "最後のタバコからわずか20分後には、血圧と脈拍が健康な正常値に戻り始めます。さらに8時間経つと血液中の酸素濃度が元通りになり、一酸化炭素が減少します。あなたの体は、あなたが意識しなくても今すぐ回復を始めています！",
        bodyEn: "Just 20 minutes after your last cigarette, your heart rate and blood pressure begin to drop back to normal. Within 8 hours, carbon monoxide levels in your blood decrease by half, and oxygen levels return to normal. Your body is healing right now!"
    ),
    PresetTrivia(
        titleJa: "1日5本減らすと貯まるご褒美",
        titleEn: "The Bright Math of Pacing 5 a Day",
        bodyJa: "もし1日に吸う本数を5本セーブすると、1ヶ月で約4,500円、1年間で約54,000円の節約になります。この浮いたお金で、ずっと欲しかった本や上質なコーヒー豆、旅行のディナーなど、自分を喜ばせる体験に投資してみませんか？",
        bodyEn: "By pacing down just 5 cigarettes a day, you save roughly $45 a month, which is over $540 a year! You can invest this saved money in rewarding experiences for yourself, like purchasing long-desired books, premium coffee beans, or a fancy dinner."
    ),
    PresetTrivia(
        titleJa: "炭酸水の爽快シュワシュワ効果",
        titleEn: "The Sparkling Water Hack",
        bodyJa: "吸いたいなと感じたら、キンキンに冷えた強炭酸水を一口飲むのが効果的です。喉を通るシュワシュワとした強い刺激が、タバコのキック感の代わりになり、口寂しさと脳の錯覚をすっきりとリセットしてくれます。",
        bodyEn: "When you feel a craving, taking a sip of ice-cold carbonated water can work wonders. The sharp, sparkling sensation in your throat acts as a satisfying physical substitute, resetting the brain's craving and leaving you refreshed."
    ),
    PresetTrivia(
        titleJa: "手の寂しさは握力ボールで解決",
        titleEn: "Relieve Hand Fidgeting with a Stress Ball",
        bodyJa: "タバコを吸いたくなる原因の多くは、実は『手持ち無沙汰』という習慣の記憶です。ペンを回したり、お気に入りのスクイーズやストレスボールをカバンに忍ばせておいて、吸いたくなったら手の運動に切り替えてみましょう。",
        bodyEn: "Many cravings are simply the muscular memory of wanting to hold something in your hand. Try keeping a stylish stress ball or squishy toy in your bag, and switch to squeezing it when a craving hits. It effectively tricks the hand habit!"
    ),
    PresetTrivia(
        titleJa: "味覚が生き返るおいしい理由",
        titleEn: "Why Food Starts Tasting Amazing",
        bodyJa: "本数をコントロールすると、わずか2〜3日で舌の味蕾が再生し始め、嗅覚も劇的にシャープになります。普段食べているお米の甘みや、スープの繊細な出汁の香りがはっきりと感じられるようになり、食事が格段に楽しくなりますよ。",
        bodyEn: "When you reduce smoking, the taste buds on your tongue start to regenerate within just 2 to 3 days, and your sense of smell sharpens. You will begin to notice the subtle sweetness of rice and the rich aroma of tea, making your daily meals incredibly delicious."
    ),
    PresetTrivia(
        titleJa: "タバコの元の姿は聖なる薬草？",
        titleEn: "Tobacco's Ancient Sacred Origin",
        bodyJa: "タバコの歴史を遡ると、元々は北米先住民が神聖な儀式や対話の場で、場を清め平和を祈るために用いた高貴な『薬草』でした。現代のように毎日何十回も吸うものではなかったのです。呼吸を清らかに保つ時間を大切にしましょう。",
        bodyEn: "Historically, tobacco was used by Native Americans as a sacred herb in rare peace-making ceremonies to purify the air and connect spirits. It was never inhaled dozens of times a day. Keeping our breathing sacred and clean honors our health."
    )
]

// MARK: - 決定論的乱数生成器

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
