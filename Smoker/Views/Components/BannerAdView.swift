//
//  BannerAdView.swift
//  SmokeCounter
//
//  バナー広告コンポーネント
//  Google AdMobのバナー広告を表示
//

import SwiftUI
import GoogleMobileAds

// MARK: - バナー広告ビュー

/// バナー広告ビュー
/// 統計画面の下部に表示される控えめな広告
struct BannerAdView: View {
    private let adManager = AdManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 広告ラベル
            HStack {
                Text("広告")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            // AdMobバナー広告 (320x50の固定サイズ)
            // SDK初期化 & ATT確定後にのみ広告をロードする
            Group {
                if adManager.canLoadAds {
                    BannerAdViewRepresentable(adUnitId: adManager.bannerAdUnitId)
                } else {
                    Color.clear
                }
            }
            .frame(width: 320, height: 50)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGray6))
    }
}

// MARK: - UIKit連携（AdMobバナー広告）

/// AdMobバナー広告のUIViewRepresentable
struct BannerAdViewRepresentable: UIViewRepresentable {
    let adUnitId: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitId
        bannerView.delegate = context.coordinator
        
        // ルートViewControllerを取得
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }
        
        // 広告をロード
        bannerView.load(Request())
        
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // 更新時は何もしない
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            let nsError = error as NSError
            print("❌ [Banner Ad] Load Failed: \(nsError.localizedDescription)")
            print("❌ [Banner Ad] Error Code: \(nsError.code), Domain: \(nsError.domain)")
        }
        
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ [Banner Ad] Loaded Successfully")
        }
    }
}

#Preview {
    VStack {
        Spacer()
        BannerAdView()
    }
}
