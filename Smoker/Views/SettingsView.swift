//
//  SettingsView.swift
//  SmokeCounter
//
//  設定画面 - 銘柄設定、金額設定、目標本数設定
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 設定画面
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var brands: [CigaretteBrand]
    @Query private var settings: [AppSettings]
    @FocusState private var isGoalFieldFocused: Bool
    
    @State private var showAddBrandSheet = false
    @State private var showPrivacyPolicy = false
    @State private var showTipJarSheet = false
    @State private var dailyGoal: String = ""
    
    private var currentSettings: AppSettings? {
        settings.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 目標設定セクション
                Section("目標設定") {
                    HStack {
                        Text("1日の目標本数")
                        Spacer()
                        TextField("未設定", text: $dailyGoal)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($isGoalFieldFocused)
                        Text("本")
                    }
                }
                
                // 銘柄設定セクション
                Section {
                    ForEach(brands) { brand in
                        BrandRowView(
                            brand: brand,
                            isActive: currentSettings?.activeBrandId == brand.id,
                            isDefault: brand.isDefaultBrand,
                            onSelect: { selectBrand(brand) },
                            onSetDefault: { setDefaultBrand(brand) }
                        )
                    }
                    .onDelete(perform: deleteBrands)
                    
                    Button(action: { showAddBrandSheet = true }) {
                        Label("銘柄を追加", systemImage: "plus")
                    }
                } header: {
                    Text("銘柄設定")
                } footer: {
                    Text("★マークの銘柄がウィジェットからのカウントアップ時に使用されます")
                }
                
                // データ管理セクション
                Section("データ管理") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("データのバックアップと復元", systemImage: "icloud")
                    }
                }
                
                // 開発者支援セクション
                TipJarSection(showTipJarSheet: $showTipJarSheet)
                
                // アプリ情報セクション
                Section("アプリ情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: { showPrivacyPolicy = true }) {
                        HStack {
                            Label("プライバシーポリシー", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                // キーボードが表示されている時に「完了」ボタンを表示
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        isGoalFieldFocused = false
                    }
                }
            }
            .sheet(isPresented: $showAddBrandSheet) {
                AddBrandView()
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTipJarSheet) {
                TipJarSheetView()
            }
            .onAppear {
                loadSettings()
            }
            .onChange(of: dailyGoal) { _, newValue in
                saveGoal(newValue)
            }
        }
    }
    
    /// 設定を読み込む
    private func loadSettings() {
        if let settings = currentSettings {
            dailyGoal = settings.dailyGoal.map { String($0) } ?? ""
        } else {
            // 設定が存在しない場合は作成
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            saveContext()
        }
    }
    
    /// 目標を保存
    private func saveGoal(_ value: String) {
        guard let settings = currentSettings else { return }
        settings.dailyGoal = Int(value)
        saveContext()
        
        // ウィジェット用の共有データも更新
        SharedDataManager.shared.dailyGoal = Int(value)
    }
    
    /// 銘柄を選択
    private func selectBrand(_ brand: CigaretteBrand) {
        guard let settings = currentSettings else { return }
        settings.activeBrandId = brand.id
        saveContext()
    }
    
    /// 銘柄を削除
    private func deleteBrands(offsets: IndexSet) {
        for index in offsets {
            let brand = brands[index]
            // アクティブな銘柄が削除される場合はクリア
            if currentSettings?.activeBrandId == brand.id {
                currentSettings?.activeBrandId = nil
            }
            modelContext.delete(brand)
        }
        saveContext()
    }
    
    /// デフォルト銘柄を設定
    private func setDefaultBrand(_ brand: CigaretteBrand) {
        // 他の銘柄のデフォルトフラグをオフにする
        for b in brands {
            b.isDefault = (b.id == brand.id)
        }
        saveContext()
    }
    
    /// コンテキストを保存（エラーハンドリング付き）
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("設定の保存に失敗しました: \(error)")
        }
    }
}

