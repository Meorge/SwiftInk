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
    
    case inkVersionNotFound
    case storyInkVersionIsNewer
    case storyInkVersionTooOld
    case rootNodeNotFound
    
    case cannotSwitchFlowDueToBackgroundSavingMode(flowName: String)
    
    case cannotContinue
    
    case errorsOnContinue(_ sb: String)
    
    case cantSaveOnBackgroundThreadTwice
    
    case nonIntWhenCreatingListFromNumericalValue
    case failedToFindList(called: String)
    
    case expectedListMinAndMaxForListRange
    case expectedListForListRandom
    
    case choosePathStringCalledDuringFunction(funcDetail: String, pathString: String, stackTrace: String)
    case cannotPerformActionBecauseAsync(activityStr: String)
    
    case nullFunction
    case functionIsEmptyOrWhitespace
    case functionDoesntExist(name: String)
    
    case variableNotDeclared(variableName: String)
    
    case variableNotStandardType
    
    case genericError(message: String, useEndLineNumber: Bool)
    case assertionFailure(_ message: String, _ currentDebugMetadata: DebugMetadata?)
    case shouldntReachHere
}
