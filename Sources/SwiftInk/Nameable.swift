import Foundation

public protocol Nameable {
    var name: String? { get }
    var hasValidName: Bool { get }
}
