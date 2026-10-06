import SwiftUI
import MapKit
import CoreLocation
import UserNotifications
import CryptoKit
import UIKit
import ActivityKit

// MARK: - Models

struct UserProfile: Codable, Equatable {
    let name: String
    let email: String
}

struct PlaceResult: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var reviewURL: String {
        "https://search.google.com/local/writereview?placeid=\(id)"
    }
}

enum VisitStatus: String, Codable, CaseIterable {
    case contacted = "Contactado"
    case pending = "Volver otro día"
    case completed = "Completado"

    var displayName: String {
        switch self {
        case .contacted: return "Contactado"
        case .pending: return "Volver otro día"
        case .completed: return "Ya lo he vendido"
        }
    }
}

struct VisitRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var place: PlaceResult
    var createdAt: Date = Date()
    var earnings: Double = 0
    var notes: String = ""
    var status: VisitStatus = .contacted
    /// Fecha/hora de la visita prevista.
    var reminderDate: Date? = nil
    /// Momento en el que el usuario quiere recibir el aviso. Si es nil, se avisa a la hora de la visita.
    var notificationDate: Date? = nil
}

// MARK: - Authentication (local account on this iPhone)

final class AuthStore: ObservableObject {
    @Published private(set) var currentUser: UserProfile?
    @Published var errorMessage: String?

    private let userKey = "resenago.currentUser"
    private let accountsKey = "resenago.accounts"

    struct Account: Codable {
        let profile: UserProfile
        let passwordHash: String
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            currentUser = profile
        }
    }

    func createAccount(name: String, email: String, password: String) -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              cleanEmail.contains("@"), password.count >= 4 else {
            errorMessage = "Completa los datos. La contraseña debe tener al menos 4 caracteres."
            return false
        }
        var accounts = loadAccounts()
        guard accounts[cleanEmail] == nil else {
            errorMessage = "Ya existe una cuenta con ese correo."
            return false
        }
        let profile = UserProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: cleanEmail)
        accounts[cleanEmail] = Account(profile: profile, passwordHash: Self.hash(password))
        saveAccounts(accounts)
        setCurrent(profile)
        errorMessage = nil
        return true
    }

    func login(email: String, password: String) -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let accounts = loadAccounts()
        guard let account = accounts[cleanEmail], account.passwordHash == Self.hash(password) else {
            errorMessage = "Correo o contraseña incorrectos."
            return false
        }
        setCurrent(account.profile)
        errorMessage = nil
        return true
    }

    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    private func setCurrent(_ profile: UserProfile) {
        currentUser = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func loadAccounts() -> [String: Account] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let value = try? JSONDecoder().decode([String: Account].self, from: data) else { return [:] }
        return value
    }

    private func saveAccounts(_ accounts: [String: Account]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    private static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - App data

@MainActor
final class AppStore: ObservableObject {
    @Published var records: [VisitRecord] = []
    @Published private(set) var hasLoadedAccount = false
    private var userKey: String?

    var totalEarnings: Double { records.reduce(0) { $0 + $1.earnings } }
    var pendingReminders: [VisitRecord] {
        records.filter { $0.reminderDate != nil && $0.status != .completed }
            .sorted { ($0.reminderDate ?? .distantFuture) < ($1.reminderDate ?? .distantFuture) }
    }

    func switchUser(_ email: String?) {
        hasLoadedAccount = false
        userKey = email
        load()
        ReminderCoordinator.replaceRecords(records)
        hasLoadedAccount = true
    }

    func addOrUpdatePlace(_ place: PlaceResult) {
        if let index = records.firstIndex(where: { $0.place.id == place.id }) {
            records[index].place = place
            records[index].createdAt = Date()
        } else {
            records.insert(VisitRecord(place: place), at: 0)
        }
        save()
    }

    func saveReminder(for place: PlaceResult, visitDate: Date, notificationDate: Date, notes: String) -> VisitRecord {
        var record: VisitRecord
        if let index = records.firstIndex(where: { $0.place.id == place.id }) {
            records[index].place = place
            records[index].status = .pending
            records[index].reminderDate = visitDate
            records[index].notificationDate = notificationDate
            records[index].notes = notes
            record = records[index]
        } else {
            record = VisitRecord(place: place, notes: notes, status: .pending, reminderDate: visitDate, notificationDate: notificationDate)
            records.insert(record, at: 0)
        }
        save()
        return record
    }

    func update(_ record: VisitRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        save()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    private func storageKey() -> String {
        "resenago.records.\(userKey ?? "guest")"
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey()),
              let decoded = try? JSONDecoder().decode([VisitRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey())
        }
        ReminderCoordinator.replaceRecords(records)
    }
}

// MARK: - Location and Google Places

@MainActor
final class PlaceFinder: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var selectedPlace: PlaceResult?
    @Published var isLoading = false
    @Published var status = "Buscando tu ubicación…"
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private var didInitialSearch = false
    private let apiKey = LocalConfig.googlePlacesAPIKey

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            status = "Activa la ubicación en Ajustes para detectar negocios cercanos."
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate
        status = "Ubicación encontrada · ±\(Int(location.horizontalAccuracy)) m"
        if !didInitialSearch {
            didInitialSearch = true
            Task { await searchNearest(to: location.coordinate) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func searchNearest(to coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let results = try await GooglePlacesService(apiKey: apiKey).nearby(coordinate: coordinate)
            guard !results.isEmpty else {
                status = "No se han encontrado negocios cerca de ese punto."
                return
            }
            let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            selectedPlace = results.min { a, b in
                target.distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude)) <
                target.distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            }
            status = "Negocio más cercano seleccionado"
        } catch {
            errorMessage = "No se pudo consultar Google Places: \(error.localizedDescription)"
        }
    }

    func searchByName(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let results = try await GooglePlacesService(apiKey: apiKey).textSearch(query: query, bias: userLocation)
            selectedPlace = results.first
            status = results.isEmpty ? "No se encontró ese negocio." : "Negocio seleccionado"
        } catch {
            errorMessage = "No se pudo buscar: \(error.localizedDescription)"
        }
    }
}

