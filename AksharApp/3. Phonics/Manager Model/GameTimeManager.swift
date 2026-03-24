import Foundation

final class GameTimerManager {

    private var timer: Timer?

    private(set) var totalSeconds: Int
    private(set) var secondsRemaining: Int

    var onTick: ((Int) -> Void)?
    var onFinished: (() -> Void)?

    init(seconds: Int) {
        self.totalSeconds = seconds
        self.secondsRemaining = seconds
    }

    // MARK: - Start
    func start() {

        stop()

        secondsRemaining = totalSeconds

        timer = Timer.scheduledTimer(withTimeInterval: 1,
                                     repeats: true) { [weak self] _ in
            guard let self else { return }

            self.secondsRemaining -= 1

            if self.secondsRemaining <= 0 {
                self.stop()
                self.onFinished?()
            } else {
                self.onTick?(self.secondsRemaining)
            }
        }
    }

    // MARK: - Stop
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Reset
    func reset() {
        stop()
        secondsRemaining = totalSeconds
    }
}
