import SwiftUI

struct ContentView: View {
    @EnvironmentObject var remote: RemoteController

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.53, green: 0.83, blue: 1.0), .white], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            switch remote.status {
            case .connected:
                ControllerView()
            default:
                PairView()
            }
        }
    }
}

private let navy = Color(red: 0.12, green: 0.23, blue: 0.43)

struct PairView: View {
    @EnvironmentObject var remote: RemoteController

    var body: some View {
        VStack(spacing: 18) {
            Text("🥚").font(.system(size: 72))
            Text("Waggle Remote").font(.system(.largeTitle, design: .rounded).bold()).foregroundColor(navy)
            Text("Open Waggle Games on your computer, then enter the pairing code shown on the menu.")
                .multilineTextAlignment(.center).foregroundColor(navy.opacity(0.8))
            TextField("Pairing code", text: $remote.code)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.system(.title2, design: .monospaced))
            TextField("Host IP (optional, auto-discovers)", text: $remote.hostIP)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
            statusLine
            Button {
                remote.status == .idle || isRejected ? remote.connect() : remote.disconnect()
            } label: {
                Text(remote.status == .searching ? "Cancel" : "Connect")
                    .font(.system(.title3, design: .rounded).bold())
                    .frame(maxWidth: .infinity).padding()
                    .background(navy).foregroundColor(.white).clipShape(Capsule())
            }
            if !remote.motionAvailable {
                Text("No motion sensors found (Simulator?). Buttons will still work.")
                    .font(.footnote).foregroundColor(.orange)
            }
        }
        .padding(28)
    }

    private var isRejected: Bool { if case .rejected = remote.status { return true } else { return false } }

    @ViewBuilder private var statusLine: some View {
        switch remote.status {
        case .searching: Label("Searching for the game…", systemImage: "wifi").foregroundColor(navy)
        case .rejected(let why): Label(why, systemImage: "exclamationmark.triangle").foregroundColor(.red)
        default: EmptyView()
        }
    }
}

struct ControllerView: View {
    @EnvironmentObject var remote: RemoteController

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                if case .connected(let host, let slot) = remote.status {
                    Label("Player \(slot) · \(host)", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                }
                Spacer()
                Button("Disconnect") { remote.disconnect() }.foregroundColor(navy)
            }
            Spacer()
            Text(remote.swingFlash ? "SWING!" : "Hold like a remote, screen up, top toward the screen")
                .font(.system(remote.swingFlash ? .largeTitle : .callout, design: .rounded).bold())
                .multilineTextAlignment(.center)
                .foregroundColor(remote.swingFlash ? .orange : navy.opacity(0.7))
            Spacer()
            HStack(spacing: 24) {
                HoldButton(title: "B", color: .red, isDown: $remote.bButton)
                HoldButton(title: "A", color: .blue, isDown: $remote.aButton)
            }
            HStack(spacing: 24) {
                HoldButton(title: "Recenter", color: .gray, isDown: $remote.homeButton, small: true)
                HoldButton(title: "Pause", color: .gray, isDown: $remote.pauseButton, small: true)
            }
        }
        .padding(24)
    }
}

/// A button that reports press and release (games need both: bow draw, guard).
struct HoldButton: View {
    let title: String
    let color: Color
    @Binding var isDown: Bool
    var small = false

    var body: some View {
        Text(title)
            .font(.system(small ? .headline : .largeTitle, design: .rounded).bold())
            .frame(width: small ? 130 : 140, height: small ? 56 : 140)
            .background(color.opacity(isDown ? 1.0 : 0.75))
            .foregroundColor(.white)
            .clipShape(small ? AnyShape(Capsule()) : AnyShape(Circle()))
            .scaleEffect(isDown ? 0.94 : 1.0)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isDown { isDown = true } }
                .onEnded { _ in isDown = false })
    }
}
