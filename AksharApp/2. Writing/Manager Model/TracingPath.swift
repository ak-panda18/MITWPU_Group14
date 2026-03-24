import UIKit

// MARK: - Data Structures
struct Stroke {
    let start: CGPoint
    let end: CGPoint
    let control1: CGPoint?
    let control2: CGPoint?
}

struct LetterPath {
    let strokes: [Stroke]
}

// MARK: - Data Store
enum TracingDataStore {
    static func getPath(for character: String) -> LetterPath? {
        return alphabetData[character]
    }
    private static let alphabetData: [String: LetterPath] = [
        "A": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.50, y: 0.075), end: CGPoint(x: 0.1133, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.50, y: 0.075), end: CGPoint(x: 0.8767, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.2667, y: 0.6688), end: CGPoint(x: 0.7333, y: 0.6688), control1: nil, control2: nil)
        ]),
        "B": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1533, y: 0.095), end: CGPoint(x: 0.1533, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.20, y: 0.09), end: CGPoint(x: 0.20, y: 0.475), control1: CGPoint(x: 1.0, y: 0.025), control2: CGPoint(x: 1.0, y: 0.5375)),
            Stroke(start: CGPoint(x: 0.20, y: 0.465), end: CGPoint(x: 0.20, y: 0.90), control1: CGPoint(x: 1.1, y: 0.45), control2: CGPoint(x: 1.1, y: 0.975))
        ]),
        "C": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.80, y: 0.20), end: CGPoint(x: 0.85, y: 0.7875), control1: CGPoint(x: -0.1167, y: -0.25), control2: CGPoint(x: -0.0833, y: 1.375))
        ]),
        "D": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1267, y: 0.10), end: CGPoint(x: 0.1267, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1667, y: 0.10), end: CGPoint(x: 0.1667, y: 0.90), control1: CGPoint(x: 1.1667, y: 0.0125), control2: CGPoint(x: 1.1667, y: 0.9625))
        ]),
        "E": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1333, y: 0.10), end: CGPoint(x: 0.1333, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1333, y: 0.10), end: CGPoint(x: 0.8333, y: 0.10), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1333, y: 0.4875), end: CGPoint(x: 0.80, y: 0.4875), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1333, y: 0.90), end: CGPoint(x: 0.8333, y: 0.90), control1: nil, control2: nil)
        ]),
        "F": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1667, y: 0.10), end: CGPoint(x: 0.1667, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1667, y: 0.10), end: CGPoint(x: 0.8667, y: 0.10), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1667, y: 0.50), end: CGPoint(x: 0.8333, y: 0.50), control1: nil, control2: nil)
        ]),
        "G": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.80, y: 0.20), end: CGPoint(x: 0.8333, y: 0.80), control1: CGPoint(x: -0.15, y: -0.25), control2: CGPoint(x: -0.0833, y: 1.375)),
            Stroke(start: CGPoint(x: 0.8333, y: 0.80), end: CGPoint(x: 0.8333, y: 0.55), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.8333, y: 0.55), end: CGPoint(x: 0.6333, y: 0.55), control1: nil, control2: nil)
        ]),
        "H": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1833, y: 0.10), end: CGPoint(x: 0.1833, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.8167, y: 0.10), end: CGPoint(x: 0.8167, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1833, y: 0.50), end: CGPoint(x: 0.8167, y: 0.50), control1: nil, control2: nil)
        ]),
        "I": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.50, y: 0.10), end: CGPoint(x: 0.50, y: 0.90), control1: nil, control2: nil)
        ]),
        "J": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.80, y: 0.125),
                end: CGPoint(x: 0.1667, y: 0.8125),
                control1: CGPoint(x: 0.90, y: 0.7625),
                control2: CGPoint(x: 0.7167, y: 1.05)
            )
        ]),
        "K": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.2167, y: 0.10), end: CGPoint(x: 0.2167, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.90, y: 0.1125), end: CGPoint(x: 0.2667, y: 0.50), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.2333, y: 0.45), end: CGPoint(x: 0.90, y: 0.825), control1: nil, control2: nil)
        ]),
        "L": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.2167, y: 0.10), end: CGPoint(x: 0.2167, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.2167, y: 0.90), end: CGPoint(x: 0.8333, y: 0.90), control1: nil, control2: nil)
        ]),
        "M": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1667, y: 0.90), end: CGPoint(x: 0.1667, y: 0.10), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.20, y: 0.10), end: CGPoint(x: 0.50, y: 0.725), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.50, y: 0.725), end: CGPoint(x: 0.80, y: 0.10), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.8167, y: 0.10), end: CGPoint(x: 0.8167, y: 0.90), control1: nil, control2: nil)
        ]),
        "N": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.2167, y: 0.90), end: CGPoint(x: 0.2167, y: 0.10), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.2167, y: 0.10), end: CGPoint(x: 0.7833, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.8167, y: 0.90), end: CGPoint(x: 0.8167, y: 0.10), control1: nil, control2: nil)
        ]),
        "O": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.50, y: 0.10), end: CGPoint(x: 0.50, y: 0.90), control1: CGPoint(x: 0.0667, y: 0.10), control2: CGPoint(x: 0.0667, y: 0.90)),
            Stroke(start: CGPoint(x: 0.50, y: 0.90), end: CGPoint(x: 0.50, y: 0.10), control1: CGPoint(x: 0.9333, y: 0.90), control2: CGPoint(x: 0.9333, y: 0.10))
        ]),
        "P": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1833, y: 0.90), end: CGPoint(x: 0.1833, y: 0.10), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1833, y: 0.10), end: CGPoint(x: 0.1833, y: 0.575), control1: CGPoint(x: 1.0, y: 0.025), control2: CGPoint(x: 1.0, y: 0.825))
        ]),
        "Q": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.50, y: 0.125), end: CGPoint(x: 0.50, y: 0.825), control1: CGPoint(x: -0.0333, y: 0.125), control2: CGPoint(x: -0.0333, y: 0.825)),
            Stroke(start: CGPoint(x: 0.50, y: 0.825), end: CGPoint(x: 0.50, y: 0.125), control1: CGPoint(x: 1.0333, y: 0.825), control2: CGPoint(x: 1.0333, y: 0.125)),
            Stroke(start: CGPoint(x: 0.60, y: 0.65), end: CGPoint(x: 0.8333, y: 0.925), control1: nil, control2: nil)
        ]),
        "R": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.2167, y: 0.9125), end: CGPoint(x: 0.2167, y: 0.0875), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.2167, y: 0.0875), end: CGPoint(x: 0.2167, y: 0.55), control1: CGPoint(x: 1.0667, y: 0.0875), control2: CGPoint(x: 1.0667, y: 0.55)),
            Stroke(start: CGPoint(x: 0.4167, y: 0.55), end: CGPoint(x: 0.90, y: 0.9125), control1: nil, control2: nil)
        ]),
        "S": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.7833, y: 0.1625), end: CGPoint(x: 0.3667, y: 0.5125), control1: CGPoint(x: -0.0333, y: 0.0), control2: CGPoint(x: -0.0333, y: 0.5125)),
            Stroke(start: CGPoint(x: 0.3667, y: 0.5125), end: CGPoint(x: 0.1833, y: 0.85), control1: CGPoint(x: 1.0333, y: 0.5125), control2: CGPoint(x: 1.0333, y: 0.975))
        ]),
        "T": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1333, y: 0.125), end: CGPoint(x: 0.8667, y: 0.125), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.5, y: 0.125), end: CGPoint(x: 0.5, y: 0.8925), control1: nil, control2: nil)
        ]),
        "U": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1667, y: 0.075), end: CGPoint(x: 0.8333, y: 0.075), control1: CGPoint(x: 0.0667, y: 1.2), control2: CGPoint(x: 0.9333, y: 1.2))
        ]),
        "V": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1667, y: 0.125), end: CGPoint(x: 0.5, y: 0.8925), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.5, y: 0.8925), end: CGPoint(x: 0.8333, y: 0.125), control1: nil, control2: nil)
        ]),
        "W": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1, y: 0.125), end: CGPoint(x: 0.3, y: 0.8925), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.3, y: 0.8925), end: CGPoint(x: 0.5, y: 0.2), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.5, y: 0.2), end: CGPoint(x: 0.7333, y: 0.8925), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.7333, y: 0.8925), end: CGPoint(x: 0.9, y: 0.125), control1: nil, control2: nil)
        ]),
        "X": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1667, y: 0.1225), end: CGPoint(x: 0.8333, y: 0.9), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.8333, y: 0.1225), end: CGPoint(x: 0.1667, y: 0.9), control1: nil, control2: nil)
        ]),
        "Y": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1833, y: 0.125), end: CGPoint(x: 0.5, y: 0.5625), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.8167, y: 0.125), end: CGPoint(x: 0.5, y: 0.5625), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.5, y: 0.55), end: CGPoint(x: 0.5, y: 0.9), control1: nil, control2: nil)
        ]),
        "Z": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1833, y: 0.125), end: CGPoint(x: 0.8167, y: 0.125), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.8167, y: 0.125), end: CGPoint(x: 0.1333, y: 0.8875), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1333, y: 0.8875), end: CGPoint(x: 0.8667, y: 0.8875), control1: nil, control2: nil)
        ]),
        
        "a": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.2333, y: 0.20),
                end: CGPoint(x: 0.8067, y: 0.9125),
                control1: CGPoint(x: 0.6667, y: 0.05),
                control2: CGPoint(x: 0.90, y: 0.05)
            ),
            Stroke(
                start: CGPoint(x: 0.8067, y: 0.50),
                end: CGPoint(x: 0.8067, y: 0.70),
                control1: CGPoint(x: -0.20, y: 0.35),
                control2: CGPoint(x: -0.0667, y: 1.25)
            )
        ]),
        
        "b": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.1667, y: 0.10), end: CGPoint(x: 0.1667, y: 0.90), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.20, y: 0.475), end: CGPoint(x: 0.1667, y: 0.7875),
                   control1: CGPoint(x: 1.1667, y: 0.025), control2: CGPoint(x: 1.1667, y: 1.125))
        ]),
        
        "c": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.8333, y: 0.225),
                end: CGPoint(x: 0.8667, y: 0.825),
                control1: CGPoint(x: -0.1667, y: -0.30),
                control2: CGPoint(x: -0.0333, y: 1.30)
            )
        ]),
        
        "d": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.8333, y: 0.10),
                end: CGPoint(x: 0.8333, y: 0.90),
                control1: nil,
                control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.80, y: 0.475),
                end: CGPoint(x: 0.8333, y: 0.7875),
                control1: CGPoint(x: -0.1667, y: 0.025),
                control2: CGPoint(x: -0.1667, y: 1.15)
            )
        ]),
        
        "e": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.2167, y: 0.475),
                end: CGPoint(x: 0.8667, y: 0.475),
                control1: CGPoint(x: 0.54, y: 0.50),
                control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.8667, y: 0.475),
                end: CGPoint(x: 0.20, y: 0.375),
                control1: CGPoint(x: 1.10, y: 0.0),
                control2: CGPoint(x: 0.50, y: -0.05)
            ),
            Stroke(
                start: CGPoint(x: 0.20, y: 0.375),
                end: CGPoint(x: 0.8333, y: 0.85),
                control1: CGPoint(x: -0.10, y: 0.75),
                control2: CGPoint(x: 0.1333, y: 1.15)
            )
        ]),
        
        "f": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.8333, y: 0.10),
                end: CGPoint(x: 0.40, y: 0.90),
                control1: CGPoint(x: 0.6667, y: -0.025),
                control2: CGPoint(x: 0.32, y: 0.0125)
            ),
            Stroke(
                start: CGPoint(x: 0.1667, y: 0.375),
                end: CGPoint(x: 0.7333, y: 0.375),
                control1: nil,
                control2: nil
            )
        ]),
        
        "g": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.8333, y: 0.3167),
                end: CGPoint(x: 0.8333, y: 0.3583),
                control1: CGPoint(x: -0.20, y: 0.05),
                control2: CGPoint(x: -0.0333, y: 1.0)
            ),
            Stroke(
                start: CGPoint(x: 0.8333, y: 0.2333),
                end: CGPoint(x: 0.2667, y: 0.75),
                control1: CGPoint(x: 1.0, y: 0.6667),
                control2: CGPoint(x: 0.6667, y: 0.8667)
            )
        ]),
        
        "h": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.2167, y: 0.10),
                end: CGPoint(x: 0.2167, y: 0.90),
                control1: nil,
                control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.2167, y: 0.55),
                end: CGPoint(x: 0.8333, y: 0.90),
                control1: CGPoint(x: 0.8333, y: 0.0125),
                control2: CGPoint(x: 0.8333, y: 0.90)
            )
        ]),
        
        "i": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.50, y: 0.40),
                end: CGPoint(x: 0.50, y: 0.90),
                control1: nil,
                control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.50, y: 0.1125),
                end: CGPoint(x: 0.50, y: 0.1127),
                control1: nil,
                control2: nil
            )
        ]),
        
        "j": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.60, y: 0.0833),
                end: CGPoint(x: 0.60, y: 0.0835),
                control1: nil,
                control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.6167, y: 0.30),
                end: CGPoint(x: 0.2667, y: 0.9167),
                control1: CGPoint(x: 0.6167, y: 0.7667),
                control2: CGPoint(x: 0.7167, y: 1.05)
            )
        ]),
        
        "k": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.2167, y: 0.10),
                end: CGPoint(x: 0.2167, y: 0.90),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.2167, y: 0.65),
                end: CGPoint(x: 0.85, y: 0.35),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.4667, y: 0.575),
                end: CGPoint(x: 0.8333, y: 0.90),
                control1: nil, control2: nil
            )
        ]),
        
        "l": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.50, y: 0.10),
                end: CGPoint(x: 0.50, y: 0.90),
                control1: nil,
                control2: nil
            )
        ]),
        
        "m": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.20, y: 0.0875),
                end: CGPoint(x: 0.20, y: 0.90),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.20, y: 0.275),
                end: CGPoint(x: 0.50, y: 0.90),
                control1: CGPoint(x: 0.525, y: 0.0),
                control2: CGPoint(x: 0.525, y: 0.50)
            ),
            Stroke(
                start: CGPoint(x: 0.50, y: 0.30),
                end: CGPoint(x: 0.80, y: 0.90),
                control1: CGPoint(x: 0.85, y: 0.0),
                control2: CGPoint(x: 0.85, y: 0.50)
            )
        ]),
        
        "n": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.20, y: 0.1125),
                end: CGPoint(x: 0.20, y: 0.90),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.20, y: 0.325),
                end: CGPoint(x: 0.80, y: 0.90),
                control1: CGPoint(x: 0.8667, y: 0.0),
                control2: CGPoint(x: 0.8667, y: 0.50)
            )
        ]),
        
        "o": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.50, y: 0.20),
                end: CGPoint(x: 0.50, y: 0.80),
                control1: CGPoint(x: 0.0667, y: 0.20),
                control2: CGPoint(x: 0.0667, y: 0.80)
            ),
            Stroke(
                start: CGPoint(x: 0.50, y: 0.80),
                end: CGPoint(x: 0.50, y: 0.20),
                control1: CGPoint(x: 0.9333, y: 0.80),
                control2: CGPoint(x: 0.9333, y: 0.20)
            )
        ]),
        
        "p": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.1833, y: 0.10),
                end: CGPoint(x: 0.1833, y: 0.90),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.1833, y: 0.225),
                end: CGPoint(x: 0.1833, y: 0.50),
                control1: CGPoint(x: 1.0, y: -0.25),
                control2: CGPoint(x: 1.0, y: 1.0)
            )
        ]),
        
        "q": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.8167, y: 0.10),
                end: CGPoint(x: 0.8167, y: 0.90),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.8167, y: 0.225),
                end: CGPoint(x: 0.8167, y: 0.50),
                control1: CGPoint(x: -0.0833, y: -0.25),
                control2: CGPoint(x: -0.0833, y: 1.0)
            )
        ]),
        
        "r": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.24, y: 0.1625),
                end: CGPoint(x: 0.24, y: 0.825),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.24, y: 0.40),
                end: CGPoint(x: 0.88, y: 0.25),
                control1: CGPoint(x: 0.72, y: 0.125),
                control2: nil
            )
        ]),
        
        "s": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.76, y: 0.20),
                end: CGPoint(x: 0.42, y: 0.50),
                control1: CGPoint(x: 0.02, y: 0.075),
                control2: CGPoint(x: 0.02, y: 0.50)
            ),
            Stroke(
                start: CGPoint(x: 0.42, y: 0.50),
                end: CGPoint(x: 0.20, y: 0.80),
                control1: CGPoint(x: 0.98, y: 0.50),
                control2: CGPoint(x: 0.98, y: 0.95)
            )
        ]),
        
        "t": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.46, y: 0.15),
                end: CGPoint(x: 0.76, y: 0.825),
                control1: CGPoint(x: 0.36, y: 0.80),
                control2: CGPoint(x: 0.52, y: 0.80)
            ),
            Stroke(
                start: CGPoint(x: 0.20, y: 0.35),
                end: CGPoint(x: 0.80, y: 0.35),
                control1: nil, control2: nil
            )
        ]),
        
        "u": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.1567, y: 0.15),
                end: CGPoint(x: 0.80, y: 0.15),
                control1: CGPoint(x: 0.0167, y: 1.05),
                control2: CGPoint(x: 0.80, y: 1.075)
            ),
            Stroke(
                start: CGPoint(x: 0.80, y: 0.20),
                end: CGPoint(x: 0.80, y: 0.85),
                control1: nil, control2: nil
            )
        ]),
        
        "v": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.18, y: 0.225),
                end: CGPoint(x: 0.50, y: 0.825),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.50, y: 0.825),
                end: CGPoint(x: 0.82, y: 0.225),
                control1: nil, control2: nil
            )
        ]),
        
        "w": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.125, y: 0.225), end: CGPoint(x: 0.3125, y: 0.825), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.3125, y: 0.825), end: CGPoint(x: 0.50, y: 0.225), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.50, y: 0.225), end: CGPoint(x: 0.6875, y: 0.825), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.6875, y: 0.825), end: CGPoint(x: 0.875, y: 0.225), control1: nil, control2: nil)
        ]),
        
        "x": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.20, y: 0.20),
                end: CGPoint(x: 0.80, y: 0.825),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.80, y: 0.20),
                end: CGPoint(x: 0.20, y: 0.825),
                control1: nil, control2: nil
            )
        ]),
        
        "0": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.50, y: 0.15),
                end: CGPoint(x: 0.50, y: 0.85),
                control1: CGPoint(x: 0.05, y: 0.15),
                control2: CGPoint(x: 0.05, y: 0.85)
            ),
            Stroke(
                start: CGPoint(x: 0.50, y: 0.85),
                end: CGPoint(x: 0.50, y: 0.15),
                control1: CGPoint(x: 0.95, y: 0.85),
                control2: CGPoint(x: 0.95, y: 0.15)
            )
        ]),
        "1": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.1667, y: 0.25),
                end: CGPoint(x: 0.70, y: 0.10),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.70, y: 0.10),
                end: CGPoint(x: 0.70, y: 0.8875),
                control1: nil, control2: nil
            )
        ]),
        
        "2": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.15, y: 0.275),
                end: CGPoint(x: 0.1833, y: 0.8875),
                control1: CGPoint(x: 0.333, y: 0.0125),
                control2: CGPoint(x: 1.333, y: 0.15)
            ),
            Stroke(
                start: CGPoint(x: 0.1833, y: 0.8875),
                end: CGPoint(x: 0.85, y: 0.8875),
                control1: nil, control2: nil
            )
        ]),
        
        "3": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.15, y: 0.20),
                end: CGPoint(x: 0.40, y: 0.50),
                control1: CGPoint(x: 0.9333, y: 0.025),
                control2: CGPoint(x: 0.9333, y: 0.45)
            ),
            Stroke(
                start: CGPoint(x: 0.40, y: 0.50),
                end: CGPoint(x: 0.15, y: 0.825),
                control1: CGPoint(x: 0.9333, y: 0.575),
                control2: CGPoint(x: 0.9333, y: 0.925)
            )
        ]),
        "4": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.65, y: 0.1125),
                end: CGPoint(x: 0.65, y: 0.90),
                control1: nil,
                control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.65, y: 0.1125),
                end: CGPoint(x: 0.10, y: 0.70),
                control1: nil,
                control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.10, y: 0.70),
                end: CGPoint(x: 0.8667, y: 0.70),
                control1: nil,
                control2: nil
            )
        ]),
        "5": LetterPath(strokes: [
            Stroke(start: CGPoint(x: 0.80, y: 0.125), end: CGPoint(x: 0.1667, y: 0.125), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1667, y: 0.125), end: CGPoint(x: 0.1667, y: 0.45), control1: nil, control2: nil),
            Stroke(start: CGPoint(x: 0.1667, y: 0.45), end: CGPoint(x: 0.15, y: 0.825), control1: CGPoint(x: 1.0, y: 0.225), control2: CGPoint(x: 1.0, y: 1.125))
        ]),
        
        "6": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.70, y: 0.0875),
                end: CGPoint(x: 0.15, y: 0.60),
                control1: CGPoint(x: 0.3333, y: 0.0875),
                control2: CGPoint(x: 0.15, y: 0.30)
            ),
            Stroke(
                start: CGPoint(x: 0.15, y: 0.60),
                end: CGPoint(x: 0.5167, y: 0.875),
                control1: CGPoint(x: 0.15, y: 0.875),
                control2: CGPoint(x: 0.3333, y: 0.875)
            ),
            Stroke(
                start: CGPoint(x: 0.5167, y: 0.875),
                end: CGPoint(x: 0.3167, y: 0.4625),
                control1: CGPoint(x: 0.9167, y: 0.875),
                control2: CGPoint(x: 0.9167, y: 0.4625)
            )
        ]),
        
        "7": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.15, y: 0.125),
                end: CGPoint(x: 0.8167, y: 0.125),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.8167, y: 0.125),
                end: CGPoint(x: 0.3667, y: 0.875),
                control1: nil, control2: nil
            )
        ]),
        
        "8": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.5, y: 0.4875),
                end: CGPoint(x: 0.5, y: 0.0875),
                control1: CGPoint(x: 0.1333, y: 0.4875),
                control2: CGPoint(x: 0.1333, y: 0.0875)
            ),
            Stroke(
                start: CGPoint(x: 0.5, y: 0.0875),
                end: CGPoint(x: 0.5, y: 0.4875),
                control1: CGPoint(x: 0.8667, y: 0.0875),
                control2: CGPoint(x: 0.8667, y: 0.4875)
            ),
            Stroke(
                start: CGPoint(x: 0.5, y: 0.4875),
                end: CGPoint(x: 0.5, y: 0.9375),
                control1: CGPoint(x: 0.0833, y: 0.4875),
                control2: CGPoint(x: 0.0833, y: 0.9375)
            ),
            Stroke(
                start: CGPoint(x: 0.5, y: 0.9375),
                end: CGPoint(x: 0.5, y: 0.4875),
                control1: CGPoint(x: 0.9167, y: 0.9375),
                control2: CGPoint(x: 0.9167, y: 0.4875)
            )
        ]),
        
        "9": LetterPath(strokes: [
            Stroke(
                start: CGPoint(x: 0.7833, y: 0.525),
                end: CGPoint(x: 0.4167, y: 0.10),
                control1: CGPoint(x: 0.7833, y: 0.10),
                control2: CGPoint(x: 0.60, y: 0.10)
            ),
            Stroke(
                start: CGPoint(x: 0.4167, y: 0.10),
                end: CGPoint(x: 0.7833, y: 0.525),
                control1: CGPoint(x: 0.05, y: 0.10),
                control2: CGPoint(x: 0.05, y: 0.525)
            ),
            Stroke(
                start: CGPoint(x: 0.7833, y: 0.525),
                end: CGPoint(x: 0.7833, y: 0.775),
                control1: nil, control2: nil
            ),
            Stroke(
                start: CGPoint(x: 0.7833, y: 0.775),
                end: CGPoint(x: 0.1833, y: 0.80),
                control1: CGPoint(x: 0.7833, y: 0.975),
                control2: CGPoint(x: 0.1833, y: 0.975)
            )
        ])
    ]
}
