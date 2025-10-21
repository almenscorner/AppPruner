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

func runBootout(args: [String], launchDPath: String, dryRun: Bool) {
	let plistDict = NSDictionary(contentsOfFile: launchDPath) as? [String: Any]
	let label = (plistDict?["Label"] as? String) ?? (launchDPath as NSString).deletingPathExtension
	
	// First attempt: path form (what you have)
	do {
		// Build arguments by appending the plist path to the provided args without mutating the original array
		let pathArgs = args + [launchDPath]
		if dryRun {
			AppLog.info("Uninstall dry run, would have run: \(pathArgs.joined(separator: " "))")
			return
		}
		AppLog.info("Booting out \(launchDPath)")
		_ = try executeCommand(with: pathArgs, executablePath: Constants.launchCtlPath)
	} catch {
		let errString = String(describing: error).lowercased()
		// If error 5 or bad request, try by label
		if errString.contains("input/output error") || errString.contains("bad request") {
			AppLog.debug("Retrying bootout by label for \(launchDPath) -> \(label)")
			let domain = args.count > 1 ? args[1] : "system"
			let labelArgs = ["bootout", "\(domain)/\(label)"]
			do {
				_ = try executeCommand(with: labelArgs, executablePath: Constants.launchCtlPath)
			} catch {
				AppLog.error("Failed to bootout \(label) (\(launchDPath)) by label: \(error)")
			}
		} else {
			AppLog.error("Failed to bootout \(launchDPath): \(error)")
		}
	}
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
	let alternativeNames = def.uninstall.alternativeNames ?? []
	for launchDFolder in launchDFolders {
		let launchDList = try fm.contentsOfDirectory(atPath: launchDFolder)
		for launchD in launchDList {
			if launchD.contains(def.uninstall.bundleId) || alternativeNames.contains(where: {launchD.contains($0)}) {
				let launchDPath = "\(launchDFolder)/\(launchD)"
				
				if launchDFolder.contains("LaunchAgents") {
					let args = ["bootout", "gui/\(userIdString)"]
					runBootout(args: args, launchDPath: launchDPath, dryRun: dryRun)
				} else if launchDFolder.contains("LaunchDaemons") {
					let args = ["bootout", "system"]
					runBootout(args: args, launchDPath: launchDPath, dryRun: dryRun)
				}
			}
		}
	}
}

