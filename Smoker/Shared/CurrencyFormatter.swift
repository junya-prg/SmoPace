//
//  CurrencyFormatter.swift
//  SmokeCounter
//
//  通貨フォーマット用のヘルパー
//  AppSettings.currencyCodeに基づいて動的に表示形式を切り替える
//

import Foundation
import SwiftUI

/// 通貨フォーマット用のヘルパー
struct CurrencyFormatter {

    /// 金額を通貨コードに応じてフォーマット
    /// - Parameters:
    ///   - amount: 金額
    ///   - currencyCode: ISO 4217通貨コード（例: "JPY", "USD"）
    /// - Returns: フォーマット済み文字列（例: "¥600"、"$10.50"）
    static func format(_ amount: Decimal, currencyCode: String) -> String {
        // 空文字列が来たら防御的にデフォルトJPYへ
        let code = currencyCode.isEmpty ? "JPY" : currencyCode
        let digits = fractionDigits(for: code)
        return amount.formatted(
            .currency(code: code)
                .precision(.fractionLength(digits))
        )
    }

    /// 通貨コードから小数点以下の桁数を返す
    static func fractionDigits(for currencyCode: String) -> Int {
        switch currencyCode {
        case "JPY": return 0
        default: return 2
        }
    }

    /// フォーマット失敗時のフォールバック表示
    static func fallbackString(currencyCode: String) -> String {
        switch currencyCode {
        case "JPY": return "¥0"
        case "USD": return "$0.00"
        default: return "0"
        }
    }

    /// 通貨コードに対応するSF Symbolsアイコン名
    static func iconName(for currencyCode: String) -> String {
        switch currencyCode {
        case "JPY": return "yensign.circle"
        case "USD": return "dollarsign.circle"
        default: return "dollarsign.circle"
        }
    }

    /// 通貨記号（"¥", "$"など）
    static func symbol(for currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }

    /// 新規ユーザー用のデフォルト通貨コードを決定
    /// - 端末のリージョンが日本ならJPY、それ以外はUSD
    static func defaultCurrencyCode() -> String {
        if Locale.current.region?.identifier == "JP" {
            return "JPY"
        }
        return "USD"
    }

    /// 新規銘柄追加時のデフォルト価格
    static func defaultPriceForNewBrand(currencyCode: String) -> String {
        switch currencyCode {
        case "JPY": return "600"
        case "USD": return "10.00"
        default: return "0"
        }
    }

    /// 価格入力フィールドのキーボードタイプ
    /// JPYは整数のみ、USDなどは小数を許可
    static func keyboardType(for currencyCode: String) -> UIKeyboardType {
        switch currencyCode {
        case "JPY": return .numberPad
        default: return .decimalPad
        }
    }
}
