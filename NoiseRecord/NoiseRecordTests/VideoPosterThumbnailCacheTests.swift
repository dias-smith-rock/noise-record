import XCTest
@testable import NoiseRecord

final class VideoPosterThumbnailCacheTests: XCTestCase {
    func testMissingFileReturnsNil() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-poster-\(UUID().uuidString).mp4")
        let image = await VideoPosterThumbnailCache.image(for: url)
        XCTAssertNil(image)
    }

    func testCacheKeyIsStableForSameFileMetadata() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("poster-key-\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data("poster".utf8))
        defer {
            try? FileManager.default.removeItem(at: url)
            VideoPosterThumbnailCache.invalidate(for: url)
        }

        let first = VideoPosterThumbnailCache.cacheKey(for: url)
        let second = VideoPosterThumbnailCache.cacheKey(for: url)
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
    }

    func testInvalidateRemovesDiskFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("poster-invalidate-\(UUID().uuidString).mp4")
        FileManager.default.createFile(atPath: url.path, contents: Data("poster".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let diskURL = VideoPosterThumbnailCache.diskURL(for: url)
        try? Data("jpeg".utf8).write(to: diskURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: diskURL.path))

        VideoPosterThumbnailCache.invalidate(for: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: diskURL.path))
    }
}
