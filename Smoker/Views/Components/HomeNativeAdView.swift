//
//  HomeNativeAdView.swift
//  SmokeCounter
//
//  ホーム画面専用コンパクトネイティブ広告コンポーネント
//  文字とアプリアイコンだけの省スペース（高さ64pt〜70pt程度）の広告
//  キャッシュ機能および自動リフレッシュ（60秒間隔）付き
//

import SwiftUI
import GoogleMobileAds
import Combine

// MARK: - ホーム専用コンパクトネイティブ広告ビュー

/// ホーム画面の下部に表示される省スペースなネイティブ広告ビュー
struct HomeNativeAdView: View {
    private let adManager = AdManager.shared

    var body: some View {
        // シングルトンの adLoader を監視することで、画面破棄時も広告インスタンスを保持する
        HomeNativeAdInnerView(adLoader: adManager.homeAdLoader)
    }
}

struct HomeNativeAdInnerView: View {
    @ObservedObject var adLoader: HomeNativeAdLoader
    private let adManager = AdManager.shared

    var body: some View {
        Group {
            if adLoader.loadFailed {
                // 読み込み失敗時は領域ごと非表示
                EmptyView()
            } else if let nativeAd = adLoader.nativeAd {
                // ロード完了後はディバイダー付きで表示（キャッシュがあれば戻ってきた瞬間に即時表示）
                VStack(spacing: 0) {
                    Divider()
                    HomeNativeAdContentRepresentable(nativeAd: nativeAd)
                        .frame(height: 64)
                        .background(Color(.systemBackground))
                }
            } else {
                // ロード中はガタつき防止のため何も表示しない
                EmptyView()
            }
        }
        .onAppear {
            loadIfReady()
        }
        .onChange(of: adManager.canLoadAds) { _, _ in
            loadIfReady()
        }
    }

    /// SDK初期化 & ATT確定が揃った段階で広告をロードする
    private func loadIfReady() {
        guard adManager.canLoadAds else { return }
        adLoader.loadAd(adUnitId: adManager.homeNativeAdUnitId)
    }
}

// MARK: - ホーム画面専用ネイティブ広告キャッシュローダー

/// ホーム専用のネイティブ広告をメモリ上に保持（キャッシュ）し、一定時間ごとに更新するローダー
class HomeNativeAdLoader: NSObject, ObservableObject, AdLoaderDelegate, NativeAdLoaderDelegate {
    @Published var nativeAd: NativeAd?
    @Published var loadFailed = false
    
    private var adLoader: AdLoader?
    private var isQuerying = false
    
    /// 最後にロード（または更新）した日時
    private(set) var lastLoadedTime: Date?
    
    /// 広告を自動更新する間隔（秒）。今回は60秒
    private let refreshInterval: TimeInterval = 60.0
    
    /// 広告をロードまたはキャッシュから再利用する
    func loadAd(adUnitId: String) {
        // すでに問い合わせ中の場合は何もしない
        guard !isQuerying else { return }
        
        // ロード済みの広告があり、かつ最終ロードから60秒経過していない場合はキャッシュをそのまま使用
        if let lastTime = lastLoadedTime, Date().timeIntervalSince(lastTime) < refreshInterval {
            print("ℹ️ [Home Native Ad] キャッシュを再利用 (最終ロードから \(Int(Date().timeIntervalSince(lastTime)))秒経過)")
            return
        }
        
        print("🔄 [Home Native Ad] 広告をロード（または更新リクエスト）開始...")
        isQuerying = true
        
        var rootViewController: UIViewController?
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            rootViewController = windowScene.windows.first?.rootViewController
        }
        
        adLoader = AdLoader(
            adUnitID: adUnitId,
            rootViewController: rootViewController,
            adTypes: [.native],
            options: nil
        )
        adLoader?.delegate = self
        adLoader?.load(Request())
    }
    
    // MARK: - AdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        let nsError = error as NSError
        print("❌ [Home Native Ad] Load Failed: \(nsError.localizedDescription)")
        DispatchQueue.main.async {
            self.isQuerying = false
            // すでにロード済みのキャッシュ広告がある場合は、ロード失敗してもそれを表示し続ける
            if self.nativeAd == nil {
                self.loadFailed = true
            }
        }
    }
    
    // MARK: - NativeAdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        print("✅ [Home Native Ad] Loaded Successfully")
        DispatchQueue.main.async {
            self.isQuerying = false
            self.nativeAd = nativeAd
            self.lastLoadedTime = Date()
            self.loadFailed = false
        }
    }
}

// MARK: - GADNativeAdView を使った UIViewRepresentable

struct HomeNativeAdContentRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd
    
    func makeUIView(context: Context) -> HomeNativeAdView_UIKit {
        let nativeAdView = HomeNativeAdView_UIKit(frame: CGRect(x: 0, y: 0, width: 320, height: 64))
        return nativeAdView
    }
    
    func updateUIView(_ nativeAdView: HomeNativeAdView_UIKit, context: Context) {
        nativeAdView.configure(with: nativeAd)
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: HomeNativeAdView_UIKit, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        return CGSize(width: width, height: 64)
    }
}

// MARK: - GADNativeAdView をコードで構築する UIKit ビュー

/// ホーム画面専用のコンパクトなネイティブ広告をレイアウトするビュークラス
class HomeNativeAdView_UIKit: GoogleMobileAds.NativeAdView {
    
