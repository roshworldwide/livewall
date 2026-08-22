//
//  WallpaperContentView.swift
//  LiveWall
//
//  Layer-backed host for an AVPlayerLayer. Kept deliberately dumb: the engine
//  owns the player, this view only owns geometry and scale.
//

import AppKit
import AVFoundation

final class WallpaperContentView: NSView {

    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Layer-hosting view: assign the layer *before* wantsLayer, otherwise
        // AppKit creates its own backing layer and replaces ours.
        let host = CALayer()
        host.backgroundColor = NSColor.black.cgColor
        host.masksToBounds = true
        layer = host
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay

        playerLayer.frame = bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = NSColor.black.cgColor
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        host.addSublayer(playerLayer)
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        // No implicit animation — the wallpaper should never "slide" into place.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2.0
        layer?.contentsScale = scale
        playerLayer.contentsScale = scale
    }

    func apply(fitMode: FitMode) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.videoGravity = fitMode.videoGravity
        CATransaction.commit()
    }

    /// Soft fade used when swapping wallpapers so the change doesn't snap.
    func crossfade(duration: CFTimeInterval = 0.35) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.0
        fade.toValue = 1.0
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        playerLayer.add(fade, forKey: "wallpaperFade")
    }
}
