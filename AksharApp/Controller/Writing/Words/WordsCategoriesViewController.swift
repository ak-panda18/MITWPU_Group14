import UIKit
import AVFoundation
import Speech
import AVKit

class WordsCategoriesViewController: UIViewController {
    
    
    // MARK: - Outlets
    
    @IBOutlet weak var ImageView: UIImageView!
    @IBOutlet weak var titleView: UIView!
    @IBOutlet weak var backView: UIView!
    @IBOutlet weak var dialogueView: UIView!
    @IBOutlet weak var powerWords: UIImageView!
    @IBOutlet weak var letter6: UIImageView!
    @IBOutlet weak var letter5: UIImageView!
    @IBOutlet weak var letter4: UIImageView!
    @IBOutlet weak var letter3: UIImageView!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        
    }
    // MARK: - Setup
    func setupUI() {
        titleView.layer.cornerRadius = 50
        titleView.layer.borderColor = UIColor.systemYellow.cgColor
        titleView.layer.borderWidth = 3.0
        
        backView.layer.cornerRadius = 25
        backView.layer.borderColor = UIColor.systemYellow.cgColor
        backView.layer.borderWidth = 3.0
//
//            textView.layer.cornerRadius = 25
//            textView.layer.borderColor = UIColor.systemYellow.cgColor
//            textView.layer.borderWidth = 1.0
        
        dialogueView.layer.cornerRadius = 12
        dialogueView.layer.shadowColor = UIColor.systemYellow.cgColor
        dialogueView.layer.shadowOpacity = 0.3
        dialogueView.layer.shadowOffset = CGSize(width: 0, height: 5)
        dialogueView.layer.shadowRadius = 10
        dialogueView.layer.masksToBounds = false
        
        let views = [letter3, letter4, letter5, letter6, powerWords]
        views.forEach { $0?.layer.cornerRadius = 20 }
    }
    private func setupGestures() {
        func addTap(to view: UIView, action: Selector) {
            let tap = UITapGestureRecognizer(target: self, action: action)
            view.addGestureRecognizer(tap)
            view.isUserInteractionEnabled = true
        }
        
        addTap(to: letter3, action: #selector(didTap3))
        addTap(to: letter4, action: #selector(didTap4))
        addTap(to: letter5, action: #selector(didTap5))
        addTap(to: letter6, action: #selector(didTap6))
        addTap(to: powerWords, action: #selector(didTapPower))
    }
    
    // MARK: - Actions
    @objc func didTap3() { openCategory(.threeLetter) }
    @objc func didTap4() { openCategory(.fourLetter) }
    @objc func didTap5() { openCategory(.fiveLetter) }
    @objc func didTap6() { openCategory(.sixLetter) }
    @objc func didTapPower() { openCategory(.power) }
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    
    // MARK: - Navigation Logic
    private func openCategory(_ category: TracingCategory) {
        TracingProgressManager.shared.lastActiveWordCategory =
                WordCategory(rawValue: category.rawValue) ?? .three
        let index = TracingProgressManager.shared.highestUnlockedWordIndex(for: category.rawValue)
        let manager = TracingProgressManager.shared
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController

        if manager.loadSixWordDrawings(index: index, category: category.rawValue) != nil {
            let c = storyboard.instantiateViewController(withIdentifier: "SixWordTraceVC") as! SixWordTraceViewController
            c.currentWordIndex = index
            c.selectedCategory = category
            vc = c
        } else if manager.loadTwoWordDrawings(index: index, category: category.rawValue) != nil {
            let c = storyboard.instantiateViewController(withIdentifier: "SixWordTraceVC") as! SixWordTraceViewController
            c.currentWordIndex = index
            c.selectedCategory = category
            vc = c
        } else if manager.loadOneWordDrawing(index: index, category: category.rawValue) != nil {
            let c = storyboard.instantiateViewController(withIdentifier: "TwoWordTraceVC") as! TwoWordTraceViewController
            c.currentWordIndex = index
            c.selectedCategory = category
            vc = c
        } else {
            let c = storyboard.instantiateViewController(withIdentifier: "OneWordTraceVC") as! OneWordTraceViewController
            c.currentWordIndex = index
            c.selectedCategory = category
            vc = c
        }

        navigationController?.pushViewController(vc, animated: true)
    }

}
