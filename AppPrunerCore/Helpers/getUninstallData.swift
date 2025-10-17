//
//  getUninstallData.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation
import CryptoKit

// MARK: - Config

struct Config {
    // Host your files on GitHub Pages (or any static host)
	static let baseURL = URL(string: Constants.repoUrl)!
    static let indexURL = baseURL.appendingPathComponent("index.json")

    // Machine-wide cache (run with sudo); switch to user Library if you prefer per-user.
    static let cacheRoot = URL(fileURLWithPath: "/Library/Application Support/AppPruner", isDirectory: true)
    static let defsDir   = cacheRoot.appendingPathComponent("defs", isDirectory: true)
    static let metaDir   = cacheRoot.appendingPathComponent("meta", isDirectory: true)
    static let indexPath = cacheRoot.appendingPathComponent("index.json")
    static let etagPath  = cacheRoot.appendingPathComponent("index.json.etag")
    static let lockPath  = metaDir.appendingPathComponent("update.lock")

    static let ttlHours: Int = 0
}

// MARK: - Models (index.json)

struct IndexFile: Decodable {
    struct Item: Decodable {
        let id: String               // bundleId
        let name: String
        let version: String          // we’ll derive this from SHA prefix server-side if you don’t set it
        let updated_at: String       // ISO string
        let path: String             // relative path to def file
        let sha256: String           // hex
    }
    let schema_version: Int
    let generated_at: String
    let items: [Item]
}

// MARK: - Files & Hashes

@discardableResult
func ensureDirs() throws -> Void {
    AppLog.debug("Ensuring directories at: defs=\(Config.defsDir.path), meta=\(Config.metaDir.path)")
    try FileManager.default.createDirectory(at: Config.defsDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: Config.metaDir, withIntermediateDirectories: true)
}

func sha256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

func atomicWrite(_ data: Data, to url: URL) throws {
    AppLog.debug("Atomic write to: \(url.path)")
    let tmp = url.deletingLastPathComponent()
        .appendingPathComponent(".\(UUID().uuidString).tmp")
    try data.write(to: tmp, options: .atomic)  // atomic temp write
    // Replace (atomic on APFS)
    if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    } else {
        try FileManager.default.moveItem(at: tmp, to: url)
    }
}

func isOlderThan(_ url: URL, hours: Int) -> Bool {
    AppLog.debug("Checking age for: \(url.lastPathComponent), ttlHours=\(hours)")
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
          let mod = attrs[.modificationDate] as? Date else { return true }
    return Date().timeIntervalSince(mod) > Double(hours) * 3600
}

// MARK: - Locking (simple file lock)

