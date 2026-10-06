import SwiftUI
import MapKit
import UserNotifications

struct RootView: View {
    @EnvironmentObject var auth: AuthStore
    var body: some View {
        Group {
#if DEBUG
            if let screen = UIReview.screen { UIReviewHost(screen: screen) }
            else { appContent }
#else
            appContent
#endif
        }
        .tint(AppTheme.blue)
    }
    @ViewBuilder private var appContent: some View {
        if auth.currentUser == nil { AuthView() }
        else { MainTabView() }
    }
}

struct AuthView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var createMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 18) {
                        LogoMark(size: 76)
                        Text("reviewNfcGo").font(.largeTitle.bold())
                        Text("Cada visita,\nuna nueva oportunidad.")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    Picker("Acceso", selection: $createMode) {
                        Text("Iniciar sesión").tag(false)
                        Text("Crear cuenta").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: createMode) { _, _ in auth.errorMessage = nil }

                    VStack(spacing: 20) {
                        if createMode { NativeField(title: "Nombre", icon: "person", text: $name) }
                        NativeField(title: "Correo electrónico", icon: "envelope", text: $email)
                        NativeSecureField(title: "Contraseña", text: $password)
                    }
                    .reviewCard()

                    if let error = auth.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(.red)
                            .accessibilityIdentifier("auth-error")
                    }

                    ReviewAction(title: createMode ? "Crear mi cuenta" : "Entrar", icon: "arrow.right", prominent: true) {
                        if createMode { _ = auth.createAccount(name: name, email: email, password: password) }
                        else { _ = auth.login(email: email, password: password) }
                    }
                    Label("Tu cuenta y tus datos se guardan en este iPhone.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .reviewScreen()
        }
    }
}

struct NativeField: View {
    let title: String
    let icon: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(.teal).frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                TextField(title, text: $text)
                    .textInputAutocapitalization(icon == "envelope" ? .never : .words)
                    .keyboardType(icon == "envelope" ? .emailAddress : .default)
                    .textContentType(icon == "envelope" ? .username : .name)
                    .autocorrectionDisabled()
                    .accessibilityLabel(title)
            }
        }
    }
}

struct NativeSecureField: View {
    let title: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock").foregroundStyle(.teal).frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                SecureField(title, text: $text).textContentType(.password).accessibilityLabel(title)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var router: AppRouter
    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Inicio", systemImage: "map", value: AppTab.home) { NavigationStack { HomeView() } }
            Tab("Sitios", systemImage: "building.2", value: AppTab.sites) {
                NavigationStack(path: $router.historyPath) {
                    HistoryView().navigationDestination(for: UUID.self) { RecordDetailView(recordID: $0) }
                }
            }
            Tab("Ganancias", systemImage: "chart.bar", value: AppTab.earnings) { NavigationStack { EarningsView() } }
            Tab("Avisos", systemImage: "bell", value: AppTab.reminders) { NavigationStack { RemindersView() } }
            Tab("Perfil", systemImage: "person.crop.circle", value: AppTab.profile) { NavigationStack { ProfileView() } }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

struct HomeView: View {
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var store: AppStore
    @StateObject private var finder = PlaceFinder()
    @State private var searchText = ""
    @State private var showSavedToast = false
    @State private var reminderPlace: PlaceResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hola, \(auth.currentUser?.name.components(separatedBy: " ").first ?? "")")
                            .font(.headline)
                        Text("Tu próxima oportunidad está cerca.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    LogoMark(size: 48)
                }

                NativeMapView(userCoordinate: finder.userLocation, selectedPlace: finder.selectedPlace) { coordinate in
                    Task { await finder.searchNearest(to: coordinate) }
                }
                .frame(height: 320)
                .clipShape(.rect(cornerRadius: 30))
                .overlay(alignment: .bottomTrailing) {
                    if let coordinate = finder.userLocation {
                        Button {
                            Task { await finder.searchNearest(to: coordinate) }
                        } label: { Label("Mi ubicación", systemImage: "location.fill") }
                        .buttonStyle(.glass).controlSize(.large).padding(16)
                    }
                }
                .accessibilityHint("Toca el mapa para buscar un negocio cerca de ese punto")

