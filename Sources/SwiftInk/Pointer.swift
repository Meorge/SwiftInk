import Foundation

public struct Pointer: CustomStringConvertible {
    public var container: Container?
    public var index: Int
    
    public init(_ container: Container?, _ index: Int) {
        self.container = container
        self.index = index
    }
    
    public func Resolve() -> Object? {
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
            return container!.path.PathByAppendingComponent(Path.Component(index))
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
    
    public static func StartOf(_ container: Container?) -> Pointer {
        return Pointer(container, 0)
    }
    
    public static let Null = Pointer(nil, -1)
}
