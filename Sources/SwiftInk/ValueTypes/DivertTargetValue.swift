import Foundation

public class DivertTargetValue: Object, BaseValue {
    public var value: Path?
    
    public typealias T = Path
    
    public var valueType: ValueType {
        .divertTarget
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
    
    public func cast(to newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public var description: String {
        "DivertTargetValue(\(targetPath))"
    }
}
