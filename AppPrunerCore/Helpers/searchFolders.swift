//
//  searchFolders.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

enum MatchMode {
	case exact
	case prefix
	case substring
	case all // all modes
}

func searchFoldersForApp(_ def: Definition, matchMode: MatchMode = .all, removeUserHive: Bool = false) throws -> Set<String> {
	
	let userNameResult = getConsoleUserProperty(type: .username)
	let userNameString: String

	switch userNameResult {
	case .username(let userName):
		userNameString = String(userName)
	case .notFound:
		AppLog.error("\(#function): Could not find console user ID")
		throw unloadDaemonError.userIDNotFound
	default:
		AppLog.error("\(#function): Unhandled case for getConsoleUserProperty(type: .uid)")
		throw unloadDaemonError.userIDNotFound
	}

	let fm = FileManager.default
	var result = Set<String>()
	
	// Build match targets from available uninstall fields without assuming unavailable members
	let matchTargets = [def.uninstall.appName, def.uninstall.bundleId] + (def.uninstall.additionalPaths ?? []) + (def.uninstall.alternativeNames ?? [])

	let targetSetLower = Set(matchTargets.map { $0.lowercased() })

	var paths = Constants.uninstallCheckPaths + (removeUserHive ? Constants.uninstallUserHivePaths : [])
	if let uninstallAny = def.uninstall as Any?,
	   let dict = uninstallAny as? [String: Any],
	   let searchPaths = dict["searchPaths"] as? [String] {
		paths = searchPaths + (removeUserHive ? Constants.uninstallUserHivePaths : [])
	}

	if let additionalPaths = def.uninstall.additionalPaths {
		AppLog.info("Including additional paths in search for app: \(def.uninstall.appName)")
		for p in additionalPaths {
			if !paths.contains(p) {
				AppLog.debug("Adding additional path: \(p)")
				paths.append(p)
			}
		}
	}

	if removeUserHive {
		AppLog.info("Including user hive paths in search for app: \(def.uninstall.appName)")
	}

	for var folder in paths {
		if folder.starts(with: "~") {
			folder = folder.replacingOccurrences(of: "~", with: "/Users/\(userNameString)")
		}
		// Attempt to access the directory; if it fails, skip and log
		if !fm.fileExists(atPath: folder) {
			AppLog.debug("\(#function): Folder does not exist, skipping: \(folder)")
			continue
		}

		var items: [String] = []
		
		// if folder is /var/folders, search all subfolders recursively for folders and files
		var recursiveItems: [String] = []
		if folder == "/var/folders/" {
			let enumerator = fm.enumerator(atPath: folder)
			while let item = enumerator?.nextObject() as? String {
				recursiveItems.append(item)
			}
		} else {
			// search one folder deeper and not all the way down e.g. /Library/Application Support/SOMEAPP and not /Library/Application Support/SOMEAPP/SUBFOLDER
			let enumerator = fm.enumerator(atPath: folder)
			while let item = enumerator?.nextObject() as? String {
				// Only accept top-level entries (no slash in the relative path)
				guard !item.contains("/") else {
					// Prevent recursing into deeper items for performance
					enumerator?.skipDescendants()
					continue
				}
				let fullItemPath = (folder as NSString).appendingPathComponent(item)
				var isDir: ObjCBool = false
				if fm.fileExists(atPath: fullItemPath, isDirectory: &isDir), isDir.boolValue {
					let subItems = (try? fm.contentsOfDirectory(atPath: fullItemPath)) ?? []
					recursiveItems.append(contentsOf: subItems.map { (fullItemPath as NSString).appendingPathComponent($0) })
				}
			}
		}

		do {
			if folder == "/var/folders/" {
				items = try fm.contentsOfDirectory(atPath: folder)
			} else {
				items = try fm.contentsOfDirectory(atPath: folder).map { (folder as NSString).appendingPathComponent($0) }
			}
			if !recursiveItems.isEmpty {
				let merged = Set(items).union(Set(recursiveItems))
				items = Array(merged)
			}
		} catch {
			AppLog.error("\(#function): Could not read folder \(folder): \(error)")
			continue
		}

		var chosenParents = Set<String>()

		for item in items {
			let fullItemPath = (folder == "/var/folders/") ? ((folder as NSString).appendingPathComponent(item)) : item

			// If we already chose a parent, skip its descendants
			if folder == "/var/folders/" && chosenParents.contains(where: { fullItemPath == $0 || fullItemPath.hasPrefix($0 + "/") }) {
				continue
			}

			// Special handling for /var/folders: anchor matches to the directory directly under .../C/
		   if folder == "/var/folders/" {
				// Build a relative path from /var/folders/ and inspect components
				let rel = String(fullItemPath.dropFirst(folder.count))
				let comps = rel.split(separator: "/", omittingEmptySubsequences: true)

				// Detect the "<type>" segment (commonly C, T, or 0). Prefer the third component,
				// fall back to any single-character component or known set if structure differs.
				let knownTypes: Set<String> = ["c", "t", "0"]
				let typeIdx: Int? = {
					if comps.count >= 3, knownTypes.contains(String(comps[2]).lowercased()) {
						return 2
					}
					return comps.firstIndex { seg in
						let s = String(seg)
						return s.count == 1 || knownTypes.contains(s.lowercased())
					}
				}()

				if let tIdx = typeIdx, tIdx + 1 < comps.count {
					let candidateName = String(comps[tIdx + 1])
					let candidateLower = candidateName.lowercased()

					var isCandidateMatch = false
					for target in matchTargets {
						let t = target.lowercased()
						switch matchMode {
						case .exact:
							if candidateLower == t { isCandidateMatch = true }
						case .prefix:
							if candidateLower.hasPrefix(t) { isCandidateMatch = true }
						case .substring:
							if candidateLower.contains(t) { isCandidateMatch = true }
						case .all:
							if candidateLower == t || candidateLower.hasPrefix(t) || candidateLower.contains(t) { isCandidateMatch = true }
						}
						if isCandidateMatch { break }
					}

					if isCandidateMatch {
						// Anchor to .../<type>/<candidateName>
						let anchorRel = comps[0...tIdx+1].joined(separator: "/")
						let anchorPath = (folder as NSString).appendingPathComponent(anchorRel)

						// Remove any children already added under this anchor
						let toRemove = result.filter { $0 == anchorPath || $0.hasPrefix(anchorPath + "/") }
						for r in toRemove { result.remove(r) }

						chosenParents.insert(anchorPath)
						result.insert(anchorPath)
						continue
					}
				}
				// For /var/folders: if not matched as <type>/<candidate>, skip generic matching entirely
				continue
			}

			let itemName = (item as NSString).lastPathComponent

			var matched = false
			for target in matchTargets {
				guard !target.isEmpty else { continue }
				switch matchMode {
				case .exact:
					if itemName.caseInsensitiveCompare(target) == .orderedSame { matched = true }
				case .prefix:
					if itemName.lowercased().hasPrefix(target.lowercased()) { matched = true }
				case .substring:
					if itemName.lowercased().contains(target.lowercased()) { matched = true }
				case .all:
					if itemName.caseInsensitiveCompare(target) == .orderedSame
						|| itemName.lowercased().hasPrefix(target.lowercased())
						|| itemName.lowercased().contains(target.lowercased()) {
						matched = true
					}
				}
				if matched {
					if folder == "/var/folders/" {
						// If the matched item IS the app dir (exact name match), keep it.
						// Otherwise, keep the item's parent directory.
						let itemIsExactDirHit = targetSetLower.contains(itemName.lowercased())
						let anchorPath = itemIsExactDirHit
							? fullItemPath
							: (fullItemPath as NSString).deletingLastPathComponent

						// Remove any previously added children under this anchor
						let toRemove = result.filter { $0 == anchorPath || $0.hasPrefix(anchorPath + "/") }
						for r in toRemove { result.remove(r) }

						chosenParents.insert(anchorPath)
						result.insert(anchorPath)
					} else {
						result.insert(fullItemPath)
					}
				}
			}
		}
	}
	return result
}

