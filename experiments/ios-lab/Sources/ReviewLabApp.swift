import SwiftUI
import UIKit
import MapKit
import CoreLocation
import UserNotifications
import ActivityKit

struct Probe: Identifiable {
    let id: String
    let detail: String
}

@main
struct DayProbeApp: App {
    var body: some Scene { WindowGroup { ProbeView() } }
}

struct ProbeView: View {
    @AppStorage("dayprobe.results") private var stored = ""
    @State private var index = 0
    @State private var showSummary = false
    @State private var location = CLLocationManager()
    private let probes: [Probe] = [
        .init(id: "Navegación y botones", detail: "Comprueba que puedes avanzar, volver y pulsar controles."),
        .init(id: "Material translúcido", detail: "Comprueba el aspecto del panel y el desenfoque sobre el degradado."),
        .init(id: "Liquid Glass", detail: "En iOS 26 o posterior, comprueba si el botón usa el material Glass nativo."),
        .init(id: "Mapa de Apple", detail: "Comprueba si aparece el mapa y puedes moverlo."),
        .init(id: "Solicitud de ubicación", detail: "Pulsa Solicitar ubicación y verifica que aparece el permiso."),
        .init(id: "Permiso de notificaciones", detail: "Pulsa Solicitar notificaciones y verifica el permiso."),
        .init(id: "Almacenamiento local", detail: "Marca una respuesta, cierra la app y comprueba que se conserva."),
        .init(id: "Apertura de enlaces", detail: "Pulsa Abrir web y comprueba que se abre Safari."),
        .init(id: "Live Activities", detail: "Comprueba si el sistema admite Live Activities; no inicia ninguna actividad."),
        .init(id: "Compatibilidad LiveContainer", detail: "Comprueba si todas las pantallas funcionan dentro de LiveContainer.")
    ]
    private var results: [String: Bool] {
        var output: [String: Bool] = [:]
        for item in stored.split(separator: "|") {
            let parts = item.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { output[String(parts[0])] = parts[1] == "1" }
        }
        return output
    }
    private func mark(_ value: Bool) {
        var updated = results
        updated[String(index)] = value
        stored = updated.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value ? "1" : "0")" }.joined(separator: "|")
        if index < probes.count - 1 { index += 1 } else { showSummary = true }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if showSummary {
                        Text("Resultados").font(.largeTitle.bold())
                        ForEach(Array(probes.enumerated()), id: \.offset) { n, probe in
                            HStack {
                                Image(systemName: results[String(n)] == true ? "checkmark.circle.fill" : results[String(n)] == false ? "xmark.circle.fill" : "questionmark.circle")
                                    .foregroundStyle(results[String(n)] == true ? .green : .red)
                                Text(probe.id)
                                Spacer()
                                Text(results[String(n)] == true ? "Funciona" : results[String(n)] == false ? "No funciona" : "Sin probar").font(.caption)
                            }.padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        Button("Copiar informe") {
                            let report = probes.enumerated().map { n, p in "\(p.id): \(results[String(n)] == true ? "Funciona" : results[String(n)] == false ? "No funciona" : "Sin probar")" }.joined(separator: "\n")
                            UIPasteboard.general.string = "ReviewNFC Go / pruebas iOS nativas (NO Day)\n" + report
                        }.buttonStyle(.borderedProminent)
                        Button("Volver a probar") { index = 0; showSummary = false }.buttonStyle(.bordered)
                    } else {
                        Text("Prueba \(index + 1) de \(probes.count)").font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: Double(index + 1), total: Double(probes.count))
                        Text(probes[index].id).font(.largeTitle.bold())
                        Text(probes[index].detail)
                        ZStack {
                            LinearGradient(colors: [.cyan, .indigo, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            if index == 3 {
                                Map(initialPosition: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 38.879, longitude: -6.97), span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))))
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "sparkles.rectangle.stack").font(.system(size: 54))
                                    Text("ReviewNFC Go · Lab").font(.title3.bold())
                                    if index == 2 {
                                        if #available(iOS 26.0, *) {
                                            Button("Liquid Glass") {}.buttonStyle(.glass)
                                        } else { Text("Requiere iOS 26") }
                                    }
                                }.padding(25).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                            }
                        }.frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 22))
                        if index == 4 { Button("Solicitar ubicación") { location.requestWhenInUseAuthorization() }.buttonStyle(.bordered) }
                        if index == 5 { Button("Solicitar notificaciones") { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in } }.buttonStyle(.bordered) }
                        if index == 7 { Button("Abrir web") { UIApplication.shared.open(URL(string: "https://example.org")!) }.buttonStyle(.bordered) }
                        if index == 8 { Text("Soportado por sistema: \(ActivityAuthorizationInfo().areActivitiesEnabled ? "Sí" : "No")").font(.callout) }
                        HStack {
                            Button("Funciona") { mark(true) }.tint(.green).buttonStyle(.borderedProminent)
                            Button("No funciona") { mark(false) }.tint(.red).buttonStyle(.borderedProminent)
                        }
                        if index > 0 { Button("Anterior") { index -= 1 }.buttonStyle(.bordered) }
                        Button("Ver resultados") { showSummary = true }.font(.footnote)
                    }
                }.padding()
            }.navigationTitle("Laboratorio iOS").navigationBarTitleDisplayMode(.inline)
        }
    }
}
