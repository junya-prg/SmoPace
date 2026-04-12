//
//  BackupManager.swift
//  SmokeCounter
//
//  データのバックアップ（エクスポート）と復元（インポート）を管理
//

import Foundation
import SwiftData

/// バックアップマネージャー
/// JSONファイルへのエクスポートとインポートを担当
class BackupManager {
    
    // MARK: - DTO（データ転送オブジェクト）
    
    /// 喫煙記録のDTO
    struct SmokingRecordDTO: Codable {
        let id: UUID
        let timestamp: Date
        let count: Int
        let brandId: UUID?
        let brandName: String?
        let pricePerCigarette: String?
        
        init(from record: SmokingRecord) {
            self.id = record.id
            self.timestamp = record.timestamp
            self.count = record.count
            self.brandId = record.brandId
            self.brandName = record.brandName
            self.pricePerCigarette = record.pricePerCigarette.map { "\($0)" }
        }
        
        func toModel() -> SmokingRecord {
            let price: Decimal? = pricePerCigarette.flatMap { Decimal(string: $0) }
            let record = SmokingRecord(
                timestamp: timestamp,
                count: count,
                brandId: brandId,
                brandName: brandName,
                pricePerCigarette: price
            )
            // バックアップ時の記録IDを維持（重複インポート時の識別用）
            record.id = id
            return record
        }
    }
    
    /// タバコ銘柄のDTO
    struct CigaretteBrandDTO: Codable {
        let id: UUID
        let name: String
        let countPerPack: Int
        let pricePerPack: String
        let isActive: Bool
        let createdAt: Date
        let isDefault: Bool?
        
        init(from brand: CigaretteBrand) {
            self.id = brand.id
            self.name = brand.name
            self.countPerPack = brand.countPerPack
            self.pricePerPack = "\(brand.pricePerPack)"
            self.isActive = brand.isActive
            self.createdAt = brand.createdAt
            self.isDefault = brand.isDefault
        }
        
        func toModel() -> CigaretteBrand {
            let price = Decimal(string: pricePerPack) ?? 0
            let brand = CigaretteBrand(
                name: name,
                countPerPack: countPerPack,
                pricePerPack: price,
                isActive: isActive,
                isDefault: isDefault ?? false
            )
            // インポート後も銘柄IDを維持（記録の brandId と一致させる）
            brand.id = id
            brand.createdAt = createdAt
            return brand
        }
    }
    
    /// アプリ設定のDTO
    struct AppSettingsDTO: Codable {
        let healthKitEnabled: Bool
        let activeBrandId: UUID?
        let dailyGoal: Int?
        let backgroundTypeRawValue: String
        let backgroundOpacity: Double
        let iCloudSyncEnabled: Bool
        
        init(from settings: AppSettings) {
            self.healthKitEnabled = settings.healthKitEnabled
            self.activeBrandId = settings.activeBrandId
            self.dailyGoal = settings.dailyGoal
            self.backgroundTypeRawValue = settings.backgroundTypeRawValue
            self.backgroundOpacity = settings.backgroundOpacity
            self.iCloudSyncEnabled = settings.iCloudSyncEnabled
        }
        
        func toModel() -> AppSettings {
            let settings = AppSettings(
                healthKitEnabled: healthKitEnabled,
                activeBrandId: activeBrandId,
                dailyGoal: dailyGoal,
                backgroundOpacity: backgroundOpacity,
                iCloudSyncEnabled: iCloudSyncEnabled
            )
            settings.backgroundTypeRawValue = backgroundTypeRawValue
            return settings
        }
    }
    
    /// バックアップデータ全体の構造
    struct BackupData: Codable {
        let version: String
        let exportDate: Date
        let appName: String
        let records: [SmokingRecordDTO]
        let brands: [CigaretteBrandDTO]
        let settings: AppSettingsDTO?
        
        /// 現在のバックアップバージョン
        static let currentVersion = "1.0"
    }
    
    // MARK: - エラー定義
    
    enum BackupError: LocalizedError {
        case encodingFailed
        case decodingFailed
        case invalidVersion(String)
        case fileWriteFailed
        case fileReadFailed
        
