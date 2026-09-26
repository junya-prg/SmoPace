//
//  CustomBackgroundStore.swift
//  SmoPace
//
//  リラックスモード「マイ背景」の画像を保存・読み込みするストア
//  Image Playground で生成した画像や写真ライブラリの画像を
//  Application Support 配下に JPEG として1枚だけ保持する（CloudKit には同期しない）
//

import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "jp.junya.SmoPace", category: "CustomBackgroundStore")

/// マイ背景の保存・読み込みを担当する
@MainActor
@Observable
final class CustomBackgroundStore {
    static let shared = CustomBackgroundStore()

    /// 現在保存されている背景画像（無ければ nil）
    private(set) var image: UIImage?

    /// 背景画像が存在するか
    var exists: Bool { image != nil }

    /// 保存時の長辺の最大ピクセル数
    private let maxPixelSize: CGFloat = 2048

    /// 保存ディレクトリ
    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("RelaxBackground", isDirectory: true)
    }

    /// 保存ファイル
    private var fileURL: URL {
        directoryURL.appendingPathComponent("custom.jpg")
    }

    private init() {
        image = loadFromDisk()
    }

    // MARK: - 読み込み

    private func loadFromDisk() -> UIImage? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else {
            logger.error("マイ背景の読み込みに失敗しました")
            return nil
        }
        return image
    }

    // MARK: - 保存

    /// Image Playground などが返す一時 URL から保存する
    /// - Note: 一時ファイルはシート終了後に消えるため、完了コールバック内で即座に呼ぶこと
    func save(fromTemporaryURL url: URL) throws {
        let data = try Data(contentsOf: url)
        try save(imageData: data)
    }

    /// 画像データから保存する（長辺 2048px に縮小して JPEG 化）
    func save(imageData: Data) throws {
        guard let downscaled = Self.downscaledImage(from: imageData, maxPixelSize: maxPixelSize) else {
            throw CustomBackgroundError.decodeFailed
        }
        guard let jpeg = downscaled.jpegData(compressionQuality: 0.9) else {
            throw CustomBackgroundError.encodeFailed
        }

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try jpeg.write(to: fileURL, options: .atomic)

        // iCloud バックアップ対象から除外（再生成・再選択できるため）
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var savedURL = fileURL
        try? savedURL.setResourceValues(resourceValues)

        image = downscaled
        logger.info("マイ背景を保存しました (\(Int(downscaled.size.width))x\(Int(downscaled.size.height)))")
    }

    // MARK: - 削除

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
        image = nil
        logger.info("マイ背景を削除しました")
    }

    // MARK: - 縮小

    /// ImageIO のサムネイル生成でメモリ効率よく縮小する
    private static func downscaledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// マイ背景の保存に関するエラー
enum CustomBackgroundError: LocalizedError {
    case decodeFailed
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .decodeFailed:
            return String(localized: "画像を読み込めませんでした")
        case .encodeFailed:
            return String(localized: "画像を保存できませんでした")
        }
    }
}
