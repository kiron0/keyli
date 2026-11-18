import Foundation
import CoreGraphics

public enum SwipeDecoder {
    public static func collapse(_ letters: [Character]) -> [Character] {
        var result: [Character] = []
        for letter in letters where result.last != letter {
            result.append(letter)
        }
        return result
    }

    public static func fits(_ word: String, path: [Character], allowedMisses: Int? = nil) -> Bool {
        let letters = collapse(Array(word.lowercased()))
        guard let first = letters.first, let last = letters.last,
              first == path.first, last == path.last, letters.count >= 2 || path.count <= 2 else { return false }
        let budget = allowedMisses ?? (letters.count >= 5 ? 1 : 0)
        var index = 0
        var misses = 0
        for letter in letters {
            if let found = path[index...].firstIndex(of: letter) {
                index = found
            } else {
                misses += 1
                if misses > budget { return false }
            }
        }
        return true
    }

    public static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard let first = points.first, count > 1 else { return points }
        guard points.count > 1 else { return Array(repeating: first, count: count) }
        var lengths: [CGFloat] = [0]
        for i in 1..<points.count {
            lengths.append(lengths[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y))
        }
        let total = lengths.last ?? 0
        guard total > 0 else { return Array(repeating: first, count: count) }
        var result: [CGPoint] = []
        var segment = 1
        for step in 0..<count {
            let target = total * CGFloat(step) / CGFloat(count - 1)
            while segment < points.count - 1 && lengths[segment] < target {
                segment += 1
            }
            let start = lengths[segment - 1]
            let span = max(0.0001, lengths[segment] - start)
            let t = min(1, max(0, (target - start) / span))
            let a = points[segment - 1]
            let b = points[segment]
            result.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        return result
    }

    public static func distance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        guard a.count == b.count, !a.isEmpty else { return .greatestFiniteMagnitude }
        var sum: CGFloat = 0
        for i in 0..<a.count {
            sum += hypot(a[i].x - b[i].x, a[i].y - b[i].y)
        }
        return sum / CGFloat(a.count)
    }

    public static func rank(
        path: [Character],
        points: [CGPoint],
        centers: [Character: CGPoint],
        keySize: CGFloat,
        candidates: [String],
        prior: (String) -> CGFloat,
        limit: Int = 4
    ) -> [String] {
        let collapsedPath = collapse(path)
        guard collapsedPath.count >= 2, points.count >= 2, keySize > 0 else { return [] }
        let sampleCount = 32
        let user = resample(points, count: sampleCount)
        var scored: [(String, CGFloat)] = []
        var seen = Set<String>()
        for word in candidates where seen.insert(word.lowercased()).inserted {
            guard fits(word, path: collapsedPath) else { continue }
            let letters = collapse(Array(word.lowercased()))
            let ideal = letters.compactMap { centers[$0] }
            guard ideal.count == letters.count, ideal.count >= 2 else { continue }
            let geometric = distance(user, resample(ideal, count: sampleCount)) / keySize
            scored.append((word, geometric - prior(word)))
        }
        return scored
            .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    public static let commonWords: [String] = """
    the be to of and in that have it for not on with he as you do at this but his by from they we say her she or an will my one all would there their what so up out if about who get which go me when make can like time no just him know take people into year your good some could them see other than then now look only come its over think also back after use two how our work first well way even new want because any these give day most us is was are been has had were said did made find here thing many where much those both before must through still life down should call world very while last might great old year off yes ever never same another tell need feel high really something home school seem few hand small part place case week company system program question during government number night point most though again turn start show every under large house problem state family student group country city right left begin keep put help talk end does why let mean move live hold bring write provide sit stand lose pay meet include continue set learn change lead understand watch follow stop create speak read allow add spend grow open walk win offer remember love consider appear buy wait serve die send expect build stay fall cut reach kill remain suggest raise pass sell require report decide pull
    hello thanks thank please okay sorry sure maybe today tomorrow tonight morning evening later soon already always often sometimes usually almost enough quite rather perhaps actually probably definitely exactly especially
    name word email phone message text call chat meeting team project code file folder app apps mac keyboard screen window button design data image photo video music game book page story news money price order account password user friend friends mom dad baby kids child children man woman men women person boy girl guy guys body head face eye eyes heart mind idea fact reason result issue problem answer side minute minutes hour hours days weeks month months years moment kind sort type lot lots
    good great nice best better bad worse worst big little long short young late early easy hard real true free full sure ready happy sad fine cool funny awesome amazing beautiful important different possible available able whole public private social local national human main major simple clear strong special final open close dear hot cold warm fast slow light dark white black red blue green
    am being having doing going coming getting making taking looking working trying saying thinking using playing running reading writing waiting talking feeling leaving sending checking
    went came got made took saw knew thought told felt became left gave found put brought began kept held wrote stood heard meant set met ran paid sat spoke lay led read grew lost fell sent built understood drew broke spent cut rose drove bought wore chose
    yeah yep nope hey hi bye lol wow ok cool great love like
    really very much more less most least
    i'm i'll i've i'd you're you'll you've we're we'll they're they'll that's there's here's what's it's let's don't doesn't didn't can't won't isn't aren't wasn't weren't haven't hasn't couldn't wouldn't shouldn't
    around above across against along among behind below beside between beyond inside outside toward towards upon within without until since unless whether either neither
    """
    .split(whereSeparator: { $0.isWhitespace })
    .map { String($0) }
    .filter { !$0.contains("'") }

    public static let commonRank: [String: Int] = {
        var ranks: [String: Int] = [:]
        for (index, word) in commonWords.enumerated() where ranks[word] == nil {
            ranks[word] = index
        }
        return ranks
    }()

    public static func commonBonus(_ word: String) -> CGFloat {
        guard let rank = commonRank[word.lowercased()] else { return 0 }
        let position = CGFloat(rank) / CGFloat(max(1, commonWords.count))
        return 0.5 - 0.2 * position
    }
}

public final class SwipeDictionary {
    public static let shared = SwipeDictionary()

    private let lock = NSLock()
    private var index: [String: [String]] = [:]
    private var isLoaded = false
    private var isLoading = false

    private init() {}

    public static func key(first: Character, last: Character) -> String {
        String([first, last])
    }

    public func preload() {
        lock.lock()
        guard !isLoaded, !isLoading else { lock.unlock(); return }
        isLoading = true
        lock.unlock()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let built = Self.buildIndex()
            guard let self else { return }
            self.lock.lock()
            self.index = built
            self.isLoaded = true
            self.isLoading = false
            self.lock.unlock()
        }
    }

    public func words(first: Character, last: Character) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        if !isLoaded {
            let common = SwipeDecoder.commonWords.filter { $0.first == first && $0.last == last }
            return common
        }
        return index[Self.key(first: first, last: last)] ?? []
    }

    static func buildIndex() -> [String: [String]] {
        var index: [String: [String]] = [:]
        var seen = Set<String>()
        func add(_ word: String) {
            guard (2...20).contains(word.count), seen.insert(word).inserted,
                  word.allSatisfy({ $0 >= "a" && $0 <= "z" }),
                  let first = word.first, let last = word.last else { return }
            index[key(first: first, last: last), default: []].append(word)
        }
        for word in SwipeDecoder.commonWords {
            add(word)
        }
        let paths = ["/usr/share/dict/words", "/usr/share/dict/web2"]
        if let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }),
           let contents = try? String(contentsOfFile: path, encoding: .utf8) {
            for line in contents.split(separator: "\n") {
                guard let first = line.first, first.isLowercase else { continue }
                add(String(line))
            }
        }
        return index
    }
}
