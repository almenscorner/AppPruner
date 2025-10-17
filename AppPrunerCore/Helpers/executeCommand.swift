//
//  executeCommand.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

import Foundation

enum executionError: Error {
	case failedToExecute(String)
}

func executeCommand(with arguments: [String] = [], executablePath: String = "") throws -> Data {
	let process = Process()
	process.executableURL = URL(fileURLWithPath: executablePath)
	process.arguments = arguments

	let outputPipe = Pipe()
	let errorPipe = Pipe()
	process.standardOutput = outputPipe
	process.standardError = errorPipe
	
	AppLog.debug(#function + ": Executing \(executablePath) with arguments: \(arguments.joined(separator: " "))")

	try process.run()
	process.waitUntilExit()

	if process.terminationStatus != 0 {
		let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
		let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
		let errorMessage = "args: \(arguments.joined(separator: " ")), \(executablePath). Error: \(errorOutput)".trimmingCharacters(in: .whitespacesAndNewlines)
		AppLog.error(#function + ": \(errorMessage)")
		throw executionError.failedToExecute(errorMessage)
	}

	return outputPipe.fileHandleForReading.readDataToEndOfFile()
}
