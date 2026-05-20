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
                Write exactly one short and extremely engaging wellness tip for people pacing or reducing smoking.
                Follow these rules:
                - Output in English
                - Keep the title within 40 characters
                - Keep the body/summary within 2 to 3 sentences (100 to 180 characters)
                - Be positive, encouraging, and science-oriented. Never nag or lecture.
                - Follow this format exactly:
                  Title: [Engaging Title]
                  Body: [Body of the article]
                - Do not output any preamble or conversational greetings.
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
                - 日本語で書く
                - タイトルは22文字以内
                - 本文は120〜200文字（2〜3文）にまとめる
                - 前向きで健康へのメリットを重視し、お説教や恐怖を煽る表現は絶対に避けること
                - 出力フォーマットは以下を厳守する：
                  タイトル: [魅力的なタイトル]
                  本文: [豆知識の本文]
                - フォーマット以外の前置きや挨拶は一切出力しない。
                """
            prompt = """
                次のテーマと切り口で、節煙豆知識を1つ書いてください。
                テーマ: \(topic.ja)
                切り口: \(angle.ja)
                """
        }

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        let raw = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let fallbackTitle = isEnglishUI ? topic.en : topic.ja
        let (title, body) = parseTitleAndBody(from: raw, fallbackTitle: fallbackTitle)

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
            category: .trivia,
            relevanceScore: 1.0,
            isAIProcessed: true,
            isAIGenerated: true
        )
    }

    /// AI出力の「タイトル: 」「本文: 」を安全にパース
    private func parseTitleAndBody(from raw: String, fallbackTitle: String) -> (String, String) {
        var title: String?
        var body: String?

        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Title:") {
                title = String(trimmed.dropFirst("Title:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("title:") {
                title = String(trimmed.dropFirst("title:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("タイトル:") {
                title = String(trimmed.dropFirst("タイトル:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("タイトル：") {
                title = String(trimmed.dropFirst("タイトル：".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Body:") {
                body = String(trimmed.dropFirst("Body:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("body:") {
                body = String(trimmed.dropFirst("body:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("本文:") {
                body = String(trimmed.dropFirst("本文:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("本文：") {
                body = String(trimmed.dropFirst("本文：".count)).trimmingCharacters(in: .whitespaces)
            } else if body != nil {
                body = (body ?? "") + " " + trimmed
            }
        }

        let finalTitle = (title != nil && !title!.isEmpty) ? title! : fallbackTitle
        let finalBody = (body != nil && !body!.isEmpty) ? body! : raw.replacingOccurrences(of: "\n", with: " ")
        return (finalTitle, finalBody)
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
            category: .trivia,
            relevanceScore: 1.0,
            isAIProcessed: true,
            isAIGenerated: true
        )
        return [article]
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
