//
//  LocalDogfightManager.swift
//  Dogfight Adventures
//
//  Two-device same-network transport. One device hosts a Bonjour-advertised TCP
//  listener; the other scans the local Wi-Fi and connects automatically.
//

import Foundation
import Darwin
import Network
import UIKit

struct PeerAircraftState: Codable {
    let playerID: String
    let displayName: String
    let px: Float
    let py: Float
    let pz: Float
    let qx: Float
    let qy: Float
    let qz: Float
    let qw: Float
    let speedKt: Int
    let health: Float
    let shotID: Int
    let isAlive: Bool
}

protocol LocalDogfightManagerDelegate: AnyObject {
    func localDogfightManager(_ manager: LocalDogfightManager, didUpdateStatus status: String)
    func localDogfightManager(_ manager: LocalDogfightManager, didReceive state: PeerAircraftState)
}

final class LocalDogfightManager {
    static let port: UInt16 = 47661
    static let bonjourType = "_dogfight._tcp"

    weak var delegate: LocalDogfightManagerDelegate?

    let localPlayerID = UUID().uuidString

    private let displayName = UIDevice.current.name
    private let queue = DispatchQueue(label: "dogfight.local-network")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var isReady = false

    deinit {
        stop()
    }

    func start(mode: DogfightMultiplayerMode) {
        stop()
        switch mode {
        case .solo:
            postStatus("Solo flight")
        case .host:
            startHost()
        case .joinNearby:
            startNearbyJoin()
        }
    }

    func stop() {
        listener?.cancel()
        browser?.cancel()
        connection?.cancel()
        listener = nil
        browser = nil
        connection = nil
        receiveBuffer.removeAll(keepingCapacity: false)
        isReady = false
    }

    func send(state: PeerAircraftState) {
        guard isReady, let connection = connection else { return }
        let frame = DogfightFrame(type: "state", state: state)
        guard var data = try? JSONEncoder().encode(frame) else { return }
        data.append(0x0a)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.postStatus("Wi-Fi send failed: \(error.localizedDescription)")
            }
        })
    }

    func hostAddressesText() -> String {
        let addresses = Self.localIPv4Addresses()
        if addresses.isEmpty {
            return "Hosting Wi-Fi game"
        }
        let preferred = addresses.filter { !$0.hasPrefix("169.254.") }
        let displayed = preferred.isEmpty ? addresses : preferred
        return "Hosting: \(displayed.joined(separator: "  "))"
    }

    private func startHost() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let port = NWEndpoint.Port(rawValue: Self.port) else {
            postStatus("Wi-Fi port unavailable")
            return
        }

        do {
            let listener = try NWListener(using: params, on: port)
            listener.service = NWListener.Service(name: displayName, type: Self.bonjourType)
            listener.stateUpdateHandler = { [weak self] state in
                self?.handleListenerState(state)
            }
            listener.newConnectionHandler = { [weak self] newConnection in
                self?.accept(newConnection)
            }
            self.listener = listener
            listener.start(queue: queue)
            postStatus(hostAddressesText())
        } catch {
            postStatus("Host failed: \(error.localizedDescription)")
        }
    }

    private func startNearbyJoin() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: Self.bonjourType, domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in
            self?.handleBrowserState(state)
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self, self.connection == nil else { return }
            guard let result = results.first else {
                self.postStatus("Scanning same Wi-Fi...")
                return
            }
            self.postStatus("Found \(self.displayName(for: result.endpoint))")
            self.connect(to: result.endpoint)
        }
        self.browser = browser
        browser.start(queue: queue)
        postStatus("Scanning same Wi-Fi...")
    }

    private func accept(_ newConnection: NWConnection) {
        connection?.cancel()
        connection = newConnection
        configure(newConnection, readyStatus: "Wi-Fi multiplayer connected")
        newConnection.start(queue: queue)
    }

    private func connect(to endpoint: NWEndpoint) {
        browser?.cancel()
        browser = nil
        let newConnection = NWConnection(to: endpoint, using: .tcp)
        connection = newConnection
        configure(newConnection, readyStatus: "Wi-Fi multiplayer connected")
        newConnection.start(queue: queue)
    }

    private func configure(_ newConnection: NWConnection, readyStatus: String) {
        isReady = false
        receiveBuffer.removeAll(keepingCapacity: false)
        newConnection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state, readyStatus: readyStatus)
        }
        receiveLoop(newConnection)
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            postStatus(hostAddressesText())
        case .failed(let error):
            postStatus("Host failed: \(error.localizedDescription)")
        case .waiting(let error):
            postStatus("Host waiting: \(error.localizedDescription)")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            postStatus("Scanning same Wi-Fi...")
        case .failed(let error):
            postStatus("Scan failed: \(error.localizedDescription)")
        case .waiting(let error):
            postStatus("Scan waiting: \(error.localizedDescription)")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func displayName(for endpoint: NWEndpoint) -> String {
        switch endpoint {
        case .service(let name, _, _, _):
            return name
        case .hostPort(let host, _):
            return "\(host)"
        default:
            return "nearby plane"
        }
    }

    private func handleConnectionState(_ state: NWConnection.State, readyStatus: String) {
        switch state {
        case .ready:
            isReady = true
            postStatus(readyStatus)
        case .failed(let error):
            isReady = false
            postStatus("Wi-Fi failed: \(error.localizedDescription)")
        case .waiting(let error):
            isReady = false
            postStatus("Wi-Fi waiting: \(error.localizedDescription)")
        case .cancelled:
            isReady = false
            postStatus("Wi-Fi disconnected")
        default:
            break
        }
    }

    private func receiveLoop(_ activeConnection: NWConnection) {
        activeConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.processReceiveBuffer()
            }
            if let error = error {
                self.postStatus("Wi-Fi receive failed: \(error.localizedDescription)")
                return
            }
            if !isComplete {
                self.receiveLoop(activeConnection)
            }
        }
    }

    private func processReceiveBuffer() {
        let newline = Data([0x0a])
        while let range = receiveBuffer.range(of: newline) {
            let packet = receiveBuffer.subdata(in: receiveBuffer.startIndex..<range.lowerBound)
            receiveBuffer.removeSubrange(receiveBuffer.startIndex...range.lowerBound)
            guard !packet.isEmpty else { continue }
            if let frame = try? JSONDecoder().decode(DogfightFrame.self, from: packet), let state = frame.state {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.localDogfightManager(self, didReceive: state)
                }
            }
        }
    }

    private func postStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.localDogfightManager(self, didUpdateStatus: status)
        }
    }

    private static func localIPv4Addresses() -> [String] {
        var result: [String] = []
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return result }
        defer { freeifaddrs(interfaces) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while pointer != nil {
            guard let interface = pointer?.pointee else { break }
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            if isUp && !isLoopback, let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) {
                var addr = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                if inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                    let value = String(cString: buffer)
                    if !result.contains(value) {
                        result.append(value)
                    }
                }
            }
            pointer = interface.ifa_next
        }
        return result
    }
}

private struct DogfightFrame: Codable {
    let type: String
    let state: PeerAircraftState?
}
