import SwiftUI

struct PollutantGrid: View {
    let pollutants: Pollutants

    private var items: [(String, Double?)] {
        [("PM2.5", pollutants.pm25), ("PM10", pollutants.pm10), ("O₃", pollutants.ozone),
         ("NO₂", pollutants.no2), ("SO₂", pollutants.so2), ("CO", pollutants.co)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Pollutants", trailing: "μg/m³")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 6) {
                ForEach(items, id: \.0) { name, value in
                    VStack(spacing: 1) {
                        Text(Formatting.concentration(value))
                            .font(.callout.weight(.medium).monospacedDigit())
                        Text(name).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            Spacer()
            if let trailing { Text(trailing).font(.caption2).foregroundStyle(.tertiary) }
        }
    }
}
