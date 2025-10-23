//
//  executeCommand.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

import Foundation

enum executionError: Error { case failedToExecute(String), timeout(String) }

func executeCommand(
	with arguments: [String] = [],
	executablePath: String = "",
	asUser: String? = nil,
	passEnv: [String:String]? = nil,
	timeoutSeconds: TimeInterval? = 60  // nil = no timeout
) throws -> Data {

	let p = Process()
	var exec = executablePath
	var args = arguments

	if let user = asUser {
		exec = "/usr/bin/sudo"
		// -n: non-interactive, -u: user, -H: set HOME
		args = ["-n", "-u", user, "-H", executablePath] + arguments
	}

	p.executableURL = URL(fileURLWithPath: exec)
	p.arguments = args

	// Environment: add Brew-safe flags and a sane PATH
	var env = ProcessInfo.processInfo.environment
	let path = env["PATH"] ?? ""
	if !path.contains("/opt/homebrew/bin") || !path.contains("/usr/local/bin") {
		env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" + (path.isEmpty ? "" : ":\(path)")
	}
	env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
	env["HOMEBREW_NO_ANALYTICS"] = "1"
	env["HOMEBREW_COLOR"] = "0"
	if let passEnv { env.merge(passEnv) { _, new in new } }
	p.environment = env

	let outPipe = Pipe()
	let errPipe = Pipe()
	p.standardOutput = outPipe
	p.standardError  = errPipe

	AppLog.debug(#function + ": Executing \(exec) \(args.joined(separator: " "))")

	var outData = Data()
	var errData = Data()

	// Drain asynchronously to avoid pipe fill deadlock
	let outFH = outPipe.fileHandleForReading
	let errFH = errPipe.fileHandleForReading

	let group = DispatchGroup()
	group.enter()
	outFH.readabilityHandler = { h in
		let chunk = h.availableData
		if chunk.isEmpty { group.leave(); h.readabilityHandler = nil; return }
		outData.append(chunk)
	}
	group.enter()
	errFH.readabilityHandler = { h in
		let chunk = h.availableData
		if chunk.isEmpty { group.leave(); h.readabilityHandler = nil; return }
		errData.append(chunk)
	}

	try p.run()

	// Optional timeout
	let deadline = timeoutSeconds.map { Date().addingTimeInterval($0) }

	// Wait for process to exit; poll for timeout
	while p.isRunning {
		if let d = deadline, Date() > d {
			p.terminate()
			// give it a beat to flush
			usleep(200_000)
			outFH.readabilityHandler = nil
			errFH.readabilityHandler = nil
			throw executionError.timeout("Timed out: \(exec) \(args.joined(separator: " "))")
		}
		usleep(50_000)
	}

	// Close pipes to trigger final empty reads
	outFH.readabilityHandler = nil
	errFH.readabilityHandler = nil

	// Make sure all data consumed
	outPipe.fileHandleForReading.closeFile()
	errPipe.fileHandleForReading.closeFile()
	group.wait()

	if p.terminationStatus != 0 {
		let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
		let msg = "args: \(args.joined(separator: " ")), \(exec). Error: \(errStr)".trimmingCharacters(in: .whitespacesAndNewlines)
		AppLog.error(#function + ": \(msg)")
		throw executionError.failedToExecute(msg)
	}

	return outData
}
