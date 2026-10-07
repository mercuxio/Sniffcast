import MapKit
import SwiftUI

/// A small map centred on the location with WAQI's AQI tiles drawn over a muted base map.
/// SwiftUI's `Map` can't take tile overlays, so this wraps `MKMapView`.
struct AQIMapView: NSViewRepresentable {
    let latitude: Double
    let longitude: Double
    let tileTemplate: String

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsZoomControls = false
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat,
                                                                emphasisStyle: .muted)
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        if context.coordinator.template != tileTemplate {
            map.removeOverlays(map.overlays)
            let overlay = MKTileOverlay(urlTemplate: tileTemplate)
            overlay.canReplaceMapContent = false
            map.addOverlay(overlay, level: .aboveRoads)
            context.coordinator.template = tileTemplate
        }
        if context.coordinator.center?.latitude != latitude || context.coordinator.center?.longitude != longitude {
            map.removeAnnotations(map.annotations)
            let pin = MKPointAnnotation()
            pin.coordinate = center
            map.addAnnotation(pin)
            map.setRegion(MKCoordinateRegion(center: center, latitudinalMeters: 120_000, longitudinalMeters: 120_000),
                          animated: false)
            context.coordinator.center = center
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var template: String?
        var center: CLLocationCoordinate2D?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tiles = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKTileOverlayRenderer(tileOverlay: tiles)
            renderer.alpha = 0.7
            return renderer
        }
    }
}

/// The map plus its required credit line.
struct AQIMapSection: View {
    let latitude: Double
    let longitude: Double
    let tileTemplate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "AQI map")
            AQIMapView(latitude: latitude, longitude: longitude, tileTemplate: tileTemplate)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Map of air quality around this location")
            Text(AQIMap.attribution).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
