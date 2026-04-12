//
//  TipJarManager.swift
//  SmokeCounter
//
//  開発者支援（チップ）機能の管理サービス
//  StoreKit 2を使用した消耗型アプリ内課金
//

import Foundation
import StoreKit
import os

private let logger = Logger(subsystem: "SmokeCounter", category: "TipJarManager")

/// チップ商品の種類（製品IDは開発チーム内で一意になるようバンドルID由来にしている）
enum TipProduct: String, CaseIterable, Identifiable {
    case coffee = "jp.junya.SmoPace.tip.coffee"
    case cigarette = "jp.junya.SmoPace.tip.developer"
    case support = "jp.junya.SmoPace.tip.cheer"
    
    var id: String { rawValue }
    
    /// 表示名
    var displayName: String {
        switch self {
        case .coffee: return "コーヒー1杯"
        case .cigarette: return "開発サポート"
        case .support: return "応援サポート"
        }
    }
    
    /// アイコン
    var iconName: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .cigarette: return "flame.fill"
        case .support: return "heart.fill"
        }
    }
    
    /// 説明文
    var description: String {
        switch self {
        case .coffee: return "開発者にコーヒーを奢る"
        case .cigarette: return "開発者を応援する"
        case .support: return "アプリ開発を応援する"
        }
    }
}

/// チップ管理サービス
@MainActor
@Observable
final class TipJarManager {
    /// 商品一覧
    private(set) var products: [Product] = []
    
    /// 読み込み中フラグ
    private(set) var isLoading = false
    
    /// 購入処理中フラグ
    private(set) var isPurchasing = false
    
    /// エラーメッセージ
    private(set) var errorMessage: String?
    
    /// 購入成功フラグ
    private(set) var purchaseSucceeded = false
    
    /// シングルトンインスタンス
    static let shared = TipJarManager()
    
    private init() {}
    
    /// 商品を読み込む
    func loadProducts() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let productIds = TipProduct.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIds)
            
            // 価格順にソート
            products = storeProducts.sorted { $0.price < $1.price }
            
            logger.info("✅ チップ商品を読み込みました: \(self.products.count)件")
        } catch {
            logger.error("❌ 商品の読み込みに失敗: \(error.localizedDescription)")
            errorMessage = "商品情報の取得に失敗しました"
        }
        
        isLoading = false
    }
    
    /// 商品を購入する
    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        
        isPurchasing = true
        errorMessage = nil
        purchaseSucceeded = false
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // トランザクションを検証
                switch verification {
                case .verified(let transaction):
                    // 購入成功
                    logger.info("✅ チップ購入成功: \(product.displayName)")
                    purchaseSucceeded = true
                    
                    // トランザクションを完了としてマーク
                    await transaction.finish()
                    
                case .unverified(_, let error):
                    logger.error("❌ トランザクション検証失敗: \(error.localizedDescription)")
                    errorMessage = "購入の検証に失敗しました"
                }
                
            case .userCancelled:
                logger.info("ℹ️ ユーザーが購入をキャンセル")
                
            case .pending:
                logger.info("ℹ️ 購入が保留中")
                errorMessage = "購入が保留中です。承認後に完了します。"
                
            @unknown default:
                logger.warning("⚠️ 不明な購入結果")
            }
        } catch {
            logger.error("❌ 購入処理エラー: \(error.localizedDescription)")
            errorMessage = "購入処理中にエラーが発生しました"
        }
        
        isPurchasing = false
    }
    
    /// TipProduct から対応する Product を取得
    func product(for tipProduct: TipProduct) -> Product? {
        products.first { $0.id == tipProduct.rawValue }
    }
    
    /// 購入成功フラグをリセット
    func resetPurchaseSucceeded() {
        purchaseSucceeded = false
    }
}
