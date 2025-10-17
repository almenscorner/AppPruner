//
//  logger.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

public enum AppLog {
	public enum Level: String {
		case info = "INFO"
		case debug = "DEBUG"
		case error = "ERROR"
		case warning = "WARNING"
	}

	private static let logDir: URL = {
		let base = FileManager.default.urls(for: .libraryDirectory, in: .localDomainMask).first!
		let dir = base.appendingPathComponent("Logs/AppPruner", isDirectory: true)
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
		return dir
	}()
	private static let logFile = logDir.appendingPathComponent("AppPruner.log")

	// Rotation settings
	private static let maxFileSize = 5 * 1024 * 1024  // 5 MB
	private static let maxFiles = 5

	// MARK: - Public API
	public static func info(_ message: String)  { write(message, level: .info) }
	public static func debug(_ message: String) { write(message, level: .debug) }
	public static func error(_ message: String) { write(message, level: .error) }
	public static func warning(_ message: String) { write(message, level: .warning) }

	// MARK: - Core
	private static func write(_ message: String, level: Level) {
		let ts = ISO8601DateFormatter().string(from: Date())
		let line = "[\(ts)] [\(level.rawValue)] \(message)\n"

		// print to console
		if level == .debug && !AppPrunerConfig.debugEnabled { return }
		print(line, terminator: "")

		// append to file
		if let data = line.data(using: .utf8) {
			if !FileManager.default.fileExists(atPath: logFile.path) {
				FileManager.default.createFile(atPath: logFile.path, contents: nil)
			}
			if let handle = try? FileHandle(forWritingTo: logFile) {
				defer { try? handle.close() }
				_ = try? handle.seekToEnd()
				try? handle.write(contentsOf: data)
			}
		}

		rotateIfNeeded()
	}

	private static func rotateIfNeeded() {
		guard
			let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
			let size = attrs[.size] as? NSNumber,
			size.intValue > maxFileSize
		else { return }

		// shift old logs: .log.4 -> .log.5, ..., .log -> .log.1
		for i in stride(from: maxFiles - 1, through: 1, by: -1) {
			let src = logDir.appendingPathComponent("AppPruner.log.\(i)")
			let dst = logDir.appendingPathComponent("AppPruner.log.\(i+1)")
			if FileManager.default.fileExists(atPath: src.path) {
				try? FileManager.default.removeItem(at: dst)
				try? FileManager.default.moveItem(at: src, to: dst)
			}
		}
		let first = logDir.appendingPathComponent("AppPruner.log.1")
		try? FileManager.default.removeItem(at: first)
		try? FileManager.default.moveItem(at: logFile, to: first)
		FileManager.default.createFile(atPath: logFile.path, contents: nil)
	}
}
