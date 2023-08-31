import Foundation

public struct Pointer: CustomStringConvertible {
    public var container: Container?
    public var index: Int
    
    public init(forContainer container: Container?, atIndex index: Int) {
        self.container = container
        self.index = index
    }
    
    public func resolve() -> Object? {
        if index < 0 {
            return container
        }
        if container == nil {
            return nil
        }
        if container!.content.count == 0 {
            return container
        }
        if index >= container!.content.count {
            return nil
        }
        return container!.content[index]
    }
    
    public var isNull: Bool {
        container == nil
    }
    
    public var path: Path? {
        if isNull {
            return nil
        }
        
        if index >= 0 {
            return container!.path.path(byAppendingComponent: Path.Component(index))
        }
        else {
            return container!.path
        }
    }
    
    public var description: String {
        if container == nil {
            return "Ink Pointer (nil)"
        }
        
        return "Ink Pointer -> \(container!.path) -- index \(index)"
    }
    
    public static func startOf(container: Container?) -> Pointer {
        return Pointer(forContainer: container, atIndex: 0)
    }
    
    public static let null = Pointer(forContainer: nil, atIndex: -1)
}
