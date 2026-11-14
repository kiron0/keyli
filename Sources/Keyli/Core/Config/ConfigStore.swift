import Foundation
import Combine

public final class ConfigStore: ObservableObject {
    public static let shared = ConfigStore()

    private let userDefaultsKey = "io.coreify.keyli.config.v1"
    private let defaults: UserDefaults

    @Published public var config: KeyliConfig {
        didSet {
            if config != oldValue {
                save()
            }
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(KeyliConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = KeyliConfig()
        }
    }

    public func save() {
        if let encoded = try? JSONEncoder().encode(config) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
    }

    public func resetToDefaults() {
        config = KeyliConfig()
        save()
    }
}
