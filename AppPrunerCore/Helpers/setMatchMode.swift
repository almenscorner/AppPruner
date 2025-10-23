//
//  setMatchMode.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-23.
//

func setMatchMode(matchMode: String) -> MatchMode {
	let mode: MatchMode
	switch matchMode.lowercased() {
	case "exact":
		mode = .exact
	case "prefix":
		mode = .prefix
	case "substring":
		mode = .substring
	default:
		mode = .all
	}
	return mode
}
