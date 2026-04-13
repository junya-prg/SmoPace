# App Review 2.1（Information Needed）対応メモ

Guideline 2.1 の追加情報依頼に対し、Resolution Center への貼り付け用テキストと実機録画の手順をまとめたものです。

---

## コードベースで確認した事実（提出本文と整合）

| 項目 | 状態 |
|------|------|
| SwiftData の CloudKit | `SharedModelContainer` で `isICloudSyncEnabled` に連動し `.automatic` / `.none` を切り替え（**デフォルト有効**）。iCloud コンテナ: `iCloud.jp.junya.SmoPace` |
| アプリ内課金 | **消耗型（Consumable）のチップのみ** 3 品。自動更新サブスクリプションなし（`SmokerTip.storekit` / `TipJarManager` 一致） |
| 製品 ID | `jp.junya.SmoPace.tip.coffee`, `jp.junya.SmoPace.tip.developer`, `jp.junya.SmoPace.tip.cheer` |
| ニュース取得 | Google News RSS（HTTPS） |
| AI | Apple Foundation Models（**オンデバイス**。喫煙記録を外部 AI サービスへ送らない） |
| 広告 | Google AdMob。ATT でトラッキング許可を要求する場合あり |

ストアの「概要」に iCloud 同期の記載があり、本ビルドでもデフォルト有効のため**整合が取れています**。

---

## 1. 実機スクリーン録画（実施チェックリスト）

**実機のみ**（審査要件）。コントロールセンターから画面収録を開始し、**ホーム画面のアイコンから起動**するところから入る。

1. [ ] ホーム画面 → アプリ起動（スプラッシュのみで終わらない）
2. [ ] メイン：記録（本数追加）と目標プログレスの表示
3. [ ] 統計：日／週などグラフ画面
4. [ ] AI ニュース：一覧が読み込まれるところまで（可能なら記事タップで外部表示まで短く）
5. [ ] リラックスモードを短く表示
6. [ ] 設定（またはチップ画面）から **開発者支援（Tip）** の一覧・価格表示。可能なら **Sandbox で購入完了**まで
7. [ ] **App Tracking Transparency** のダイアログが出るタイミングを収録（許可／不許可どちらでも可）

**未収録でテキスト補足するもの**

- アカウント登録・ログイン・削除：**なし**
- UGC・通報・ブロック UI：**なし**（ニュースは第三者 RSS）

録画ファイルを iCloud Drive / Google Drive 等に上げ、**リンクを知っている人のみ**共有にしたうえで、下記英語メッセージの `YOUR_VIDEO_URL` を差し替える。

---

## 2. Resolution Center 用（英語・そのまま貼り付け可）

`YOUR_VIDEO_URL` のみ実 URL に置き換えてください。

```
Hello App Review Team,

Thank you for reviewing SmoPace. Below is the requested information.

1) Screen recording (physical device)
A screen recording captured on a physical iPhone is available here:
YOUR_VIDEO_URL

The video starts from the Home Screen by launching the app and walks through the core user flow: logging a cigarette count on the main screen, viewing goal progress, opening Statistics, opening the News section (articles load from a public RSS feed), briefly opening Relax mode, and opening the optional Developer Tip (consumable in-app purchase) screen. It also includes the App Tracking Transparency prompt when it appears (for personalized ads via Google AdMob).

There is no user account registration, login, or account deletion in the app.

There is no user-generated content feed. News headlines/snippets are fetched from Google News RSS; there are no in-app reporting/blocking tools for that third-party content.

2) App purpose
SmoPace is a lifestyle / self-tracking app that helps people who want to reduce smoking at their own pace. Users can log counts with minimal taps, set a daily goal, visualize trends with charts, optionally read smoking-reduction-related news, and use a short relaxation session when they feel urges. On supported devices, on-device Apple Intelligence (Foundation Models) can summarize news content; smoking logs are not sent to an external AI service. The app is not medical treatment and does not provide clinical diagnosis or prescriptions.

3) Review instructions and credentials
No login credentials are required; the app has no developer-provided user accounts.

Suggested review path after launch:
- Main tab: tap to add a log entry and check today’s count / goal progress.
- Statistics tab: switch day/week/month views.
- News tab: wait for the list to load (network).
- Relax tab: start a short session.
- Settings (or Tip section): open Developer Tips and, if you wish, complete a consumable tip purchase in the Sandbox environment.

4) External services used for core-related functionality
- Google Mobile Ads (AdMob): display and measurement of ads; App Tracking Transparency may be requested for personalized ads.
- Google News RSS (https://news.google.com/...): fetch public news metadata for the in-app news list (HTTPS).
- Apple StoreKit: consumable in-app purchases (developer tips only). Product IDs: jp.junya.SmoPace.tip.coffee, jp.junya.SmoPace.tip.developer, jp.junya.SmoPace.tip.cheer. There are no auto-renewable subscriptions.
- Apple on-device intelligence (Foundation Models / Apple Intelligence on supported hardware): optional summarization/categorization of fetched news text on device.

- Apple iCloud (CloudKit): iCloud sync via CloudKit is enabled by default; users can disable it in Settings. Data is stored on the user's own iCloud account. iCloud container: iCloud.jp.junya.SmoPace.

5) Regional differences
The primary UI language is Japanese. The news RSS query is configured for Japanese locale (hl=ja, gl=JP). Core logging, goals, statistics, tips, and ads behave the same in all regions; only the news topics/language bias may differ by region/network.

6) Highly regulated industry
Not applicable. The app is a personal habit-tracking and wellness-style utility, not a regulated medical service.

Additional notes for a smooth review:
- We tested the submitted build on physical devices.
- App Store screenshots show the real app in use (not only splash/login).
- There are no auto-renewable subscriptions; only consumable tips.

Thank you for your time.
```

---

## 3. App Review Information → Notes 用（短縮版・英語）

毎回の提出用に残す場合の要約（動画 URL を含める）。

```
Physical device demo: YOUR_VIDEO_URL
No login. Consumable IAP only (jp.junya.SmoPace.tip.coffee, jp.junya.SmoPace.tip.developer, jp.junya.SmoPace.tip.cheer). No auto-renewable subscriptions.
External: AdMob; Google News RSS (HTTPS); StoreKit; on-device Apple Intelligence for optional news summarization (no user logs sent to external AI).
CloudKit: enabled by default (user-configurable). iCloud container: iCloud.jp.junya.SmoPace.
Japanese-first UI; news RSS is JP-biased. Not a medical device/regulated clinical service.
```

---

## 4. 実施後の作業（手動）

1. 実機で録画し、リンクを発行する。
2. App Store Connect → **Resolution Center** に上記英語全文を貼り、`YOUR_VIDEO_URL` を置換して送信する。
3. **App Review Information** の **Notes** にセクション 3 を貼り、同じ動画 URL を入れる。
