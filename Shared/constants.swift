//
//  constants.swift
//  AppPruner
//
//  Created by Tobias Almén on 2025-10-16.
//

enum Constants {
	static let pkgutilPath = "/usr/sbin/pkgutil"
	static let launchCtlPath = "/bin/launchctl"
	static let repoUrl = "https://almenscorner.github.io/AppPruner/"
	static let uninstallCheckPaths = [
		"/Applications/",
		"/Applications/Utilities/",
		"/Library/Application Support/",
		"/Library/PrivilegedHelperTools/",
		"/usr/local/bin/",
		"/usr/local/sbin/",
		"/usr/local/share/",
		"/usr/local/opt/",
		"/usr/local/etc/",
		"/usr/local/var/",
		"/Users/Shared/",
		"/usr/local/lib/",
		"/usr/local/include/",
		"/Users/Shared/Library/Application Support/",
		"/Library/SystemExtensions/",
		"/Library/LaunchAgents/",
		"/Library/LaunchDaemons/",
		"/Library/Frameworks/",
		"/Library/PreferencePanes/",
		"/Library/QuickLook/",
		"/Library/Services/",
		"/Library/Audio/Plug-Ins/",
		"/Library/Extensions/",
		"/Library/Internet Plug-Ins/",
		"/Library/Logs/",
		"/Library/Logs/DiagnosticReports/",
		"/Library/Preferences/",
		"/var/folders/",
		"~/Applications/"
	]
	static let uninstallUserHivePaths = [
		"~/Library/Application Support/",
		"~/Library/Application Support/CrashReporter/",
		"~/Library/Caches/",
		"~/Library/Preferences/",
		"~/Library/Caches/",
		"~/Library/WebKit/",
		"~/Library/HTTPStorages/",
		"~/Library/Containers/",
		"~/Library/Group Containers/",
		"~/Library/Logs/",
		"~/Library/Logs/DiagnosticReports/",
		"~/Library/Saved Application State/",
		"~/Library/",
		"~/Library/Services/",
		"~/Library/LaunchAgents/",
		"~/Library/Preferences/ByHost/",
		"~/Library/PreferencePanes/",
		"~/Library/QuickLook/",
		"~/Library/Application Scripts/",
		"~/Library/Audio/Plug-Ins/",
		"~/Library/WebKit/",
		"~/Library/HTTPStorages/",
		"~/Library/Internet Plug-Ins/",
		"~/"
	]
}
