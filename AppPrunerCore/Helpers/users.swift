//
//  users.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation
import SystemConfiguration

enum ConsoleUserProperty {
	case uid
	case gid
	case username
}

enum ConsoleUserResult {
	case uid(uid_t)
	case gid(uid_t)
	case username(String)
	case notFound
}

func getConsoleUserProperty(type: ConsoleUserProperty) -> ConsoleUserResult {
	var uid: uid_t = 0
	var gid: uid_t = 0
	let user = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid)
	
	switch type {
	case .uid:
		if uid != 0 {
			return .uid(uid)
		} else {
			return .notFound
		}
	case .gid:
		if gid != 0 {
			return .gid(gid)
		} else {
			return .notFound
		}
	case .username:
		if let user = user as String? {
			return .username(user)
		} else {
			return .notFound
		}
	}
}
