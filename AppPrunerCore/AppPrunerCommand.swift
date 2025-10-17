//
//  AppPrunerCommand.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import ArgumentParser
import Foundation

struct AppPruner: ParsableCommand {
	static var configuration = CommandConfiguration(
		commandName: "AppPruner",
		abstract: "Command-line tool for managing macOS app uninstallations",
		subcommands: [
			Uninstall.self,
			listAppDefinitions.self,
			generateAppDefinition.self,
			syncDefinitions.self
		],
		defaultSubcommand: Uninstall.self
	)
}

struct syncDefinitions: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Sync the local catalog of definitions with the remote source.")
	
	@OptionGroup var global: GlobalOptions

	mutating func run() throws {
		if global.debug { AppPrunerConfig.debugEnabled = true }
		syncCatalog(force: true)
	}
}

struct listAppDefinitions: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "List all available definitions.")
	
	@OptionGroup var global: GlobalOptions

	mutating func run() throws {
		if global.debug { AppPrunerConfig.debugEnabled = true }
		try listDefinitions()
	}
}

struct generateAppDefinition: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Generate a definition for an app.")
	
	@Option(help: "Name of the definition to create.")
	var name: String
	
	@Option(help: "App name to generate definition for.")
	var definitionName: String

	@Option(help: "Version of the definition. Default: 1.")
	var version: String?

	@Option(help: "Alternative names for the app separated by commas.", transform: { $0.components(separatedBy: ",") })
	var alternativeNames: [String]?

	@Option(help: "Bundle ID of the app.")
	var bundleId: String

	@Option(help: "Search file paths for the app. Overrides the defaults searh paths.", transform: { $0.components(separatedBy: ",") })
	var searchFilePaths: [String]?

	@Option(help: "Additional paths to include in the definition separated by commas.", transform: { $0.components(separatedBy: ",") })
	var additionalPaths: [String]?

	@Flag(help: "Forget package receipts during uninstall. Defualt: false.")
	var forgetPkg: Bool = false

	@Flag(help: "Unload launch daemons during uninstall. Default: false.")
	var unloadLaunchDaemons: Bool = false
	
	@Option(help: "Path to save the definition to. Defaults to the current working directory.")
	var outputPath: String? = nil

	@OptionGroup var global: GlobalOptions

	mutating func run() throws {
		if global.debug { AppPrunerConfig.debugEnabled = true }
		try generateDefinition(
			name: name,
			for: definitionName,
			version: version,
			alternativeNames: alternativeNames,
			bundleId: bundleId,
			searchFilePaths: searchFilePaths,
			additionalPaths: additionalPaths,
			forgetPkg: forgetPkg,
			unloadLaunchDaemons: unloadLaunchDaemons,
			path: outputPath)
	}
}

struct Uninstall: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Uninstall by definition name.")
	
	@Option(help: "Definition name to uninstall. Required if no path to definition is provided.")
	var definitionName: String?

	@Option(help: "Matching strategy for file discovery: 'exact', 'prefix', 'substring', or 'all' (default).")
	var matchMode: String?
	
	@Flag(help: "Do a dry run of the uninstall to get the output of what would happen.")
	var dryRun: Bool = false

	@Flag(help: "Remove user hive data for application (skipped by default).")
	var removeUserHive: Bool = false
	
	@Option(help: "Run a specific version of the app (skipped by default).")
	var version: String?

	@Flag(help: "Does not send uninstall notifications to the user if set.")
	var silent: Bool = false
	
	@Option(help: "Time in minutes to wait before continuing with the uninstall (default: 5)")
	var waitTime: Int = 5
	
	@Option(help: "Run a specific definition from a path (skipped by default). Does not work with --definition-name")
	var definitionPath: String?
	
	@OptionGroup var global: GlobalOptions

	mutating func run() throws {
		if global.debug { AppPrunerConfig.debugEnabled = true }
		if definitionName == nil && definitionPath == nil {
			// show help CLI help
			throw CleanExit.helpRequest(AppPruner.self)
		}
		try uninstallApp(
			def: definitionName,
			matchMode: matchMode,
			dryRun: dryRun,
			removeUserHive: removeUserHive,
			silent: silent,
			version: version,
			waitTime: waitTime,
			definitionPath: definitionPath)
	}
}
