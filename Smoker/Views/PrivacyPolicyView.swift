//
//  PrivacyPolicyView.swift
//  SmokeCounter
//
//  プライバシーポリシー表示画面
//

import SwiftUI

/// プライバシーポリシービュー
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 最終更新日
                    Text("最終更新日: 2026年2月2日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // 概要
                    PolicySection(title: "はじめに") {
                        Text("SmoPace（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めています。本プライバシーポリシーでは、本アプリがどのような情報を収集し、どのように使用するかについて説明します。")
                    }
                    
                    // 収集する情報
                    PolicySection(title: "収集する情報") {
                        VStack(alignment: .leading, spacing: 12) {
                            PolicySubSection(title: "1. 記録データ") {
                                Text("本アプリは、ユーザーが入力した本数、時刻、銘柄情報などの記録データを収集します。これらのデータはユーザーのデバイス上およびiCloud（ユーザーが有効にしている場合）に保存されます。")
                            }
                            
                            PolicySubSection(title: "2. 広告に関する情報") {
                                Text("本アプリはGoogle AdMobを使用して広告を表示します。AdMobは、パーソナライズされた広告を表示するために、デバイス識別子（IDFA）やIPアドレスなどの情報を収集する場合があります。ユーザーはiOSの設定からトラッキングを拒否することができます。")
                            }
                            
                            PolicySubSection(title: "3. 購入情報") {
                                Text("開発者支援（チップ）機能を利用した場合、Apple App Storeを通じて購入処理が行われます。本アプリは購入履歴を直接収集・保存しません。")
                            }
                        }
                    }
                    
                    // 情報の使用目的
                    PolicySection(title: "情報の使用目的") {
                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint("記録の管理と統計表示")
                            BulletPoint("iCloudを通じたデバイス間のデータ同期")
                            BulletPoint("広告の表示とパーソナライズ")
                            BulletPoint("アプリの改善と機能向上")
                        }
                    }
                    
                    // 第三者への情報提供
                    PolicySection(title: "第三者への情報提供") {
                        Text("本アプリは、以下の場合を除き、ユーザーの個人情報を第三者に提供しません：")
                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint("ユーザーの同意がある場合")
                            BulletPoint("法令に基づく場合")
                            BulletPoint("広告配信のためのGoogle AdMobへの情報提供（トラッキング許可時のみ）")
                        }
                    }
                    
                    // データの保存
                    PolicySection(title: "データの保存") {
                        Text("記録データは、ユーザーのデバイス上のローカルストレージおよびiCloud（有効な場合）に保存されます。ユーザーはいつでもアプリを削除することでローカルデータを削除できます。iCloudに保存されたデータは、iCloudの設定から削除できます。")
                    }
                    
                    // 広告について
                    PolicySection(title: "広告について") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("本アプリはGoogle AdMobを使用して広告を表示します。")
                            
                            Text("トラッキングを許可した場合、パーソナライズされた広告が表示されます。トラッキングを拒否した場合でも、コンテキストに基づいた広告が表示されます。")
                            
                            Text("Google AdMobのプライバシーポリシーについては、以下をご参照ください：")
                            
                            Link("Google プライバシーポリシー", destination: URL(string: "https://policies.google.com/privacy")!)
                                .font(.subheadline)
                        }
                    }
                    
                    // お問い合わせ
                    PolicySection(title: "お問い合わせ") {
                        Text("本プライバシーポリシーに関するご質問やお問い合わせは、App Storeのアプリページからお願いいたします。")
                    }
                    
                    // 変更について
                    PolicySection(title: "プライバシーポリシーの変更") {
                        Text("本プライバシーポリシーは、必要に応じて変更されることがあります。重要な変更がある場合は、アプリ内でお知らせします。")
                    }
                }
                .padding()
            }
            .navigationTitle("プライバシーポリシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// ポリシーセクション
struct PolicySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// ポリシーサブセクション
struct PolicySubSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// 箇条書きポイント
struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    PrivacyPolicyView()
}
