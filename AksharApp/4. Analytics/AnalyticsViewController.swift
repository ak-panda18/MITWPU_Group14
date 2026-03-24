import UIKit
import FirebaseAuth

class AnalyticsViewController: UIViewController,
                                UICollectionViewDelegate,
                                UICollectionViewDataSource,
                               UICollectionViewDelegateFlowLayout {

    var selectedStats: DailyStats?
    private var selectedGraphTitle: String?
    private var selectedGraphData: [AccuracyPoint] = []

    // MARK: - IBOutlets
    @IBOutlet weak var weeklyMonthlySegmentedControl: UISegmentedControl!
    @IBOutlet weak var collectionView: UICollectionView!

    // MARK: - Injected
    var analyticsStore: AnalyticsStore!
    var checkpointHistoryManager: CheckpointHistoryManager!

    private var analyticsData: AnalyticsData = .empty
    private var lastUpdatedWidth: CGFloat = 0

    // MARK: - Properties
    private var isWeeklyView: Bool = true
    private var recentDailyStats: [DailyStats] = []

    // MARK: - Lifecycle
    private func verifyDependencies() {
        assert(analyticsStore != nil, "analyticsStore was not injected into \(type(of: self))")
        assert(checkpointHistoryManager != nil, "checkpointHistoryManager was not injected into \(type(of: self))")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyDependencies()
        setupUI()
        setupCollectionView()
        registerNibs()
    }

    private func registerNibs() {
        let writingNib = UINib(nibName: "WritingAccuracyViewCell", bundle: nil)
        collectionView.register(writingNib, forCellWithReuseIdentifier: "WritingAccuracyViewCell")

        let readingNib = UINib(nibName: "ReadingStatisticsViewCell", bundle: nil)
        collectionView.register(readingNib, forCellWithReuseIdentifier: "ReadingStatisticsViewCell")

        let phonicsNib = UINib(nibName: "PhonicsStatisticsViewCell", bundle: nil)
        collectionView.register(phonicsNib, forCellWithReuseIdentifier: "PhonicsStatisticsViewCell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAnalyticsData()
        refreshDataBasedOnSegment()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let currentWidth = collectionView.bounds.width
        if currentWidth != lastUpdatedWidth && currentWidth > 0 {
            lastUpdatedWidth = currentWidth
            DispatchQueue.main.async {
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.layoutIfNeeded()
            }
        }
    }

    private func loadAnalyticsData() {
        analyticsData = AnalyticsData(
            readingSessions: analyticsStore.fetchReadingSessions(),
            readingCheckpointResults: analyticsStore.fetchCheckpointResults(),
            phonicsSessions: analyticsStore.fetchPhonicsSessions(),
            writingSessions: analyticsStore.fetchWritingSessions()
        )
    }

    private func getCutoffDate() -> Date {
        let now = Date()
        let calendar = Calendar.current
        let days = isWeeklyView ? -7 : -30
        return calendar.date(byAdding: .day, value: days, to: now)!
    }

    private func filteredPhonicsSessions() -> [PhonicsSessionData] {
        return analyticsStore.fetchPhonicsSessions(from: getCutoffDate())
    }

    private func filteredWritingSessions() -> [WritingSessionData] {
        return analyticsStore.fetchWritingSessions(from: getCutoffDate())
    }

    private func previousWritingSessions() -> [WritingSessionData] {
        let now = Date()
        let calendar = Calendar.current

        let (start, end): (Date, Date) = {
            if isWeeklyView {
                let end   = calendar.date(byAdding: .day, value: -7, to: now)!
                let start = calendar.date(byAdding: .day, value: -14, to: now)!
                return (start, end)
            } else {
                let end   = calendar.date(byAdding: .day, value: -30, to: now)!
                let start = calendar.date(byAdding: .day, value: -60, to: now)!
                return (start, end)
            }
        }()

        return analyticsData.writingSessions.filter {
            $0.date >= start && $0.date < end
        }
    }

    private func filteredReadingSessions() -> [ReadingSessionData] {
        return analyticsStore.fetchReadingSessions(from: getCutoffDate())
    }

    private func totalReadingMinutes() -> Int? {
        let sessions = filteredReadingSessions()
        guard !sessions.isEmpty else { return nil }

        let totalSeconds = sessions.reduce(0.0) { sum, session in
            guard let end = session.endTime else { return sum }
            return sum + end.timeIntervalSince(session.startTime)
        }

        return Int(totalSeconds / 60)
    }

    private func formattedReadingTime() -> NSAttributedString {
        guard let minutesVal = totalReadingMinutes() else {
            return NSAttributedString(string: "--")
        }

        let totalHours   = Double(minutesVal) / 60.0
        let flooredHours = Int(floor(totalHours))
        let numberText   = flooredHours == 0 ? "\(minutesVal)" : "\(flooredHours)"
        let unitText     = flooredHours == 0 ? "\nminutes"     : "\nhours"

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 50),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let unitAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .regular),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: paragraphStyle
        ]

        let finalString = NSMutableAttributedString(string: numberText, attributes: numberAttributes)
        finalString.append(NSAttributedString(string: unitText, attributes: unitAttributes))
        return finalString
    }

    private func currentReadingLevel() -> (String, String) {
        let sessions = analyticsData.readingSessions
        guard let maxLevel = sessions.map({ $0.levelUnlocked }).max() else {
            return ("--", "--")
        }
        switch maxLevel {
        case 1: return ("Level 1", "(Arial + 3 spaces)")
        case 2: return ("Level 2", "(Trebuchet MS + 2 spaces)")
        case 3: return ("Level 3", "(Times New Roman + 1 space)")
        default: return ("--", "--")
        }
    }

    private func showGraph(title: String, data: [AccuracyPoint]) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        guard let graphVC = storyboard.instantiateViewController(withIdentifier: "GraphPopupViewController") as? GraphPopupViewController else {
            return
        }
        graphVC.graphTitle = title
        graphVC.graphData  = data
        graphVC.modalPresentationStyle = .overFullScreen
        present(graphVC, animated: true)
    }

    // MARK: - Setup
    private func setupUI() {
        weeklyMonthlySegmentedControl.selectedSegmentIndex = 0
        weeklyMonthlySegmentedControl.addTarget(
            self,
            action: #selector(segmentChanged),
            for: .valueChanged
        )
    }

    private func setupCollectionView() {
        collectionView.delegate   = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
        }
    }

    // MARK: - Actions
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        isWeeklyView = sender.selectedSegmentIndex == 0
        refreshDataBasedOnSegment()
    }

    private func refreshDataBasedOnSegment() {
        let attempts = checkpointHistoryManager.getAllAttempts()

        if isWeeklyView {
            recentDailyStats = AnalyticsAggregator.weeklyCheckpointStats(attempts: attempts)
        } else {
            recentDailyStats = AnalyticsAggregator.monthlyCheckpointStats(attempts: attempts)
        }

        collectionView.reloadData()
    }

    @IBAction func backButtonTapped(_ sender: UIButton) {
        if let navigationController = navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - Color Helper
    private func colorForScore(_ score: Int?) -> UIColor {
        guard let s = score else { return .lightGray }
        switch s {
        case 0..<40: return .systemRed
        case 40..<80: return .systemOrange
        default: return .systemGreen
        }
    }

    // MARK: - Sign Out
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Navigation
    func showCheckpointDetails(for stats: DailyStats) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        guard let popupVC = storyboard.instantiateViewController(withIdentifier: "CheckpointDetailsVC") as? CheckpointDetailsViewController else {
            return
        }
        popupVC.checkpointHistoryManager = self.checkpointHistoryManager
        popupVC.stats = stats
        if let sheet = popupVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(popupVC, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowGraphPopup",
           let graphVC = segue.destination as? GraphPopupViewController {
            graphVC.graphTitle = selectedGraphTitle ?? ""
            graphVC.graphData  = selectedGraphData
            graphVC.modalPresentationStyle = .overFullScreen
        }
        if segue.identifier == "ShowCheckpointDetails",
           let popupVC = segue.destination as? CheckpointDetailsViewController {
            popupVC.checkpointHistoryManager = checkpointHistoryManager
            popupVC.stats = selectedStats
            if let sheet = popupVC.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }
    }
}

