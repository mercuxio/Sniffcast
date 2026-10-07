import MapKit
import SwiftUI

/// The stations' AQI interpolated into a smooth colour field, as a map overlay.
private final class HeatOverlay: NSObject, MKOverlay {
    let stations: [StationReading]
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    private let region: MKCoordinateRegion

    init(stations: [StationReading], region: MKCoordinateRegion) {
        self.stations = stations
        self.region = region
        coordinate = region.center
        let tl = MKMapPoint(CLLocationCoordinate2D(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                                                   longitude: region.center.longitude - region.span.longitudeDelta / 2))
        let br = MKMapPoint(CLLocationCoordinate2D(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                                                   longitude: region.center.longitude + region.span.longitudeDelta / 2))
        boundingMapRect = MKMapRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
    }

    /// A continuous scale through the band colours, anchored at each band's midpoint, so
    /// 152 and 196 read differently even though both are "unhealthy".
    private static func color(forAQI aqi: Double) -> NSColor {
        let anchors: [(Double, AQIBand)] = [(25, .good), (75, .moderate), (125, .sensitive),
                                            (175, .unhealthy), (250, .veryUnhealthy), (400, .hazardous)]
        func rgb(_ band: AQIBand) -> NSColor { AQIColors.nsColor(band).usingColorSpace(.sRGB) ?? .gray }
        if aqi <= anchors[0].0 { return rgb(anchors[0].1) }
        for i in 1..<anchors.count where aqi <= anchors[i].0 {
            let (a0, b0) = anchors[i - 1], (a1, b1) = anchors[i]
            let t = CGFloat((aqi - a0) / (a1 - a0))
            let c0 = rgb(b0), c1 = rgb(b1)
            return NSColor(srgbRed: c0.redComponent + (c1.redComponent - c0.redComponent) * t,
                           green: c0.greenComponent + (c1.greenComponent - c0.greenComponent) * t,
                           blue: c0.blueComponent + (c1.blueComponent - c0.blueComponent) * t, alpha: 1)
        }
        return rgb(anchors[anchors.count - 1].1)
    }

    /// A low-resolution RGBA grid; drawing it scaled up with interpolation gives the smooth look.
    func image(columns: Int = 96, rows: Int = 96) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: columns * rows * 4)
        let rect = boundingMapRect
        for row in 0..<rows {
            for col in 0..<columns {
                let point = MKMapPoint(x: rect.minX + (Double(col) + 0.5) / Double(columns) * rect.width,
                                       y: rect.minY + (Double(row) + 0.5) / Double(rows) * rect.height)
                let c = point.coordinate
                guard let v = AQIMap.interpolate(latitude: c.latitude, longitude: c.longitude, stations: stations)
                else { continue }
                let color = Self.color(forAQI: v.aqi)
                let alpha = 0.34 * v.confidence
                let i = (row * columns + col) * 4
                // Premultiplied RGBA.
                pixels[i] = UInt8(color.redComponent * alpha * 255)
                pixels[i + 1] = UInt8(color.greenComponent * alpha * 255)
                pixels[i + 2] = UInt8(color.blueComponent * alpha * 255)
                pixels[i + 3] = UInt8(alpha * 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: columns, height: rows, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: columns * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true,
                       intent: .defaultIntent)
    }
}

private final class HeatRenderer: MKOverlayRenderer {
    private let image: CGImage?

    init(overlay: HeatOverlay) {
        image = overlay.image()
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let image else { return }
        let rect = self.rect(for: overlay.boundingMapRect)
        context.interpolationQuality = .high
        // CGImage rows run top-down; the renderer's context is flipped, so flip back.
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }
}

private final class StationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let aqi: Int
    let title: String?
    init(_ s: StationReading) {
        coordinate = CLLocationCoordinate2D(latitude: s.latitude, longitude: s.longitude)
        aqi = s.aqi
        title = s.name
    }
}

/// A small coloured badge carrying a station's AQI number.
private func stationBadge(aqi: Int) -> NSImage {
    let text = "\(aqi)"
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9, weight: .bold),
                                                .foregroundColor: NSColor.white]
    let size = (text as NSString).size(withAttributes: attrs)
    let w = max(size.width + 8, 20), h: CGFloat = 15
    return NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
        let fill = AQIColors.nsColor(AQIScale.band(for: aqi, scale: .us)).usingColorSpace(.sRGB) ?? .gray
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: h / 2, yRadius: h / 2)
        fill.withAlphaComponent(0.95).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 1
        path.stroke()
        (text as NSString).draw(at: NSPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2),
                                withAttributes: attrs)
        return true
    }
}

