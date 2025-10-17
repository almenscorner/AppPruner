//
//  listDefinitions.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

func listDefinitions() throws {
	syncCatalog(force: false)
	// get all definitions from the index
	let index = try loadIndex()
	for def in index.items {
		print("\(def.id) - \(def.name) (version: \(def.version), updated: \(def.updated_at))")
	}
}