        var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "データのエンコードに失敗しました"
            case .decodingFailed:
                return "データのデコードに失敗しました"
            case .invalidVersion(let version):
                return "サポートされていないバックアップバージョンです: \(version)"
            case .fileWriteFailed:
                return "ファイルの書き込みに失敗しました"
            case .fileReadFailed:
                return "ファイルの読み込みに失敗しました"
            }
        }
    }
    
    // MARK: - シングルトン
    
    static let shared = BackupManager()
    
    private init() {}
    
    // MARK: - エクスポート
    
    /// データをJSON形式でエクスポート
    /// - Parameters:
    ///   - records: 喫煙記録の配列
    ///   - brands: 銘柄の配列
    ///   - settings: アプリ設定（オプション）
    /// - Returns: JSONデータ
    func exportData(
        records: [SmokingRecord],
        brands: [CigaretteBrand],
        settings: AppSettings?
    ) throws -> Data {
        let recordDTOs = records.map { SmokingRecordDTO(from: $0) }
        let brandDTOs = brands.map { CigaretteBrandDTO(from: $0) }
        let settingsDTO = settings.map { AppSettingsDTO(from: $0) }
        
        let backupData = BackupData(
            version: BackupData.currentVersion,
            exportDate: Date(),
            appName: "SmokeCounter",
            records: recordDTOs,
            brands: brandDTOs,
            settings: settingsDTO
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            return try encoder.encode(backupData)
        } catch {
            print("❌ エクスポートエラー: \(error)")
            throw BackupError.encodingFailed
        }
    }
    
    /// エクスポート用のファイル名を生成
    func generateExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        return "SmokeCounter_Backup_\(dateString).json"
    }
    
    // MARK: - インポート
    
    /// JSONデータからバックアップデータを読み込み
    /// - Parameter data: JSONデータ
    /// - Returns: パースされたバックアップデータ
    func parseBackupData(from data: Data) throws -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let backupData = try decoder.decode(BackupData.self, from: data)
            
            // バージョンチェック（将来の互換性のため）
            if backupData.version != BackupData.currentVersion {
                print("⚠️ バックアップバージョンが異なります: \(backupData.version)")
            }
            
            return backupData
        } catch {
            print("❌ インポートエラー: \(error)")
            throw BackupError.decodingFailed
        }
    }
    
    /// バックアップデータをModelContextにインポート
    /// - Parameters:
    ///   - backupData: パースされたバックアップデータ
    ///   - modelContext: インポート先のModelContext
    ///   - clearExisting: 既存データを削除するかどうか
    func importData(
        _ backupData: BackupData,
        to modelContext: ModelContext,
        clearExisting: Bool = true
    ) throws {
        // 既存データの削除
        if clearExisting {
            try clearAllData(in: modelContext)
            // 大量削除と挿入を同一トランザクションにするとシミュレータ等でストアオープンに失敗することがあるため、一度コミットする
            try modelContext.save()
        }
        
        // 銘柄のインポート（記録より先にインポートする必要がある）
        for brandDTO in backupData.brands {
            let brand = brandDTO.toModel()
            modelContext.insert(brand)
        }
        
        // 設定のインポート（記録より先：activeBrandId が銘柄を参照する）
        if let settingsDTO = backupData.settings {
            let settings = settingsDTO.toModel()
            modelContext.insert(settings)
        }
        
        try modelContext.save()
        
        // 記録は件数が多い場合があるためバッチで保存（SwiftData の単一 save で失敗する端末への対策）
        let batchSize = 80
        var batchCount = 0
        for recordDTO in backupData.records {
            let record = recordDTO.toModel()
            modelContext.insert(record)
            batchCount += 1
            if batchCount >= batchSize {
                try modelContext.save()
                batchCount = 0
            }
        }
        if batchCount > 0 {
            try modelContext.save()
        }
        
        print("✅ インポート完了: \(backupData.records.count)件の記録, \(backupData.brands.count)件の銘柄")
    }
    
    /// 全データを削除
    private func clearAllData(in modelContext: ModelContext) throws {
        // 喫煙記録を削除
        let recordDescriptor = FetchDescriptor<SmokingRecord>()
        let records = try modelContext.fetch(recordDescriptor)
        for record in records {
            modelContext.delete(record)
        }
        
        // 銘柄を削除
        let brandDescriptor = FetchDescriptor<CigaretteBrand>()
        let brands = try modelContext.fetch(brandDescriptor)
        for brand in brands {
            modelContext.delete(brand)
        }
        
        // 設定を削除
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settingsList = try modelContext.fetch(settingsDescriptor)
        for settings in settingsList {
            modelContext.delete(settings)
        }
    }
    
    // MARK: - バックアップ情報
    
    /// バックアップデータの概要を取得
    func getBackupSummary(from data: Data) -> (recordCount: Int, brandCount: Int, exportDate: Date)? {
        guard let backupData = try? parseBackupData(from: data) else {
            return nil
        }
        return (backupData.records.count, backupData.brands.count, backupData.exportDate)
    }
}
