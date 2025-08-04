//
//  SquarePlayerContainer.swift
//  Socra
//
//  A reusable AVPlayerLayer wrapper that always crops to a 1 × 1 square
//  and fills it with .resizeAspectFill (no black bars).
//

import SwiftUI
import AVKit

struct SquarePlayerContainer: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> UIView { PlayerView(player) }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? PlayerView)?.playerLayer.player = player
    }

    // MARK: – Private UIView subclass
    private final class PlayerView: UIView {
        init(_ p: AVPlayer?) {
            super.init(frame: .zero)
            playerLayer.videoGravity = .resizeAspectFill   // key line
            playerLayer.player       = p
            backgroundColor          = .black              // failsafe
        }
        required init?(coder: NSCoder) { fatalError() }

        // Force the layer into a centred square every layout pass
        override func layoutSubviews() {
            super.layoutSubviews()
            let side = min(bounds.width, bounds.height)
            playerLayer.frame = CGRect(
                x: (bounds.width  - side) / 2,
                y: (bounds.height - side) / 2,
                width:  side,
                height: side
            )
        }

        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
