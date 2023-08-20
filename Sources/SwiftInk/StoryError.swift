import Foundation

enum StoryError: Error {
    case badCast(valueObject: Any?, sourceType: ValueType, targetType: ValueType)
    case exactInternalStoryLocationNotFound(pathStr: String)
    case contentAlreadyHasParent(parent: Object)
    
    case unexpectedNumberOfParameters
    case performOperationOnVoid
    case cannotPerformOperation(name: String, valType: ValueType)
    case unexpectedNumberOfParametersToNativeFunctionCall(params: Int)
    case cannotPerformBinaryOperation(name: String, lhs: ValueType, rhs: ValueType)
    
    case couldNotFindListItem(value: Int, listName: String)
    case couldNotMixListWithValueInOperation(valueType: ValueType)
    
    case cannotAssignToUndeclaredVariable(name: String)
    case cannotPassNilToVariableState
    case invalidValuePassedToVariableState(value: Any?)
    
    case unsupportedRuntimeObjectType(valType: String)
    
    case contentAtPathNotFound(path: String)
    
    case cannotDestroyDefaultFlow
    
    case poppingTooManyObjects
    
    case invalidArgument(argName: String)
    
    case expectedExternalFunctionEvaluationComplete(stackTrace: String)
}