// MARK: - UICollectionViewDataSource
extension AnalyticsViewController {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 6 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        switch indexPath.item {

        case 0:
            return collectionView.dequeueReusableCell(withReuseIdentifier: "WritingAccuracyTitleCell", for: indexPath)

        case 1:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "WritingAccuracyViewCell",
                for: indexPath
            ) as? WritingAccuracyViewCell else { return UICollectionViewCell() }

            let now = Date()
            let calendar = Calendar.current

            let currentStartDate = isWeeklyView
                ? calendar.date(byAdding: .day, value: -7, to: now)!
                : calendar.date(byAdding: .day, value: -30, to: now)!

            let previousStartDate = isWeeklyView
                ? calendar.date(byAdding: .day, value: -14, to: now)!
                : calendar.date(byAdding: .day, value: -60, to: now)!

            let currentLetters = AnalyticsAggregator.periodAverage(
                allSessions: analyticsData.writingSessions,
                keyPath: \.lettersAccuracy,
                startDate: currentStartDate, endDate: now)
            let previousLetters = AnalyticsAggregator.periodAverage(
                allSessions: analyticsData.writingSessions,
                keyPath: \.lettersAccuracy,
                startDate: previousStartDate, endDate: currentStartDate)

            let currentWords = AnalyticsAggregator.periodAverage(
                allSessions: analyticsData.writingSessions,
                keyPath: \.wordsAccuracy,
                startDate: currentStartDate, endDate: now)
            let previousWords = AnalyticsAggregator.periodAverage(
                allSessions: analyticsData.writingSessions,
                keyPath: \.wordsAccuracy,
                startDate: previousStartDate, endDate: currentStartDate)

            let currentNumbers = AnalyticsAggregator.periodAverage(
                allSessions: analyticsData.writingSessions,
                keyPath: \.numbersAccuracy,
                startDate: currentStartDate, endDate: now)
            let previousNumbers = AnalyticsAggregator.periodAverage(
                allSessions: analyticsData.writingSessions,
                keyPath: \.numbersAccuracy,
                startDate: previousStartDate, endDate: currentStartDate)

