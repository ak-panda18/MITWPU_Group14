import UIKit
import AVKit

class TestViewController: UIViewController {
    @IBOutlet weak var videoContainerView: UIView!
    
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        playVideoInView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoContainerView.bounds
        
    }

    func playVideoInView() {
        guard let path = Bundle.main.path(forResource: "myVideo", ofType: "mp4") else { return }
        
        player = AVPlayer(url: URL(fileURLWithPath: path))
        
        playerLayer = AVPlayerLayer(player: player)
        
        playerLayer?.frame = videoContainerView.bounds
        
        playerLayer?.videoGravity = .resizeAspectFill
        
        videoContainerView.layer.addSublayer(playerLayer!)
        
        player?.play()
        
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
