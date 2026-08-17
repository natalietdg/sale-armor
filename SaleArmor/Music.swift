import AVFoundation
import SwiftUI

/// The soundtrack, and the rules it has to obey.
///
/// Sale Armor is opened for thirty seconds at a time — you arm it and you leave — so music here is
/// atmosphere rather than a soundtrack, and it has to be a guest in the phone's audio rather than
/// an occupant. Three rules follow from that:
///
/// - **`.ambient`, never `.playback`.** Ambient mixes with whatever is already playing and is
///   silenced by the ring/silent switch. A wellbeing app that stops someone's podcast to play its
///   own theme is an app they delete, and `.playback` would do exactly that.
/// - **Off by default.** Sound that starts without being asked for is the fastest way to lose
///   someone in a quiet room, and this app's whole argument is that it does not nag.
/// - **The choice sticks.** Somebody who turned it off once should never be asked again.
@MainActor
final class Music: ObservableObject {
    @Published var isOn: Bool {
        didSet {
            UserDefaults.standard.set(isOn, forKey: Self.key)
            isOn ? start() : stop()
        }
    }

    private static let key = "music.isOn"
    private var player: AVAudioPlayer?

    init() {
        isOn = UserDefaults.standard.bool(forKey: Self.key)   // false unless they asked for it
        if isOn { start() }
    }

    private func start() {
        guard let url = Bundle.main.url(forResource: "NeonRain", withExtension: "m4a") else { return }
        do {
            // Mixes with other audio, and the silent switch still wins.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default,
                                                            options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            // Under the interface rather than over it. This is a room tone, not a performance.
            player.volume = 0.35
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            // Audio failing must never take the app with it — the shield is the product.
            isOn = false
        }
    }

    private func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Pauses while the app is in the background rather than holding the session open. A blocker
    /// that keeps playing after you close it is a blocker that drains a battery.
    func setActive(_ active: Bool) {
        guard isOn else { return }
        if active { player?.play() } else { player?.pause() }
    }
}
