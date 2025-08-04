//
//  StoreManager.swift
//  Socra
//
//  Handles the $9.99 / month subscription with 7-day free trial
//  using StoreKit 2.  Exposes a single `load()` entry point that
//  fetches products and starts a transaction-update listener.
//

import StoreKit
import SwiftUI
import os.log

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.funloop.socra",
    category: "StoreManager"
)

@MainActor
final class StoreManager: ObservableObject {

    // ───────── Published state ─────────
    @Published var products:        [Product] = []
    @Published var isLoading:       Bool      = true
    @Published var isPurchasing:    Bool      = false
        @AppStorage("isSubscribed") private var subscribed = false
    var isSubscribed: Bool { subscribed }   // ← no async, no MainActor hop


    // ───────── Product IDs (update to match App Store Connect) ─────────
    private let productIDs = ["com.funloop.socra.plus.monthly"]

    // MARK: – Public API
    /// Call once from `.task { await store.load() }`
    func load() async {
        await fetchProducts()
        observeTransactions()              // detached listener
        await refreshSubscriptionStatus()  // set flag at launch
    }

    /// Launch the purchase flow for the monthly plan.
    /// Returns `true` when the user is now entitled.
    @discardableResult
    func purchaseMonthly() async throws -> Bool {
        guard let product = products.first else {
            throw StoreError.noProduct
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            subscribed = true
            logger.info("✅ Purchase complete for \(product.id, privacy: .public)")
            return true

        case .userCancelled:
            logger.debug("User cancelled purchase")
            return false

        case .pending:
            logger.debug("Purchase pending – awaiting payment method auth")
            return false

        @unknown default:
            return false
        }
    }

    // Restore button helper
    func refreshSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               productIDs.contains(tx.productID) {
                subscribed = true
                return
            }
        }
        subscribed = false
    }

    // MARK: – Private
    private func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.products = try await Product.products(for: self.productIDs)
            logger.info("Fetched \(self.products.count, privacy: .public) products")
        } catch {
            logger.error("Product fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Detached transaction stream listener
    private func observeTransactions() {
        Task { @MainActor in                          // run on MainActor
            for await update in Transaction.updates {
                do {
                    let transaction = try checkVerified(update)
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                } catch {
                    logger.error("⚠️ Verification failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: – Helper
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let signed):
            return signed
        }
    }

    enum StoreError: LocalizedError {
        case noProduct
        case failedVerification
    }
}
