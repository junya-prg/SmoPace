//
//  TipJarView.swift
//  SmokeCounter
//
//  開発者支援（チップ）UI
//

import SwiftUI
import StoreKit

/// 開発者支援ビュー
struct TipJarView: View {
    private var tipJarManager = TipJarManager.shared
    @State private var showThankYouAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダー
            VStack(alignment: .leading, spacing: 4) {
                Text("開発者を応援する")
                    .font(.headline)
                Text("このアプリが気に入ったら、開発者を支援してください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 商品一覧
            if tipJarManager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if tipJarManager.products.isEmpty {
                // 商品が読み込めなかった場合
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("商品情報を読み込めませんでした")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task {
                            await tipJarManager.loadProducts()
                        }
                    } label: {
                        Label("再読み込み", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                // 実際の商品
                VStack(spacing: 12) {
                    ForEach(tipJarManager.products, id: \.id) { product in
                        TipProductRow(
                            product: product,
                            tipProduct: TipProduct(rawValue: product.id),
                            isPurchasing: tipJarManager.isPurchasing,
                            onPurchase: {
                                Task {
                                    await tipJarManager.purchase(product)
                                }
                            }
                        )
                    }
                }
            }
            
            // エラーメッセージ
            if let error = tipJarManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task {
            await tipJarManager.loadProducts()
        }
        .onChange(of: tipJarManager.purchaseSucceeded) { _, succeeded in
            if succeeded {
                showThankYouAlert = true
                tipJarManager.resetPurchaseSucceeded()
            }
        }
        .alert("ありがとうございます！", isPresented: $showThankYouAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("開発者への応援、心より感謝いたします。\nこれからもアプリの改善に努めます！")
        }
    }
}

/// チップ商品行（実際の商品）
struct TipProductRow: View {
    let product: Product
    let tipProduct: TipProduct?
    let isPurchasing: Bool
    let onPurchase: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // アイコン
            Image(systemName: tipProduct?.iconName ?? "gift")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            // 商品情報
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(tipProduct?.description ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 購入ボタン
            Button(action: onPurchase) {
                if isPurchasing {
                    ProgressView()
                        .frame(width: 70)
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 70)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPurchasing)
        }
        .padding(.vertical, 4)
    }
}


/// 設定画面用のチップセクション
struct TipJarSection: View {
    @Binding var showTipJarSheet: Bool
    
    var body: some View {
        Section {
            Button(action: { showTipJarSheet = true }) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                    Text("開発者を応援する")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("サポート")
        } footer: {
            Text("アプリが気に入ったら、開発者を応援してください")
        }
    }
}

/// チップシートビュー
struct TipJarSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // アイコンと説明
                    VStack(spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.pink)
                        
                        Text("開発者を応援する")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("SmoPaceは個人開発のアプリです。\nアプリが気に入ったら、開発者を応援してください。\nいただいた支援は、アプリの改善に活用させていただきます。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // チップ選択
                    TipJarView()
                        .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            TipJarSection(showTipJarSheet: .constant(false))
        }
    }
}

#Preview("TipJarSheet") {
    TipJarSheetView()
}
