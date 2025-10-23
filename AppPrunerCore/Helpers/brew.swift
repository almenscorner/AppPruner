//
//  brew.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-23.
//

import Foundation

struct BrewEnv { let brewPath: String; let owner: String; let prefix: String }

func detectBrew() -> BrewEnv? {
	let cand = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
	guard let brewPath = cand.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
	guard let p = try? executeCommand(with: ["--prefix"], executablePath: brewPath),
		  let prefix = String(data: p, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
		  !prefix.isEmpty else { return nil }
	let o = try? executeCommand(with: ["-f","%Su", prefix], executablePath: "/usr/bin/stat")
	let owner = (o.flatMap { String(data:$0, encoding:.utf8) } ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
	return .init(brewPath: brewPath, owner: owner.isEmpty ? NSUserName() : owner, prefix: prefix)
}

// A. Was a token installed that matches a human name?
func resolveBrewTokenByName(_ humanName: String, brew: BrewEnv) -> (token: String, isCask: Bool)? {
	func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }

	// installed casks
	if let d = try? executeCommand(with: ["list","--cask","--versions"], executablePath: brew.brewPath, asUser: brew.owner),
	   let s = String(data:d, encoding:.utf8) {
		let tokens = s.split(separator:"\n").compactMap { $0.split(separator:" ").first }.map(String.init)
		let target = norm(humanName)
		if let hit = tokens.first(where: { norm($0) == target || $0.compare(humanName, options:.caseInsensitive) == .orderedSame }) {
			return (hit, true)
		}
	}
	// installed formulae
	if let d = try? executeCommand(with: ["list","--formula"], executablePath: brew.brewPath, asUser: brew.owner),
	   let s = String(data:d, encoding:.utf8) {
		let tokens = s.split(separator:"\n").map(String.init)
		let target = norm(humanName)
		if let hit = tokens.first(where: { norm($0) == target || $0.compare(humanName, options:.caseInsensitive) == .orderedSame }) {
			return (hit, false)
		}
	}
	return nil
}

// B. Is there a Caskroom directory
func tokenFromCaskroomGuess(_ humanName: String, brew: BrewEnv) -> String? {
	let caskroom = (brew.prefix as NSString).appendingPathComponent("Caskroom")
	guard let entries = try? FileManager.default.contentsOfDirectory(atPath: caskroom) else { return nil }
	let normName = humanName.lowercased().replacingOccurrences(of:" ", with:"").replacingOccurrences(of:"_", with:"")
	return entries.first { token in
		let t = token.lowercased().replacingOccurrences(of:"-", with:"")
		return t == normName || t.contains(normName)
	}
}

@discardableResult
func brewTidyPostHook(bundleId: String?,
					  appData: UninstallData,
					  dryRun: Bool = false) -> Bool {
	guard let brew = detectBrew() else { return false }


	var guess: (token:String, isCask:Bool)?

	let name = appData.brewName ?? appData.appName
	if guess == nil, !name.isEmpty {
		if let r = resolveBrewTokenByName(name, brew: brew) {
			guess = r
		} else if let t = tokenFromCaskroomGuess(name, brew: brew) {
			guess = (t, true)
		}
	}

	guard let (token, isCask) = guess else {
		AppLog.debug("brewTidyPostHook: no Brew evidence, skipping.")
		return false
	}

	AppLog.info("Brew tidy: token=\(token) kind=\(isCask ? "cask" : "formula") \(bundleId.map { "(bundleId=\($0))" } ?? "")")
	if isCask {
		if !dryRun {
			_ = try? executeCommand(with: ["uninstall","--cask","--force", token], executablePath: brew.brewPath, asUser: brew.owner)
			_ = try? executeCommand(with: ["cleanup","--prune-prefix", token], executablePath: brew.brewPath, asUser: brew.owner)
		} else {
			AppLog.info("brewTidyPostHook: (dry run) would uninstall cask \(token)")
		}
	} else {
		if !dryRun {
			_ = try? executeCommand(with: ["uninstall", token], executablePath: brew.brewPath, asUser: brew.owner)
			_ = try? executeCommand(with: ["autoremove"], executablePath: brew.brewPath, asUser: brew.owner)
			_ = try? executeCommand(with: ["cleanup","--prune-prefix", token], executablePath: brew.brewPath, asUser: brew.owner)
		} else {
			AppLog.info("brewTidyPostHook: (dry run) would uninstall \(token)")
		}
	}
	return true
}

