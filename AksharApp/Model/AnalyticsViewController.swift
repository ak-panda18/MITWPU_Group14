import UIKit

class AnalyticsViewController: UIViewController,
                                UICollectionViewDelegate,
                                UICollectionViewDataSource,
                               UICollectionViewDelegateFlowLayout {
    
    private struct PhonicsStats {
        let soundAccuracy: Int
        let quizAccuracy: Int
        let rhymeAccuracy: Int
        let wordAccuracy: Int
        let fluencyWPM: Int
    }
    var selectedStats: DailyStats?
    private var selectedGraphTitle: String?
    private var selectedGraphData: [AccuracyPoint] = []
    
    // MARK: - IBOutlets
    @IBOutlet weak var weeklyMonthlySegmentedControl: UISegmentedControl!
    @IBOutlet weak var collectionView: UICollectionView!
    
    private var analyticsData: AnalyticsData = .empty
    private var lastUpdatedWidth: CGFloat = 0
    
    // MARK: - Properties
    private var isWeeklyView: Bool = true
    private var recentDailyStats: [DailyStats] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
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
        let store = AnalyticsStore.shared
        
        analyticsData = AnalyticsData(
            readingSessions: store.fetchReadingSessions(),
            readingCheckpointResults: store.fetchCheckpointResults(),
            phonicsSessions: store.fetchPhonicsSessions(),
            writingSessions: store.fetchWritingSessions()
        )
        
        print("Analytics loaded")
        print("Reading sessions:", analyticsData.readingSessions.count)
        print("Checkpoint results:", analyticsData.readingCheckpointResults.count)
        print("Phonics sessions:", analyticsData.phonicsSessions.count)
        print("Writing sessions:", analyticsData.writingSessions.count)
    }
    
    private func computePhonicsStats() -> PhonicsStats {
        let sessions = filteredPhonicsSessions()
        
        return PhonicsStats(
            soundAccuracy: accuracy(for: "sound_detector", sessions: sessions),
            quizAccuracy: accuracy(for: "quiz_my_story", sessions: sessions),
            rhymeAccuracy: accuracy(for: "rhyme_words", sessions: sessions),
            wordAccuracy: accuracy(for: "word_builder", sessions: sessions),
            fluencyWPM: fluencyWPM(sessions: sessions)
        )
    }
    
    private func accuracy(for type: String, sessions: [PhonicsSessionData]) -> Int {
        let filtered = sessions.filter {
            $0.exerciseType == type
        }
        
        let totalCorrect = filtered.reduce(0) { $0 + $1.correctCount }
        let totalAttempts = filtered.reduce(0) { $0 + $1.totalAttempts }
        
        guard totalAttempts > 0 else { return 0 }
        
        return Int((Double(totalCorrect) / Double(totalAttempts)) * 100)
    }
    
    private func fluencyWPM(sessions: [PhonicsSessionData]) -> Int {
        
        let fluencySessions = sessions.filter {
            $0.exerciseType == "fluency_drill"
        }
        
        let totalCorrect = fluencySessions.reduce(0) {
            $0 + $1.correctCount
        }
        
        let totalDuration = fluencySessions.reduce(0.0) { result, session in
            guard let end = session.endTime else { return result }
            return result + end.timeIntervalSince(session.startTime)
        }
        
        guard totalDuration > 0 else { return 0 }
        
        let minutes = totalDuration / 60
        return Int(Double(totalCorrect) / minutes)
    }
    private func average(from sessions: [WritingSessionData], keyPath: KeyPath<WritingSessionData, Int>) -> Int? {
        let relevantSessions = sessions.filter { $0[keyPath: keyPath] > 0 }
        guard !relevantSessions.isEmpty else { return nil }
        let total = relevantSessions.reduce(0) { $0 + $1[keyPath: keyPath] }
        return total / relevantSessions.count
    }
    
    private func comparisonDelta(
        current: Int?,
        previous: Int?
    ) -> Int? {
        guard let current, let previous else { return nil }
        return current - previous
    }
    
    private func hasPhonicsDataForSelectedRange() -> Bool {
        !filteredPhonicsSessions().isEmpty
    }
    
    private func filteredPhonicsSessions() -> [PhonicsSessionData] {
        let now = Date()
        let calendar = Calendar.current
        
        let cutoffDate: Date = {
            if isWeeklyView {
                return calendar.date(byAdding: .day, value: -7, to: now)!
            } else {
                return calendar.date(byAdding: .day, value: -30, to: now)!
            }
        }()
        return analyticsData.phonicsSessions.filter {
            $0.date >= cutoffDate
        }
    }
    
    private func filteredWritingSessions() -> [WritingSessionData] {
        let now = Date()
        let calendar = Calendar.current
        
        let cutoff = isWeeklyView
        ? calendar.date(byAdding: .day, value: -7, to: now)!
        : calendar.date(byAdding: .day, value: -30, to: now)!
        
        return analyticsData.writingSessions.filter {
            $0.date >= cutoff
        }
    }
    
    private func previousWritingSessions() -> [WritingSessionData] {
        let now = Date()
        let calendar = Calendar.current
        
        let (start, end): (Date, Date) = {
            if isWeeklyView {
                let end = calendar.date(byAdding: .day, value: -7, to: now)!
                let start = calendar.date(byAdding: .day, value: -14, to: now)!
                return (start, end)
            } else {
                let end = calendar.date(byAdding: .day, value: -30, to: now)!
                let start = calendar.date(byAdding: .day, value: -60, to: now)!
                return (start, end)
            }
        }()
        
        return analyticsData.writingSessions.filter {
            $0.date >= start && $0.date < end
        }
    }
    
    private func filteredReadingSessions() -> [ReadingSessionData] {
        let now = Date()
        let calendar = Calendar.current
        
        let cutoff = isWeeklyView
        ? calendar.date(byAdding: .day, value: -7, to: now)!
        : calendar.date(byAdding: .day, value: -30, to: now)!
        
        return analyticsData.readingSessions.filter {
            $0.startTime >= cutoff && $0.endTime != nil
        }
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
        
        let totalHours = Double(minutesVal) / 60.0
        let flooredHours = Int(floor(totalHours))
        let numberText = flooredHours == 0 ? "\(minutesVal)" : "\(flooredHours)"
        let unitText = flooredHours == 0 ? "\nminutes" : "\nhours"
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
        let unitString = NSAttributedString(string: unitText, attributes: unitAttributes)
        finalString.append(unitString)
        
        return finalString
    }
    
    private func currentReadingLevel() -> (String, String) {
        let sessions = analyticsData.readingSessions
        guard let maxLevel = sessions.map({ $0.levelUnlocked }).max() else {
            return ("--", "--")
        }
        switch maxLevel {
        case 1:
            return ("Level 1", "(Arial + 3 spaces)")
        case 2:
            return ("Level 2", "(Trebuchet MS + 2 spaces)")
        case 3:
            return ("Level 3", "(Times New Roman + 1 space)")
        default:
            return ("--", "--")
        }
    }
    
    private func averageLettersAccuracy() -> Int {
        let sessions = analyticsData.writingSessions
        guard !sessions.isEmpty else { return 0 }
        
        let total = sessions.reduce(0) { $0 + $1.lettersAccuracy }
        return total / sessions.count
    }
    
    private func averageWordsAccuracy() -> Int {
        let sessions = analyticsData.writingSessions
        guard !sessions.isEmpty else { return 0 }
        
        let total = sessions.reduce(0) { $0 + $1.wordsAccuracy }
        return total / sessions.count
    }
    
    private func averageNumbersAccuracy() -> Int {
        let sessions = analyticsData.writingSessions
        guard !sessions.isEmpty else { return 0 }
        
        let total = sessions.reduce(0) { $0 + $1.numbersAccuracy }
        return total / sessions.count
    }
    
    private func writingGraphData(
        keyPath: KeyPath<WritingSessionData, Int>
    ) -> [AccuracyPoint] {
        let sessions = filteredWritingSessions()
        let relevantSessions = sessions.filter { $0[keyPath: keyPath] > 0 }
        let calendar = Calendar.current
        
        let groupKey: (Date) -> Date = { date in
            if self.isWeeklyView {
                return calendar.startOfDay(for: date)
            } else {
                return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            }
        }
        let groupedSessions = Dictionary(grouping: relevantSessions) { session in
            groupKey(session.date)
        }
        let sortedDates = groupedSessions.keys.sorted()
        
        let points = sortedDates.map { date -> AccuracyPoint in
            let sessionsInGroup = groupedSessions[date]!
            let total = sessionsInGroup.reduce(0) { $0 + $1[keyPath: keyPath] }
            let average = total / sessionsInGroup.count
            let dateFormatter = DateFormatter()
            if self.isWeeklyView {
                dateFormatter.dateFormat = "E"
            } else {
                dateFormatter.dateFormat = "d MMM"
            }
            let label = dateFormatter.string(from: date)
            
            return AccuracyPoint(
                dateLabel: label,
                value: average
            )
        }
        
        return points
    }
    
    private func showGraph(title: String, data: [AccuracyPoint]) {
        selectedGraphTitle = title
        selectedGraphData = data
        performSegue(withIdentifier: "ShowGraphPopup", sender: nil)
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
        collectionView.delegate = self
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
        if isWeeklyView {
            loadWeeklyStats()
        } else {
            loadMonthlyStats()
        }
        collectionView.reloadItems(at: [IndexPath(item: 3, section: 0)])
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
        case 0..<40:
            return .systemRed
        case 40..<80:
            return .systemOrange
        default:
            return .systemGreen
        }
    }
    
    // MARK: - Data Loading Logic
    
    private func loadWeeklyStats() {
        let allAttempts = CheckpointHistoryManager.shared.getAllAttempts()
        var groupedData: [Date: [Int]] = [:]
        for attempt in allAttempts {
            let dateKey = Calendar.current.startOfDay(for: attempt.timestamp)
            if groupedData[dateKey] != nil {
                groupedData[dateKey]?.append(attempt.accuracy)
            } else {
                groupedData[dateKey] = [attempt.accuracy]
            }
        }
        var processedList: [DailyStats] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy"
        
        let sortedDates = groupedData.keys.sorted(by: { $0 > $1 })
        
        for date in sortedDates {
            if let scores = groupedData[date] {
                let total = scores.reduce(0, +)
                let average = total / scores.count
                let dateString = dateFormatter.string(from: date)
                
                processedList.append(DailyStats(date: date, accuracy: average, formattedDate: dateString))
            }
        }
        
        self.recentDailyStats = Array(processedList.prefix(7))
        collectionView.reloadData()
    }
    private func loadMonthlyStats() {
        let allAttempts = CheckpointHistoryManager.shared.getAllAttempts()
        let calendar = Calendar.current
        let now = Date()
        var weeklyBuckets: [[Int]] = [[], [], [], []]
        for attempt in allAttempts {
            guard let daysAgo = calendar.dateComponents([.day], from: attempt.timestamp, to: now).day else { continue }
            if daysAgo < 7 {
                weeklyBuckets[3].append(attempt.accuracy)
            } else if daysAgo < 14 {
                weeklyBuckets[2].append(attempt.accuracy)
            } else if daysAgo < 21 {
                weeklyBuckets[1].append(attempt.accuracy)
            } else if daysAgo < 28 {
                weeklyBuckets[0].append(attempt.accuracy)
            }
        }
        
        let labels = ["3 Weeks Ago", "2 Weeks Ago", "Last Week", "This Week"]
        var monthlyList: [DailyStats] = []
        for i in 0...3 {
            let scores = weeklyBuckets[i]
            if !scores.isEmpty {
                let average = scores.reduce(0, +) / scores.count
                monthlyList.append(DailyStats(date: Date(), accuracy: average, formattedDate: labels[i]))
            }
        }
        
        self.recentDailyStats = monthlyList
        collectionView.reloadData()
    }
    
    // MARK: - Navigation Functions
    func showCheckpointDetails(for stats: DailyStats) {
        selectedStats = stats
        performSegue(withIdentifier: "ShowCheckpointDetails", sender: nil)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowGraphPopup",
           let graphVC = segue.destination as? GraphPopupViewController {

            graphVC.graphTitle = selectedGraphTitle ?? ""
            graphVC.graphData = selectedGraphData

            graphVC.modalPresentationStyle = .overFullScreen
        }
        if segue.identifier == "ShowCheckpointDetails",
           let popupVC = segue.destination as? CheckpointDetailsViewController {
            
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

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 6
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        switch indexPath.item {

        case 0:
            return collectionView.dequeueReusableCell(withReuseIdentifier: "WritingAccuracyTitleCell", for: indexPath)

        case 1:
                    let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: "WritingAccuracyViewCell",
                        for: indexPath
                    ) as! WritingAccuracyViewCell

                    let current = filteredWritingSessions()
                    let previous = previousWritingSessions()

                    // 1. Calculate Averages
                    let currentLetters = average(from: current, keyPath: \.lettersAccuracy)
                    let previousLetters = average(from: previous, keyPath: \.lettersAccuracy)
                    
                    let currentWords = average(from: current, keyPath: \.wordsAccuracy)
                    let previousWords = average(from: previous, keyPath: \.wordsAccuracy)
                    
                    let currentNumbers = average(from: current, keyPath: \.numbersAccuracy)
                    let previousNumbers = average(from: previous, keyPath: \.numbersAccuracy)

            let deltaData: (Int?, Int?) -> (text: String, color: UIColor) = { curr, prev in
                            guard let c = curr else { return ("--", .gray) }
                            let p = prev ?? 0 // Treat new user (nil previous) as 0
                            
                            let diff = c - p
                            let symbol = diff >= 0 ? "↑" : "↓"
                            let text = "\(symbol) \(abs(diff))%"
                            let color: UIColor = diff >= 0 ? .systemGreen : .systemRed
                            
                            return (text, color)
                        }
                        
                        let lData = deltaData(currentLetters, previousLetters)
                        let wData = deltaData(currentWords, previousWords)
                        let nData = deltaData(currentNumbers, previousNumbers)
                        
                        let percentText: (Int?) -> String = { $0 != nil ? "\($0!)%" : "--" }
                        let comparisonLabel = isWeeklyView ? "\nvs last week" : "\nvs last month"
                        cell.configure(
                            letters: percentText(currentLetters),
                            lettersDelta: lData.text,
                            lettersColor: lData.color,
                            lettersComparisonText: comparisonLabel,

                            words: percentText(currentWords),
                            wordsDelta: wData.text,
                            wordsColor: wData.color,
                            wordsComparisonText: comparisonLabel,

                            numbers: percentText(currentNumbers),
                            numbersDelta: nData.text,
                            numbersColor: nData.color,
                            numbersComparisonText: comparisonLabel
                        )
                        cell.setColors(
                            letters: colorForScore(currentLetters),
                            words: colorForScore(currentWords),
                            numbers: colorForScore(currentNumbers)
                        )
                    cell.onLettersTapped = { [weak self] in
                        self?.showGraph(title: "Letters Accuracy", data: self?.writingGraphData(keyPath: \.lettersAccuracy) ?? [])
                    }
                    cell.onWordsTapped = { [weak self] in
                        self?.showGraph(title: "Words Accuracy", data: self?.writingGraphData(keyPath: \.wordsAccuracy) ?? [])
                    }
                    cell.onNumbersTapped = { [weak self] in
                        self?.showGraph(title: "Numbers Accuracy", data: self?.writingGraphData(keyPath: \.numbersAccuracy) ?? [])
                    }

                    return cell
        case 2:
            return collectionView.dequeueReusableCell(withReuseIdentifier: "ReadingStatisticsTitleCell", for: indexPath)

        case 3:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ReadingStatisticsViewCell", for: indexPath) as! ReadingStatisticsViewCell
            
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
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "PhonicsStatisticsViewCell",
                for: indexPath
            ) as! PhonicsStatisticsViewCell

            let phonics = computePhonicsStats()
            let hasData = hasPhonicsDataForSelectedRange()

            cell.configure(
                sound: hasData ? "\(phonics.soundAccuracy)%" : "--",
                quiz: hasData ? "\(phonics.quizAccuracy)%" : "--",
                rhyme: hasData ? "\(phonics.rhymeAccuracy)%" : "--",
                word: hasData ? "\(phonics.wordAccuracy)%" : "--",
                fluency: hasData ? "\(phonics.fluencyWPM)" : "--"
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
