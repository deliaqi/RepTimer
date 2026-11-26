import Foundation

enum WorkoutPhase: String {
    case preparation = "PREP"
    case work = "WORK"
    case rest = "REST"
    case cooldown = "COOLDOWN"

    var title: String {
        switch self {
        case .preparation: "Get ready"
        case .work: "Work"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        }
    }
}
