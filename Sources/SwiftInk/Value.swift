import Foundation

public enum ValueType
{
    case Bool
    case Int
    case Float
    case List
    case String
    
    case DivertTarget
    case VariablePointer
}

public protocol BaseValue<T> {
    associatedtype T
    var valueType: ValueType { get }
    var isTruthy: Bool { get }
    
    func Cast(_ newType: ValueType) throws -> (any BaseValue)?
    
    var value: T? { get set }
}
