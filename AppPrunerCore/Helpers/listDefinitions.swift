//
//  listDefinitions.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

func listDefinitions() throws {
	syncCatalog(force: false)
	// get all definitions from the index
	let index = try loadIndex()
    let rows: [[String]] = index.items.map { def in
        [def.id, def.name, def.version, def.updated_at]
    }

    let table = Table(
        headers: ["id", "name", "version", "updated"],
        rows: rows
    )

    table.render()
}

func searchDefinitions(name: String) throws {
    syncCatalog(force: false)
    // get all definitions from the index
    let index = try loadIndex()
    let filteredItems = index.items.filter { def in
        def.name.localizedCaseInsensitiveContains(name)
    }
    let rows: [[String]] = filteredItems.map { def in
        [def.id, def.name, def.version, def.updated_at]
    }

    let table = Table(
        headers: ["id", "name", "version", "updated"],
        rows: rows
    )

    table.render()
}
