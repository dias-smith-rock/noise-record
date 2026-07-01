import Foundation

enum EvidenceMediaFolder: String {
    case recordings = "Recordings"
    case videoEvidence = "VideoEvidence"
}

enum EvidenceFileResolver {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Persists a path relative to Documents so it survives app reinstall / container changes.
    static func makeRelativePath(from url: URL) -> String {
        let docs = documentsDirectory.standardizedFileURL.path
        let full = url.standardizedFileURL.path

        if full.hasPrefix(docs + "/") {
            return String(full.dropFirst(docs.count + 1))
        }

        for folder in [EvidenceMediaFolder.recordings.rawValue, EvidenceMediaFolder.videoEvidence.rawValue] {
            if full.contains("/\(folder)/") {
                return "\(folder)/\(url.lastPathComponent)"
            }
        }

        return url.lastPathComponent
    }

    /// Resolves a stored path against the current sandbox Documents directory.
    static func resolveURL(
        storedPath: String,
        fileName: String,
        folder: EvidenceMediaFolder
    ) -> URL {
        let fileManager = FileManager.default
        let docs = documentsDirectory

        if storedPath.hasPrefix("/") {
            let legacy = URL(fileURLWithPath: storedPath)
            if fileManager.fileExists(atPath: legacy.path) {
                return legacy
            }
        }

        let relative = docs.appendingPathComponent(storedPath)
        if fileManager.fileExists(atPath: relative.path) {
            return relative
        }

        let byFileName = docs
            .appendingPathComponent(folder.rawValue, isDirectory: true)
            .appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: byFileName.path) {
            return byFileName
        }

        if !storedPath.contains("/") {
            let nested = docs
                .appendingPathComponent(folder.rawValue, isDirectory: true)
                .appendingPathComponent(storedPath)
            if fileManager.fileExists(atPath: nested.path) {
                return nested
            }
        }

        return byFileName
    }

    /// Fast URL resolution for list rendering — avoids repeated filesystem checks.
    static func preferredURL(
        storedPath: String,
        fileName: String,
        folder: EvidenceMediaFolder
    ) -> URL {
        let docs = documentsDirectory
        if storedPath.hasPrefix("/") {
            return URL(fileURLWithPath: storedPath)
        }
        if storedPath.contains("/") {
            return docs.appendingPathComponent(storedPath)
        }
        return docs
            .appendingPathComponent(folder.rawValue, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func fileExists(
        storedPath: String,
        fileName: String,
        folder: EvidenceMediaFolder
    ) -> Bool {
        FileManager.default.fileExists(
            atPath: resolveURL(storedPath: storedPath, fileName: fileName, folder: folder).path
        )
    }

    /// Rewrites legacy absolute paths to relative paths when the file can be located.
    static func repairedRelativePath(
        storedPath: String,
        fileName: String,
        folder: EvidenceMediaFolder
    ) -> String? {
        let resolved = resolveURL(storedPath: storedPath, fileName: fileName, folder: folder)
        guard FileManager.default.fileExists(atPath: resolved.path) else { return nil }
        let relative = makeRelativePath(from: resolved)
        return relative == storedPath ? nil : relative
    }
}
