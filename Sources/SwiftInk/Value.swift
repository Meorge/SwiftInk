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

public protocol BaseValue<T>: Equatable, CustomStringConvertible {
    associatedtype T = Equatable
    var valueType: ValueType { get }
    var isTruthy: Bool { get }
    
    func Cast(_ newType: ValueType) throws -> (any BaseValue)?
    
    var value: T? { get set }
    
    var description: String { get }
}

extension BaseValue {
    var valueObject: Any? {
        value as Any?
    }
}

public func CreateValue(_ val: Any?) -> Object? {
    print("CREATE A VALUE FROM '\(val)'")
    if val is Bool {
        print("this is a bool")
        return BoolValue(val as! Bool)
    }
    else if val is Int {
        print("this is an int")
        return IntValue(val as! Int)
    }
    else if val is Float || val is Double {
        print("this is a float")
        return FloatValue(Float(val as! Double))
    }
    else if val is String {
        print("this is a string")
        return StringValue(val as! String)
    }
    else if val is Path {
        print("this is a path")
        return DivertTargetValue((val as! Path))
    }
    else if val is InkList {
        print("this is a list")
        return ListValue(val as! InkList)
    }
    
    print("couldn't figure this one out :(")
    return nil
}
