import Foundation
import Observation
import StoreKit

/// Native StoreKit 2 In-App Purchase manager compliant with Apple Review Guideline 3.1.1.
@Observable
@MainActor
public final class StoreKitManager {
    public static let productIds: [String] = [
        "com.verirx.app.monthly",
        "com.verirx.app.quarterly",
        "com.verirx.app.lifetime"
    ]

    public private(set) var products: [Product] = []
    public private(set) var isProEntitled: Bool = false
    public private(set) var isLoading: Bool = false
    public var errorMessage: String?

    public init() {}

    public func start(studyStore: StudyStore) async {
        await fetchProducts()
        await refreshEntitlements(studyStore: studyStore)
    }

    public func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Self.productIds)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Unable to load App Store plans: \(error.localizedDescription)"
        }
    }

    public func purchase(_ product: Product, studyStore: StudyStore) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements(studyStore: studyStore)
                } else {
                    errorMessage = "Purchase verification failed."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Required by Apple App Store Review Guideline 3.1.1 ("Restore Purchases" button).
    public func restorePurchases(studyStore: StudyStore) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements(studyStore: studyStore)
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    public func refreshEntitlements(studyStore: StudyStore) async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIds.contains(transaction.productID),
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isProEntitled = unlocked
        studyStore.isProUnlocked = unlocked
    }
}
