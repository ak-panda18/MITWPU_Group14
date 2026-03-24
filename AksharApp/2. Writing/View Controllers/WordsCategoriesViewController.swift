import UIKit

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

    // MARK: - Injected
    var writingGameplayManager: WritingGameplayManager!

    // MARK: - Lifecycle
    private func verifyDependencies() {
        assert(writingGameplayManager != nil, "writingGameplayManager was not injected into \(type(of: self))")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyDependencies()
        setupUI()
        setupGestures()
    }

    // MARK: - Setup
    func setupUI() {
        titleView.layer.cornerRadius = 50
        titleView.layer.borderColor  = UIColor.systemYellow.cgColor
        titleView.layer.borderWidth  = 3.0

        backView.layer.cornerRadius = 25
        backView.layer.borderColor  = UIColor.systemYellow.cgColor
        backView.layer.borderWidth  = 3.0

        dialogueView.layer.cornerRadius  = 12
        dialogueView.layer.shadowColor   = UIColor.systemYellow.cgColor
        dialogueView.layer.shadowOpacity = 0.3
        dialogueView.layer.shadowOffset  = CGSize(width: 0, height: 5)
        dialogueView.layer.shadowRadius  = 10
        dialogueView.layer.masksToBounds = false

        [letter3, letter4, letter5, letter6, powerWords].forEach { $0?.layer.cornerRadius = 20 }
    }

    private func setupGestures() {
        func addTap(to view: UIView, action: Selector) {
            let tap = UITapGestureRecognizer(target: self, action: action)
            view.addGestureRecognizer(tap)
            view.isUserInteractionEnabled = true
        }
        addTap(to: letter3,    action: #selector(didTap3))
        addTap(to: letter4,    action: #selector(didTap4))
        addTap(to: letter5,    action: #selector(didTap5))
        addTap(to: letter6,    action: #selector(didTap6))
        addTap(to: powerWords, action: #selector(didTapPower))
    }

    // MARK: - Actions
    @objc func didTap3()     { openCategory(.threeLetter) }
    @objc func didTap4()     { openCategory(.fourLetter) }
    @objc func didTap5()     { openCategory(.fiveLetter) }
    @objc func didTap6()     { openCategory(.sixLetter) }
    @objc func didTapPower() { openCategory(.power) }

    @IBAction func backButtonTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Navigation Logic
    private func openCategory(_ category: TracingCategory) {
        writingGameplayManager.lastActiveCategory = category.rawValue

        let index      = writingGameplayManager.getHighestUnlockedIndex(category: category.rawValue)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: UIViewController

        if writingGameplayManager.loadTwoDrawings(index: index, category: category.rawValue) != nil {
            guard let c = storyboard.instantiateViewController(withIdentifier: "SixWordTraceVC") as? SixWordTraceViewController else { return }
            c.currentWordIndex       = index
            c.selectedCategory       = category
            c.writingGameplayManager = writingGameplayManager
            vc = c
        } else if writingGameplayManager.loadOneDrawing(index: index, category: category.rawValue) != nil {
            guard let c = storyboard.instantiateViewController(withIdentifier: "TwoWordTraceVC") as? TwoWordTraceViewController else { return }
            c.currentWordIndex       = index
            c.selectedCategory       = category
            c.writingGameplayManager = writingGameplayManager
            vc = c
        } else {
            guard let c = storyboard.instantiateViewController(withIdentifier: "OneWordTraceVC") as? OneWordTraceViewController else { return }
            c.currentWordIndex       = index
            c.selectedCategory       = category
            c.writingGameplayManager = writingGameplayManager
            vc = c
        }

        navigationController?.pushViewController(vc, animated: true)
    }
}
