//
//  ModernSplashView.swift
//  Spoiled
//
//  Created by Assistant on 1/15/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct ModernSplashView: View {
    @ObservedObject var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var hasPerformedInitialHealth = false
    @State private var serverStatusMessage: String?
    private let healthService = HealthService()
    
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var buttonScale: CGFloat = 0.8
    @State private var buttonOpacity: Double = 0
    @State private var backgroundGradientOffset: CGFloat = -200
    
    var body: some View {
        ZStack {
            // Animated background
            LinearGradient(
                colors: [
                    Color(.systemPurple),
                    Color(.systemBlue),
                    Color(.systemTeal),
                    Color(.systemGreen)
                ],
                startPoint: .init(x: 0.2, y: 0.1),
                endPoint: .init(x: 0.8, y: 0.9)
            )
            .offset(y: backgroundGradientOffset)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: backgroundGradientOffset)
            .ignoresSafeArea()
            
            // Floating circles decoration
            GeometryReader { geometry in
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: CGFloat.random(in: 20...80))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .animation(
                            .easeInOut(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.5),
                            value: logoScale
                        )
                }
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo with animation
                ZStack {
                    // Glow effect
                    ZStack {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 120, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: 20)
                        
                        Image(systemName: "gift.fill")
                            .font(.system(size: 120, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blur(radius: 10)
                    }
                    
                    // Main logo
                    Image(systemName: "gift.fill")
                        .font(.system(size: 100, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                VStack(spacing: 16) {
                    // App title
                    Text("Welcome to Spoiled")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)
                    
                    // Subtitle
                    Text("Sign in to continue")
                        .font(.system(.title3, design: .default, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .opacity(subtitleOpacity)
                }
                
                Spacer()
                
                // Authentication content based on state
                authenticationContent
                
                // Privacy Policy link
                Button(action: {}) {
                    Link("Privacy Policy", destination: AppConfig.api.privacyPolicyURL)
                        .font(.system(.footnote, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .underline()
                }
                .opacity(subtitleOpacity)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Orchestrated animation sequence
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.3)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(1.2)) {
                subtitleOpacity = 1.0
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.6)) {
                buttonScale = 1.0
                buttonOpacity = 1.0
            }
            
            // Background animation trigger
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                backgroundGradientOffset = 0
            }
        }
        // Run health check once on first appearance
        .task {
            guard !hasPerformedInitialHealth else { return }
            let ok = await healthService.check()
            hasPerformedInitialHealth = true
            if !ok { serverStatusMessage = "Server unavailable." }
        }
    }
    
    @ViewBuilder
    private var authenticationContent: some View {
        switch auth.state {
        case .authenticating:
            VStack(spacing: 16) {
                Text("Signing in…")
                    .font(.system(.body, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
            .scaleEffect(buttonScale)
            .opacity(buttonOpacity)
            .padding(.horizontal, 32)
            
        default:
            VStack(spacing: 16) {
                if let serverError = serverStatusMessage {
                    Text(serverError)
                        .font(.system(.footnote, weight: .medium))
                        .foregroundColor(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                }
                
                // Modern Google Sign In
                ModernGoogleSignInButton()
                
                // Modern Apple Sign In  
                ModernAppleSignInButton()
            }
            .scaleEffect(buttonScale)
            .opacity(buttonOpacity)
            .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private func ModernGoogleSignInButton() -> some View {
        Button(action: { auth.signInWithGoogle() }) {
            HStack(spacing: 12) {
                // Google logo placeholder - you can replace with actual Google logo
                Circle()
                    .fill(Color.blue)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("G")
                            .font(.system(.caption, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Text("Sign in with Google")
                    .font(.system(.body, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    @ViewBuilder 
    private func ModernAppleSignInButton() -> some View {
        SignInWithAppleButton(.continue, onRequest: { request in
            auth.prepareAppleRequest(request)
        }, onCompletion: { result in
            auth.handleAppleCompletion(result)
        })
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ModernAuthButton: View {
    let icon: String
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Use SF Symbols for Apple logo, custom handling for Google
                if icon == "logo.google" {
                    // Google logo placeholder - you'd replace this with actual Google logo
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("G")
                                .font(.system(.caption, weight: .bold))
                                .foregroundColor(.white)
                        )
                } else {
                    Image(systemName: icon)
                        .font(.system(.title3, weight: .medium))
                        .foregroundColor(foregroundColor)
                }
                
                Text(title)
                    .font(.system(.body, weight: .semibold))
                    .foregroundColor(foregroundColor)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
