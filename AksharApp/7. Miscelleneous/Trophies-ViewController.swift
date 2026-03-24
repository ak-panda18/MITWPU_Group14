import UIKit

class Trophies_ViewController: UIViewController {

    @IBOutlet weak var storyExplorerCurrentImage: UIImageView!
    @IBOutlet weak var rhymeRookieCurrentImage: UIImageView!
    @IBOutlet weak var letterTracerCurrentImage: UIImageView!
    @IBOutlet weak var checkpointChampCurrentImage: UIImageView!
    
    @IBOutlet weak var storyProgressBar: UIProgressView!
    @IBOutlet weak var rhymingProgressBar: UIProgressView!
    @IBOutlet weak var checkpointProgressBar: UIProgressView!
    @IBOutlet weak var tracerProgressBar: UIProgressView!
    
    @IBOutlet weak var letterTracerCard: UIView!
    @IBOutlet weak var checkpointChampCard: UIView!
    @IBOutlet weak var storyExplorerCard: UIView!
    @IBOutlet weak var rhymingRookieCard: UIView!
    
    @IBOutlet weak var tracerCurrentNumber: UILabel!
    @IBOutlet weak var storyCurrentNumber: UILabel!
    @IBOutlet weak var rhymingCurrentNumber: UILabel!
    @IBOutlet weak var checkpointCurrentNumber: UILabel!
    
    @IBOutlet weak var tracerGoalNumber: UILabel!
    @IBOutlet weak var storyGoalNumber: UILabel!
    @IBOutlet weak var rhymingGoalNumber: UILabel!
    @IBOutlet weak var checkpointGoalNumber: UILabel!
    
    @IBOutlet weak var storyExplorerNextImage: UIImageView!
    @IBOutlet weak var rhymeRookieNextImage: UIImageView!
    @IBOutlet weak var letterTracerNextImage: UIImageView!
    @IBOutlet weak var checkpointChampNextImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let strokeColor = UIColor(red: 231/255, green: 199/255, blue: 110/255, alpha: 1.0)
        
        styleCard(letterTracerCard, strokeColor: strokeColor)
        styleCard(checkpointChampCard, strokeColor: strokeColor)
        styleCard(rhymingRookieCard, strokeColor: strokeColor)
        styleCard(storyExplorerCard, strokeColor: strokeColor)
    }
    
    func styleCard(_ card: UIView, strokeColor: UIColor) {
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.1
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowRadius = 4
        card.layer.masksToBounds = false
        
        card.layer.borderColor = strokeColor.cgColor
        card.layer.borderWidth = 4.0
        
        card.layer.shouldRasterize = true
        card.layer.rasterizationScale = traitCollection.displayScale
    }
}
