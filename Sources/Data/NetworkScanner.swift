import Foundation
import Network

/// Lightweight Bonjour scanner. Browses a curated list of service types and
/// accumulates discovered service names. Thread-safe snapshot via `currentDevices()`.
final class NetworkScanner {
    static let shared = NetworkScanner()

    struct Device: Equatable {
        let name: String
        let serviceType: String
        let firstSeen: Date
    }

    private let queue = DispatchQueue(label: "NetworkScanner.queue")
    private var browsers: [NWBrowser] = []
    private var devices: [String: Device] = [:]   // name → Device (dedupe by name)
    private var started = false

    private let serviceTypes = [
        "_companion-link._tcp",     // iPhone Handoff
        "_apple-mobdev2._tcp",      // iOS device
        "_airplay._tcp",            // AirPlay (Apple TV, AirPlay receivers)
        "_raop._tcp",               // AirPlay audio (HomePods, speakers)
        "_homekit._tcp",            // HomeKit accessories
        "_hap._tcp",                // HomeKit Accessory Protocol
        "_googlecast._tcp",         // Chromecast / Google devices
        "_smb._tcp",                // SMB file sharing (Macs, NAS)
        "_afpovertcp._tcp",         // Apple file sharing
        "_workstation._tcp",        // Generic workstation broadcast
        "_device-info._tcp",        // Apple device info
        "_ssh._tcp",                // SSH servers
        "_http._tcp"                // HTTP services
    ]

    func start() {
        queue.async {
            guard !self.started else { return }
            self.started = true
            for type in self.serviceTypes {
                let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: nil)
                let parameters = NWParameters()
                parameters.includePeerToPeer = true
                let browser = NWBrowser(for: descriptor, using: parameters)
                browser.browseResultsChangedHandler = { [weak self] results, _ in
                    self?.handle(results: results, type: type)
                }
                browser.stateUpdateHandler = { _ in
                    // No-op; we don't tear down browsers
                }
                browser.start(queue: self.queue)
                self.browsers.append(browser)
            }
        }
    }

    private func handle(results: Set<NWBrowser.Result>, type: String) {
        queue.async {
            for result in results {
                if case .service(let name, _, _, _) = result.endpoint {
                    if self.devices[name] == nil {
                        self.devices[name] = Device(name: name, serviceType: type, firstSeen: Date())
                    }
                }
            }
        }
    }

    /// Snapshot of currently-discovered devices, sorted by name.
    func currentDevices() -> [Device] {
        queue.sync {
            Array(devices.values).sorted { $0.name < $1.name }
        }
    }

    /// Returns true if any discovered device name contains `pattern` (case-insensitive).
    func hasDevice(matching pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        return queue.sync {
            devices.values.contains { $0.name.localizedCaseInsensitiveContains(pattern) }
        }
    }
}
