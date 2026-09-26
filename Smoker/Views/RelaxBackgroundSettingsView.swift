//
//  RelaxBackgroundSettingsView.swift
//  SmoPace
//
//  リラックス背景の設定画面
//  - 背景の種類（ランダム / 煙 / 炎 / 焚き火 / マイ背景）の選択
//  - マイ背景の作成（Image Playground）・写真からの選択・削除
//

import SwiftUI
import SwiftData
import PhotosUI
import ImagePlayground

/// Image Playground に渡すプリセットのテーマ
enum RelaxBackgroundConcept: String, CaseIterable, Identifiable {
    case campfire
    case fireplace
    case seaside
    case forest

    var id: String { rawValue }

    /// 表示名
    var title: String {
        switch self {
        case .campfire:  return String(localized: "夜の焚き火")
        case .fireplace: return String(localized: "暖炉")
        case .seaside:   return String(localized: "夜の海辺")
        case .forest:    return String(localized: "朝の森")
        }
    }

    /// 生成プロンプト（Image Playground のコンセプト）
    var prompt: String {
        switch self {
        case .campfire:
            return String(localized: "夜のキャンプ場で静かに燃える焚き火。暖かいオレンジの光、星空、穏やかで癒される雰囲気、写実的な写真")
        case .fireplace:
            return String(localized: "薪が燃える暖炉のある落ち着いたリビング。柔らかい光、木のぬくもり、リラックスした雰囲気、写実的な写真")
        case .seaside:
            return String(localized: "月明かりに照らされた静かな夜の海辺。穏やかな波、深い青の空、癒される雰囲気、写実的な写真")
        case .forest:
            return String(localized: "朝霧に包まれた静かな森。木漏れ日、緑の葉、深呼吸したくなる清々しい雰囲気、写実的な写真")
        }
    }
}

/// リラックス背景の設定画面
struct RelaxBackgroundSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @Query private var settings: [AppSettings]

    private var store = CustomBackgroundStore.shared

    /// Picker の選択状態（DB と onChange で同期）
    @State private var selectedType: RelaxingBackgroundType = .random
    @State private var selectedConcept: RelaxBackgroundConcept = .campfire
    @State private var showImagePlayground = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var errorMessage: String?

    private var currentSettings: AppSettings? { settings.first }

    /// Picker に出す選択肢（マイ背景は画像があるときだけ）
    private var selectableTypes: [RelaxingBackgroundType] {
        RelaxingBackgroundType.allCases.filter { $0 != .custom || store.exists }
    }

    var body: some View {
        Form {
            // 背景の種類
            Section {
                Picker("背景の種類", selection: $selectedType) {
                    ForEach(selectableTypes) { type in
                        Label(type.displayName, systemImage: type.iconName)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("背景の種類")
            } footer: {
                Text(selectedType.localizedDescription)
            }

            // マイ背景
            Section {
                if let image = store.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if supportsImagePlayground {
                    Picker("テーマ", selection: $selectedConcept) {
                        ForEach(RelaxBackgroundConcept.allCases) { concept in
                            Text(concept.title).tag(concept)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        showImagePlayground = true
                    } label: {
                        Label("AIで背景を作る", systemImage: "sparkles")
                    }
                    .disabled(isImporting)
                } else {
                    Text("Image Playground はこの端末では利用できません")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("写真から選ぶ", systemImage: "photo.on.rectangle")
                }
                .disabled(isImporting)

                if store.exists {
                    Button(role: .destructive) {
                        deleteCustomBackground()
                    } label: {
                        Label("背景を削除", systemImage: "trash")
                    }
                }
            } header: {
                Text("マイ背景")
            } footer: {
                Text("作った画像や選んだ写真の上に、陽炎と火の粉の演出が重なります。画像はこの端末にだけ保存されます。")
            }
        }
        .navigationTitle("リラックス背景")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isImporting {
                ProgressView()
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .imagePlaygroundSheet(
            isPresented: $showImagePlayground,
            concepts: [.text(selectedConcept.prompt)],
            onCompletion: { url in
                importGeneratedImage(from: url)
            }
        )
        .modifier(ImagePlaygroundConfiguration())
        .alert(
            "エラー",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            selectedType = currentSettings?.backgroundType ?? .random
        }
        .onChange(of: selectedType) { _, newValue in
            saveBackgroundType(newValue)
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            importPhoto(newItem)
        }
    }

    // MARK: - 保存

    private func saveBackgroundType(_ type: RelaxingBackgroundType) {
        guard let currentSettings, currentSettings.backgroundType != type else { return }
        currentSettings.backgroundType = type
        saveContext()
    }

    /// Image Playground の完了 URL から取り込む（一時ファイルなので即座に保存）
    private func importGeneratedImage(from url: URL) {
        do {
            try store.save(fromTemporaryURL: url)
            selectedType = .custom
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 写真ライブラリから取り込む
    private func importPhoto(_ item: PhotosPickerItem) {
        isImporting = true
        Task {
            defer {
                isImporting = false
                photoItem = nil
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw CustomBackgroundError.decodeFailed
                }
                try store.save(imageData: data)
                selectedType = .custom
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteCustomBackground() {
        store.delete()
        if selectedType == .custom {
            selectedType = .random
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("背景設定の保存に失敗しました: \(error)")
        }
    }
}

// MARK: - Image Playground の構成

/// iOS 27 ではフォトリアルを含む任意スタイルと画面サイズ指定を有効にする
private struct ImagePlaygroundConfiguration: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content
                .imagePlaygroundGenerationStyle(.any, in: [.any, .illustration, .animation])
                .imagePlaygroundOptions(Self.iOS27Options())
        } else {
            content
        }
    }

    @available(iOS 27.0, *)
    private static func iOS27Options() -> ImagePlaygroundOptions {
        var options = ImagePlaygroundOptions()
        options.personalization = .disabled
        options.creationStrategy = .generateNew
        // 端末の縦画面いっぱいに使えるサイズを要求（ピクセル単位）
        options.sizeSpecification = .closest(to: portraitScreenPixelSize())
        return options
    }

    /// 現在のウィンドウシーンから縦向きの画面ピクセルサイズを取得（取得できなければ 6.1 インチ相当）
    private static func portraitScreenPixelSize() -> CGSize {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let screen = scene?.screen else {
            return CGSize(width: 1179, height: 2556)
        }
        let bounds = screen.bounds.size
        let scale = screen.scale
        let portrait = CGSize(width: min(bounds.width, bounds.height), height: max(bounds.width, bounds.height))
        return CGSize(width: portrait.width * scale, height: portrait.height * scale)
    }
}

#Preview {
    NavigationStack {
        RelaxBackgroundSettingsView()
    }
    .modelContainer(for: [AppSettings.self], inMemory: true)
}
