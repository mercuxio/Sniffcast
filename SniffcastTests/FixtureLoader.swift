import Foundation


enum Fixture {
    /// Loads a JSON fixture from `SniffcastTests/Fixtures`, located relative to this source file
    /// so fixtures need not be copied into the test bundle.
    static func data(_ name: String) throws -> Data {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
        return try Data(contentsOf: dir.appendingPathComponent(name).appendingPathExtension("json"))
    }
}