                HStack(spacing: 10) {
                    if finder.isLoading { ProgressView().controlSize(.small) }
                    else { Image(systemName: "location.circle.fill").foregroundStyle(.teal) }
                    Text(finder.status).font(.footnote).foregroundStyle(.secondary)
                }

                if let place = finder.selectedPlace {
                    placeCard(place)
                    PlaceDirectionsCard(place: place)
                } else if !finder.isLoading && finder.errorMessage == nil {
                    ContentUnavailableView("Encuentra tu siguiente sitio", systemImage: "mappin.and.ellipse",
                        description: Text("Busca un negocio por su nombre o toca un punto del mapa."))
                }
                if let error = finder.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.subheadline).foregroundStyle(.red).reviewCard()
                }
            }
            .padding(20)
        }
        .reviewScreen()
        .navigationTitle("Descubrir")
        .searchable(text: $searchText, prompt: "Buscar negocio")
        .onSubmit(of: .search) { Task { await finder.searchByName(searchText) } }
        .onAppear {
#if DEBUG
            if UIReview.screen != nil {
                finder.selectedPlace = UIReview.place
                finder.userLocation = UIReview.place.coordinate
                finder.status = "Un negocio cerca de ti"
            } else { finder.start() }
#else
            finder.start()
#endif
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                Label("Enlace copiado · Sitio guardado", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(16)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("copied-link")
            }
        }
        .sheet(item: $reminderPlace) { QuickReminderView(place: $0).environmentObject(store) }
    }

    private func placeCard(_ place: PlaceResult) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("NEGOCIO SELECCIONADO", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(.teal)
            Text(place.name).font(.title2.bold())
            Text(place.address).font(.subheadline).foregroundStyle(.secondary)
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    ReviewAction(title: "Copiar enlace de reseña", icon: "doc.on.doc", prominent: true) {
                        UIPasteboard.general.string = place.reviewURL
                        store.addOrUpdatePlace(place)
                        showSavedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { showSavedToast = false }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { secondaryActions(place) }
                        VStack(spacing: 12) { secondaryActions(place) }
                    }
                }
            }
            DisclosureGroup("Detalles del enlace") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(place.id).font(.footnote.monospaced()).textSelection(.enabled)
                    Button("Copiar Place ID", systemImage: "number") { UIPasteboard.general.string = place.id }
                        .buttonStyle(.glass)
                }
                .padding(.top, 12)
            }
            .font(.subheadline)
        }
        .reviewCard()
    }

    @ViewBuilder private func secondaryActions(_ place: PlaceResult) -> some View {
        ReviewAction(title: "Escribir NFC", icon: "wave.3.right") {
            store.addOrUpdatePlace(place)
            ExternalNFCWriter.write(reviewURL: place.reviewURL)
        }
        ReviewAction(title: "Volver luego", icon: "calendar.badge.clock") {
            store.addOrUpdatePlace(place)
            reminderPlace = place
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var filter = 0
    @State private var search = ""
    private var filtered: [VisitRecord] {
        store.records.filter { record in
            (filter == 0 || (filter == 1 && record.status != .completed) || (filter == 2 && record.status == .completed)) &&
            (search.isEmpty || record.place.name.localizedCaseInsensitiveContains(search) || record.place.address.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        List {
            Section {
                Picker("Filtrar sitios", selection: $filter) {
                    Text("Todos").tag(0)
                    Text("En curso").tag(1)
                    Text("Vendidos").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 12, trailing: 0))
            }
            if filtered.isEmpty {
                ContentUnavailableView(search.isEmpty ? "Todo empieza con una visita" : "Sin resultados",
                    systemImage: "building.2.crop.circle",
                    description: Text(search.isEmpty ? "Los negocios que guardes aparecerán aquí." : "Prueba otro nombre o cambia el filtro."))
                    .listRowBackground(Color.clear)
            } else {
                Section("\(filtered.count) sitios") {
                    ForEach(filtered) { record in
                        NavigationLink(value: record.id) { RecordRow(record: record) }
                    }
                    .onDelete { offsets in
                        let ids = Set(offsets.map { filtered[$0].id })
                        store.delete(at: IndexSet(store.records.indices.filter { ids.contains(store.records[$0].id) }))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Mis sitios")
        .searchable(text: $search, prompt: "Buscar en tus sitios")
    }
}

struct QuickReminderView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let place: PlaceResult
    @State private var visitDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
    @State private var notificationDate = Calendar.current.date(byAdding: .hour, value: 23, to: Date()) ?? Date().addingTimeInterval(82800)
    @State private var notes = ""
    @FocusState private var notesFocused: Bool
    private var minimumDate: Date { Date().addingTimeInterval(5) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(place.name, systemImage: "building.2").font(.headline)
                    Text(place.address).font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    DatePicker("Visita", selection: $visitDate, in: minimumDate...)
                        .onChange(of: visitDate) { _, value in
                            if notificationDate > value { notificationDate = value }
                        }
                    DatePicker("Avisarme", selection: $notificationDate, in: minimumDate...max(visitDate, minimumDate))
                } header: {
                    Label("Cuándo vuelves", systemImage: "calendar.badge.clock")
                } footer: {
                    Text("Elige cuándo será la visita y a qué hora quieres recibir el aviso.")
                }
                Section("Para recordar") {
                    TextField("Ej. Preguntar por el encargado", text: $notes, axis: .vertical)
                        .lineLimit(3...6).focused($notesFocused)
                }
                Section {
                    PlaceMiniMap(place: place).frame(height: 180).clipShape(.rect(cornerRadius: 20))
                    Button("Apple Maps", systemImage: "map") { MapLauncher.openAppleMaps(place: place) }
                    Button("Google Maps", systemImage: "location") { MapLauncher.openGoogleMaps(place: place) }
                } header: { Text("Ubicación") }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Planear visita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark") {
                        notesFocused = false
                        guard visitDate > Date(), notificationDate > Date(), notificationDate <= visitDate else { return }
                        _ = store.saveReminder(for: place, visitDate: visitDate, notificationDate: notificationDate, notes: notes)
                        dismiss()
                    }
                    .tint(.teal)
                    .disabled(visitDate <= Date() || notificationDate <= Date() || notificationDate > visitDate)
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("OK") { notesFocused = false } }
            }
        }
    }
}

