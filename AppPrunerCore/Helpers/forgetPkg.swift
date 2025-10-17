//
//  forgetPkg.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

func forgetPackage(def: Definition, dryRun: Bool = false) throws {
	do {
		let args = ["--pkgs"]
		let outputData = try executeCommand(with: args, executablePath: Constants.pkgutilPath)
		let output = String(data: outputData, encoding: .utf8) ?? ""
		let installedPackages = output.split(separator: "\n").map(String.init)
		let alternativeNames = def.uninstall.alternativeNames ?? []
		let matchingPackages = installedPackages.filter { pkg in pkg.contains(def.uninstall.appName) || alternativeNames.contains(where: { pkg.contains($0) }) }
		if matchingPackages.isEmpty {
			AppLog.info("Package receipt not found (skipped): \(def.uninstall.appName)")
		} else {
			for receipt in matchingPackages {
				let args = ["--forget", receipt]
				do {
					if dryRun {
						AppLog.info("Uninstall dry run, would run: \(args.joined(separator: " "))")
						continue
					}
					_ = try executeCommand(with: args, executablePath: Constants.pkgutilPath)
					AppLog.info("Removed package receipt: \(receipt)")
				} catch {
					AppLog.error("Failed to remove package receipt \(receipt): \(error)")
				}
			}
		}
	} catch {
		AppLog.error("Failed to list installed packages: \(error)")
	}
}