/// A small map centred on the location with an AQI heat map over a muted base map.
/// SwiftUI's `Map` can't take custom overlays, so this wraps `MKMapView`.
struct AQIMapView: NSViewRepresentable {
    let latitude: Double
    let longitude: Double
    let stations: [StationReading]
    /// The box the stations were fetched for; the heat overlay covers exactly this.
    let coverage: Coordinate
    let halfSpanDegrees: Double
    let onRegionChange: (Coordinate, Double) -> Void

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsZoomControls = true
        map.isZoomEnabled = true
        map.isScrollEnabled = true
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let coordinator = context.coordinator
        coordinator.onRegionChange = onRegionChange
        if coordinator.center?.latitude != latitude || coordinator.center?.longitude != longitude {
            map.removeAnnotations(map.annotations.filter { !($0 is StationAnnotation) })
            let pin = MKPointAnnotation()
            pin.coordinate = center
            map.addAnnotation(pin)
            map.setRegion(MKCoordinateRegion(center: center, latitudinalMeters: 90_000, longitudinalMeters: 90_000),
                          animated: false)
            coordinator.center = center
            coordinator.stations = nil
        }
        let box = [coverage.latitude, coverage.longitude, halfSpanDegrees]
        if coordinator.stations != stations || coordinator.box != box {
            coordinator.box = box
            map.removeOverlays(map.overlays)
            if !stations.isEmpty {
                let lonSpan = halfSpanDegrees * 2 / max(cos(coverage.latitude * .pi / 180), 0.2)
                let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: coverage.latitude, longitude: coverage.longitude),
                                                span: MKCoordinateSpan(latitudeDelta: halfSpanDegrees * 2, longitudeDelta: lonSpan))
                map.addOverlay(HeatOverlay(stations: stations, region: region), level: .aboveRoads)
            }
            map.removeAnnotations(map.annotations.filter { $0 is StationAnnotation })
            // Every station; MapKit hides overlapping badges and reveals them as you zoom in.
            map.addAnnotations(stations.map(StationAnnotation.init))
            coordinator.stations = stations
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var center: CLLocationCoordinate2D?
        var stations: [StationReading]?
        var box: [Double] = []
        var onRegionChange: ((Coordinate, Double) -> Void)?

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let r = mapView.region
            onRegionChange?(Coordinate(latitude: r.center.latitude, longitude: r.center.longitude), r.span.latitudeDelta / 2)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let station = annotation as? StationAnnotation else {
                // The location pin always wins over nearby badges.
                let pin = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
                pin.displayPriority = .required
                pin.markerTintColor = .systemRed
                return pin
            }
            let id = "station"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: station, reuseIdentifier: id)
            view.annotation = station
            view.image = stationBadge(aqi: station.aqi)
            view.canShowCallout = false
            view.displayPriority = .defaultLow
            view.collisionMode = .rectangle
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let heat = overlay as? HeatOverlay else { return MKOverlayRenderer(overlay: overlay) }
            return HeatRenderer(overlay: heat)
        }
    }
}

/// The map plus its caption and the credit WAQI requires.
struct AQIMapSection: View {
    let latitude: Double
    let longitude: Double
    let token: String
    let stationName: String?

    @State private var stations: [StationReading] = []
    @State private var loaded = false
    @State private var coverage = Coordinate(latitude: 0, longitude: 0)
    @State private var halfSpan = 1.0
    @State private var refetch: Task<Void, Never>?
    private static let minHalfSpan = 1.0
    private static let maxHalfSpan = 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "AQI map")
            AQIMapView(latitude: latitude, longitude: longitude, stations: stations,
                       coverage: coverage, halfSpanDegrees: halfSpan, onRegionChange: regionChanged)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Heat map of air quality around this location")
            Text(caption).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }
        .task(id: "\(latitude),\(longitude),\(token)") {
            let here = Coordinate(latitude: latitude, longitude: longitude)
            let fetched = await WAQIClient().stations(around: here, halfSpanDegrees: Self.minHalfSpan, token: token)
            coverage = here
            halfSpan = Self.minHalfSpan
            stations = fetched
            loaded = true
        }
    }

    /// Zooming out or panning past the fetched box loads the stations for what is now visible.
    private func regionChanged(center: Coordinate, half: Double) {
        guard loaded else { return }
        let wanted = min(max(half * 1.3, Self.minHalfSpan), Self.maxHalfSpan)
        let zoomedOut = wanted > halfSpan * 1.05
        let movedLat = abs(center.latitude - coverage.latitude) > halfSpan * 0.5
        let movedLon = abs(center.longitude - coverage.longitude) * max(cos(center.latitude * .pi / 180), 0.2) > halfSpan * 0.5
        guard zoomedOut || movedLat || movedLon else { return }
        refetch?.cancel()
        refetch = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let span = max(wanted, halfSpan)
            let fetched = await WAQIClient().stations(around: center, halfSpanDegrees: span, token: token)
            guard !Task.isCancelled, !fetched.isEmpty else { return }
            coverage = center
            halfSpan = span
            stations = fetched
        }
    }

    private var caption: String {
        if loaded && stations.isEmpty { return "No stations nearby, or the token was not accepted · \(AQIMap.attribution)" }
        let station = stationName.flatMap { $0.isEmpty ? nil : "AQI from \($0) · " } ?? ""
        return station + AQIMap.attribution
    }
}
