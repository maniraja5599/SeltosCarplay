import Foundation
import CoreLocation

/// Monitors vehicle movement and motion state to enforce CarPlay driving safety compliance
public final class CarPlaySafetyMonitor: NSObject, CLLocationManagerDelegate {
    public static let shared = CarPlaySafetyMonitor()

    @Published public private(set) var isVehicleMoving: Bool = false
    @Published public private(set) var isParked: Bool = true

    private var locationManager: CLLocationManager?

    private override init() {
        super.init()
    }

    public func startMonitoring() {
        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        }
        locationManager?.startUpdatingLocation()
    }

    public func stopMonitoring() {
        locationManager?.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        // Speed is in m/s; > 1.5 m/s (~5.4 km/h) indicates vehicle is in motion
        if latest.speed > 1.5 {
            isVehicleMoving = true
            isParked = false
        } else if latest.speed >= 0 && latest.speed <= 0.5 {
            isVehicleMoving = false
            isParked = true
        }
    }
}
