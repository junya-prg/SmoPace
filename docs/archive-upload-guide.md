# Xcode Archive & App Store Connect アップロードガイド

---

## 事前確認

### 1. Bundle ID の確認

Apple Developer Portal で以下が登録されていることを確認：

- **App ID**: `jp.junya.Smoker`
- **App Group**: `group.jp.junya.SmokeCounter`

### 2. プロビジョニングプロファイル

Xcode → Preferences → Accounts で Apple ID が登録されていることを確認。

---

## Archive 作成手順

### Step 1: プロジェクトを開く

```bash
open /Users/hondajunya/00_work/94_自作/SmokeCounter/Smoker.xcodeproj
```

### Step 2: ビルド設定の確認

1. プロジェクトナビゲータで「Smoker」プロジェクトを選択
2. 「Smoker」ターゲットを選択
3. 「Signing & Capabilities」タブを確認：
   - Team: 9U4XHS35A9（あなたのチーム）
   - Bundle Identifier: jp.junya.Smoker
   - Signing Certificate: Apple Distribution（自動管理）

### Step 3: デバイスの選択

1. Xcodeツールバーのデバイス選択ドロップダウンをクリック
2. **「Any iOS Device (arm64)」** を選択

⚠️ シミュレータが選択されているとArchiveが作成できません。

### Step 4: Archive の作成

1. メニューバー → **Product** → **Archive** をクリック
2. ビルドが開始されます（数分かかります）
3. 完了すると **Organizer** ウィンドウが自動的に開きます

---

## App Store Connect へのアップロード

### Step 1: Organizer でArchiveを選択

1. Organizer ウィンドウで、作成したArchiveを選択
2. 右側の **「Distribute App」** ボタンをクリック

### Step 2: 配布方法の選択

1. **「App Store Connect」** を選択 → Next
2. **「Upload」** を選択 → Next

### Step 3: オプションの設定

以下のオプションはデフォルトのままでOK：

- [x] Upload your app's symbols to receive symbolicated reports from Apple
- [x] Manage Version and Build Number

→ **Next** をクリック

### Step 4: 署名の確認

自動署名が有効な場合、Xcodeが自動的に適切な証明書を選択します。

- Distribution Certificate: Apple Distribution
- Provisioning Profile: 自動生成

→ **Upload** をクリック

### Step 5: アップロード完了

アップロードが完了すると、成功メッセージが表示されます。

---

## アップロード後の処理

### Apple側の処理

アップロード後、Appleのサーバーで以下の処理が行われます：

1. バイナリの検証
2. App Storeへの登録準備
3. 自動テスト

**処理時間**: 通常 5〜30分

### 処理完了の確認

1. App Store Connect にログイン
2. マイApp → Smoker → 「App Store」タブ
3. 「ビルド」セクションを確認
4. 処理が完了すると、ビルドが表示されます

### ビルドの選択

1. 「ビルド」セクションの **「＋」** ボタンをクリック
2. アップロードしたビルドを選択
3. **「完了」** をクリック

---

## トラブルシューティング

### エラー: "No accounts with App Store Connect access"

**解決方法**:
1. Xcode → Preferences → Accounts
2. Apple ID を追加または再認証

### エラー: "Invalid Provisioning Profile"

**解決方法**:
1. Xcode → Preferences → Accounts → チームを選択
2. 「Download Manual Profiles」をクリック
3. または、Signing & Capabilities で「Automatically manage signing」を有効化

### エラー: "Missing Compliance"

**解決方法**:
App Store Connect でビルドを選択後、輸出コンプライアンス情報を入力：
- 「このAppは暗号化を使用していますか？」→ いいえ

### エラー: "App uses IDFA"

**解決方法**:
App Store Connect で広告識別子の使用目的を設定：
- 「このApp内で広告を配信する」にチェック

---

## 次のステップ

ビルドがApp Store Connectに表示されたら、審査提出に進みます。

→ [審査提出ガイド](./submit-review-guide.md)