    // サブビュー
    private let adBadgeLabel = UILabel()           // 「広告」バッジ
    private let iconImageView = UIImageView()      // 広告主アイコン
    private let headlineLabel = UILabel()           // 見出し
    private let advertiserLabel = UILabel()         // 広告主名 / 説明
    private let callToActionLabel = UILabel()       // アクションボタン (CTA)
    
    // AdMobポリシー要件：MediaView はビュー階層に登録が必要だが、コンパクト化のためサイズ0で非表示にする
    private let nativeMediaView = MediaView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        clipsToBounds = true
        backgroundColor = .systemBackground
        
        // 1. 広告バッジの設定
        adBadgeLabel.text = "広告"
        adBadgeLabel.font = .systemFont(ofSize: 8, weight: .bold)
        adBadgeLabel.textColor = .systemBackground
        adBadgeLabel.backgroundColor = .systemGray2
        adBadgeLabel.layer.cornerRadius = 2
        adBadgeLabel.clipsToBounds = true
        adBadgeLabel.textAlignment = .center
        adBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 2. アイコン画像の設定
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 6
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 3. 見出しラベルの設定
        headlineLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headlineLabel.numberOfLines = 1
        headlineLabel.textColor = .label
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 4. 広告主ラベル（説明）の設定
        advertiserLabel.font = .systemFont(ofSize: 11)
        advertiserLabel.textColor = .secondaryLabel
        advertiserLabel.numberOfLines = 1
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 5. CTAラベル（ボタン風）の設定
        callToActionLabel.font = .systemFont(ofSize: 11, weight: .bold)
        callToActionLabel.textColor = .systemBlue
        callToActionLabel.textAlignment = .center
        callToActionLabel.layer.borderColor = UIColor.systemBlue.cgColor
        callToActionLabel.layer.borderWidth = 1.0
        callToActionLabel.layer.cornerRadius = 12
        callToActionLabel.clipsToBounds = true
        callToActionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 6. メディアビュー（非表示にしてポリシー対応）
        nativeMediaView.isHidden = true
        nativeMediaView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nativeMediaView)
        
        // --- レイアウト構築 ---
        // バッジと見出しを横に並べるスタックビュー
        let headlineRow = UIStackView(arrangedSubviews: [adBadgeLabel, headlineLabel])
        headlineRow.axis = .horizontal
        headlineRow.spacing = 6
        headlineRow.alignment = .center
        
        // テキスト情報を縦に並べるスタックビュー
        let textColumn = UIStackView(arrangedSubviews: [headlineRow, advertiserLabel])
        textColumn.axis = .vertical
        textColumn.spacing = 2
        textColumn.translatesAutoresizingMaskIntoConstraints = false
        
        // 全体を横に並べるメインスタックビュー
        let mainStack = UIStackView(arrangedSubviews: [iconImageView, textColumn, callToActionLabel])
        mainStack.axis = .horizontal
        mainStack.spacing = 10
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        
        // レイアウト制約
        NSLayoutConstraint.activate([
            // メインスタックをビュー中央に配置（左右にパディング）
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            mainStack.heightAnchor.constraint(equalToConstant: 48),
            
            // バッジのサイズ
            adBadgeLabel.widthAnchor.constraint(equalToConstant: 24),
            adBadgeLabel.heightAnchor.constraint(equalToConstant: 13),
            
            // アイコン画像サイズ
            iconImageView.widthAnchor.constraint(equalToConstant: 36),
            iconImageView.heightAnchor.constraint(equalToConstant: 36),
            
            // CTAボタンサイズ
            callToActionLabel.widthAnchor.constraint(equalToConstant: 64),
            callToActionLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // 非表示メディアビューのサイズ制約（0x0）
            nativeMediaView.widthAnchor.constraint(equalToConstant: 0),
            nativeMediaView.heightAnchor.constraint(equalToConstant: 0),
            nativeMediaView.leadingAnchor.constraint(equalTo: leadingAnchor),
            nativeMediaView.topAnchor.constraint(equalTo: topAnchor)
        ])
        
        // AdMob SDKに各ビューを登録（タップや広告主ロゴが動作するように）
        self.headlineView = headlineLabel
        self.iconView = iconImageView
        self.advertiserView = advertiserLabel
        self.callToActionView = callToActionLabel
        self.mediaView = nativeMediaView
    }
    
    func configure(with nativeAd: NativeAd) {
        self.nativeAd = nativeAd
        
        headlineLabel.text = nativeAd.headline
        callToActionLabel.text = nativeAd.callToAction ?? "詳細"
        
        // 広告主名（なければボディテキストを代替表示）
        if let advertiser = nativeAd.advertiser {
            advertiserLabel.text = advertiser
        } else {
            advertiserLabel.text = nativeAd.body
        }
        
        // アイコン画像の設定
        if let icon = nativeAd.icon?.image {
            iconImageView.image = icon
            iconImageView.contentMode = .scaleAspectFill
            iconImageView.backgroundColor = .clear
        } else {
            iconImageView.image = UIImage(systemName: "megaphone.fill")
            iconImageView.tintColor = .systemBlue.withAlphaComponent(0.6)
            iconImageView.contentMode = .center
            iconImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        }
        
        setNeedsLayout()
        layoutIfNeeded()
    }
}

#Preview {
    HomeNativeAdView()
}
