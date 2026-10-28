import Foundation
import CoreMotion
import UIKit

/// Streams motion + buttons to Waggle Games over UDP. See docs/PROTOCOL.md.
@MainActor
final class RemoteController: ObservableObject {
    enum Status: Equatable {
        case idle, searching, connected(host: String, slot: Int), rejected(String)
    }

    static let port: UInt16 = 47777

    @Published var status: Status = .idle
    @Published var hostIP: String = UserDefaults.standard.string(forKey: "hostIP") ?? ""
    @Published var code: String = UserDefaults.standard.string(forKey: "code") ?? ""
    @Published var aButton = false { didSet { sendNow() } }
    @Published var bButton = false { didSet { sendNow() } }
    @Published var homeButton = false { didSet { sendNow() } }
    @Published var pauseButton = false { didSet { sendNow() } }
    @Published var swingFlash = false

    private let motion = CMMotionManager()
    private var socket = UDPSocket()
    private var timer: Timer?
    private let id = UserDefaults.standard.string(forKey: "deviceID") ?? {
        let v = UUID().uuidString
        UserDefaults.standard.set(v, forKey: "deviceID")
        return v
    }()
    private var targetIP: String?
    private var lastHello = Date.distantPast
    private var lastRX = Date.distantPast
    private let impact = UIImpactFeedbackGenerator(style: .heavy)

    var motionAvailable: Bool { motion.isDeviceMotionAvailable }

    func connect() {
        UserDefaults.standard.set(hostIP, forKey: "hostIP")
        UserDefaults.standard.set(code, forKey: "code")
        targetIP = hostIP.isEmpty ? nil : hostIP
        status = .searching
        UIApplication.shared.isIdleTimerDisabled = true
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 60.0
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func disconnect() {
        timer?.invalidate()
        motion.stopDeviceMotionUpdates()
        UIApplication.shared.isIdleTimerDisabled = false
        status = .idle
    }

    private func tick() {
        drainReplies()
        let now = Date()
        if case .connected = status, now.timeIntervalSince(lastRX) > 3 {
            status = .searching
        }
        if case .connected = status {
            sendState()
        } else if now.timeIntervalSince(lastHello) > 0.5 {
            lastHello = now
            sendHello()
        }
    }

    private func sendHello() {
        let hello: [String: Any] = ["t": "hello", "id": id, "code": code, "name": UIDevice.current.name]
        let data = (try? JSONSerialization.data(withJSONObject: hello)) ?? Data()
        if let ip = targetIP {
            socket?.send(data, to: ip, port: Self.port)
        } else {
            socket?.send(Data("WAGGLE?".utf8), to: "255.255.255.255", port: Self.port)
        }
    }

    private func drainReplies() {
        while let (data, ip) = socket?.receive() {
            lastRX = Date()
            if String(data: data, encoding: .utf8) == nil { continue }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let t = obj["t"] as? String else { continue }
            switch t {
            case "host":
                targetIP = ip
                sendHello()
            case "ok":
                status = .connected(host: obj["host"] as? String ?? ip, slot: (obj["slot"] as? Int ?? 0) + 1)
                targetIP = ip
            case "no":
                status = .rejected((obj["why"] as? String) == "code" ? "Wrong pairing code" : "Game is full")
            case "r":
                let s = (obj["s"] as? Double) ?? 0.6
                impact.impactOccurred(intensity: CGFloat(min(max(s, 0.1), 1.0)))
            default: break
            }
        }
    }

    private func buttonMask() -> Int {
        (aButton ? 1 : 0) | (bButton ? 2 : 0) | (homeButton ? 4 : 0) | (pauseButton ? 8 : 0)
    }

    private func sendNow() {
        if case .connected = status { sendState() }
    }

    private func sendState() {
        guard let ip = targetIP else { return }
        var msg: [String: Any] = ["t": "s", "id": id, "b": buttonMask()]
        if let dm = motion.deviceMotion {
            let r = dm.attitude.rotationMatrix
            msg["x"] = [r.m11, r.m12, r.m13]
            msg["y"] = [r.m21, r.m22, r.m23]
            msg["z"] = [r.m31, r.m32, r.m33]
            msg["a"] = [dm.userAcceleration.x, dm.userAcceleration.y, dm.userAcceleration.z]
            msg["g"] = [dm.rotationRate.x, dm.rotationRate.y, dm.rotationRate.z]
            let mag = (dm.userAcceleration.x * dm.userAcceleration.x + dm.userAcceleration.y * dm.userAcceleration.y + dm.userAcceleration.z * dm.userAcceleration.z).squareRoot()
            if mag > 1.25 && !swingFlash {
                swingFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.swingFlash = false }
            }
        } else {
            // No sensors (e.g. Simulator): identity pose, so buttons still work.
            msg["x"] = [1, 0, 0]; msg["y"] = [0, 1, 0]; msg["z"] = [0, 0, 1]
            msg["a"] = [0, 0, 0]; msg["g"] = [0, 0, 0]
        }
        if let data = try? JSONSerialization.data(withJSONObject: msg) {
            socket?.send(data, to: ip, port: Self.port)
        }
    }
}
