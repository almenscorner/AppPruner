//
//  GlobalOptions.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation
import ArgumentParser

enum AppPrunerConfig {
	static var debugEnabled: Bool = false
}

struct GlobalOptions: ParsableArguments {
	@Flag(name: .shortAndLong, help: "Enable debug logging.")
	var debug: Bool = false
}
