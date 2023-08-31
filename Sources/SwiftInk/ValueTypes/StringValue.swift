import Foundation

public class StringValue: Object, BaseValue {
    public var isTruthy: Bool {
        value!.count > 0
    }
    
    public var value: String?
    
    public typealias T = String
    
    public var valueType: ValueType {
        .string
    }
    
    private(set) var isNewline: Bool
    private(set) var isInlineWhitespace: Bool
    public var isNonWhitespace: Bool {
        !isNewline && !isInlineWhitespace
    }
    
    public init(_ str: String) {
        value = str
        // Classify whitespace status
        isNewline = value == "\n"
        isInlineWhitespace = true
        for c in value! {
            if c != " " && c != "\t" {
                isInlineWhitespace = false
                break
            }
        }
    }
    
    public convenience override init() {
        self.init("")
    }
    
    public func cast(to newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        // NOTE: no casting to bool??
        
        if newType == .int {
            if let parsedInt = Int(value!) {
                return IntValue(parsedInt)
            }
            else {
                return nil
            }
        }
        
        if newType == .float {
            if let parsedFloat = Float(value!) {
                return FloatValue(parsedFloat)
            }
            else {
                return nil
            }
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public var description: String {
        "\(value!)"
    }
}