struct GooglePlacesService {
    let apiKey: String

    struct NearbyResponse: Decodable { let places: [APIPlace]? }
    struct APIPlace: Decodable {
        struct DisplayName: Decodable { let text: String }
        struct Location: Decodable { let latitude: Double; let longitude: Double }
        let id: String
        let displayName: DisplayName?
        let formattedAddress: String?
        let location: Location?
    }

    func nearby(coordinate: CLLocationCoordinate2D) async throws -> [PlaceResult] {
        let url = URL(string: "https://places.googleapis.com/v1/places:searchNearby")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location", forHTTPHeaderField: "X-Goog-FieldMask")
        let body: [String: Any] = [
            "maxResultCount": 12,
            "rankPreference": "DISTANCE",
            "locationRestriction": [
                "circle": [
                    "center": ["latitude": coordinate.latitude, "longitude": coordinate.longitude],
                    "radius": 800.0
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request)
    }

    func textSearch(query: String, bias: CLLocationCoordinate2D?) async throws -> [PlaceResult] {
        let url = URL(string: "https://places.googleapis.com/v1/places:searchText")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location", forHTTPHeaderField: "X-Goog-FieldMask")
        var body: [String: Any] = ["textQuery": query, "maxResultCount": 10]
        if let bias {
            body["locationBias"] = [
                "circle": [
                    "center": ["latitude": bias.latitude, "longitude": bias.longitude],
                    "radius": 5000.0
                ]
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await execute(request)
    }

    private func execute(_ request: URLRequest) async throws -> [PlaceResult] {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let text = String(data: data, encoding: .utf8) ?? "Error HTTP \(http.statusCode)"
            throw NSError(domain: "GooglePlaces", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: text])
        }
        let decoded = try JSONDecoder().decode(NearbyResponse.self, from: data)
        return (decoded.places ?? []).compactMap { place in
            guard let loc = place.location else { return nil }
            return PlaceResult(
                id: place.id,
                name: place.displayName?.text ?? "Negocio",
                address: place.formattedAddress ?? "",
                latitude: loc.latitude,
                longitude: loc.longitude
            )
        }
    }
}


// MARK: - NFC handoff (sin entitlement Core NFC)

enum ExternalNFCWriter {
    private static let appStoreURL = URL(string: "https://apps.apple.com/es/app/nfc-helper/id6472720100")!

    /// NFC Helper documenta nfchelper://write?url=... para abrir directamente
    /// la pantalla de escritura con el registro URL ya cargado.
    static func write(reviewURL: String) {
        // Respaldo silencioso: si hiciera falta, el mismo enlace queda en el portapapeles.
        UIPasteboard.general.string = reviewURL

        var components = URLComponents()
        components.scheme = "nfchelper"
        components.host = "write"
        components.queryItems = [
            URLQueryItem(name: "url", value: reviewURL)
        ]

        guard let writerURL = components.url else { return }
        UIApplication.shared.open(writerURL, options: [:]) { success in
            if !success {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
}


// MARK: - Directions

enum MapLauncher {
    static func openAppleMaps(place: PlaceResult) {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "daddr", value: "\(place.latitude),\(place.longitude)"),
            URLQueryItem(name: "q", value: place.name),
            URLQueryItem(name: "dirflg", value: "d")
        ]
        if let url = components.url { UIApplication.shared.open(url) }
    }

    static func openGoogleMaps(place: PlaceResult) {
        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: "\(place.latitude),\(place.longitude)"),
            URLQueryItem(name: "destination_place_id", value: place.id),
            URLQueryItem(name: "travelmode", value: "driving")
        ]
        if let url = components.url { UIApplication.shared.open(url) }
    }

    static func openAppleMaps(latitude: Double, longitude: Double, name: String?) {
        let place = PlaceResult(id: "", name: name ?? "Destino", address: "", latitude: latitude, longitude: longitude)
        openAppleMaps(place: place)
    }

    static func openGoogleMaps(latitude: Double, longitude: Double, name: String?, placeID: String?) {
        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        var items = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "travelmode", value: "driving")
        ]
        if let placeID, !placeID.isEmpty { items.append(URLQueryItem(name: "destination_place_id", value: placeID)) }
        components.queryItems = items
        if let url = components.url { UIApplication.shared.open(url) }
    }
}

