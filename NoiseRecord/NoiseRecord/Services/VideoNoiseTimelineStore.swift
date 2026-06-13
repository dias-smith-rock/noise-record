import Foundation

enum VideoNoiseTimelineStore {
    static let fileExtension = "noise.json"

    static func sidecarURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension(fileExtension)
    }

    static func save(_ timeline: VideoNoiseTimeline, for videoURL: URL) throws {
        let url = sidecarURL(for: videoURL)
        let data = try JSONEncoder().encode(timeline)
        try data.write(to: url, options: .atomic)
    }

    static func load(for videoURL: URL) -> VideoNoiseTimeline? {
        let url = sidecarURL(for: videoURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(VideoNoiseTimeline.self, from: data)
    }

    static func remove(for videoURL: URL) {
        let url = sidecarURL(for: videoURL)
        try? FileManager.default.removeItem(at: url)
    }

    static func moveSidecar(from oldVideoURL: URL, to newVideoURL: URL) throws {
        let source = sidecarURL(for: oldVideoURL)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let destination = sidecarURL(for: newVideoURL)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }
}
