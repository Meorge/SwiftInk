import Foundation

public enum ValueType: Int
{
    case bool = -1
    case int
    case float
    case list
    case string
    
    case divertTarget
    case variablePointer
}

public protocol BaseValue<T>: Equatable, CustomStringConvertible {
    associatedtype T = Equatable
    var valueType: ValueType { get }
    var isTruthy: Bool { get }
    
    func cast(to newType: ValueType) throws -> (any BaseValue)?
    
    var value: T? { get set }
    
    var description: String { get }
}

extension BaseValue {
    var valueObject: Any? {
        value as Any?
    }
}

public func createValue(fromAny val: Any?) -> Object? {
    let val = val!
    switch val {
    case is Int:
        return IntValue(val as! Int)
    case is Bool:
        return BoolValue(val as! Bool)
    case is Float:
        fallthrough
    case is Double:
        return FloatValue(val as! Float)
    case is String:
        return StringValue(val as! String)
    case is Path:
        return DivertTargetValue((val as! Path))
    case is InkList:
        return ListValue(val as! InkList)
    default:
        return nil
    }
}
