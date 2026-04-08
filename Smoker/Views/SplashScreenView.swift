//
//  SplashScreenView.swift
//  SmokeCounter
//
//  アプリ起動時のスプラッシュスクリーン
//

import SwiftUI

/// スプラッシュスクリーンビュー
@available(iOS 26.0, macOS 26.0, *)
struct SplashScreenView: View {
    // アニメーション状態
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var iconRotation: Double = -30
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var backgroundOpacity: Double = 1
    
    // 完了コールバック
    var onFinished: () -> Void
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.14),
                    Color(red: 0.08, green: 0.08, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // アプリアイコン
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
                    .shadow(color: Color.cyan.opacity(0.3), radius: 40, x: 0, y: 0)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                    .rotationEffect(.degrees(iconRotation))
                
                // アプリ名
                VStack(spacing: 8) {
                    Text("SmoPace")
                        .font(.custom("Avenir Next", size: 36).weight(.bold))
                        .tracking(6)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.6, green: 0.85, blue: 1.0),
                                    Color(red: 0.4, green: 0.65, blue: 0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 2)
                    
                    Text("— 少しずつ、自分のペースで —")
                        .font(.custom("Avenir Next", size: 13).weight(.medium))
                        .tracking(2)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .opacity(backgroundOpacity)
        .onAppear {
            startAnimation()
        }
    }
    
    /// アニメーションを開始
    private func startAnimation() {
        // アイコンのフェードイン＆スケール（ゆっくり）
        withAnimation(.spring(response: 0.9, dampingFraction: 0.7, blendDuration: 0)) {
            iconScale = 1.0
            iconOpacity = 1.0
            iconRotation = 0
        }
        
        // テキストのフェードイン（ゆっくり）
        withAnimation(.easeOut(duration: 0.7).delay(0.5)) {
            textOpacity = 1.0
            textOffset = 0
        }
        
        // 少し待ってからフェードアウト（表示時間を長く）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                backgroundOpacity = 0
            }
            
            // アニメーション完了後にコールバック
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onFinished()
            }
        }
    }
}

#Preview {
    if #available(iOS 26.0, macOS 26.0, *) {
        SplashScreenView(onFinished: {})
    }
}
