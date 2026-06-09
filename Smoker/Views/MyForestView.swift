//
//  MyForestView.swift
//  Smoker
//
//  マイフォレスト画面 - 移植された大樹たちのコレクション表示
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct MyForestView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// Trackerの監視
    @State private var tracker = PaceNewsTracker.shared
    
    /// グリッド列のレイアウト（幅に合わせて自動調整）
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // トータルステータスカード（グラスモルフィズム風）
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.mint, .green],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .mint.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "tree.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("森の大樹たち")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Text("これまでに移植された大樹の総数")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(tracker.transplantedTrees.count)本")
                                  .font(.system(size: 32, weight: .black, design: .rounded))
                                  .foregroundStyle(
                                      LinearGradient(
                                          colors: [.mint, .blue],
                                          startPoint: .leading,
                                          endPoint: .trailing
                                      )
                                  )
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
                        
                        if tracker.transplantedTrees.isEmpty {
                            // 空の状態のプレースホルダー
                            VStack(spacing: 20) {
                                Spacer(minLength: 40)
                                Image(systemName: "tree.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.tertiary)
                                    .padding()
                                    .background(
                                        Circle()
                                            .fill(Color.primary.opacity(0.03))
                                            .frame(width: 130, height: 130)
                                    )
                                
                                Text("森はまだ静かです")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("AIニュースを読んで苗木をMAXまで育てると、ここにあなただけの大樹を植樹することができます。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                Spacer(minLength: 40)
                            }
                        } else {
                            // 大樹のグリッド表示
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(tracker.transplantedTrees.reversed()) { tree in
                                    TreeCardView(tree: tree)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("マイフォレスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 大樹カードビュー

@available(iOS 26.0, macOS 26.0, *)
struct TreeCardView: View {
    let tree: TransplantedTree
    
    private var gradientColors: [Color] {
        tree.colorsHex.map { Color(hex: $0) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 大樹のシンボル表示（グラデーション）
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: gradientColors.first?.opacity(0.4) ?? .clear, radius: 8, x: 0, y: 4)
                
                Image(systemName: tree.iconName)
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(.top, 8)
            
            VStack(spacing: 4) {
                Text(tree.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Text("第\(tree.cycleIndex)代目")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                
                Text(formattedDate(tree.transplantedAt))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}

// MARK: - カラーコード変換用拡張

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
