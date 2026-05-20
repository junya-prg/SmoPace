//
//  PaceNewsTracker.swift
//  Smoker
//
//  ニュースの既読・お気に入り管理と、「ペースの苗木（Pace Sprout）」レベルを管理するサービス
//  UserDefaults に永続化することで、アプリ再起動後も状態を復元する
//

import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: "jp.junya.SmoPace", category: "PaceNewsTracker")

// MARK: - ペース・レベル（ペースの苗木）

/// Pace Level の定義
/// 読破数に応じてランクアップし、苗木が大きく成長する
enum PaceLevel: Int, CaseIterable, Comparable {
    case beginner = 0   // 0〜4 記事 (種)
    case explorer = 1   // 5〜14 記事 (双葉)
    case expert = 2     // 15〜29 記事 (若木)
    case master = 3     // 30〜49 記事 (大樹)
    case legend = 4     // 50+ 記事 (天空の大樹)

    static func < (lhs: PaceLevel, rhs: PaceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 表示用のレベル番号（1始まり）
    var displayLevel: Int { rawValue + 1 }

    /// レベル名（ユーザーに見せる愛称）
    var title: String {
        switch self {
        case .beginner: return String(localized: "ペースの種")
        case .explorer: return String(localized: "クリーン・スプラウト")
        case .expert:   return String(localized: "ブリーズ・サプリング")
        case .master:   return String(localized: "ライフ・ツリー")
        case .legend:   return String(localized: "天空のペーストツリー")
        }
    }

    /// レベルの説明
    var levelDescription: String {
        switch self {
        case .beginner: return String(localized: "清らかな息吹への第一歩。節煙と健康の旅が始まりました。")
        case .explorer: return String(localized: "健康的な呼吸と習慣への理解が深まっています。若々しい新芽の成長。")
        case .expert:   return String(localized: "喫煙コントロールとリラックス方法を熟知しています。青々と茂る若木のように。")
        case .master:   return String(localized: "健康的な呼吸と澄み切ったマインドを極めました。周囲に清らかな空気を広げる大樹です。")
        case .legend:   return String(localized: "クリアマインドと究極の健康状態。きらめくオーラを放つ伝説の大樹。")
        }
    }

    /// レベルに対応する SF Symbols アイコン名
    var iconName: String {
        switch self {
        case .beginner: return "leaf.circle"
        case .explorer: return "sprout.fill"
        case .expert:   return "leaf.max.fill"
        case .master:   return "tree.fill"
        case .legend:   return "bubbles.and.sparkles.fill"
        }
    }

    /// アイコンに適用するプライマリ色
    var color: Color {
        switch self {
        case .beginner: return .gray
        case .explorer: return .mint
        case .expert:   return .blue
        case .master:   return .green
        case .legend:   return .purple
        }
    }

    /// このレベルに到達するために必要な読破数（下限）
    var requiredReadCount: Int {
        switch self {
        case .beginner: return 0
        case .explorer: return 5
        case .expert:   return 15
        case .master:   return 30
        case .legend:   return 50
        }
    }

    /// 次のレベル（既に最高レベルの場合は nil）
    var next: PaceLevel? {
        PaceLevel(rawValue: rawValue + 1)
    }

    /// 読破数からレベルを判定
    static func level(for readCount: Int) -> PaceLevel {
        let sortedDescending = PaceLevel.allCases.sorted(by: >)
        for level in sortedDescending where readCount >= level.requiredReadCount {
            return level
        }
        return .beginner
    }
}

// MARK: - ペースニュース・トラッカー

/// 既読・お気に入り・ペースレベルを管理する
@available(iOS 26.0, macOS 26.0, *)
@Observable
@MainActor
final class PaceNewsTracker {
    /// 共有インスタンス
    static let shared = PaceNewsTracker()
    
    /// 既読記事の id 集合
    private(set) var readArticleIDs: Set<UUID> = []

    /// お気に入り記事の id 集合
    private(set) var bookmarkedArticleIDs: Set<UUID> = []

    /// 読んだ記事のカテゴリ集合（網羅率の表示用）
    private(set) var readCategories: Set<ArticleCategory> = []

    /// 直近のレベルアップで上がった「新しいレベル」。
    /// UI 側で監視し、nil でなければアラートを出して直後に nil にリセットする。
    var pendingLevelUp: PaceLevel?

    // MARK: - UserDefaults キー

    private let readArticleIDsKey = "paceNews.readArticleIDs"
    private let bookmarkedArticleIDsKey = "paceNews.bookmarkedArticleIDs"
    private let readCategoriesKey = "paceNews.readCategories"

