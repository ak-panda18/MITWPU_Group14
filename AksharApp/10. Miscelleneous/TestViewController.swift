//
//  TestViewController.swift
//  AksharApp
//
//  Created by SDC-USER on 06/01/26.
//

import UIKit
import AVKit

class TestViewController: UIViewController {

    @IBOutlet weak var videoContainerView: UIView! // Connect this to your UIView
    
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        playVideoInView()
    }
    
    // Important: Update the frame if the screen rotates or layout changes
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoContainerView.bounds
    }

    func playVideoInView() {
        guard let path = Bundle.main.path(forResource: "myVideo", ofType: "mp4") else { return }
        
        // 1. Setup the Player
        player = AVPlayer(url: URL(fileURLWithPath: path))
        
        // 2. Setup the Layer (The visual part)
        playerLayer = AVPlayerLayer(player: player)
        
        // 3. Set Size and Positioning
        playerLayer?.frame = videoContainerView.bounds
        
        // 4. MIMIC IMAGE VIEW SETTINGS:
        // Use .resizeAspectFill for "Aspect Fill" behavior (zooms in to fill)
        // Use .resizeAspect for "Aspect Fit" behavior (shows black bars)
        playerLayer?.videoGravity = .resizeAspectFill
        
        // 5. Add it to your container view
        videoContainerView.layer.addSublayer(playerLayer!)
        
        // 6. Play
        player?.play()
        
        // Optional: Loop it (Simple method)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(loopVideo),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem)
    }
    
    @objc func loopVideo() {
        player?.seek(to: .zero)
        player?.play()
    }
}
