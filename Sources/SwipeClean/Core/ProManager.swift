import Combine
import StoreKit

/// The features that are only available to SwipeClean Pro.
///
/// Swiping itself is never gated. Reviewing a library by hand is the whole
/// product, and metering it would earn one-star reviews for the exact thing the
/// App Store listing promises. Pro sells the *automatic* work instead — the
/// passes that decide for you, and the montage that makes something out of what
/// you kept.
enum ProFeature: String, CaseIterable, Identifiable {
    case smartCleanup
    case similarPhotos
    case autoClean
    case supercut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smartCleanup: return "Smart Cleanup"
        case .similarPhotos: return "Similar Photos"
        case .autoClean: return "Auto Clean Rules"
        case .supercut: return "Supercut"
        }
    }

    var pitch: String {
        switch self {
        case .smartCleanup:
            return "Scores every photo for blur, framing, and faces, then puts the worst ones first."
        case .similarPhotos:
            return "Groups near-duplicate bursts side by side so you can keep the best one and drop the rest."
        case .autoClean:
            return "Standing rules like \"screenshots older than six months\" flag photos before you even look."
        case .supercut:
            return "Turns any month or album into a montage video, cut to the beat of a song you pick."
        }
    }

    var icon: String {
        switch self {
        case .smartCleanup: return "wand.and.stars"
        case .similarPhotos: return "square.on.square"
        case .autoClean: return "slider.horizontal.3"
        case .supercut: return "film"
        }
    }
}

/// Owns SwipeClean's single non-consumable "Pro" unlock via StoreKit 2.
///
/// During development the flow is driven by the bundled `SwipeClean.storekit`
/// configuration (wired into the scheme's run options). In production the same
/// code talks to the App Store once the product id below exists in App Store
/// Connect.
@MainActor
final class ProManager: ObservableObject {
    static let shared = ProManager()

    static let proProductID = "com.nosleeplab.swipeclean.pro.lifetime"

    @Published private(set) var isPro = false
    @Published private(set) var isWorking = false
    @Published private(set) var product: Product?
    /// Set when a purchase or restore fails, so the paywall can say what went
    /// wrong rather than appearing to do nothing.
    @Published var errorMessage: String?

    /// Localized price, with a placeholder before the catalog loads so the paywall
    /// is never blank.
    var displayPrice: String { product?.displayPrice ?? "$4.99" }

    private let defaults: UserDefaults
    private let entitlementKey = "sc_pro_unlocked"
    // Held for the life of the singleton so purchases approved outside the app
    // (Ask to Buy, another device) still land. Never cancelled.
    private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Trust the cached flag for the first frame so gated rows don't flash
        // locked on launch; the App Store is the authority a moment later.
        isPro = defaults.bool(forKey: entitlementKey)
        updatesTask = listenForTransactions()

        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    // MARK: - Gating

    func isLocked(_ feature: ProFeature) -> Bool { !isPro }

    /// The Pro feature an album source represents, or nil when the source is a
    /// plain album that anyone can swipe through.
    func feature(for source: AlbumSource) -> ProFeature? {
        switch source {
        case .smartCleanup: return .smartCleanup
        case .similarPhotos: return .similarPhotos
        case .autoClean: return .autoClean
        default: return nil
        }
    }

    func isLocked(_ source: AlbumSource) -> Bool {
        guard let feature = feature(for: source) else { return false }
        return isLocked(feature)
    }

    // MARK: - Catalog

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.proProductID]).first
        } catch {
            // Non-fatal: the paywall falls back to the placeholder price and the
            // purchase button re-fetches before charging.
            errorMessage = nil
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        if product == nil { await loadProduct() }
        guard let product else {
            errorMessage = "The App Store isn't reachable right now. Check your connection and try again."
            return
        }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                setPro(true)
            case .pending:
                errorMessage = "That purchase needs approval before Pro unlocks."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        await refreshEntitlements()
        if !isPro {
            errorMessage = "No previous SwipeClean Pro purchase was found on this Apple Account."
        }
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == Self.proProductID, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        setPro(unlocked)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self, let transaction = try? self.checkVerified(result) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }

    private func setPro(_ value: Bool) {
        isPro = value
        defaults.set(value, forKey: entitlementKey)
    }
}
