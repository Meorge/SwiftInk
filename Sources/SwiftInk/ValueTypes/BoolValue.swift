import Foundation

public class BoolValue: Object, BaseValue {
    public var isTruthy: Bool {
        value!
    }
    
    public var value: Bool?
    
    public typealias T = Bool
    
    public var valueType: ValueType {
        .bool
    }
    
    public func cast(to newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        if newType == .int {
            return IntValue(value! ? 1 : 0)
        }
        
        if newType == .float {
            return FloatValue(value! ? 1.0 : 0.0)
        }
        
        if newType == .string {
            return StringValue(value! ? "true" : "false")
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public init(_ boolVal: Bool) {
        value = boolVal
    }
    
    public convenience override init() {
        self.init(false)
    }
    
    public var description: String {
        "\(value!)"
    }
}
