import AppKit
import Observation
import UserNotifications

/// Tells the user when a newer release is out.
///
/// Once a day, it asks GitHub for the latest published release of this repo and
/// compares its tag with the running version. That one request is the app's only
/// network traffic, and nothing goes with it but the app's name and version as
/// the User-Agent GitHub requires. A newer version shows as a row in the
/// settings window sidebar and as one macOS notification per version; clicking
/// either opens the release page. Installing stays manual, as the README's
/// Install section describes: this app is not notarized, so it does not replace
/// itself.
///
/// The notification permission is asked for the first time there is an update to
/// report, not at first launch. The switch in the sidebar turns the check off.
@MainActor
@Observable
final class UpdateChecker: NSObject {
    static let shared = UpdateChecker()

    struct Release: Equatable {
        let version: String
        let page: URL
    }

    enum Status: Equatable {
        /// Not busy and nothing to say beyond `available`.
        case idle
        case checking
        case upToDate
        case failed
    }

    private(set) var status: Status = .idle

    /// The newer release the last successful check found. Drives the row in the
    /// sidebar.
    ///
    /// Held apart from `status` on purpose. Check Now sets `.checking` and a
    /// failed re-check sets `.failed`; when the update lived inside `status`,
    /// either one threw a known update away, so clicking Check Now offline
    /// removed the Download button for a release the app had already found. Only
    /// a successful check changes it, and switching the check off clears it.
    private(set) var available: Release?

    // The three lines that differ per app. `repoSlug` is the name GitHub uses,
    // which is not the local directory name here: the checkout is
    // imperator-menu-bar-folders and the repo is imperator-menubarfolders.
    private static let repoSlug = "goranimperator/imperator-menubarfolders"
    private static let appName = "Imperator MenuBarFolders"
    private static let userAgentName = "Imperator-MenuBarFolders"

    static let enabledKey = "checkForUpdates"
    private static let lastCheckKey = "lastUpdateCheck"
    private static let notifiedKey = "notifiedUpdateVersion"
    private static let interval: TimeInterval = 24 * 60 * 60
    private static let latestURL = URL(string: "https://api.github.com/repos/\(repoSlug)/releases/latest")!

    @ObservationIgnored private var timer: Timer?

    /// The one network call, replaceable so a probe can answer without a network.
    @ObservationIgnored var fetch: (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }

    /// True while the hourly tick is scheduled. Read by the probe.
    var isScheduled: Bool { timer != nil }

    /// `UNUserNotificationCenter.current()` raises when the process is not a
    /// bundled app, so a bare `swift run` or `.build/release/...` launch used to
    /// terminate in `applicationDidFinishLaunching`. Without a bundle the check
    /// still runs; it just has no notification to post.
    nonisolated static var canNotify: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// On by default; read through `object(forKey:)` because `bool(forKey:)`
    /// reports an unset key as false.
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func start() {
        if Self.canNotify { UNUserNotificationCenter.current().delegate = self }
        refreshSchedule()
    }

    /// Brings the hourly tick in line with the switch. Called at launch and
    /// whenever the switch changes.
    ///
    /// The tick only exists while the check is on: left running with the switch
    /// off it woke the app every hour to do nothing. It is hourly rather than
    /// daily so a Mac that slept through the 24-hour mark checks soon after it
    /// wakes, and a failed check is retried within the hour.
    func refreshSchedule() {
        if isEnabled {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { _ in
                    Task { @MainActor in UpdateChecker.shared.checkIfDue() }
                }
            }
            checkIfDue()
        } else {
            timer?.invalidate()
            timer = nil
            // Switched off, so a row that says an update is available would be
            // a result of a check the user just turned off. Check Now brings it
            // back.
            available = nil
            if status != .checking { status = .idle }
        }
    }

    func checkIfDue() {
        guard isEnabled else { return }
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard Date().timeIntervalSince1970 - last >= Self.interval else { return }
        Task { await check() }
    }

    /// Checks now. Check Now calls this directly, which is an explicit request
    /// and so runs even with the daily check switched off.
    func check() async {
        guard status != .checking else { return }
        status = .checking

        var request = URLRequest(url: Self.latestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("\(Self.userAgentName)/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await fetch(request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                status = .failed
                return
            }
            let latest = try JSONDecoder().decode(LatestRelease.self, from: data)
            // Only a successful check counts toward the daily interval, so a
            // failure is retried on the next hourly tick.
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)

            let version = latest.tagName.hasPrefix("v") ? String(latest.tagName.dropFirst()) : latest.tagName
            guard Self.isNewer(version, than: Self.currentVersion) else {
                available = nil
                status = .upToDate
                return
            }
            let release = Release(version: version, page: latest.htmlURL)
            available = release
            status = .idle
            await notifyOnce(release)
        } catch {
            status = .failed
        }
    }

    /// Opens a release page, and only a GitHub page over HTTPS: the link comes
    /// from a network response, and nothing else should be opened from it.
    static func open(_ url: URL) {
        guard isOpenable(url) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Split out so the rule can be tested without opening a browser.
    nonisolated static func isOpenable(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "github.com"
    }

    /// Numeric comparison, component by component, so 1.0.10 is newer than
    /// 1.0.9. A missing component counts as 0.
    ///
    /// A pre-release or build label after the first `-` or `+` is not a
    /// component, so `1.2.1-beta` compares as 1.2.1. A tag that still does not
    /// parse, like `1.2.x`, is never offered: reading its unparseable part as 0
    /// made it look equal to, or older than, the version already installed.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let a = components(of: candidate), let b = components(of: current) else { return false }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }

    nonisolated private static func components(of version: String) -> [Int]? {
        let core = version.split(
            maxSplits: 1,
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == "-" || $0 == "+" }
        ).first ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, !parts.contains(where: { $0 == nil }) else { return nil }
        return parts.compactMap { $0 }
    }

    /// One notification per version, and the permission question only once there
    /// is something to say.
    ///
    /// The version is recorded as soon as the user has answered, granted or not.
    /// It used to be recorded only after the notification was added, so a denial
    /// left it unset and every successful daily check asked again for a version
    /// the user had already turned down. A notification that fails to post is
    /// the one case that still retries.
    private func notifyOnce(_ release: Release) async {
        guard Self.canNotify else { return }
        guard UserDefaults.standard.string(forKey: Self.notifiedKey) != release.version else { return }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else {
            UserDefaults.standard.set(release.version, forKey: Self.notifiedKey)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(Self.appName) \(release.version) is available"
        content.body = "You have \(Self.currentVersion). Click to open the release page."
        content.userInfo = ["url": release.page.absoluteString]
        let request = UNNotificationRequest(identifier: "update-\(release.version)", content: content, trigger: nil)
        do {
            try await center.add(request)
        } catch {
            return
        }
        UserDefaults.standard.set(release.version, forKey: Self.notifiedKey)
    }
}

extension UpdateChecker: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let string = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: string) else { return }
        await MainActor.run { UpdateChecker.open(url) }
    }

    /// Show the banner even when the app is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// The two fields of GitHub's "latest release" response the check uses.
private nonisolated struct LatestRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