            let delta: (Int?, Int?) -> (String, UIColor) = { curr, prev in
                guard let c = curr else { return ("--", .gray) }
                let p    = prev ?? 0
                let diff = c - p
                let sym  = diff >= 0 ? "↑" : "↓"
                return ("\(sym) \(abs(diff))%", diff >= 0 ? .systemGreen : .systemRed)
            }

            let percent: (Int?) -> String = { $0 != nil ? "\($0!)%" : "--" }
            let comparisonText = isWeeklyView ? "\nvs last week" : "\nvs last month"

            let lDelta = delta(currentLetters, previousLetters)
            let wDelta = delta(currentWords,   previousWords)
            let nDelta = delta(currentNumbers, previousNumbers)

            cell.configure(
                letters: percent(currentLetters), lettersDelta: lDelta.0,
                lettersColor: lDelta.1, lettersComparisonText: comparisonText,
                words: percent(currentWords),     wordsDelta: wDelta.0,
                wordsColor: wDelta.1, wordsComparisonText: comparisonText,
                numbers: percent(currentNumbers), numbersDelta: nDelta.0,
                numbersColor: nDelta.1, numbersComparisonText: comparisonText
            )
            cell.setColors(
                letters: colorForScore(currentLetters),
                words:   colorForScore(currentWords),
                numbers: colorForScore(currentNumbers)
            )

            cell.onLettersTapped = { [weak self] in
                guard let self else { return }
                let data = AnalyticsAggregator.writingGraphData(
                    allSessions: self.analyticsData.writingSessions,
                    keyPath: \.lettersAccuracy,
                    isWeekly: self.isWeeklyView)
                self.showGraph(title: "Letters Accuracy", data: data)
            }
            cell.onWordsTapped = { [weak self] in
                guard let self else { return }
                let data = AnalyticsAggregator.writingGraphData(
                    allSessions: self.analyticsData.writingSessions,
                    keyPath: \.wordsAccuracy,
                    isWeekly: self.isWeeklyView)
                self.showGraph(title: "Words Accuracy", data: data)
            }
            cell.onNumbersTapped = { [weak self] in
                guard let self else { return }
                let data = AnalyticsAggregator.writingGraphData(
                    allSessions: self.analyticsData.writingSessions,
                    keyPath: \.numbersAccuracy,
                    isWeekly: self.isWeeklyView)
                self.showGraph(title: "Numbers Accuracy", data: data)
            }
            return cell

        case 2:
            return collectionView.dequeueReusableCell(withReuseIdentifier: "ReadingStatisticsTitleCell", for: indexPath)

        case 3:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ReadingStatisticsViewCell", for: indexPath) as? ReadingStatisticsViewCell else { return UICollectionViewCell() }

            cell.updateViewMode(isWeekly: self.isWeeklyView)
            let readingTime = formattedReadingTime()
            let (level, description) = currentReadingLevel()

            cell.configure(
                readingTime: readingTime,
                level: level,
                levelDescription: description,
                stats: recentDailyStats
            )
            cell.onCheckpointSelected = { [weak self] selectedStat in
                self?.showCheckpointDetails(for: selectedStat)
            }
            return cell

        case 4:
            return collectionView.dequeueReusableCell(withReuseIdentifier: "PhonicsStatisticsTitleCell", for: indexPath)

        case 5:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "PhonicsStatisticsViewCell",
                for: indexPath
            ) as? PhonicsStatisticsViewCell else { return UICollectionViewCell() }

            let sessions = filteredPhonicsSessions()
            let overview = AnalyticsAggregator.phonicsOverview(sessions: sessions)

            cell.configure(
                sound:   overview.sound.map   { "\($0)%" } ?? "--",
                quiz:    overview.quiz.map    { "\($0)%" } ?? "--",
                rhyme:   overview.rhyme.map   { "\($0)%" } ?? "--",
                word:    overview.word.map    { "\($0)%" } ?? "--",
                fluency: overview.fluency.map { "\($0)" } ?? "--"
            )
            return cell

        default:
            fatalError("Unhandled index \(indexPath.item)")
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension AnalyticsViewController {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        let width = collectionView.bounds.width
        let screenHeight = view.window?.windowScene?.screen.bounds.height
            ?? collectionView.bounds.height
        let referenceHeight: CGFloat = 852.0

        func adaptiveHeight(_ minPoints: CGFloat) -> CGFloat {
            let proportionalHeight = screenHeight * (minPoints / referenceHeight)
            return max(minPoints, proportionalHeight)
        }

        switch indexPath.item {
        case 0: return CGSize(width: width, height: 50)
        case 1: return CGSize(width: width, height: adaptiveHeight(200))
        case 2: return CGSize(width: width, height: 50)
        case 3: return CGSize(width: width, height: adaptiveHeight(276))
        case 4: return CGSize(width: width, height: 50)
        case 5: return CGSize(width: width, height: adaptiveHeight(349))
        default: return CGSize(width: width, height: 44)
        }
    }
}
