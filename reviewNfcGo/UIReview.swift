#if DEBUG
import SwiftUI

// These sample screens exist only in Debug simulator builds for visual review.
// They are excluded from the Release IPA.
enum UIReview {
    static var screen: String? { ProcessInfo.processInfo.environment["UI_REVIEW_SCREEN"] }
    static let place = PlaceResult(id: "ui-review-place", name: "Café del Parque",
        address: "Calle del Sol, 18 · Madrid", latitude: 40.4168, longitude: -3.7038)
    static var records: [VisitRecord] {
        [VisitRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, place: place,
            notes: "Hablar con Marta sobre la tarjeta NFC.", status: .pending,
            reminderDate: Date().addingTimeInterval(7200), notificationDate: Date().addingTimeInterval(3600)),
         VisitRecord(place: PlaceResult(id: "ui-review-place-2", name: "Estudio Norte",
            address: "Avenida de la Luz, 7 · Madrid", latitude: 40.418, longitude: -3.705),
            earnings: 45, notes: "Tarjeta entregada.", status: .completed),
         VisitRecord(place: PlaceResult(id: "ui-review-place-3", name: "La Floristería",
            address: "Plaza Mayor, 4 · Madrid", latitude: 40.415, longitude: -3.707))]
    }
}

struct UIReviewHost: View {
    let screen: String
    @StateObject private var auth: AuthStore
    @StateObject private var store: AppStore
    init(screen: String) {
        self.screen = screen
        let a = AuthStore()
        if !a.createAccount(name: "Alex", email: "preview@example.test", password: "preview-only") {
            _ = a.login(email: "preview@example.test", password: "preview-only")
        }
        let s = AppStore()
        s.records = UIReview.records
        _auth = StateObject(wrappedValue: a)
        _store = StateObject(wrappedValue: s)
    }
    var body: some View {
        Group {
            if screen == "auth" { AuthView() }
            else if screen == "reminder" { QuickReminderView(place: UIReview.place) }
            else {
                TabView {
                    Tab("Inicio", systemImage: "map") {
                        NavigationStack {
                            switch screen {
                            case "history": HistoryView()
                            case "detail": RecordDetailView(recordID: UIReview.records[0].id)
                            case "edit": RecordEditView(recordID: UIReview.records[0].id)
                            case "earnings": EarningsView()
                            case "reminders": RemindersView()
                            case "profile": ProfileView()
                            default: HomeView()
                            }
                        }
                    }
                    Tab("Sitios", systemImage: "building.2") { NavigationStack { HistoryView() } }
                    Tab("Ganancias", systemImage: "chart.bar") { NavigationStack { EarningsView() } }
                    Tab("Avisos", systemImage: "bell") { NavigationStack { RemindersView() } }
                    Tab("Perfil", systemImage: "person.crop.circle") { NavigationStack { ProfileView() } }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
            }
        }
        .environmentObject(auth).environmentObject(store).tint(.teal)
    }
}
#endif
