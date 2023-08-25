import Foundation

public class ListValue: Object, BaseValue {
    public var value: InkList?
    
    public typealias T = InkList
    
    public var valueType: ValueType {
        .List
    }
    
    public var isTruthy: Bool {
        value!.count > 0
    }
    
    public func Cast(_ newType: ValueType) throws -> (any BaseValue)? {
        if newType == valueType {
            return self
        }
        
        if newType == .Int {
            var maxItem = value?.maxItem
            if maxItem?.key == nil {
                return IntValue(0)
            }
            else {
                return IntValue(maxItem!.value)
            }
        }
        
        if newType == .Float {
            var maxItem = value?.maxItem
            if maxItem?.key == nil {
                return FloatValue(0.0)
            }
            else {
                return FloatValue(Float(maxItem!.value))
            }
        }
        
        if newType == .String {
            var maxItem = value?.maxItem
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
    
    public static func RetainListOriginsForAssignment(_ oldValue: Object?, _ newValue: Object?) {
        var oldList = oldValue as? ListValue
        var newList = newValue as? ListValue
        
        if oldList != nil && newList != nil && newList!.value!.count == 0 {
            newList!.value!.SetInitialOriginNames(oldList!.value?.originNames)
        }
    }
}
