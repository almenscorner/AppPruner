//
//  generateDefinition.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-17.
//

import Foundation

func generateDefinition(name: String,
						for app: String,
                        version: String? = nil,
                        alternativeNames: [String]? = nil,
                        bundleId: String,
                        searchFilePaths: [String]? = nil,
                        additionalPaths: [String]? = nil,
                        forgetPkg: Bool = true,
                        unloadLaunchDaemons: Bool = false,
						path: String? = nil,
						matchMode: String? = nil,
						brewName: String? = nil) throws {
    let uninstallData = UninstallData(
        appName: app,
        alternativeNames: alternativeNames,
        bundleId: bundleId,
        searchFilePaths: searchFilePaths,
        additionalPaths: additionalPaths,
        forgetPkg: forgetPkg,
        unloadLaunchDaemons: unloadLaunchDaemons,
		matchMode: matchMode,
		brewName: brewName
    )
    let definition = Definition(
		name: name.lowercased().replacingOccurrences(of: " ", with: ""),
        version: version ?? "1",
        updated_at: ISO8601DateFormatter().string(from: Date()),
        uninstall: uninstallData
    )
	let encoder = JSONEncoder()
	encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
    let jsonData = try encoder.encode(definition)
    FileManager.default.createFile(atPath: "\(path ?? ".")/\(name.lowercased().replacingOccurrences(of: " ", with: "")).json", contents: jsonData, attributes: nil)
}
