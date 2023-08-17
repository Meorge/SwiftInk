import Foundation

public class DivertTargetValue: Object, BaseValue, CustomStringConvertible {
    public var value: Path?
    
    public typealias T = Path
    
    public var valueType: ValueType {
        .DivertTarget
    }
    
    public var isTruthy: Bool {
        // TODO: throw an exception here
        false
    }
    
    public var targetPath: Path {
        get {
            value!
        }
        set {
            value = newValue
        }
    }
    
    public init(_ targetPath: Path?) {
        value = targetPath
    }
    
    public convenience override init() {
        self.init(nil)
    }
    
    public func Cast(_ newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public var description: String {
        "DivertTargetValue(\(targetPath))"
    }
}
