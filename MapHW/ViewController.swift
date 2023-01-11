import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {
    
    private lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.preferredConfiguration = MKHybridMapConfiguration()
        mapView.isRotateEnabled = false
        mapView.userTrackingMode = .followWithHeading
        mapView.showsCompass = true
        mapView.delegate = self
        
        return mapView
    }()
    
    private let locationManager = CLLocationManager()
    
    private lazy var longPress: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        gesture.numberOfTapsRequired = 0
        gesture.minimumPressDuration = 0.3
        
        return gesture
    }()
    
    private lazy var deleteButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .regular, scale: .medium)), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(deleteAllPins), for: .touchUpInside)
        
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        config()
    }
    
    private func config() {
        permissionStatus()
        setupSubviews()
        infoAlert()
    }
    
    private func setupSubviews() {
        mapView.addGestureRecognizer(longPress)
        view.addSubview(mapView)
        view.addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            deleteButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            deleteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 60),
            deleteButton.heightAnchor.constraint(equalTo: deleteButton.widthAnchor),
        ])
    }
    
    private func infoAlert() {
        let message: String = "Set a pin - long gesture\nRoute - select pin\n"
        let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
        let confirm = UIAlertAction(title: "Ok", style: .default)
        
        alertController.addAction(confirm)
        present(alertController, animated: true)
    }
    
    private func permissionStatus() {
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.desiredAccuracy = 50
            locationManager.startUpdatingLocation()
            mapView.showsUserLocation = true
            updateCurrentArea()
            
        case .restricted:
            debugPrint("Navigation isn't allowed.")
            
        case .denied:
            locationManager.stopUpdatingLocation()
            mapView.showsUserLocation = false
            debugPrint("Allow location tracking in settings.")
            
        @unknown default:
            preconditionFailure("Unknown error")
        }
    }
    
    private func updateCurrentArea() {
        guard let coordinates = locationManager.location?.coordinate else { return }
        let region = MKCoordinateRegion(center: coordinates, latitudinalMeters: 1000, longitudinalMeters: 1000)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.mapView.setRegion(region, animated: true)
        }
    }
    
    private func addPin(_ coordinates: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinates
        mapView.addAnnotation(annotation)
        debugPrint(mapView.annotations.count)
    }
    
    private func showRoute(_ endPoint: CLLocationCoordinate2D) {
        let directionRequest = MKDirections.Request()
        directionRequest.transportType = .automobile
        
        guard let startPoint = locationManager.location?.coordinate else { return }
        let start = MKMapItem(placemark: MKPlacemark(coordinate: startPoint))
        directionRequest.source = start
        
        let end = MKMapItem(placemark: MKPlacemark(coordinate: endPoint))
        directionRequest.destination = end
        
        let direction = MKDirections(request: directionRequest)
        DispatchQueue.global().async {
            direction.calculate { response, error in
                if error == nil {
                    guard let route = response?.routes.first else { return }
                    let routeRegion = MKCoordinateRegion(route.polyline.boundingMapRect.insetBy(dx: 300, dy: 300))
                    DispatchQueue.main.async { [weak self] in
                        self?.mapView.addOverlay(route.polyline, level: .aboveRoads)
                        self?.mapView.setRegion(routeRegion, animated: true)
                    }
                } else {
                    debugPrint(error)
                }
            }
        }
    }
    
    @objc private func longPressAction(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            debugPrint("👇🏼👇🏼👇🏼")
            let touchLocation = sender.location(in: mapView)
            let touchCoordinates = mapView.convert(touchLocation, toCoordinateFrom: mapView)
            addPin(touchCoordinates)
        }
    }
    
    @objc private func deleteAllPins() {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
    }
}

// MARK: - MKMapViewDelegate
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        updateCurrentArea()
    }
    
    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        mapView.removeOverlays(mapView.overlays)
        showRoute(annotation.coordinate)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.lineWidth = 5
        renderer.strokeColor = .systemCyan
        
        return renderer
    }
}

// MARK: - CLLocationManagerDelegate
extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        permissionStatus()
    }
}
