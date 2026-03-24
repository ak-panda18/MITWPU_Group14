import Foundation

protocol ExerciseReceivesCover {
    var exerciseType: ExerciseType? { get set }
    var coverWasShown: Bool { get set }
}

protocol ExerciseResumable {
    var startingIndex: Int? { get set }
}

protocol ExerciseProgressReporting {
    var currentIndex: Int { get }
}

protocol ExerciseDependencyReceivable: AnyObject {
    var phonicsGameplayManager: PhonicsGameplayManager! { get set }
    var bundleDataLoader: BundleDataLoader! { get set }
}

// MARK: - TTS speech injection.
protocol ExerciseSpeechReceivable: AnyObject {
    var speechManager: SpeechManager! { get set }
}

// MARK: - STT + timer injection.
protocol ExerciseSTTReceivable: AnyObject {
    var speechRecognitionManager: SpeechRecognitionManager! { get set }
    var gameTimerManager: GameTimerManager! { get set }
}
