import UIKit

class HomeViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var readingView: UIView!
    @IBOutlet weak var writingView: UIView!
    @IBOutlet weak var phonicsView: UIView!
    @IBOutlet weak var ocrView: UIView!
    @IBOutlet weak var analytics: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        // No need to setup cycle here anymore, the Manager handles it automatically
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        let menuViews = [readingView, writingView, phonicsView, ocrView]
        let brownBorderColor = UIColor.systemBrown.cgColor
        
        menuViews.forEach { view in
            view?.layer.cornerRadius = 25
            view?.layer.borderColor = brownBorderColor
            view?.layer.borderWidth = 2.0
        }
    }

    // MARK: - Navigation Logic
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "phonicsSegue",
           let coverVC = segue.destination as? PhonicsCoverViewController {
            
            // 1. Get the correct exercise (Sequential First -> Then Random)
            coverVC.chosenExercise = PhonicsFlowManager.shared.getCurrentExercise()
            
            // 2. Advance the pointer for next time
            PhonicsFlowManager.shared.advance()
        }
    }
    // MARK: - Actions
    @IBAction func phonicsTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "phonicsSegue", sender: nil)
    }
    
    @IBAction func readingTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "readingSegue", sender: nil)
    }

    @IBAction func writingTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "writingSegue", sender: nil)
    }
    
    @IBAction func ocrTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "ocrSegue", sender: nil)
    }
}
