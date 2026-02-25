import UIKit

class HomeViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var readingView: UIView!
    @IBOutlet weak var writingView: UIView!
    @IBOutlet weak var phonicsView: UIView!
    @IBOutlet weak var ocrView: UIView!
    @IBOutlet weak var analytics: UIButton!
    @IBOutlet var continueLabel: UILabel!
    @IBOutlet var subContinueLabel: UILabel!
    @IBOutlet var teddyImageView: UIImageView!
    @IBOutlet var chevronButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        updateDashboardState()
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
    
    // MARK: - Dashboard Logic
    private func navigateToReading() {
            guard let (story, pageIndex, _) = StoryManager.shared.getLastActiveStory() else {
                performSegue(withIdentifier: "readingSegue", sender: nil)
                return
            }
            
            let sb = UIStoryboard(name: "Main", bundle: nil)
            
            guard let previewVC = sb.instantiateViewController(withIdentifier: "ReadingPreviewVC") as? ReadingPreviewViewController else { return }
            
            let pageContent = story.content[pageIndex]
            let targetVC: UIViewController
            
            if let imgName = pageContent.imageURL, !imgName.isEmpty {
                let vc = sb.instantiateViewController(withIdentifier: "ImageLabelReadingVC") as! ImageLabelReadingViewController
                vc.story = story
                vc.currentIndex = pageIndex
                vc.storyTextString = pageContent.text
                vc.imageName = imgName
                targetVC = vc
            } else {
                let vc = sb.instantiateViewController(withIdentifier: "LabelReadingVC") as! LabelReadingViewController
                vc.story = story
                vc.currentIndex = pageIndex
                vc.storyTextString = pageContent.text
                targetVC = vc
            }
            navigationController?.setViewControllers([self, previewVC, targetVC], animated: true)
        }
        
        private func navigateToWriting() {
            let manager = WritingGameplayManager.shared
            let category = manager.lastActiveCategory
            let index = manager.getHighestUnlockedIndex(category: category)
            
            let sb = UIStoryboard(name: "Main", bundle: nil)
            
            guard let previewVC = sb.instantiateViewController(withIdentifier: "WritingPreviewVC") as? WritingPreviewViewController else { return }
            
            var stack: [UIViewController] = [self, previewVC]
            
            if category != "letters" && category != "numbers" {
                if let catVC = sb.instantiateViewController(withIdentifier: "WordsCategoriesViewController") as? WordsCategoriesViewController {
                    stack.append(catVC)
                }
            }
            let targetVC: UIViewController
            
            if manager.loadTwoDrawings(index: index, category: category) != nil {
                if category == "letters" || category == "numbers" {
                    let vc = sb.instantiateViewController(withIdentifier: "SixLetterTraceVC") as! SixLetterTraceViewController
                    vc.contentType = (category == "letters") ? .letters : .numbers
                    vc.currentLetterIndex = index
                    targetVC = vc
                } else {
                    let vc = sb.instantiateViewController(withIdentifier: "SixWordTraceVC") as! SixWordTraceViewController
                    vc.currentWordIndex = index
                    vc.selectedCategory = TracingCategory(rawValue: category) ?? .threeLetter
                    targetVC = vc
                }
            }
            else if manager.loadOneDrawing(index: index, category: category) != nil {
                if category == "letters" || category == "numbers" {
                    let vc = sb.instantiateViewController(withIdentifier: "TwoLetterTraceVC") as! TwoLetterTraceViewController
                    vc.contentType = (category == "letters") ? .letters : .numbers
                    vc.currentLetterIndex = index
                    targetVC = vc
                } else {
                    let vc = sb.instantiateViewController(withIdentifier: "TwoWordTraceVC") as! TwoWordTraceViewController
                    vc.currentWordIndex = index
                    vc.selectedCategory = TracingCategory(rawValue: category) ?? .threeLetter
                    targetVC = vc
                }
            }
            else {
                if category == "letters" || category == "numbers" {
                    let vc = sb.instantiateViewController(withIdentifier: "OneLetterTraceVC") as! OneLetterTraceViewController
                    vc.contentType = (category == "letters") ? .letters : .numbers
                    vc.currentLetterIndex = index
                    targetVC = vc
                } else {
                    let vc = sb.instantiateViewController(withIdentifier: "OneWordTraceVC") as! OneWordTraceViewController
                    vc.currentWordIndex = index
                    vc.selectedCategory = TracingCategory(rawValue: category) ?? .threeLetter
                    targetVC = vc
                }
            }
            
            stack.append(targetVC)
            navigationController?.setViewControllers(stack, animated: true)
        }
        private func updateDashboardState() {
            let lastModule = UserDefaults.standard.string(forKey: "LastActiveModule") ?? "reading"
            
            if lastModule == "reading" {
                teddyImageView.image = UIImage(named: "reader_teddy")
                
                if let (title, isNew) = StoryManager.shared.getLastActiveStoryDetails() {
                    continueLabel.text = isNew ? "Want to start reading?" : "Want to continue reading?"
                    subContinueLabel.text = title
                } else {
                    continueLabel.text = "Want to start reading?"
                    subContinueLabel.text = "Select a Story"
                }
                
            } else if lastModule == "writing" {
                teddyImageView.image = UIImage(named: "writer_teddy")
                
                continueLabel.text = "Want to continue tracing?"
                subContinueLabel.text = WritingGameplayManager.shared.getLastActiveItemDescription()
            }
        }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            
            if segue.identifier == "readingSegue" {
                UserDefaults.standard.set("reading", forKey: "LastActiveModule")
            }
            else if segue.identifier == "writingSegue" {
                UserDefaults.standard.set("writing", forKey: "LastActiveModule")
            }
            
            UserDefaults.standard.synchronize()
        }
    // MARK: - Actions
    @IBAction func phonicsTapped(_ sender: UITapGestureRecognizer) {
        performSegue(withIdentifier: "spinWheelSegue", sender: nil)
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
    @IBAction func continueTapped(_ sender: UIButton) {
        let lastModule = UserDefaults.standard.string(forKey: "LastActiveModule") ?? "reading"
                
                if lastModule == "reading" {
                    navigateToReading()
                } else {
                    navigateToWriting()
                }
    }
}
