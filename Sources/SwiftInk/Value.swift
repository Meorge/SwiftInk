import Foundation

public enum ValueType: Int
{
    case Bool = -1
    case Int
    case Float
    case List
    case String
    
    case DivertTarget
    case VariablePointer
}

public protocol BaseValue<T>: Equatable {
    associatedtype T = Equatable
    var valueType: ValueType { get }
    var isTruthy: Bool { get }
    
    func Cast(_ newType: ValueType) throws -> (any BaseValue)?
    
    var value: T? { get set }
}

extension BaseValue {
    var valueObject: Any? {
        value as Any?
    }
}

public func CreateValue(_ val: Any?) -> Object? {
    if val is Bool {
        return BoolValue(val as! Bool)
    }
    else if val is Int {
        return IntValue(val as! Int)
    }
    else if val is Float || val is Double {
        return FloatValue(val as! Float)
    }
    else if val is String {
        return StringValue(val as! String)
    }
    else if val is Path {
        return DivertTargetValue((val as! Path))
    }
    else if val is InkList {
        return ListValue(val as! InkList)
    }
    
    return nil
}