struct UpdateLock {
    let url = Config.lockPath
    func acquire() throws {
        try ensureDirs()
        AppLog.debug("Attempting to acquire update lock at: \(url.path)")
        let ok = FileManager.default.createFile(atPath: url.path, contents: "\(ProcessInfo.processInfo.processIdentifier)".data(using: .utf8))
        if !ok {
            // If exists, consider stale after 10 minutes
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let mod = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(mod) > 600 {
                try? FileManager.default.removeItem(at: url)
                _ = FileManager.default.createFile(atPath: url.path, contents: "\(getpid())".data(using: .utf8))
                AppLog.debug("Update lock acquired")
            } else {
                AppLog.debug("Lock present and not stale; another update is in progress")
                throw NSError(domain: "Lock", code: 1, userInfo: [NSLocalizedDescriptionKey: "Another update is in progress"])
            }
        } else {
            AppLog.debug("Update lock acquired")
        }
    }
    func release() {
        AppLog.debug("Releasing update lock at: \(url.path)")
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Networking

struct HTTP {
    static func getWithETag(_ url: URL, etag: String?) throws -> (Data?, HTTPURLResponse) {
        AppLog.debug("GET with ETag: \(url.absoluteString), If-None-Match=\(etag ?? "<nil>")")
        // set url session to not use cache
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        var req = URLRequest(url: url)
        if let etag { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let semaphore = DispatchSemaphore(value: 0)
        var outData: Data?
        var outResp: URLResponse?
        var outErr: Error?

		let task = session.dataTask(with: req) { data, resp, err in
            outData = data
            outResp = resp
            outErr = err
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = outErr { throw error }
        guard let http = outResp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        AppLog.debug("Response for \(url.lastPathComponent): status=\(http.statusCode), ETag=\(http.value(forHTTPHeaderField: "ETag") ?? "<none>")")
        return (outData, http)
    }

    static func get(_ url: URL) throws -> Data {
        AppLog.debug("GET: \(url.absoluteString)")
        let semaphore = DispatchSemaphore(value: 0)
        var outData: Data?
        var outResp: URLResponse?
        var outErr: Error?

        let task = URLSession.shared.dataTask(with: url) { data, resp, err in
            outData = data
            outResp = resp
            outErr = err
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = outErr { throw error }
        guard let http = outResp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        AppLog.debug("Fetched \(url.lastPathComponent): status=\(http.statusCode), bytes=\(outData?.count ?? 0)")
        return outData ?? Data()
    }
}

// MARK: - Catalog refresh

func refreshIndexIfNeeded(force: Bool = false) {
    do {
        try ensureDirs()
        AppLog.debug("Refreshing index (force=\(force))")
        let need = true // always refresh on run
        AppLog.debug("Index refresh needed: \(need)")
        guard need else { return }

        let lock = UpdateLock()
        try lock.acquire()
        defer { lock.release() }

		let etag = (try? String(contentsOf: Config.etagPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
        AppLog.debug("Current ETag: \(etag ?? "<none>")")
        let (maybeData, http) = try HTTP.getWithETag(Config.indexURL, etag: etag)

		switch http.statusCode {
		case 304:
			// Not modified — no need to rewrite
			return
		case 200:
			guard let data = maybeData else { return }
			let newETag = http.value(forHTTPHeaderField: "ETag")?.trimmingCharacters(in: .whitespacesAndNewlines)
			let oldETag = etag?.trimmingCharacters(in: .whitespacesAndNewlines)
			if newETag == oldETag {
				// Same ETag, content likely identical — skip writing
				return
			}
			// otherwise, replace index.json
			try atomicWrite(data, to: Config.indexPath)
			if let newETag { try atomicWrite(Data(newETag.utf8), to: Config.etagPath) }
		default:
			return
		}
    } catch {
        AppLog.error("Index refresh failed: \(error.localizedDescription)")
        // Stay quiet but useful
        fputs("index refresh failed: \(error)\n", stderr)
    }
}

// MARK: - Sync definitions

func loadIndex() throws -> IndexFile {
    AppLog.debug("Loading index from: \(Config.indexPath.path)")
    let data = try Data(contentsOf: Config.indexPath)
    return try JSONDecoder().decode(IndexFile.self, from: data)
}

func removeOldDefinitions(idx: IndexFile) {
    AppLog.debug("Removing old definitions, keeping ids: \(idx.items.map { $0.id })")
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(at: Config.defsDir, includingPropertiesForKeys: nil) else {
        AppLog.debug("No defs directory found at: \(Config.defsDir.path); nothing to clean")
        return
    }
    let validFiles = Set(idx.items.map { localDefURL(for: $0).lastPathComponent })
    for file in files {
        let name = file.lastPathComponent
        if !validFiles.contains(name) {
            AppLog.info("Removing old definition file: \(name)")
            try? fm.removeItem(at: file)
        }
    }
}

func localDefURL(for item: IndexFile.Item) -> URL {
    // Store by id + version for immutability
    let safeID = item.id.replacingOccurrences(of: "/", with: "_")
    return Config.defsDir.appendingPathComponent("\(safeID)@\(item.version).json")
}

func ensureDefinition(_ item: IndexFile.Item) throws -> URL {
    AppLog.debug("Ensuring definition for id=\(item.id), version=\(item.version)")
    let dst = localDefURL(for: item)

    // If a cached file exists, verify its SHA-256 before trusting it.
    if FileManager.default.fileExists(atPath: dst.path) {
        do {
            let localData = try Data(contentsOf: dst)
            let localSha = sha256Hex(localData)
            let expected = item.sha256.lowercased()
            AppLog.debug("Local cache found at: \(dst.path); sha256(local)=\(localSha), expected=\(expected)")
            if localSha == expected {
                // Local cache is valid
                return dst
            } else {
                // Local cache is invalid/tampered; remove and re-fetch
                AppLog.error("Local definition hash mismatch for id=\(item.id). Will re-fetch. (local=\(localSha), expected=\(expected))")
                try? FileManager.default.removeItem(at: dst)
            }
        } catch {
            // If we cannot read or hash, fall back to re-fetching
            AppLog.error("Failed to read/validate local definition at \(dst.path): \(error.localizedDescription). Will re-fetch.")
            try? FileManager.default.removeItem(at: dst)
        }
    }

    // Fetch from remote and validate
    let remote = Config.baseURL.appendingPathComponent(item.path)
    AppLog.info("Fetching definition from: \(remote.absoluteString)")
    let data = try HTTP.get(remote)
    let got = sha256Hex(data)
    AppLog.debug("Downloaded sha256=\(got), expected=\(item.sha256.lowercased())")
    guard got == item.sha256.lowercased() else {
        throw NSError(domain: "HashMismatch", code: 2, userInfo: [NSLocalizedDescriptionKey: "sha256 mismatch for \(item.id)"])
    }

    try atomicWrite(data, to: dst)
    AppLog.debug("Cached definition to: \(dst.path)")
    return dst
}

// MARK: - Public CLI entry points

/// Call this once near startup (or when user passes --update)
func syncCatalog(force: Bool = false) {
    AppLog.debug("syncCatalog(force=\(force)) started")
    refreshIndexIfNeeded(force: force)
    // Opportunistic prefetch (optional): warm new defs in background
    if let idx = try? loadIndex() {
        AppLog.debug("Prefetching \(idx.items.count) definitions")
        for item in idx.items {
            AppLog.debug("Prefetch: \(item.id)@\(item.version)")
            _ = try? ensureDefinition(item)
        }
        removeOldDefinitions(idx: idx)
    }
}

/// Load the definition for a given bundleId (uses latest by updated_at if multiple present)
func loadDefinition(appName: String, version: String? = nil) throws -> Data {
    AppLog.info("Loading definition for app \(appName)")
    let idx = try loadIndex()
    let candidates = idx.items.filter { $0.name == appName }
    AppLog.debug("Found \(candidates.count) candidate(s) for \(appName)")
    guard !candidates.isEmpty else {
        throw NSError(domain: "Defs", code: 404, userInfo: [NSLocalizedDescriptionKey: "No definition for \(appName)"])
    }
    AppLog.debug("Selecting most recent candidate by updated_at, with version fallback")
    // Pick the most recent: prefer updated_at (ISO 8601), fallback to version when equal
    // If a specific version is requested, prefer that version
    if let version {
        let byVersion = candidates.filter { $0.version == version }
        if !byVersion.isEmpty {
            AppLog.debug("Found \(byVersion.count) candidate(s) matching requested version \(version)")
            // Pick most recent among those with matching version
            let best = byVersion.max { a, b in
                if a.updated_at == b.updated_at {
                    // Fallback: compare version strings lexicographically as a conservative default
                    return a.version < b.version
                }
                return a.updated_at < b.updated_at
            }!
            AppLog.debug("Selected by version: id=\(best.id), version=\(best.version), updated_at=\(best.updated_at)")
            let url = localDefURL(for: best)
            if FileManager.default.fileExists(atPath: url.path) {
                AppLog.info("Reading cached definition at: \(url.path)")
                return try Data(contentsOf: url)
            }
            AppLog.info("Definition not cached; fetching now")
            // If not cached yet, fetch it synchronously (network)
            let fetchedURL = try ensureDefinition(best)
            return try Data(contentsOf: fetchedURL)
        } else {
            AppLog.debug("No candidates match requested version \(version); falling back to most recent overall")
        }
    }
    let best = candidates.max { a, b in
        if a.updated_at == b.updated_at {
            // Fallback: compare version strings lexicographically as a conservative default
            return a.version < b.version
        }
        return a.updated_at < b.updated_at
    }!
    AppLog.debug("Selected: id=\(best.id), version=\(best.version), updated_at=\(best.updated_at)")
    let url = localDefURL(for: best)
    if FileManager.default.fileExists(atPath: url.path) {
        AppLog.info("Reading cached definition at: \(url.path)")
        return try Data(contentsOf: url)
    }
    AppLog.info("Definition not cached; fetching now")
    // If not cached yet, fetch it synchronously (network)
    let fetchedURL = try ensureDefinition(best)
    return try Data(contentsOf: fetchedURL)
}

