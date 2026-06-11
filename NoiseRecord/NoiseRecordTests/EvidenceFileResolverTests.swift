import XCTest
@testable import NoiseRecord

final class EvidenceFileResolverTests: XCTestCase {
    func testMakeRelativePathFromDocumentsURL() {
        let docs = EvidenceFileResolver.documentsDirectory
        let fileURL = docs.appendingPathComponent("Recordings/test.m4a")
        let relative = EvidenceFileResolver.makeRelativePath(from: fileURL)
        XCTAssertEqual(relative, "Recordings/test.m4a")
    }

    func testResolveByFileNameWhenStoredPathStale() {
        let docs = EvidenceFileResolver.documentsDirectory
        let folder = docs.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("resolver-test.m4a")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data([0x00]), attributes: nil)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let resolved = EvidenceFileResolver.resolveURL(
            storedPath: "stale/path/resolver-test.m4a",
            fileName: "resolver-test.m4a",
            folder: .recordings
        )
        XCTAssertEqual(resolved.lastPathComponent, "resolver-test.m4a")
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.path))
    }
}
