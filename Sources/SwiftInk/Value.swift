//
//  File.swift
//  
//
//  Created by Malcolm Anderson on 8/15/23.
//

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
    
    func Cast(_ newType: ValueType) -> (any BaseValue)?
    
    var value: T? { get set }
    
    // TODO: BadCastException
}