/// 銘柄行ビュー
struct BrandRowView: View {
    let brand: CigaretteBrand
    let isActive: Bool
    let isDefault: Bool
    let onSelect: () -> Void
    let onSetDefault: () -> Void
    
    private var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: brand.pricePerPack as NSDecimalNumber) ?? "¥0"
    }
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text(brand.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if isDefault {
                            Text("デフォルト")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(formattedPrice) / \(brand.countPerPack)本")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // デフォルト設定ボタン
            Button(action: onSetDefault) {
                Image(systemName: isDefault ? "star.fill" : "star")
                    .foregroundStyle(isDefault ? .orange : .gray)
            }
            .buttonStyle(.plain)
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

/// 銘柄追加ビュー
struct AddBrandView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: AddBrandField?
    
    @State private var name = ""
    @State private var countPerPack = "20"
    @State private var pricePerPack = ""
    
    enum AddBrandField {
        case name, count, price
    }
    
    private var isValid: Bool {
        !name.isEmpty && !pricePerPack.isEmpty && Int(countPerPack) != nil && Decimal(string: pricePerPack) != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("銘柄情報") {
                    TextField("銘柄名", text: $name)
                        .focused($focusedField, equals: .name)
                    
                    HStack {
                        Text("1箱あたりの本数")
                        Spacer()
                        TextField("20", text: $countPerPack)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .focused($focusedField, equals: .count)
                        Text("本")
                    }
                    
                    HStack {
                        Text("1箱あたりの価格")
                        Spacer()
                        Text("¥")
                        TextField("600", text: $pricePerPack)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .price)
                    }
                }
            }
            .navigationTitle("銘柄を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addBrand()
                    }
                    .disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        focusedField = nil
                    }
                }
            }
        }
    }
    
    /// 銘柄を追加
    private func addBrand() {
        guard let count = Int(countPerPack),
              let price = Decimal(string: pricePerPack) else { return }
        
        let brand = CigaretteBrand(
            name: name,
            countPerPack: count,
            pricePerPack: price
        )
        
        modelContext.insert(brand)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("銘柄の保存に失敗しました: \(error)")
        }
    }
}

