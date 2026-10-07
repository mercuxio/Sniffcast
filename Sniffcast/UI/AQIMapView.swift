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
                let alpha = 0.55 * v.confidence
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

/// A small map centred on the location with an AQI heat map over a muted base map.
/// SwiftUI's `Map` can't take custom overlays, so this wraps `MKMapView`.
struct AQIMapView: NSViewRepresentable {
    let latitude: Double
    let longitude: Double
    let stations: [StationReading]
    let halfSpanDegrees: Double

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsZoomControls = false
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let coordinator = context.coordinator
        if coordinator.center?.latitude != latitude || coordinator.center?.longitude != longitude {
            map.removeAnnotations(map.annotations)
            let pin = MKPointAnnotation()
            pin.coordinate = center
            map.addAnnotation(pin)
            map.setRegion(MKCoordinateRegion(center: center, latitudinalMeters: 90_000, longitudinalMeters: 90_000),
                          animated: false)
            coordinator.center = center
            coordinator.stations = nil
        }
        if coordinator.stations != stations {
            map.removeOverlays(map.overlays)
            if !stations.isEmpty {
                let lonSpan = halfSpanDegrees * 2 / max(cos(latitude * .pi / 180), 0.2)
                let region = MKCoordinateRegion(center: center,
                                                span: MKCoordinateSpan(latitudeDelta: halfSpanDegrees * 2, longitudeDelta: lonSpan))
                map.addOverlay(HeatOverlay(stations: stations, region: region), level: .aboveRoads)
            }
            coordinator.stations = stations
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var center: CLLocationCoordinate2D?
        var stations: [StationReading]?

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
    private static let halfSpan = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "AQI map")
            AQIMapView(latitude: latitude, longitude: longitude, stations: stations, halfSpanDegrees: Self.halfSpan)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Heat map of air quality around this location")
            Text(caption).font(.caption2).foregroundStyle(.tertiary)
        }
        .task(id: "\(latitude),\(longitude),\(token)") {
            stations = await WAQIClient().stations(around: Coordinate(latitude: latitude, longitude: longitude),
                                                   halfSpanDegrees: Self.halfSpan, token: token)
            loaded = true
        }
    }

    private var caption: String {
        if loaded && stations.isEmpty { return "No stations nearby, or the token was not accepted · \(AQIMap.attribution)" }
        let station = stationName.flatMap { $0.isEmpty ? nil : "AQI from \($0) · " } ?? ""
        return station + AQIMap.attribution
    }
}