struct RecordDetailView: View {
    @EnvironmentObject var store: AppStore
    let recordID: UUID
    @State private var copied = false
    private var record: VisitRecord? { store.records.first { $0.id == recordID } }

    var body: some View {
        Group {
            if let record {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            StatusBadge(status: record.status)
                            Text(record.place.name).font(.largeTitle.bold())
                            Label(record.place.address, systemImage: "mappin.and.ellipse")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if !record.notes.isEmpty {
                                Divider()
                                Label(record.notes, systemImage: "note.text").font(.body)
                            }
                            if record.earnings > 0 {
                                Divider()
                                LabeledContent("Ganado") {
                                    Text(record.earnings, format: .currency(code: "EUR"))
                                        .font(.title2.bold()).foregroundStyle(.teal)
                                }
                            }
                        }
                        .reviewCard()

                        if let visit = record.reminderDate, record.status != .completed {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("PRÓXIMA VISITA", systemImage: "calendar.badge.clock")
                                    .font(.caption.bold()).foregroundStyle(.teal)
                                Text(visit, format: .dateTime.day().month(.wide).hour().minute())
                                    .font(.title3.bold())
                                if let notify = record.notificationDate ?? record.reminderDate {
                                    Label("Aviso: \(notify.formatted(date: .abbreviated, time: .shortened))", systemImage: "bell")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    if visit > context.date {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(visit, style: .timer).font(.largeTitle.weight(.semibold)).monospacedDigit()
                                            Text("para tu visita").font(.caption).foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("La hora prevista ya ha llegado").foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .reviewCard()
                        }
                        GlassEffectContainer(spacing: 12) {
                            VStack(spacing: 12) {
                                ReviewAction(title: "Escribir NFC", icon: "wave.3.right", prominent: true) {
                                    ExternalNFCWriter.write(reviewURL: record.place.reviewURL)
                                }
                                ReviewAction(title: copied ? "Enlace copiado" : "Copiar enlace de reseña", icon: copied ? "checkmark" : "doc.on.doc") {
                                    UIPasteboard.general.string = record.place.reviewURL
                                    copied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                                }
                            }
                        }
                        PlaceDirectionsCard(place: record.place)
                    }
                    .padding(20)
                }
                .reviewScreen()
                .navigationTitle("Ficha del sitio")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(destination: RecordEditView(recordID: recordID)) {
                            Label("Editar", systemImage: "pencil")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Sitio no encontrado", systemImage: "building.2")
            }
        }
    }
}

