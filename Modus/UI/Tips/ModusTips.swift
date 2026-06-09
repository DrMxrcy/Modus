import SwiftUI
import TipKit

// MARK: - Radio Queue Tip
/// Appears when the "Next Up" queue first populates on RadioView.
struct RadioQueueTip: Tip {
    var title: Text {
        Text("See What's Next")
    }
    var message: Text? {
        Text("Tap the Next Up button to see upcoming tracks in your station.")
    }
    var image: Image? {
        Image(systemName: "list.bullet")
    }
}

// MARK: - Hard Skip Tip
/// Appears when the user first taps the hard-skip (thumbs down) button.
struct HardSkipTip: Tip {
    var title: Text {
        Text("Hard Skip")
    }
    var message: Text? {
        Text("Hard skip tells us you didn't vibe with this track, so we'll steer away from similar ones.")
    }
    var image: Image? {
        Image(systemName: "hand.thumbsdown")
    }
}

// MARK: - Search Start Tip
/// Appears on first visit to SearchView.
struct SearchStartTip: Tip {
    var title: Text {
        Text("Start a Station")
    }
    var message: Text? {
        Text("Tap any track to start a behavioral radio station built from its energy, mood, and rhythm.")
    }
    var image: Image? {
        Image(systemName: "play.radiowaves.left.and.right")
    }
}

// MARK: - Surprise Mode Tip
/// Appears on first StationOptionsSheet presentation.
struct SurpriseModeTip: Tip {
    var title: Text {
        Text("Surprise Me")
    }
    var message: Text? {
        Text("Surprise Me mixes in tracks outside your usual taste for a more adventurous station.")
    }
    var image: Image? {
        Image(systemName: "shuffle")
    }
}