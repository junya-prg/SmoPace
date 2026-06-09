//
//  AINewsViewModel.swift
//  SmokeCounter
//
//  AIニュース画面のViewModel
//

import Foundation
import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "SmokeCounter", category: "AINewsViewModel")

/// AIニュース画面のViewModel
@available(iOS 26.0, macOS 26.0, *)
@Observable
@MainActor
class AINewsViewModel {
    /// 記事一覧（AI処理済み）
    var articles: [Article] = []
    
    /// 読み込み中かどうか
    var isLoading = false
    
    /// AI処理中かどうか
    var isProcessingAI = false
    
    /// AIが実際に利用可能かどうか（チェック後に更新）
    var isAIActuallyAvailable: Bool?
    
    /// エラーメッセージ
    var errorMessage: String?
    
    /// 選択中のカテゴリフィルター（nilの場合は全て表示）
    var selectedCategory: ArticleCategory? = nil
    
    /// 記事取得サービス
    private let articleFetchService = ArticleFetchService()
    
    /// AI処理サービス（現在はスタブ実装）
    private let aiService = AIServiceFactory.createService()
    
    /// 進行中の AI 処理タスク（画面遷移でキャンセルされないよう View の `.task` から切り離して保持する）
    private var aiProcessingTask: Task<Void, Never>?
    
    /// AI機能が利用可能かどうか
    /// 注意: iOS 26以降でFoundation Modelsが利用可能になったらtrueを返すように変更
    var isAIAvailable: Bool {
        aiService.isAvailable
    }
    
    /// フィルター済みの記事一覧
    var filteredArticles: [Article] {
        guard let category = selectedCategory else {
            return articles
        }
        return articles.filter { $0.category == category }
    }
    
    /// 全カテゴリ
    var allCategories: [ArticleCategory] {
        ArticleCategory.allCases
    }
    
    /// 記事を取得してAI処理
    /// - Parameter modelContext: SwiftDataのModelContext（ユーザーデータ取得用）
    func loadArticles(modelContext: ModelContext) async {
        logger.notice("📱 loadArticles開始")
        isLoading = true
        errorMessage = nil
        
        // RSSから記事を取得
        logger.notice("📱 RSS記事取得中...")
        await articleFetchService.fetchArticles()
        logger.notice("📱 RSS記事取得完了")
        
        // 取得した記事を取得
        var fetchedArticles = articleFetchService.articles
        logger.notice("📱 取得記事数: \(fetchedArticles.count)")
        
        if fetchedArticles.isEmpty {
            // フォールバック: サンプルデータを使用
            logger.notice("📱 サンプルデータを使用")
            fetchedArticles = Article.sampleArticles
        }
        
        // 今日の豆知識記事を生成して先頭に挿入
        logger.notice("📱 今日の豆知識生成中...")
        let dailyTrivia = await PaceTriviaGenerator.shared.generateDailyTrivia()
        logger.notice("📱 今日の豆知識生成完了: \(dailyTrivia.count)件")
        
        // 重複を避けるため、一旦URLベースでフィルタリングして挿入
        var uniqueArticles = dailyTrivia
        let triviaUrls = Set(dailyTrivia.map { $0.url })
        uniqueArticles.append(contentsOf: fetchedArticles.filter { !triviaUrls.contains($0.url) })
        fetchedArticles = uniqueArticles
        
        // ユーザーの喫煙データを取得
        logger.notice("📱 ユーザーデータ取得中...")
        let userData = fetchUserSmokingData(modelContext: modelContext)
        logger.notice("📱 ユーザーデータ: \(userData != nil ? "あり" : "なし")")
        
        // まず記事を即座に表示（AI処理なし）
        articles = fetchedArticles
        isLoading = false
        logger.notice("📱 記事を即座に表示: \(self.articles.count)件")
        
        // AI 処理は View の `.task` から切り離して独立 Task で実行する。
        // これにより詳細画面への遷移などで `.task` がキャンセルされても処理が継続する。
        startAIProcessingIfNeeded(userData: userData)
    }
    
    /// AI 処理を独立 Task として開始する
    /// すでに走っている場合は何もしない（多重起動防止）
    private func startAIProcessingIfNeeded(userData: UserSmokingData?) {
        if let existing = aiProcessingTask, !existing.isCancelled {
            logger.notice("📱 AI処理は既に実行中のためスキップ")
            return
        }

        let targetArticleIDs = articles.map { $0.id }

        aiProcessingTask = Task { [weak self] in
            guard let self else { return }
            await self.runAIProcessingLoop(for: targetArticleIDs, userData: userData)
        }
    }

