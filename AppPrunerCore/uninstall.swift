//
//  uninstall.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

func uninstallApp(def: String?,
				  matchMode: String?,
				  dryRun: Bool = false,
				  removeUserHive: Bool = false,
				  silent: Bool = false,
				  version: String? = nil,
				  waitTime: Int? = 5,
				  definitionPath: String? = nil,
				  brewTidy: Bool = false,
				  preFlightCommand: String? = nil,
				  postFlightCommand: String? = nil) throws {
	let fm = FileManager.default
	
	syncCatalog(force: true)
	
	var defData = Data()
	if definitionPath != nil && fm.fileExists(atPath: definitionPath!) {
		let definitionURL = URL(fileURLWithPath: definitionPath!)
		defData = try Data(contentsOf: definitionURL)
	} else {
		defData = try loadDefinition(appName: def!, version: version)
	}

	// Decode definition
	let appData = try JSONDecoder().decode(Definition.self, from: defData)
	
	let mode: MatchMode
	if let matchMode = matchMode {
		mode = setMatchMode(matchMode: matchMode)
	} else if appData.uninstall.matchMode != nil {
		mode = setMatchMode(matchMode: appData.uninstall.matchMode!)
	} else {
		mode = .all
	}
	
	AppLog.info("Found definition for app: \(appData.name), version: \(appData.version)")

	// Get application files
	let appFiles = try searchFoldersForApp(appData, matchMode: mode, removeUserHive: removeUserHive)

	if appFiles.isEmpty {
		AppLog.info("No files found for app: \(appData.uninstall.appName). Nothing to uninstall.")
		return
	}

	// Send notification that uninstall will start in 5 minutes
	if !silent {
		// Get time 5 minutes from now and format as HH:mm
		let waitMinutesFromNow = Date().addingTimeInterval(Double(waitTime ?? 5) * 60)
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "HH:mm"
		let formattedTime = dateFormatter.string(from: waitMinutesFromNow)
		NotificationService().sendNow(
			title: "Uninstall starting",
			body: "Application \(appData.uninstall.appName) will be uninstalled in 5 minutes (at \(formattedTime)). Please save your work and close the app if it is running. The app will be force-quit if needed.",
			subtitle: "",
			imagePath: "",
			playSound: true,
			interruptionLevel: "active"
		)
		// Wait 5 minutes to allow user to see notification
		sleep(5 * 60)
	}

	if !silent {
		NotificationService().sendNow(
			title: "Uninstall starting",
			body: "Application \(appData.uninstall.appName) is now being uninstalled.",
			subtitle: "",
			imagePath: "",
			playSound: true,
			interruptionLevel: "active"
		)
	}

	// run pre-flight scripts
	if preFlightCommand != nil {
		AppLog.info("Running pre-flight command: \(preFlightCommand!)")
		_ = try executeCommand(with: ["-c", preFlightCommand!], executablePath: "/bin/zsh")
	}

	// Unload daemons and agents
	if appData.uninstall.unloadLaunchDaemons {
		try unloadDaemons(def: appData, dryRun: dryRun)
	}
	
	guard !appFiles.isEmpty else {
		AppLog.info("No files to remove for app: \(appData.uninstall.appName)")
		return
	}

	// Try to kill the application process
	let runningProcessesData = try executeCommand(with: ["-c", "pgrep -f \"\(appData.uninstall.appName)\" || true"], executablePath: "/bin/zsh")
	if runningProcessesData.isEmpty {
		AppLog.info("Process not running (skipped): \(appData.uninstall.appName)")
	} else {
		// Kill the process
		let args = ["-c", "pkill -f \"\(appData.uninstall.appName)\""]
		if dryRun {
			AppLog.info("Uninstall dry run, would run: \(args.joined(separator: " "))")
		} else {
			_ = try executeCommand(with: args, executablePath: "/bin/zsh")
			AppLog.info("Attempted to kill process: \(appData.uninstall.appName)")
		}
	}

	// Remove files and directories
	let spaceSavings = calculateSpaceSavings(for: appFiles)
	AppLog.info("Found \(appFiles.count) items to remove for app \(appData.uninstall.appName) totaling \(formatBytes(spaceSavings))")
	for filePath in appFiles.sorted() {
		var isDir: ObjCBool = false
		let exists = fm.fileExists(atPath: filePath, isDirectory: &isDir)

		// Check if the path is a symbolic link, even if the target is missing (dangling symlink)
		let isSymlink: Bool = {
			if let attrs = try? fm.attributesOfItem(atPath: filePath),
			   let type = attrs[.type] as? FileAttributeType {
				return type == .typeSymbolicLink
			}
			return false
		}()

		// If it exists or is a symlink (including dangling), attempt removal
		if exists || isSymlink {
			do {
				if dryRun {
					if isSymlink && !exists {
						AppLog.info("Uninstall dry run, would remove dangling symlink: \(filePath)")
					} else if isSymlink {
						AppLog.info("Uninstall dry run, would remove symlink: \(filePath)")
					} else {
						AppLog.info("Uninstall dry run, would remove: \(filePath)")
					}
					continue
				}
				try fm.removeItem(atPath: filePath)
				if isSymlink && !exists {
					AppLog.info("Removed dangling symlink: \(filePath)")
				} else if isSymlink {
					AppLog.info("Removed symlink: \(filePath)")
				} else {
					AppLog.info("Removed: \(filePath)")
				}
			} catch {
				AppLog.error("Failed to remove \(filePath): \(error)")
			}
		} else {
			AppLog.info("File not found (skipped): \(filePath)")
		}
	}
	
	if appData.uninstall.forgetPkg {
		try forgetPackage(def: appData, dryRun: dryRun)
	}
	
	if brewTidy {
		_ = brewTidyPostHook(
			bundleId: appData.uninstall.bundleId,
			appData: appData.uninstall,
			dryRun: dryRun
		)
	}
	
	// run post-flight scripts
	if postFlightCommand != nil {
		AppLog.info("Running post-flight command: \(postFlightCommand!)")
		_ = try executeCommand(with: ["-c", postFlightCommand!], executablePath: "/bin/zsh")
	}

	if !silent {
		NotificationService().sendNow(
			title: "Uninstall complete",
			body: "Application \(appData.uninstall.appName) has been uninstalled.",
			subtitle: "",
			imagePath: "",
			playSound: true,
			interruptionLevel: "active"
		)
	}
}

