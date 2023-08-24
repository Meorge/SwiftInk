import Foundation

public protocol StoryEventHandler {
    func onError(withMessage message: String, ofType type: ErrorType)
    func onWarning()
    
    func onDidContinue()
    
    func onMakeChoice(named choice: Choice)
    
    func onEvaluateFunction(named functionName: String, withArguments arguments: [Any?])
    
    func onCompleteEvaluateFunction(named functionName: String, withArguments arguments: [Any?], outputtingText textOutput: String, withResult result: Any?)
    
    func onChoosePathString(atPath path: String, withArguments arguments: [Any?])
}

public typealias VariableObserver = (_ variableName: String, _ newValue: Any?) -> Void

public class VariableChangeHandler: Equatable, Hashable {
    public static func == (lhs: VariableChangeHandler, rhs: VariableChangeHandler) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    let id: UUID
    var onVariableChanged: VariableObserver? = nil
    
    public init(_ onVariableChanged: @escaping VariableObserver) {
        self.id = UUID()
        self.onVariableChanged = onVariableChanged
    }
}
