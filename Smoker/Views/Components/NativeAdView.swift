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
    
    var body: some View {
        Group {
            // 広告の読み込みに失敗した場合は非表示
            if adLoader.loadFailed {
                EmptyView()
            } else if let nativeAd = adLoader.nativeAd {
                // 広告が読み込まれた場合
                VStack(alignment: .leading, spacing: 12) {
                    // ヘッダー（広告ラベル）
                    HStack {
                        Text("広告")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                        
                        Spacer()
                    }
                    
                    NativeAdContentRepresentable(nativeAd: nativeAd)
                        .frame(minHeight: 80)
                }
                .padding()
                .background(Color(.systemBackground))
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
            adLoader.loadAd(adUnitId: AdManager.shared.nativeAdUnitId)
        }
    }
}

// MARK: - GADNativeAdView を使った UIViewRepresentable

/// AdMob の GADNativeAdView を使ってネイティブ広告を表示する UIViewRepresentable
/// GADNativeAdView を使用することで、広告のタップ（クリック）が正しく機能する
struct NativeAdContentRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd
    
    func makeUIView(context: Context) -> NativeAdView_UIKit {
        // xib を使わず、コードで GADNativeAdView を構築
        let nativeAdView = NativeAdView_UIKit(frame: .zero)
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        return nativeAdView
    }
    
    func updateUIView(_ nativeAdView: NativeAdView_UIKit, context: Context) {
        nativeAdView.configure(with: nativeAd)
    }
}

/// GADNativeAdView をコードで構築する UIKit ビュー
class NativeAdView_UIKit: GoogleMobileAds.NativeAdView {
    
    // サブビュー
    private let iconImageView = UIImageView()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let callToActionLabel = UILabel()
    private let containerStack = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // アイコン画像の設定
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 8
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // ヘッドラインラベルの設定
        headlineLabel.font = .preferredFont(forTextStyle: .headline)
        headlineLabel.numberOfLines = 1
        headlineLabel.textColor = .label
        
        // ボディラベルの設定
        bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        bodyLabel.numberOfLines = 2
        bodyLabel.textColor = .secondaryLabel
        
        // CTA ラベルの設定
        callToActionLabel.font = .preferredFont(forTextStyle: .caption1)
        callToActionLabel.textColor = .systemBlue
        callToActionLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        
        // テキスト部分を縦に並べる
        let textStack = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel, callToActionLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        
        // アイコン + テキストを横に並べる
        containerStack.addArrangedSubview(iconImageView)
        containerStack.addArrangedSubview(textStack)
        containerStack.axis = .horizontal
        containerStack.spacing = 12
        containerStack.alignment = .center
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(containerStack)
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // GADNativeAdView のプロパティに各ビューを登録
        // これにより AdMob SDK がタップイベントを正しくハンドリングする
        self.headlineView = headlineLabel
        self.bodyView = bodyLabel
        self.iconView = iconImageView
        self.callToActionView = callToActionLabel
    }
    
    /// NativeAd のデータをビューに反映する
    func configure(with nativeAd: NativeAd) {
        self.nativeAd = nativeAd
        
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        callToActionLabel.text = nativeAd.callToAction
        callToActionLabel.isHidden = (nativeAd.callToAction == nil)
        
        if let icon = nativeAd.icon?.image {
            iconImageView.image = icon
            iconImageView.isHidden = false
            iconImageView.backgroundColor = .clear
        } else {
            iconImageView.image = UIImage(systemName: "megaphone.fill")
            iconImageView.tintColor = .systemBlue.withAlphaComponent(0.5)
            iconImageView.contentMode = .center
            iconImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            iconImageView.isHidden = false
        }
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
        DispatchQueue.main.async {
            self.loadFailed = true
        }
    }
    
    // MARK: - NativeAdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        timeoutTimer?.invalidate()
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