    // MARK: - 初期化

    private init() {
        load()
    }

    // MARK: - 集計値

    /// 既読記事数
    var totalReadCount: Int {
        readArticleIDs.count
    }

    /// お気に入り数
    var totalBookmarkCount: Int {
        bookmarkedArticleIDs.count
    }

    /// 現在のペースレベル
    var currentLevel: PaceLevel {
        PaceLevel.level(for: totalReadCount)
    }

    /// 次のレベルまでに必要な残り記事数（最大レベル時は 0）
    var articlesUntilNextLevel: Int {
        guard let next = currentLevel.next else { return 0 }
        return max(0, next.requiredReadCount - totalReadCount)
    }

    /// 現在のレベル内での進捗率（0.0〜1.0）。最大レベルでは 1.0 を返す。
    var levelProgress: Double {
        guard let next = currentLevel.next else { return 1.0 }
        let lower = Double(currentLevel.requiredReadCount)
        let upper = Double(next.requiredReadCount)
        let value = Double(totalReadCount)
        let range = upper - lower
        guard range > 0 else { return 1.0 }
        return min(1.0, max(0.0, (value - lower) / range))
    }

    /// カテゴリ網羅率（読んだカテゴリ数 / 全カテゴリ数）
    var categoryCoverageRatio: Double {
        let total = Double(ArticleCategory.allCases.count)
        guard total > 0 else { return 0 }
        return Double(readCategories.count) / total
    }

    // MARK: - 既読操作

    /// 既読かどうか
    func isRead(_ article: Article) -> Bool {
        readArticleIDs.contains(article.id)
    }

    /// 既読としてマーク（初回のみレベル判定）
    /// - Parameter article: 記事
    func markAsRead(_ article: Article) {
        guard !readArticleIDs.contains(article.id) else {
            // 既に既読なら何もしない（カテゴリは更新するチャンスを残す）
            if let category = article.category {
                if !readCategories.contains(category) {
                    readCategories.insert(category)
                    persistReadCategories()
                }
            }
            return
        }

        let previousLevel = currentLevel
        readArticleIDs.insert(article.id)
        persistReadArticleIDs()

        if let category = article.category, !readCategories.contains(category) {
            readCategories.insert(category)
            persistReadCategories()
        }

        let newLevel = currentLevel
        if newLevel > previousLevel {
            logger.notice("🎉 Pace LevelUp: \(previousLevel.title) → \(newLevel.title)")
            pendingLevelUp = newLevel
        }
    }

    // MARK: - お気に入り操作

    /// お気に入りかどうか
    func isBookmarked(_ article: Article) -> Bool {
        bookmarkedArticleIDs.contains(article.id)
    }

    /// お気に入りトグル
    func toggleBookmark(_ article: Article) {
        if bookmarkedArticleIDs.contains(article.id) {
            bookmarkedArticleIDs.remove(article.id)
        } else {
            bookmarkedArticleIDs.insert(article.id)
        }
        persistBookmarkedArticleIDs()
    }

    // MARK: - レベルアップ消費

    /// レベルアップアラートを表示した後に呼び、状態をクリアする
    func consumeLevelUp() {
        pendingLevelUp = nil
    }

    // MARK: - 永続化（読み込み）

    private func load() {
        readArticleIDs = loadUUIDSet(forKey: readArticleIDsKey)
        bookmarkedArticleIDs = loadUUIDSet(forKey: bookmarkedArticleIDsKey)
        readCategories = loadCategorySet(forKey: readCategoriesKey)
        logger.notice("📊 PaceNewsTracker 復元: 既読\(self.readArticleIDs.count)件 / お気に入り\(self.bookmarkedArticleIDs.count)件 / 網羅\(self.readCategories.count)カテゴリ")
    }

    private func loadUUIDSet(forKey key: String) -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let array = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(array)
    }

    private func loadCategorySet(forKey key: String) -> Set<ArticleCategory> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let array = try? JSONDecoder().decode([ArticleCategory].self, from: data) else {
            return []
        }
        return Set(array)
    }

    // MARK: - 永続化（保存）

    private func persistReadArticleIDs() {
        let array = Array(readArticleIDs)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: readArticleIDsKey)
        }
    }

    private func persistBookmarkedArticleIDs() {
        let array = Array(bookmarkedArticleIDs)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: bookmarkedArticleIDsKey)
        }
    }

    private func persistReadCategories() {
        let array = Array(readCategories)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: readCategoriesKey)
        }
    }
}