    /// 実際の AI 処理ループ。`aiProcessingTask` の中で実行される。
    private func runAIProcessingLoop(for targetArticleIDs: [UUID], userData: UserSmokingData?) async {
        logger.notice("📱 AI準備中...")
        await aiService.ensureAIReady()
        isAIActuallyAvailable = aiService.isActuallyAvailable
        logger.notice("📱 AI利用可能: \(self.isAIActuallyAvailable == true ? "はい" : "いいえ")")

        logger.notice("📱 AI処理開始（独立Task）...")
        isProcessingAI = true
        defer { isProcessingAI = false }

        for (index, articleID) in targetArticleIDs.enumerated() {
            // 既に処理済みの場合はスキップ
            guard let currentIndex = articles.firstIndex(where: { $0.id == articleID }) else {
                continue
            }
            let currentArticle = articles[currentIndex]
            if currentArticle.isAIGenerated || currentArticle.isAIProcessed {
                continue
            }

            logger.notice("📱 記事 \(index + 1)/\(targetArticleIDs.count) を処理中...")
            
            // 処理実行
            let processedArticle = await aiService.processOneArticle(currentArticle, userData: userData)
            
            // 配列の状態は処理中にも変わり得るので、ID で再検索して安全に反映する
            if let targetIndex = articles.firstIndex(where: { $0.id == processedArticle.id }) {
                articles[targetIndex] = processedArticle
            }
            
            // タスクがキャンセルされている場合は中断してリターンする
            if Task.isCancelled {
                logger.notice("📱 AI処理がキャンセルされました（中断）")
                return
            }
        }

        // 最後におすすめ度でソート（ただしAI豆知識記事は常に最上部）
        articles.sort { lhs, rhs in
            if lhs.isAIGenerated != rhs.isAIGenerated {
                return lhs.isAIGenerated // AI生成記事を最優先
            }
            return (lhs.relevanceScore ?? 0) > (rhs.relevanceScore ?? 0)
        }
        logger.notice("📱 AI処理完了・ソート済み: \(self.articles.count)件")
    }

    /// 走っている AI 処理をキャンセル
    private func cancelAIProcessing() {
        aiProcessingTask?.cancel()
        aiProcessingTask = nil
        isProcessingAI = false
    }

    /// 画面再表示時などに「まだ AI 未処理の記事」が残っていれば AI 処理を再開する
    /// View の `.onAppear` などから呼ばれることを想定。多重起動はガードしているので何度呼んでも安全。
    func resumeAIProcessingIfNeeded(modelContext: ModelContext) {
        let hasUnprocessed = articles.contains(where: { !$0.isAIGenerated && !$0.isAIProcessed })
        guard hasUnprocessed else { return }
        
        let userData = fetchUserSmokingData(modelContext: modelContext)
        startAIProcessingIfNeeded(userData: userData)
    }
    
    /// 記事を強制的に更新
    /// - Parameter modelContext: SwiftDataのModelContext
    func refreshArticles(modelContext: ModelContext) async {
        logger.notice("📱 refreshArticles - キャッシュクリア")
        cancelAIProcessing()
        articleFetchService.clearCache()
        await loadArticles(modelContext: modelContext)
    }
    
    /// ユーザーの喫煙データを取得
    /// - Parameter modelContext: SwiftDataのModelContext
    /// - Returns: ユーザーの喫煙データ
    private func fetchUserSmokingData(modelContext: ModelContext) -> UserSmokingData? {
        // 設定を取得
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        guard let settings = try? modelContext.fetch(settingsDescriptor).first else {
            return nil
        }
        
        // 過去7日間の喫煙記録を取得
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        
        let recordPredicate = #Predicate<SmokingRecord> { record in
            record.timestamp >= weekAgo && record.timestamp < now
        }
        let recordDescriptor = FetchDescriptor<SmokingRecord>(predicate: recordPredicate)
        
        guard let records = try? modelContext.fetch(recordDescriptor) else {
            return nil
        }
        
        // 日別カウントを計算
        var dailyCounts: [Date: Int] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.timestamp)
            dailyCounts[day, default: 0] += record.count
        }
        
        // 平均を計算
        let totalCount = dailyCounts.values.reduce(0, +)
        let dayCount = max(1, dailyCounts.count)
        let averageCount = totalCount / dayCount
        
        // 傾向を判定（最近3日と前3日を比較）
        let sortedDays = dailyCounts.keys.sorted()
        var isDecreasing = false
        
        if sortedDays.count >= 6 {
            let recentDays = sortedDays.suffix(3)
            let olderDays = sortedDays.dropLast(3).suffix(3)
            
            let recentAvg = recentDays.compactMap { dailyCounts[$0] }.reduce(0, +) / 3
            let olderAvg = olderDays.compactMap { dailyCounts[$0] }.reduce(0, +) / 3
            
            isDecreasing = recentAvg < olderAvg
        }
        
        return UserSmokingData(
            averageDailyCount: averageCount,
            dailyGoal: settings.dailyGoal,
            isDecreasing: isDecreasing,
            totalRecordsCount: nil
        )
    }
    
    /// カテゴリフィルターを設定
    /// - Parameter category: 選択するカテゴリ（nilで全て表示）
    func selectCategory(_ category: ArticleCategory?) {
        selectedCategory = category
    }
    
    /// 特定の記事のAI処理を再実行
    /// - Parameters:
    ///   - article: 処理対象の記事
    ///   - modelContext: SwiftDataのModelContext
    func reprocessArticle(_ article: Article, modelContext: ModelContext) async {
        guard let index = articles.firstIndex(where: { $0.id == article.id }) else {
            return
        }
        
        isProcessingAI = true
        
        let userData = fetchUserSmokingData(modelContext: modelContext)
        let updatedArticle = await aiService.processOneArticle(article, userData: userData)
        
        articles[index] = updatedArticle
        
        isProcessingAI = false
    }
}