// MARK: - Root / Auth

struct NativeMapView: UIViewRepresentable {
    let userCoordinate: CLLocationCoordinate2D?
    let selectedPlace: PlaceResult?
    let onTap: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .includingAll
        map.isRotateEnabled = false
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:)))
        tap.cancelsTouchesInView = false
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        if let userCoordinate, !context.coordinator.didCenter {
            context.coordinator.didCenter = true
            map.setRegion(MKCoordinateRegion(center: userCoordinate, latitudinalMeters: 850, longitudinalMeters: 850), animated: true)
        }
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
        if let place = selectedPlace {
            let annotation = MKPointAnnotation()
            annotation.coordinate = place.coordinate
            annotation.title = place.name
            annotation.subtitle = place.address
            map.addAnnotation(annotation)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NativeMapView
        var didCenter = false
        init(parent: NativeMapView) { self.parent = parent }

        @objc func didTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            parent.onTap(coordinate)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let id = "SelectedPlace"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.markerTintColor = UIColor.systemBlue
            view.glyphImage = UIImage(systemName: "building.2.fill")
            view.canShowCallout = true
            return view
        }
    }
}

struct PlaceMiniMap: UIViewRepresentable {
    let place: PlaceResult

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.pointOfInterestFilter = .includingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = place.coordinate
        annotation.title = place.name
        map.addAnnotation(annotation)
        map.setRegion(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 650, longitudinalMeters: 650), animated: false)
    }
}

struct ContentView: View { var body: some View { RootView() } }
