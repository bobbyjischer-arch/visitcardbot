import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var currentLocation: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var serverOnline = false
    @Published var locationHistory: [LocationPoint] = []
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let manager   = CLLocationManager()
    private let network   = NetworkService()
    private let notif     = NotificationService.shared
    private let settings  = AppSettings.shared

    // MARK: - Private
    private var sendTimer:   Timer?
    private var healthTimer: Timer?
    private var wasServerOnline = false

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate                      = self
        manager.desiredAccuracy               = kCLLocationAccuracyBest
        manager.distanceFilter                = 30
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        authStatus = manager.authorizationStatus
        loadHistory()
    }

    // MARK: - Control

    func startTracking() {
        guard authStatus == .authorizedAlways || authStatus == .authorizedWhenInUse else {
            manager.requestAlwaysAuthorization()
            return
        }
        manager.startUpdatingLocation()
        isTracking = true
        settings.systemStatus = "tracking"
        scheduleSend()
        scheduleHealthCheck()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        sendTimer?.invalidate();   sendTimer   = nil
        healthTimer?.invalidate(); healthTimer = nil
        isTracking = false
        settings.systemStatus = "online"
    }

    func requestPermission() { manager.requestAlwaysAuthorization() }

    // MARK: - Manual send

    func sendNow() {
        guard let loc = currentLocation else { return }
        let point = LocationPoint(coordinate: loc.coordinate, source: "ios_manual")
        Task { await sendPoint(point) }
    }

    // MARK: - Timers

    private func scheduleSend() {
        sendTimer?.invalidate()
        let interval = TimeInterval(settings.intervalMinutes * 60)
        sendTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendCurrentLocation()
        }
        sendCurrentLocation()
    }

    private func scheduleHealthCheck() {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { await self?.checkServerHealth() }
        }
        Task { await checkServerHealth() }
    }

    private func sendCurrentLocation() {
        guard let loc = currentLocation else { return }
        let point = LocationPoint(coordinate: loc.coordinate)
        Task { await sendPoint(point) }
    }

    private func sendPoint(_ point: LocationPoint) async {
        let ok = await network.sendLocation(point, to: settings.serverURL)
        if ok {
            locationHistory.append(point)
            if locationHistory.count > 200 { locationHistory.removeFirst() }
            saveHistory()
            settings.lastLatitude     = point.latitude
            settings.lastLongitude    = point.longitude
            settings.lastLocationDate = point.timestamp
            settings.totalPointsSent += 1
            errorMessage = nil
        } else {
            errorMessage = "Не удалось отправить точку"
        }
    }

    private func checkServerHealth() async {
        let alive = await network.checkHealth(settings.serverURL)
        serverOnline = alive
        settings.serverReachable = alive

        if wasServerOnline && !alive {
            notif.notifyServerDown()
        } else if !wasServerOnline && alive {
            notif.notifyServerRestored()
        }
        wasServerOnline = alive
    }

    // MARK: - History persistence

    private var historyURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppSettings.appGroup)?
            .appendingPathComponent("location_history.json")
    }

    private func saveHistory() {
        guard let url = historyURL,
              let data = try? JSONEncoder().encode(Array(locationHistory.suffix(200))) else { return }
        try? data.write(to: url)
    }

    private func loadHistory() {
        guard let url = historyURL,
              let data = try? Data(contentsOf: url),
              let points = try? JSONDecoder().decode([LocationPoint].self, from: data) else { return }
        locationHistory = points
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.currentLocation = locations.last }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways { self.startTracking() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.errorMessage = "GPS: \(error.localizedDescription)" }
    }
}
