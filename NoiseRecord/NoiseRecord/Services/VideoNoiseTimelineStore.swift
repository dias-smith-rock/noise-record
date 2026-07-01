import Foundation

enum VideoNoiseTimelineStore {
    static let fileExtension = "noise.json"

    static func sidecarURL(for mediaURL: URL) -> URL {
        mediaURL.deletingPathExtension().appendingPathExtension(fileExtension)
    }

    static func load(for mediaURL: URL, alternateURLs: [URL] = []) -> VideoNoiseTimeline? {
        for url in [mediaURL] + alternateURLs {
            let sidecar = sidecarURL(for: url)
            guard let data = try? Data(contentsOf: sidecar),
                  let timeline = try? JSONDecoder().decode(VideoNoiseTimeline.self, from: data) else {
                continue
            }
            return timeline
        }
        return nil
    }

    static func save(_ timeline: VideoNoiseTimeline, for videoURL: URL) throws {
        let url = sidecarURL(for: videoURL)
        let data = try JSONEncoder().encode(timeline)
        try data.write(to: url, options: .atomic)
    }

    static func remove(for videoURL: URL) {
        let url = sidecarURL(for: videoURL)
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAll(for mediaURL: URL, alternateURLs: [URL] = []) {
        for url in [mediaURL] + alternateURLs {
            remove(for: url)
        }
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
