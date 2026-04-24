//
//  NativeAdView.swift
//  SmokeCounter
//
//  ネイティブ広告コンポーネント
//  AIニュース記事一覧に溶け込む形式の広告
//

import SwiftUI
import GoogleMobileAds
import SwiftData
import Combine

// MARK: - ネイティブ広告ビュー

/// ネイティブ広告ビュー
/// 記事カードと同じスタイルで表示される広告
struct NativeAdView: View {
    @StateObject private var adLoader = NativeAdLoader()
    private let adManager = AdManager.shared

    var body: some View {
        Group {
            // 広告の読み込みに失敗した場合は非表示
            if adLoader.loadFailed {
                EmptyView()
            } else if let nativeAd = adLoader.nativeAd {
                // 広告が読み込まれた場合
                // ※「広告」バッジはGADNativeAdView内部に含まれている（AdMobポリシー準拠）
                NativeAdContentRepresentable(nativeAd: nativeAd)
                    .frame(minHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            } else {
                // 読み込み中
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("広告")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())

                        Spacer()
                    }

                    NativeAdPlaceholder()
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
        adLoader.loadAd(adUnitId: adManager.nativeAdUnitId)
    }
}

// MARK: - GADNativeAdView を使った UIViewRepresentable

/// AdMob の GADNativeAdView を使ってネイティブ広告を表示する UIViewRepresentable
/// GADNativeAdView を使用することで、広告のタップ（クリック）が正しく機能する
struct NativeAdContentRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd
    
    func makeUIView(context: Context) -> NativeAdView_UIKit {
        // 初期サイズを0にすると制約クラッシュの恐れがあるため適当なサイズを設定
        let nativeAdView = NativeAdView_UIKit(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        // ※ translatesAutoresizingMaskIntoConstraints は設定しない
        // SwiftUI が UIView のサイズを自動管理する
        return nativeAdView
    }
    
    func updateUIView(_ nativeAdView: NativeAdView_UIKit, context: Context) {
        nativeAdView.configure(with: nativeAd)
    }
    
    /// SwiftUI にビューの適切なサイズを伝える
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NativeAdView_UIKit, context: Context) -> CGSize? {
        let width = max(proposal.width ?? UIScreen.main.bounds.width, 320)
        let fittingSize = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return fittingSize
    }
}

/// GADNativeAdView をコードで構築する UIKit ビュー
/// AdMobポリシー準拠：MediaView使用 + 全アセットがビュー境界内に配置
class NativeAdView_UIKit: GoogleMobileAds.NativeAdView {
    
    // サブビュー
    private let adBadgeLabel = UILabel()           // 「広告」バッジ（ビュー内部に配置）
    private let iconImageView = UIImageView()      // アプリ/広告主アイコン
    private let headlineLabel = UILabel()           // ヘッドライン
    private let bodyLabel = UILabel()               // ボディテキスト
    private let nativeMediaView = MediaView()       // ★ メイン画像/動画（AdMob必須）
    private let advertiserLabel = UILabel()         // 広告主名
    private let callToActionLabel = UILabel()       // CTAラベル
    
    private var mediaHeightConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // ビュー境界内にすべてのアセットを収める
        clipsToBounds = true
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        
        // 広告バッジの設定（GADNativeAdView内部に配置 - ポリシー準拠）
        adBadgeLabel.text = "広告"
        adBadgeLabel.font = .systemFont(ofSize: 9, weight: .medium)
        adBadgeLabel.textColor = .secondaryLabel
        adBadgeLabel.textAlignment = .center
        adBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // アイコン画像の設定
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 6
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // ヘッドラインラベルの設定
        headlineLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        headlineLabel.numberOfLines = 2
        headlineLabel.textColor = .label
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // ボディラベルの設定
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 2
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // ★ メディアビューの設定（AdMob必須 - メイン画像/動画表示用）
        // バリデーターエラー「MediaView not used」の修正
        nativeMediaView.contentMode = .scaleAspectFill
        nativeMediaView.clipsToBounds = true
        nativeMediaView.layer.cornerRadius = 8
        nativeMediaView.translatesAutoresizingMaskIntoConstraints = false
        
