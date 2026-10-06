import SwiftUI
import MapKit

// Liquid Glass comes from SwiftUI on iOS 26+. Content surfaces remain solid
// so glass is reserved for navigation and interactive controls.
enum AppTheme {
    static let blue = Color.teal
    static let softBlue = Color.teal.opacity(0.12)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

extension View {
    func reviewCard(padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card, in: .rect(cornerRadius: 28))
    }

    func reviewScreen() -> some View {
        self.background(AppTheme.background)
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title3.bold())
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReviewAction: View {
    let title: String
    let icon: String
    var prominent = false
    let action: () -> Void
    var body: some View {
        Group {
            if prominent {
                button.buttonStyle(.glassProminent)
            } else {
                button.buttonStyle(.glass)
            }
        }
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }
    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 24)
                .padding(.vertical, 3)
        }
    }
}

struct StatusBadge: View {
    let status: VisitStatus
    private var color: Color {
        switch status {
        case .contacted: return .teal
        case .pending: return .orange
        case .completed: return .green
        }
    }
    private var icon: String {
        switch status {
        case .contacted: return "bubble.left"
        case .pending: return "calendar.badge.clock"
        case .completed: return "checkmark.circle.fill"
        }
    }
    var body: some View {
        Label(status.displayName, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(color.opacity(0.10), in: .capsule)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(.teal)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reviewCard(padding: 18)
        .accessibilityElement(children: .combine)
    }
}

struct RecordRow: View {
    let record: VisitRecord
    var showVisit = false
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: showVisit ? "calendar" : "building.2.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.teal)
                .frame(width: 44, height: 44)
                .background(AppTheme.softBlue, in: .rect(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 8) {
                Text(record.place.name).font(.headline).foregroundStyle(.primary)
                Text(record.place.address).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if showVisit, let date = record.reminderDate {
                    Text(date, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.teal)
                } else {
                    StatusBadge(status: record.status)
                }
                if showVisit, let date = record.notificationDate ?? record.reminderDate {
                    Label("Aviso: \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "bell")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if showVisit && !record.notes.isEmpty {
                    Text(record.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if record.earnings > 0 {
                    Text(record.earnings, format: .currency(code: "EUR"))
                        .font(.subheadline.bold()).foregroundStyle(.primary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct PlaceDirectionsCard: View {
    let place: PlaceResult
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: "Cómo llegar", subtitle: place.address)
            Button { MapLauncher.openAppleMaps(place: place) } label: {
                PlaceMiniMap(place: place)
                    .allowsHitTesting(false)
                    .frame(height: 190)
                    .clipShape(.rect(cornerRadius: 20))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.right")
                            .padding(12)
                            .glassEffect(.regular, in: .circle)
                            .padding(12)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cómo llegar a \(place.name) con Apple Maps")
            GlassEffectContainer(spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { mapButtons }
                    VStack(spacing: 12) { mapButtons }
                }
            }
        }
        .reviewCard()
    }
    @ViewBuilder private var mapButtons: some View {
        ReviewAction(title: "Apple Maps", icon: "map") { MapLauncher.openAppleMaps(place: place) }
        ReviewAction(title: "Google Maps", icon: "location") { MapLauncher.openGoogleMaps(place: place) }
    }
}

struct LogoMark: View {
    let size: CGFloat
    var body: some View {
        Image(systemName: "star.bubble.fill")
            .font(.system(size: size * 0.53, weight: .medium))
            .foregroundStyle(.teal)
            .frame(width: size, height: size)
            .glassEffect(.regular.tint(.teal.opacity(0.12)), in: .rect(cornerRadius: size * 0.31))
            .accessibilityHidden(true)
    }
}
