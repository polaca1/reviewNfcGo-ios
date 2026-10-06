import Foundation
import Combine

enum AppTab: Hashable { case home, sites, earnings, reminders, profile }

enum NotificationRecordRoute {
    static func recordID(userInfo: [AnyHashable: Any], requestIdentifier: String) -> UUID? {
        if let value = userInfo["recordID"] as? String, let id = UUID(uuidString: value) { return id }
        // Support pending notifications created by previous app versions.
        if let id = UUID(uuidString: requestIdentifier) { return id }
        let prefix = "resenago.activity."
        guard requestIdentifier.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(requestIdentifier.dropFirst(prefix.count)))
    }
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var selectedTab: AppTab = .home
    @Published var historyPath: [UUID] = []
    @Published private(set) var pendingRecordID: UUID?
    @Published var showUnavailableRecord = false

    func openRecord(_ id: UUID) { pendingRecordID = id }

    func resolve(availableRecordIDs: Set<UUID>, isSignedIn: Bool, hasLoadedAccount: Bool) {
        // A notification can arrive before the first SwiftUI scene or sign-in.
        guard isSignedIn, hasLoadedAccount, let id = pendingRecordID else { return }
        pendingRecordID = nil
        selectedTab = .sites
        if availableRecordIDs.contains(id) {
            historyPath = [id]
            showUnavailableRecord = false
        } else {
            historyPath = []
            showUnavailableRecord = true
        }
    }

    func resetNavigation() {
        historyPath = []
        selectedTab = .home
        showUnavailableRecord = false
    }
}
