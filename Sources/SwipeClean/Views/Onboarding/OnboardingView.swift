import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @EnvironmentObject private var permissionManager: PermissionManager

    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var buttonPulse = false
    @State private var dragOffset: CGFloat = 0

    private let pages = OnboardingPage.allPages

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    pageView(for: page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom controls
            VStack(spacing: 20) {
                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(pages) { page in
                        Circle()
                            .fill(page.id == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                // Action button
                if currentPage == pages.count - 1 {
                    Button {
                        permissionManager.requestAccess { _ in
                            hasSeenOnboarding = true
                        }
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressDownButtonStyle())
                    .padding(.horizontal, 32)
                    .scaleEffect(buttonPulse ? 1.04 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: buttonPulse
                    )
                    .onAppear {
                        buttonPulse = true
                    }
                } else {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressDownButtonStyle())
                    .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 48)
        }
        .onChange(of: currentPage) { _ in
            // Reset and re-trigger icon animation on page change
            iconScale = 0.5
            iconOpacity = 0
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }

    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon with scale/bounce animation and parallax
            Image(systemName: page.iconName)
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .frame(height: 120)
                .scaleEffect(currentPage == page.id ? iconScale : 0.8)
                .opacity(currentPage == page.id ? iconOpacity : 0.4)
                .offset(x: currentPage == page.id ? 0 : (page.id < currentPage ? -30 : 30))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPage)

            // Title
            Text(page.title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
