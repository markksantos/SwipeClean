import Foundation

struct OnboardingPage: Identifiable {
    let id: Int
    let iconName: String
    let title: String
    let subtitle: String

    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            iconName: "hand.draw",
            title: "Swipe to clean",
            subtitle: "Right to keep. Left to delete."
        ),
        OnboardingPage(
            id: 1,
            iconName: "photo.on.rectangle.angled",
            title: "Pick your mess",
            subtitle: "Choose an album or smart collection to clean up."
        ),
        OnboardingPage(
            id: 2,
            iconName: "chart.bar.fill",
            title: "Free up space",
            subtitle: "Track how much storage you've reclaimed."
        )
    ]
}
