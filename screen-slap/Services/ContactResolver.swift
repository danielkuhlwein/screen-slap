//
//  ContactResolver.swift
//  screen-slap
//

import Contacts
import os

/// Resolves email addresses to contact information (name, photo) using Contacts.framework.
/// Results are cached per-session to avoid repeated lookups.
final class ContactResolver {

    static let shared = ContactResolver()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "screen-slap",
        category: "ContactResolver"
    )

    /// Cached contact info keyed by lowercase email
    private var cache: [String: ContactInfo] = [:]

    /// Whether we have Contacts access
    private var hasAccess: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    private let store = CNContactStore()

    struct ContactInfo {
        let givenName: String
        let familyName: String
        let thumbnailImageData: Data?
    }

    // MARK: - Public API

    /// Resolve a batch of email addresses to contact info.
    /// Returns a dictionary keyed by the original email (lowercased).
    func resolve(_ emails: [String]) -> [String: ContactInfo] {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            Self.logger.warning("Contacts not authorized (status: \(String(describing: status))), requesting access")
            requestAccessIfNeeded()
            return [:]
        }

        Self.logger.debug("Resolving \(emails.count) email(s): \(emails.joined(separator: ", "))")
        var results: [String: ContactInfo] = [:]

        for email in emails {
            let key = email.lowercased()

            // Check cache first
            if let cached = cache[key] {
                results[key] = cached
                continue
            }

            // Look up in Contacts
            if let info = lookupContact(email: key) {
                Self.logger.info("Resolved contact for \(key): \(info.givenName) \(info.familyName)")
                cache[key] = info
                results[key] = info
            } else {
                Self.logger.debug("No contact found for \(key)")
            }
        }

        Self.logger.debug("Resolved \(results.count)/\(emails.count) contacts")
        return results
    }

    /// Clear the cache (e.g., when contacts change)
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func lookupContact(email: String) -> ContactInfo? {
        let predicate = CNContact.predicateForContacts(matchingEmailAddress: email)
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
        ]

        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            guard let contact = contacts.first else { return nil }

            return ContactInfo(
                givenName: contact.givenName,
                familyName: contact.familyName,
                thumbnailImageData: contact.thumbnailImageData
            )
        } catch {
            Self.logger.error("Failed to look up contact for \(email): \(error.localizedDescription)")
            return nil
        }
    }

    private func requestAccessIfNeeded() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .notDetermined else { return }

        Task {
            do {
                let granted = try await store.requestAccess(for: .contacts)
                Self.logger.info("Contacts access request result: \(granted)")
            } catch {
                Self.logger.error("Failed to request contacts access: \(error.localizedDescription)")
            }
        }
    }
}
