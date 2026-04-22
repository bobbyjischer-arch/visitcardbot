import SwiftUI
import MapKit

struct MapHistoryView: View {
    @EnvironmentObject var loc: LocationService
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.75, longitude: 37.62),
        span:   MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedPoint: LocationPoint?
    @State private var showRoute = true

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Карта
                Map(coordinateRegion: $region, showsUserLocation: true,
                    annotationItems: loc.locationHistory) { point in
                    MapAnnotation(coordinate: point.coordinate) {
                        PointPin(point: point, isSelected: selectedPoint?.id == point.id)
                            .onTapGesture { selectedPoint = point }
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Нижняя панель
                VStack(spacing: 0) {
                    // Карточка выбранной точки
                    if let p = selectedPoint {
                        selectedCard(p)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Статус бар
                    HStack {
                        Label("\(loc.locationHistory.count) точек", systemImage: "mappin.and.ellipse")
                            .font(.caption).foregroundColor(.cyan)
                        Spacer()
                        Button {
                            centerOnLatest()
                        } label: {
                            Label("Последняя", systemImage: "location.fill")
                                .font(.caption)
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Карта")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { centerOnLatest() }
            .animation(.easeInOut(duration: 0.25), value: selectedPoint?.id)
        }
    }

    // MARK: - Helpers

    func centerOnLatest() {
        guard let last = loc.locationHistory.last else { return }
        withAnimation {
            region.center = last.coordinate
            region.span   = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
    }

    func selectedCard(_ point: LocationPoint) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(point.formattedCoords)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.white)
                Text(point.timeAgoString)
                    .font(.caption).foregroundColor(.gray)
                Text("Источник: \(point.source)")
                    .font(.caption2).foregroundColor(.gray)
            }
            Spacer()
            Link(destination: point.mapsURL) {
                Image(systemName: "map.fill")
                    .foregroundColor(.cyan)
                    .padding(8)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(8)
            }
            Button { selectedPoint = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(Color(white: 0.1))
        .cornerRadius(14, corners: [.topLeft, .topRight])
    }
}

// MARK: - Точка на карте

struct PointPin: View {
    let point: LocationPoint
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? Color.cyan : Color.cyan.opacity(0.6))
            .frame(width: isSelected ? 14 : 8, height: isSelected ? 14 : 8)
            .overlay(Circle().stroke(Color.white, lineWidth: isSelected ? 2 : 1))
            .shadow(color: .cyan, radius: isSelected ? 6 : 2)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - View Extension for corner radius

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