struct EarningsView: View {
    @EnvironmentObject var store: AppStore
    private var paid: [VisitRecord] { store.records.filter { $0.earnings > 0 } }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("TOTAL GANADO", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.bold()).foregroundStyle(.teal)
                    Text(store.totalEarnings, format: .currency(code: "EUR"))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.65).lineLimit(1)
                    Text("El resultado de cada visita.").font(.subheadline).foregroundStyle(.secondary)
                }
                .reviewCard(padding: 24)
                HStack(spacing: 14) {
                    MetricTile(title: "Con ganancias", value: "\(paid.count)", icon: "eurosign.circle")
                    MetricTile(title: "Vendidos", value: "\(store.records.filter { $0.status == .completed }.count)", icon: "checkmark.seal")
                }
                SectionHeading(title: "Tus movimientos", subtitle: "Importes anotados en las fichas de tus sitios.")
                if paid.isEmpty {
                    ContentUnavailableView("Tu primera venta está por llegar", systemImage: "chart.bar",
                        description: Text("Añade el importe ganado al editar un sitio."))
                } else {
                    VStack(spacing: 0) {
                        ForEach(paid) { record in
                            NavigationLink(destination: RecordDetailView(recordID: record.id)) {
                                HStack(spacing: 14) {
                                    Image(systemName: "arrow.down.left").foregroundStyle(.teal)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(record.place.name).font(.headline).foregroundStyle(.primary)
                                        Text(record.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(record.earnings, format: .currency(code: "EUR"))
                                        .font(.headline).foregroundStyle(.teal)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 16)
                            }
                            .buttonStyle(.plain)
                            if record.id != paid.last?.id { Divider() }
                        }
                    }
                    .reviewCard()
                }
            }
            .padding(20)
        }
        .reviewScreen()
        .navigationTitle("Ganancias")
    }
}

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        List {
            Section { NotificationDiagnosticsRow() }
            if store.pendingReminders.isEmpty {
                ContentUnavailableView("Tu agenda está libre", systemImage: "calendar.badge.checkmark",
                    description: Text("Planea tu próxima visita desde un negocio o una ficha guardada."))
                    .listRowBackground(Color.clear)
            } else {
                Section("Próximas visitas · \(store.pendingReminders.count)") {
                    ForEach(store.pendingReminders) { record in
                        NavigationLink(destination: RecordDetailView(recordID: record.id)) {
                            RecordRow(record: record, showVisit: true)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Avisos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Probar notificación", systemImage: "bell.badge") { NotificationManager.scheduleTest() }
                    .accessibilityLabel("Probar notificación en 5 segundos")
            }
        }
        .onAppear {
#if DEBUG
            if UIReview.screen != nil { return }
#endif
            NotificationManager.requestPermission()
        }
    }
}

struct NotificationDiagnosticsRow: View {
    @State private var statusText = "Comprobando notificaciones…"
    @State private var denied = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(statusText, systemImage: denied ? "bell.slash" : "bell.badge")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(denied ? .orange : .teal)
            Button("Enviar aviso de prueba", systemImage: "paperplane") { NotificationManager.scheduleTest() }
                .buttonStyle(.glass).controlSize(.regular)
            Text("Lo recibirás dentro de 5 segundos.").font(.caption).foregroundStyle(.secondary)
            if denied {
                Button("Abrir Ajustes", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.buttonStyle(.glassProminent)
            }
        }
        .padding(.vertical, 10)
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, value in if value == .active { refresh() } }
    }
    private func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    statusText = "Notificaciones activadas"; denied = false
                case .denied:
                    statusText = "Notificaciones desactivadas"; denied = true
                case .notDetermined:
                    statusText = "Activa tus notificaciones"; denied = false
                @unknown default:
                    statusText = "Comprueba tus notificaciones"; denied = false
                }
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var auth: AuthStore
    @EnvironmentObject var store: AppStore
    @State private var confirmLogout = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    LogoMark(size: 80)
                    Text(auth.currentUser?.name ?? "").font(.title.bold())
                    Text(auth.currentUser?.email ?? "").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                HStack(spacing: 14) {
                    MetricTile(title: "Sitios guardados", value: "\(store.records.count)", icon: "building.2")
                    MetricTile(title: "Próximas visitas", value: "\(store.pendingReminders.count)", icon: "calendar")
                }
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("Ganancias") {
                        Text(store.totalEarnings, format: .currency(code: "EUR")).font(.headline).foregroundStyle(.teal)
                    }
                    Divider()
                    Label("Tus datos se quedan contigo", systemImage: "lock.shield").font(.headline)
                    Text("Esta cuenta guarda tus sitios, notas y visitas en este iPhone. No se envían a un servidor.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .reviewCard()
                Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    confirmLogout = true
                }
                .buttonStyle(.glass).controlSize(.large)
                Text("reviewNfcGo · 2.9").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(20)
        }
        .reviewScreen()
        .navigationTitle("Tu perfil")
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { auth.logout() }
        } message: { Text("Tus datos seguirán guardados en este iPhone.") }
    }
}

