import Foundation

@main
@MainActor
struct NavigationTests {
    static func main() {
        let first = UUID(), second = UUID()
        precondition(NotificationRecordRoute.recordID(userInfo: ["recordID": first.uuidString], requestIdentifier: "custom") == first)
        precondition(NotificationRecordRoute.recordID(userInfo: [:], requestIdentifier: first.uuidString) == first)
        precondition(NotificationRecordRoute.recordID(userInfo: [:], requestIdentifier: "resenago.activity.\(first)") == first)
        precondition(NotificationRecordRoute.recordID(userInfo: [:], requestIdentifier: "resenago.test") == nil)
        precondition(NotificationRecordRoute.recordID(userInfo: ["recordID": "not-a-uuid"], requestIdentifier: "invalid") == nil)
        let router = AppRouter()
        router.openRecord(first)
        router.resolve(availableRecordIDs: [], isSignedIn: true, hasLoadedAccount: false)
        precondition(router.pendingRecordID == first && router.historyPath.isEmpty, "Cold launch must wait for stored records")
        router.resolve(availableRecordIDs: [first], isSignedIn: false, hasLoadedAccount: true)
        precondition(router.pendingRecordID == first, "Signed-out users must sign in before opening a private record")
        router.resolve(availableRecordIDs: [first], isSignedIn: true, hasLoadedAccount: true)
        precondition(router.pendingRecordID == nil && router.selectedTab == .sites && router.historyPath == [first])
        router.selectedTab = .earnings
        router.openRecord(second)
        router.resolve(availableRecordIDs: [first, second], isSignedIn: true, hasLoadedAccount: true)
        precondition(router.selectedTab == .sites && router.historyPath == [second], "A new notification must open the correct business from another tab")
        router.openRecord(second)
        router.resolve(availableRecordIDs: [second], isSignedIn: true, hasLoadedAccount: true)
        precondition(router.historyPath == [second], "Repeated taps must not stack duplicate screens")
        router.openRecord(first)
        router.resolve(availableRecordIDs: [second], isSignedIn: true, hasLoadedAccount: true)
        precondition(router.historyPath.isEmpty && router.showUnavailableRecord, "Deleted or other-account records must not expose a stale detail")
        router.resetNavigation()
        precondition(router.historyPath.isEmpty && router.selectedTab == .home && !router.showUnavailableRecord)
        print("PASS: 12 notification routing checks (cold launch, sign-in, correct business, repeated taps, missing record)")
    }
}