/// データ管理ビュー
struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [SmokingRecord]
    @Query private var brands: [CigaretteBrand]
    @Query private var settings: [AppSettings]
    
    @State private var iCloudSyncEnabled = SharedModelContainer.isICloudSyncEnabled
    @State private var showRestartAlert = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var showImportConfirmAlert = false
    @State private var showImportSuccessAlert = false
    @State private var showImportErrorAlert = false
    @State private var importErrorMessage = ""
    @State private var pendingImportData: Data?
    @State private var exportFileURL: URL?
    
    private var currentSettings: AppSettings? {
        settings.first
    }
    
    var body: some View {
        Form {
            iCloudSyncSection
            manualBackupSection
            dataOverviewSection
        }
        .navigationTitle("データ管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("アプリの再起動が必要です", isPresented: $showRestartAlert) {
            Button("OK") { }
        } message: {
            Text("iCloud同期の設定を反映するには、アプリを完全に終了して再起動してください。")
        }
        .alert("データをインポートしますか？", isPresented: $showImportConfirmAlert) {
            Button("キャンセル", role: .cancel) {
                pendingImportData = nil
            }
            Button("インポート", role: .destructive) {
                performImport()
            }
        } message: {
            Text(importConfirmMessage)
        }
        .alert("インポート完了", isPresented: $showImportSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("データのインポートが完了しました。")
        }
        .alert("インポートエラー", isPresented: $showImportErrorAlert) {
            Button("OK") { }
        } message: {
            Text(importErrorMessage)
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }
    
    // MARK: - View Components
    
    /// iCloud同期セクション
    @ViewBuilder
    private var iCloudSyncSection: some View {
        Section {
            Toggle(isOn: $iCloudSyncEnabled) {
                Label("iCloud同期", systemImage: "icloud")
            }
            .onChange(of: iCloudSyncEnabled) { _, newValue in
                handleICloudSyncToggle(newValue)
            }
            
            iCloudStatusRow
        } header: {
            Text("クラウド同期")
        } footer: {
            Text("iCloud同期を有効にすると、同じApple IDでサインインしている他のデバイスとデータが自動的に同期されます。設定を変更した場合はアプリの再起動が必要です。")
        }
    }
    
    /// iCloud同期状態の行
    @ViewBuilder
    private var iCloudStatusRow: some View {
        if iCloudSyncEnabled {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("同期が有効です")
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("データはこのデバイスにのみ保存されます")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    /// 手動バックアップセクション
    @ViewBuilder
    private var manualBackupSection: some View {
        Section {
            Button(action: exportData) {
                exportButtonContent
            }
            
            Button(action: { showImportPicker = true }) {
                Label("データをインポート", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("手動バックアップ")
        } footer: {
            Text("JSONファイル形式でデータをエクスポート・インポートできます。機種変更時やバックアップ用にご利用ください。")
        }
    }
    
    /// エクスポートボタンの内容
    private var exportButtonContent: some View {
        HStack {
            Label("データをエクスポート", systemImage: "square.and.arrow.up")
            Spacer()
            Text("\(records.count)件の記録")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
    
    /// データ概要セクション
    @ViewBuilder
    private var dataOverviewSection: some View {
        Section("現在のデータ") {
            HStack {
                Text("喫煙記録")
                Spacer()
                Text("\(records.count)件")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("登録銘柄")
                Spacer()
                Text("\(brands.count)件")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    /// インポート確認メッセージ
    private var importConfirmMessage: String {
        guard let data = pendingImportData,
              let summary = BackupManager.shared.getBackupSummary(from: data) else {
            return "既存のデータは上書きされます。"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: summary.exportDate)
        return "既存のデータは上書きされます。\n\nバックアップ日時: \(dateString)\n記録数: \(summary.recordCount)件\n銘柄数: \(summary.brandCount)件"
    }
    
    // MARK: - Actions
    
    /// iCloud同期トグルの変更を処理
    private func handleICloudSyncToggle(_ enabled: Bool) {
        SharedModelContainer.isICloudSyncEnabled = enabled
        
        if let settings = currentSettings {
            settings.iCloudSyncEnabled = enabled
            try? modelContext.save()
        }
        
        showRestartAlert = true
    }
    
    /// データをエクスポート
    private func exportData() {
        do {
            let data = try BackupManager.shared.exportData(
                records: records,
                brands: brands,
                settings: currentSettings
            )
            
            let fileName = BackupManager.shared.generateExportFileName()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            
            exportFileURL = tempURL
            showExportSheet = true
        } catch {
            print("❌ エクスポートエラー: \(error)")
        }
    }
    
    /// インポート結果を処理
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "ファイルへのアクセス権限がありません。"
                showImportErrorAlert = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                _ = try BackupManager.shared.parseBackupData(from: data)
                pendingImportData = data
                showImportConfirmAlert = true
            } catch {
                importErrorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
                showImportErrorAlert = true
            }
            
        case .failure(let error):
            importErrorMessage = "ファイルの選択に失敗しました: \(error.localizedDescription)"
            showImportErrorAlert = true
        }
    }
    
    /// インポートを実行
    private func performImport() {
        guard let data = pendingImportData else { return }
        
        do {
            let backupData = try BackupManager.shared.parseBackupData(from: data)
            try BackupManager.shared.importData(backupData, to: modelContext, clearExisting: true)
            showImportSuccessAlert = true
        } catch {
            importErrorMessage = "インポートに失敗しました: \(error.localizedDescription)"
            showImportErrorAlert = true
        }
        
        pendingImportData = nil
    }
}

/// 共有シート（UIActivityViewController）
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(for: [CigaretteBrand.self, AppSettings.self], inMemory: true)
}
