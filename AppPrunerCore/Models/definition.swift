//
//  app.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

struct Definition: Codable {
	let name: String
	let version: String
	let updated_at: String
	let uninstall: UninstallData
}

struct UninstallData: Codable {
	let appName: String
	let alternativeNames: [String]?
	let bundleId: String
	let searchFilePaths: [String]?
	let additionalPaths: [String]?
	let forgetPkg: Bool
	let unloadLaunchDaemons: Bool
	let matchMode: String?
	let brewName: String?
}
