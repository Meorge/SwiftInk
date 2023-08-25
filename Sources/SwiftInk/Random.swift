import Foundation

// https://www.advancedswift.com/swift-random-numbers/#swift-random-seed
// honestly kinda baffled this isn't built into swift already but okay
struct Random: RandomNumberGenerator {
    init(withSeed seed: Int) {
        srand48(seed)
    }
    
    func next() -> UInt64 {
        return withUnsafeBytes(of: drand48()) { bytes in
            bytes.load(as: UInt64.self)
        }
    }
}