        // 広告主ラベルの設定
        advertiserLabel.font = .systemFont(ofSize: 11)
        advertiserLabel.textColor = .tertiaryLabel
        advertiserLabel.numberOfLines = 1
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // CTAラベルの設定
        callToActionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        callToActionLabel.textColor = .systemBlue
        callToActionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // --- レイアウト構築 ---
        // UIStackViewを使用してすべてのアセットをGADNativeAdView内部に配置
        
        // バッジ行（左寄せ）
        let badgeRow = UIStackView(arrangedSubviews: [adBadgeLabel, UIView()])
        badgeRow.axis = .horizontal
        
        // テキスト列（ヘッドライン + ボディ）
        let textColumn = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel])
        textColumn.axis = .vertical
        textColumn.spacing = 2
        
        // ヘッダー行（アイコン + テキスト列）
        let headerRow = UIStackView(arrangedSubviews: [iconImageView, textColumn])
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        
        // フッター行（広告主名 ... CTAラベル）
        let footerRow = UIStackView(arrangedSubviews: [advertiserLabel, UIView(), callToActionLabel])
        footerRow.axis = .horizontal
        
        // メインスタック（バッジ → ヘッダー → メディア → フッター）
        let mainStack = UIStackView(arrangedSubviews: [badgeRow, headerRow, nativeMediaView, footerRow])
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        
        // メディアビューの高さ制約
        // AdMob要件：動画表示時は最低120x120ポイント必要
        let mediaMinHeight = nativeMediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        let mediaHeight = nativeMediaView.heightAnchor.constraint(equalToConstant: 150)
        mediaHeight.priority = .defaultHigh
        mediaHeightConstraint = mediaHeight
        
        // メインスタックの下端制約
        // lessThanOrEqualTo を使用して、アセットがビュー外にはみ出さないことを保証
        let bottomConstraint = mainStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        
        // できるだけ下端に詰めるための制約
        let bottomFillConstraint = mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        bottomFillConstraint.priority = .defaultLow
        
        NSLayoutConstraint.activate([
            // メインスタックをビュー内に配置（内部パディング付き）
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            bottomConstraint,
            bottomFillConstraint,
            
            // アイコンサイズ
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            // メディアビュー高さ（最小120pt + 希望150pt）
            mediaMinHeight,
            mediaHeight,
        ])
        
        // ★ GADNativeAdView のプロパティに各ビューを登録
        // これにより AdMob SDK がタップイベントを正しくハンドリングする
        self.headlineView = headlineLabel
        self.bodyView = bodyLabel
        self.iconView = iconImageView
        self.callToActionView = callToActionLabel
        self.mediaView = nativeMediaView       // ★ 必須：MediaViewを登録
        self.advertiserView = advertiserLabel   // ★ 広告主ビューを登録
    }
    
    /// NativeAd のデータをビューに反映する
    func configure(with nativeAd: NativeAd) {
        self.nativeAd = nativeAd
        
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        callToActionLabel.text = nativeAd.callToAction
        callToActionLabel.isHidden = (nativeAd.callToAction == nil)
        
        // 広告主名の表示
        advertiserLabel.text = nativeAd.advertiser
        advertiserLabel.isHidden = (nativeAd.advertiser == nil)
        
        // アイコンの表示
        if let icon = nativeAd.icon?.image {
            iconImageView.image = icon
            iconImageView.contentMode = .scaleAspectFill
            iconImageView.backgroundColor = .clear
        } else {
            iconImageView.image = UIImage(systemName: "megaphone.fill")
            iconImageView.tintColor = .systemBlue.withAlphaComponent(0.5)
            iconImageView.contentMode = .center
            iconImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        }
        iconImageView.isHidden = false
        
        // ★ MediaView はSDKが自動的にメディアコンテンツを表示する
        // nativeAd プロパティが設定されると自動でメイン画像/動画が表示される
        // メディアコンテンツがない場合のみ非表示にする
        if nativeAd.mediaContent.hasVideoContent || nativeAd.images?.isEmpty == false {
            nativeMediaView.isHidden = false
            mediaHeightConstraint?.constant = 150
        } else {
            // メディアがない場合でもMediaViewは表示（SDKが管理）
            nativeMediaView.isHidden = false
            mediaHeightConstraint?.constant = 100
        }
        
        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: - ネイティブ広告コンテンツビュー（後方互換用・未使用）

/// ネイティブ広告プレースホルダー（読み込み中用）
struct NativeAdPlaceholder: View {
    var body: some View {
        HStack(spacing: 12) {
            // 広告アイコン
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
                .frame(width: 60, height: 60)
                .overlay {
                    ProgressView()
                }
            
            // 広告テキスト
            VStack(alignment: .leading, spacing: 4) {
                Text("広告を読み込み中...")
                    .font(.headline)
                    .foregroundStyle(.primary.opacity(0.5))
                
                Text("しばらくお待ちください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(.gray.opacity(0.3))
        )
    }
}

// MARK: - ネイティブ広告ローダー

/// ネイティブ広告を読み込むクラス
class NativeAdLoader: NSObject, ObservableObject, AdLoaderDelegate, NativeAdLoaderDelegate {
    @Published var nativeAd: NativeAd?
    @Published var loadFailed = false
    private var adLoader: AdLoader?
    private var timeoutTimer: Timer?
    
    /// 広告を読み込む
    func loadAd(adUnitId: String) {
        // すでに読み込み済みまたは失敗済みの場合はスキップ
        guard nativeAd == nil && !loadFailed else { return }
        
        // ルートViewControllerを取得
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
        
        // 10秒後にタイムアウト
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.nativeAd == nil {
                    self?.loadFailed = true
                }
            }
        }
    }
    
    // MARK: - AdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        timeoutTimer?.invalidate()
        let nsError = error as NSError
        print("❌ [Native Ad] Load Failed: \(nsError.localizedDescription)")
        print("❌ [Native Ad] Error Code: \(nsError.code), Domain: \(nsError.domain)")
        DispatchQueue.main.async {
            self.loadFailed = true
        }
    }
    
    // MARK: - NativeAdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        timeoutTimer?.invalidate()
        print("✅ [Native Ad] Loaded Successfully")
        DispatchQueue.main.async {
            self.nativeAd = nativeAd
        }
    }
}

// MARK: - 記事リストに広告を挿入するヘルパー

/// 記事と広告を混在させたリストアイテム
enum ArticleListItem: Identifiable {
    case article(Article)
    case ad(id: String)
    
    var id: String {
        switch self {
        case .article(let article):
            return article.id.uuidString
        case .ad(let id):
            return "ad_\(id)"
        }
    }
}

/// 記事リストに広告を挿入する
/// - Parameters:
///   - articles: 元の記事リスト
///   - interval: 広告を挿入する間隔（記事数）
/// - Returns: 広告が挿入されたリストアイテム
func insertAdsIntoArticles(_ articles: [Article], interval: Int = AdConfiguration.nativeAdInterval) -> [ArticleListItem] {
    guard AdConfiguration.showNativeInAINews else {
        return articles.map { .article($0) }
    }
    
    var result: [ArticleListItem] = []
    
    for (index, article) in articles.enumerated() {
        result.append(.article(article))
        
        // 指定間隔ごとに広告を挿入
        if (index + 1) % interval == 0 && index < articles.count - 1 {
            result.append(.ad(id: "\(index)"))
        }
    }
    
    return result
}

#Preview {
    VStack {
        NativeAdView()
            .padding()
    }
    .background(Color(.systemGray6))
}