struct RecordEditView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let recordID: UUID

    @State private var original: VisitRecord?
    @State private var draft: VisitRecord?
    @State private var reminderEnabled = false
    @State private var earningsText = ""
    @State private var showDiscardAlert = false
    @FocusState private var focusedField: EditorField?

    enum EditorField: Hashable { case notes, earnings }
    private var isSold: Bool { draft?.status == .completed }
    private var minimumDate: Date { Date().addingTimeInterval(5) }

    private var hasChanges: Bool {
        guard var draft, let original else { return false }
        draft.earnings = parsedEarnings
        if !reminderEnabled || draft.status == .completed {
            draft.reminderDate = nil
            draft.notificationDate = nil
        }
        return draft != original
    }

    private var parsedEarnings: Double {
        let normalized = earningsText.replacingOccurrences(of: "€", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    var body: some View {
        Form {
            if draft != nil {
                let binding = Binding<VisitRecord>(get: { draft! }, set: { draft = $0 })
                Section("Negocio") {
                    Text(binding.wrappedValue.place.name).font(.headline)
                    Text(binding.wrappedValue.place.address).foregroundStyle(.secondary)
                }
                Section("Seguimiento") {
                    Picker("Estado", selection: binding.status) {
                        Text("Contactado").tag(VisitStatus.contacted)
                        Text("Volver").tag(VisitStatus.pending)
                        Text("Vendido").tag(VisitStatus.completed)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: binding.wrappedValue.status) { status in
                        if status == .completed {
                            reminderEnabled = false
                            draft?.reminderDate = nil
                            draft?.notificationDate = nil
                        }
                    }
                    TextField("Notas", text: binding.notes, axis: .vertical).lineLimit(3...7).focused($focusedField, equals: .notes)
                    HStack {
                        Text("Ganado"); Spacer()
                        TextField("0,00", text: $earningsText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focusedField, equals: .earnings).frame(maxWidth: 110)
                        Text("€").foregroundStyle(.secondary)
                    }
                }
                Section("Recordatorio") {
                    Toggle("Volver otro día", isOn: $reminderEnabled)
                        .disabled(isSold)
                        .onChange(of: reminderEnabled) { enabled in
                            if enabled && draft?.reminderDate == nil {
                                let visit = Date().addingTimeInterval(3600)
                                draft?.reminderDate = visit
                                draft?.notificationDate = Date().addingTimeInterval(1800)
                            }
                            if !enabled {
                                draft?.reminderDate = nil
                                draft?.notificationDate = nil
                            }
                        }
                    if isSold {
                        Text("Este negocio está marcado como vendido; sus avisos quedan cancelados.").font(.footnote).foregroundStyle(.secondary)
                    } else if reminderEnabled {
                        DatePicker("Fecha y hora de la visita", selection: Binding(
                            get: { max(draft?.reminderDate ?? Date().addingTimeInterval(3600), minimumDate) },
                            set: { newValue in
                                draft?.reminderDate = newValue
                                if let n = draft?.notificationDate, n > newValue { draft?.notificationDate = newValue }
                            }
                        ), in: minimumDate...)
                        if let visit = draft?.reminderDate {
                            DatePicker("Avisarme el", selection: Binding(
                                get: { max(min(draft?.notificationDate ?? visit, visit), minimumDate) },
                                set: { draft?.notificationDate = $0 }
                            ), in: minimumDate...max(visit, minimumDate))
                        }
                        Text("No se pueden guardar fechas pasadas. El aviso puede ser anterior a la visita.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Editar sitio")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { focusedField = nil; attemptDismiss() } label: { Label("Atrás", systemImage: "chevron.left") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Guardar") { saveAndDismiss() }.bold().disabled(draft == nil)
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("OK") { focusedField = nil } }
        }
        .onAppear {
            if let value = store.records.first(where: { $0.id == recordID }) {
                original = value; draft = value
                reminderEnabled = value.reminderDate != nil && value.status != .completed
                earningsText = value.earnings == 0 ? "" : Self.earningsFormatter.string(from: NSNumber(value: value.earnings)) ?? "\(value.earnings)"
                if value.notificationDate == nil { draft?.notificationDate = value.reminderDate }
            }
        }
        .alert("¿Descartar cambios?", isPresented: $showDiscardAlert) {
            Button("Seguir editando", role: .cancel) {}
            Button("Descartar", role: .destructive) { dismiss() }
        } message: { Text("Los cambios que no hayas guardado se perderán.") }
    }

    private func attemptDismiss() { if hasChanges { showDiscardAlert = true } else { dismiss() } }

    private func saveAndDismiss() {
        focusedField = nil
        guard var value = draft else { return }
        value.earnings = parsedEarnings
        if value.status == .completed || !reminderEnabled {
            value.reminderDate = nil; value.notificationDate = nil
        } else {
            if value.reminderDate == nil || value.reminderDate! <= Date() { value.reminderDate = Date().addingTimeInterval(3600) }
            if value.notificationDate == nil || value.notificationDate! <= Date() { value.notificationDate = min(Date().addingTimeInterval(60), value.reminderDate!) }
            if value.notificationDate! > value.reminderDate! { value.notificationDate = value.reminderDate }
        }
        store.update(value)
        original = value; draft = value; dismiss()
    }

    private static let earningsFormatter: NumberFormatter = {
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "es_ES"); formatter.numberStyle = .decimal; formatter.minimumFractionDigits = 0; formatter.maximumFractionDigits = 2; return formatter
    }()
}
