//
//  unloadDaemons.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

enum unloadDaemonError: Error {
	case userIDNotFound
}

func unloadDaemons(def: Definition, dryRun: Bool = false) throws {
	let fm = FileManager.default
	let userIdResult = getConsoleUserProperty(type: .uid)
	let userIdString: String
	switch userIdResult {
	case .uid(let uid):
		userIdString = String(uid)
	case .notFound:
		AppLog.error(#function + ": Could not find console user ID")
		throw unloadDaemonError.userIDNotFound
	default:
		AppLog.error(#function + ": Unhandled case for getConsoleUserProperty(type: .uid)")
		throw unloadDaemonError.userIDNotFound
	}
	let launchDFolders: [String] = ["/Library/LaunchAgents", "/Library/LaunchDaemons"]
	
	for launchDFolder in launchDFolders {
		let launchDList = try fm.contentsOfDirectory(atPath: launchDFolder)
		for launchD in launchDList {
			if launchD.contains(def.uninstall.bundleId) {
				let launchDPath = "\(launchDFolder)/\(launchD)"
				if launchDFolder.contains("LaunchAgents") {
					let args = ["bootout", "gui/\(userIdString)", launchDPath]
					if dryRun {
						AppLog.info("Uninstall dry run, would run: \(args.joined(separator: " "))")
						continue
					}
					AppLog.info("Unloading LaunchAgent: \(launchDPath)")
					_ = try executeCommand(with: args, executablePath: Constants.launchCtlPath)
				} else if launchDFolder.contains("LaunchDaemons") {
					let args = ["bootout", "system", launchDPath]
					if dryRun {
						AppLog.info("Uninstall dry run, would run: \(args.joined(separator: " "))")
						continue
					}
					AppLog.info("Unloading LaunchDaemon: \(launchDPath)")
					_ = try executeCommand(with: args, executablePath: Constants.launchCtlPath)
				}
			}
		}
	}
}
