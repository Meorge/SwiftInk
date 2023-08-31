import Foundation

public class ListValue: Object, BaseValue {
    public var value: InkList?
    
    public typealias T = InkList
    
    public var valueType: ValueType {
        .list
    }
    
    public var isTruthy: Bool {
        value!.count > 0
    }
    
    public func cast(to newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        if newType == .int {
            let maxItem = value?.maxItem
            if maxItem?.key == nil {
                return IntValue(0)
            }
            else {
                return IntValue(maxItem!.value)
            }
        }
        
        if newType == .float {
            let maxItem = value?.maxItem
            if maxItem?.key == nil {
                return FloatValue(0.0)
            }
            else {
                return FloatValue(Float(maxItem!.value))
            }
        }
        
        if newType == .string {
            let maxItem = value?.maxItem
            if maxItem?.key == nil {
                return StringValue("")
            }
            else {
                return StringValue(String(describing: maxItem!.key))
            }
        }
        
        throw StoryError.badCast(valueObject: self, sourceType: valueType, targetType: newType)
    }
    
    public override init() {
        value = InkList()
    }
    
    public init(_ list: InkList) {
        value = InkList(list)
    }
    
    public init(_ singleItem: InkListItem, _ singleValue: Int) {
        value = InkList((singleItem, singleValue))
    }
    
    public static func retainListOriginsForAssignment(old oldValue: Object?, new newValue: Object?) {
        let oldList = oldValue as? ListValue
        let newList = newValue as? ListValue
        
        if oldList != nil && newList != nil && newList!.value!.count == 0 {
            newList!.value!.setInitialOriginNames(oldList!.value?.originNames)
        }
    }
    
    public var description: String {
        "\(value!)"
    }
}
