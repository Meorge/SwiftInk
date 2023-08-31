import Foundation

public class FloatValue: Object, BaseValue {
    public var isTruthy: Bool {
        value! != 0.0
    }
    
    public var value: Float?
    
    public typealias T = Float
    
    public var valueType: ValueType {
        .float
    }
    
    public func cast(to newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        if newType == .bool {
            return BoolValue(value == 0.0 ? false : true)
        }
        
        if newType == .int {
            return IntValue(Int(value!))
        }
        
        if newType == .string {
            return StringValue(String(describing: value!))
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public init(_ floatVal: Float) {
        value = floatVal
    }
    
    public convenience override init() {
        self.init(0.0)
    }
    
    public var description: String {
        "\(value!)"
    }
}
