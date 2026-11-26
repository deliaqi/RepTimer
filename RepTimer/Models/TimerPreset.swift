import Foundation

struct TimerPreset: Identifiable, Codable {
    var id: String
    var name: String
    var detail: String
    var work: Int
    var rest: Int
    var rounds: Int
    var symbol: String
    var preparationSeconds: Int = 10
    var preparationEnabled: Bool = false
    var cooldownSeconds: Int = 60
    var cooldownEnabled: Bool = false

    init(
        id: String,
        name: String,
        detail: String,
        work: Int,
        rest: Int,
        rounds: Int,
        symbol: String,
        preparationSeconds: Int = 10,
        preparationEnabled: Bool = false,
        cooldownSeconds: Int = 60,
        cooldownEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.work = work
        self.rest = rest
        self.rounds = rounds
        self.symbol = symbol
        self.preparationSeconds = preparationSeconds
        self.preparationEnabled = preparationEnabled
        self.cooldownSeconds = cooldownSeconds
        self.cooldownEnabled = cooldownEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, detail, work, rest, rounds, symbol
        case preparationSeconds, preparationEnabled, cooldownSeconds, cooldownEnabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        detail = try values.decodeIfPresent(String.self, forKey: .detail) ?? "Custom"
        work = try values.decode(Int.self, forKey: .work)
        rest = try values.decode(Int.self, forKey: .rest)
        rounds = try values.decode(Int.self, forKey: .rounds)
        symbol = try values.decodeIfPresent(String.self, forKey: .symbol) ?? "timer"
        preparationSeconds = try values.decodeIfPresent(Int.self, forKey: .preparationSeconds) ?? 10
        preparationEnabled = try values.decodeIfPresent(Bool.self, forKey: .preparationEnabled) ?? false
        cooldownSeconds = try values.decodeIfPresent(Int.self, forKey: .cooldownSeconds) ?? 60
        cooldownEnabled = try values.decodeIfPresent(Bool.self, forKey: .cooldownEnabled) ?? false
    }
}

enum EditableDuration: String, Identifiable {
    case work
    case rest
    case preparation
    case cooldown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .work: "Work time"
        case .rest: "Rest time"
        case .preparation: "Preparation time"
        case .cooldown: "Cooldown time"
        }
    }
}
