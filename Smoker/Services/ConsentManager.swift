//
//  ConsentManager.swift
//  Smoker
//
//  UMP（User Messaging Platform）同意管理サービス
//  GDPR / 米国州法 / IDFA 説明メッセージなど、AdMob管理画面で公開した
//  同意フォームを必要に応じて表示する。
//

import Foundation
import UIKit
import UserMessagingPlatform
import os

private let logger = Logger(subsystem: "SmokeCounter", category: "ConsentManager")

@MainActor
final class ConsentManager {
    static let shared = ConsentManager()

    private(set) var isCompleted = false

    private init() {}

    /// 同意情報を更新し、必要ならフォームを表示する
    /// 完了後（同意結果に関わらず）completion が呼ばれる
    func gatherConsent(completion: @escaping () -> Void) {
        let parameters = RequestParameters()

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            guard let self else { return }

            if let error {
                logger.error("⚠️ Consent info update failed: \(error.localizedDescription)")
                self.complete(completion)
                return
            }

            Task { @MainActor in
                guard let rootVC = Self.topViewController() else {
                    self.complete(completion)
                    return
                }

                do {
                    try await ConsentForm.loadAndPresentIfRequired(from: rootVC)
                    logger.info("✅ Consent form flow completed")
                } catch {
                    logger.error("⚠️ Consent form failed: \(error.localizedDescription)")
                }

                self.complete(completion)
            }
        }
    }

    private func complete(_ completion: @escaping () -> Void) {
        isCompleted = true
        AdManager.shared.markConsentResolved()
        completion()
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? scene?.windows.first?.rootViewController
    }
}
