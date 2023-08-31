import Foundation
import SwiftyJSON

public class CallStack {
    public class Element {
        public var currentPointer: Pointer
        
        public var inExpressionEvaluation: Bool
        public var temporaryVariables: [String: Object?]
        public var type: PushPopType
        
        /// When this callstack element is actually a function evaluation called from the game, we need to keep track of the size of the evaluation stack when it was called so that we know whether there was any return value.
        public var evaluationStackHeightWhenPushed: Int = 0
        
        // MARK: name misspelled!!! this is UNFORGIVABLE
        /// When functions are called, we trim whitespace from the start and end of what they generate, so we make sure we know where the function's start and end are.
        public var functionStartInOuputStream: Int = 0
        
        public init(_ type: PushPopType, _ pointer: Pointer, _ inExpressionEvaluation: Bool = false) {
            self.currentPointer = pointer
            self.inExpressionEvaluation = inExpressionEvaluation
            self.temporaryVariables = [:]
            self.type = type
        }
        
        public func copy() -> Element {
            let copy = Element(self.type, currentPointer, self.inExpressionEvaluation)
            copy.temporaryVariables = temporaryVariables
            copy.evaluationStackHeightWhenPushed = evaluationStackHeightWhenPushed
            copy.functionStartInOuputStream = functionStartInOuputStream
            return copy
        }
    }
    
    public class Thread {
        public var callstack: [Element]
        public var threadIndex: Int = 0
        public var previousPointer: Pointer = Pointer.null
        
        public init() {
            callstack = []
        }
        
        public convenience init(_ jThreadObj: [String: JSON], _ storyContext: Story) throws {
            self.init()
            
            let jThreadCallstack = jThreadObj["callstack"]!.arrayValue
            for jElTok in jThreadCallstack {
                let jElementObj = jElTok.dictionaryValue
                let pushPopType = PushPopType(rawValue: jElementObj["type"]!.intValue)
                
                var pointer = Pointer.null
                
                var currentContainerPathStr: String? = nil
                var _: Any?
                if let currentContainerPathStrToken = jElementObj["cPath"]?.object {
                    currentContainerPathStr = String(describing: currentContainerPathStrToken)
                    
                    let threadPointerResult = storyContext.contentAtPath(Path(fromComponentsString: currentContainerPathStr!))
                    pointer.container = threadPointerResult!.container
                    pointer.index = jElementObj["idx"]!.intValue
                    
                    if threadPointerResult!.obj == nil {
                        throw StoryError.exactInternalStoryLocationNotFound(pathStr: currentContainerPathStr ?? "nil")
                    }
                    else if threadPointerResult!.approximate {
                        storyContext.warning("When loading state, exact internal story location couldn't be found: '\(currentContainerPathStr!)', so it was approximated to '\(pointer.container!.path)' to recover. Has the story changed since this save data was created?")
                    }
                }
                
                let inExpressionEvaluation = jElementObj["exp"]!.boolValue
                
                let el = Element(pushPopType!, pointer, inExpressionEvaluation)
                
                if let temps = jElementObj["temp"]?.dictionary {
                    el.temporaryVariables = try jsonObjectToDictionaryRuntimeObjs(jsonObject: temps)
                }
                else {
                    el.temporaryVariables = [:]
                }
                
                callstack.append(el)
            }
            
            if let prevContentObjPath = jThreadObj["previousContentObject"] {
                let prevPath = Path(fromComponentsString: String(describing: prevContentObjPath))
                previousPointer = try storyContext.pointer(at: prevPath)
            }
        }
        
        public func copy() -> Thread {
            let copy = Thread()
            copy.threadIndex = threadIndex
            for e in callstack {
                copy.callstack.append(e.copy())
            }
            copy.previousPointer = previousPointer
            return copy
        }
        
        public func writeJSON() -> JSON {
            var obj = JSON()
            obj["callstack"] = JSON(callstack.map { el in
                var innerObj = JSON()
                if !el.currentPointer.isNull {
                    innerObj["cPath"] = JSON(el.currentPointer.container!.path.componentsString)
                    innerObj["idx"] = JSON(el.currentPointer.index)
                }
                
                innerObj["exp"] = JSON(el.inExpressionEvaluation)
                innerObj["type"] = JSON(el.type.rawValue)
                
                if !el.temporaryVariables.isEmpty {
                    innerObj["temp"] = JSON(el.temporaryVariables.mapValues { writeRuntimeObject($0) })
                }
            })
            
            obj["threadIndex"].int = threadIndex
            
            if !previousPointer.isNull {
                obj["previousContentObject"].string = previousPointer.resolve()?.path.description
            }
            
            return obj
        }
    }
    
    public var elements: [Element] {
        callStack
    }
    
    public var depth: Int {
        elements.count
    }
    
    public var currentElement: Element {
        let thread = _threads[_threads.count - 1]
        let cs = thread.callstack
        return cs[cs.count - 1]
    }
    
    public var currentElementIndex: Int {
        callStack.count - 1
    }
    
    public var currentThread: Thread {
        get {
            return _threads[_threads.count - 1]
        }
        set {
            assert(_threads.count == 1, "Shouldn't be directly setting the current thread when we have a stack of them")
            _threads = []
            _threads.append(newValue)
        }
    }
    
    public var canPop: Bool {
        callStack.count > 1
    }
    
    public init(withStoryContext storyContext: Story) {
        _startOfRoot = Pointer.startOf(container: storyContext.rootContentContainer)
        self._threads = []
        self._threadCounter = 0
        reset()
    }
    
    public init(copying toCopy: CallStack) {
        _threads = []
        for otherThread in toCopy._threads {
            _threads.append(otherThread.copy())
        }
        _threadCounter = toCopy._threadCounter
        _startOfRoot = toCopy._startOfRoot
    }
    
    public func reset() {
        _threads = []
        _threads.append(Thread())
        
        _threads[0].callstack.append(Element(.tunnel, _startOfRoot))
    }
    
    public func setJSONToken(_ jObject: [String: JSON], withStoryContext storyContext: Story) throws {
        _threads = []

        let jThreads = jObject["threads"]!.arrayValue

        for jThreadTok in jThreads {
            let jThreadObj = jThreadTok.dictionaryValue
            let thread = try Thread(jThreadObj, storyContext)
            _threads.append(thread)
        }

        _threadCounter = jObject["threadCounter"]!.intValue
        _startOfRoot = Pointer.startOf(container: storyContext.rootContentContainer)
    }
    
    public func writeJSON() -> JSON {
        return [
            "threads": _threads.map({ $0.writeJSON() }),
            "threadCounter": JSON(_threadCounter)
        ]
    }
    
    public func pushThread() {
        let newThread = currentThread.copy()
        _threadCounter += 1
        newThread.threadIndex = _threadCounter
        _threads.append(newThread)
    }
    
    public func forkThread() -> Thread {
        let forkedThread = currentThread.copy()
        _threadCounter += 1
        forkedThread.threadIndex = _threadCounter
        return forkedThread
    }
    
    public func popThread() {
        if canPopThread {
            _ = _threads.popLast()
        }
        else {
            fatalError("Can't pop thread")
        }
    }
    
    public var canPopThread: Bool {
        _threads.count > 1 && !elementIsEvaluateFromGame
    }
    
    public var elementIsEvaluateFromGame: Bool {
        currentElement.type == .functionEvaluationFromGame
    }
    
    public func push(_ type: PushPopType, externalEvaluationStackHeight: Int = 0, outputStreamLengthWithPushed: Int = 0) {
        // When pushing to callstack, maintain the current content path, but jump out of expressions by default
        let element = Element(type, currentElement.currentPointer, false)
        
        element.evaluationStackHeightWhenPushed = externalEvaluationStackHeight
        element.functionStartInOuputStream = outputStreamLengthWithPushed
        
        currentThread.callstack.append(element)
    }
    
    public func canPop(_ type: PushPopType? = nil) -> Bool {
        if !canPop {
            return false
        }
        
        if type == nil {
            return true
        }
        
        return currentElement.type == type
    }
    
    public func pop(_ type: PushPopType? = nil) {
        if canPop(type) {
            _ = currentThread.callstack.popLast()
        }
        else {
            fatalError("Mismatched push/pop in Callstack")
        }
    }
    
    /// Get variable value, dereferencing a variable pointer if necessary
    public func temporaryVariable(named name: String, atContextIndex contextIndex: Int = -1) -> Object? {
        var _contextIndex = contextIndex
        if _contextIndex == -1 {
            _contextIndex = currentElementIndex + 1
        }
        
        let contextElement = callStack[_contextIndex - 1]
        
        if let varValue = contextElement.temporaryVariables[name] {
            return varValue
        }
        else {
            return nil
        }
    }
    
    public func setTemporaryVariable(named name: String, to value: Object?, _ declareNew: Bool, withContextIndex contextIndex: Int = -1) {
        var _contextIndex = contextIndex
        if _contextIndex == -1 {
            _contextIndex = currentElementIndex + 1
        }
        
        let contextElement = callStack[_contextIndex - 1]
        
        if !declareNew && !contextElement.temporaryVariables.keys.contains(name) {
            fatalError("Could not find temporary variable to set: \(name)")
        }
        
        if let oldValue = contextElement.temporaryVariables[name] {
            ListValue.retainListOriginsForAssignment(old: oldValue, new: value)
        }
        
        contextElement.temporaryVariables[name] = value
    }
    
    /// Find the most appropriate context for this variable.
    /// Are we referencing a temporary or global variable?
    /// Note that the compiler will have warned us about potential conflicts,
    /// so anything that happens here should be safe!
    public func contextForVariable(named name: String) -> Int {
        // Current temporary context?
        // (Shouldn't attempt to access contexts higher in the callstack.)
        if currentElement.temporaryVariables.keys.contains(name) {
            return currentElementIndex + 1
        }
        
        // Global
        else {
            return 0
        }
    }
    
    public func thread(withIndex index: Int) -> Thread? {
        return _threads.first { $0.threadIndex == index }
    }
    
    private var callStack: [Element] {
        return currentThread.callstack
    }
    
    public var callStackTrace: String {
        var sb = ""
        
        for t in 0 ..< _threads.count {
            let thread = _threads[t]
            let isCurrent = (t == _threads.count - 1)
            sb += "=== THREAD \(t+1)/\(_threads.count) \(isCurrent ? "(current)" : "")===\n"
            
            for i in 0 ..< thread.callstack.count {
                if thread.callstack[i].type == .function {
                    sb += "  [FUNCTION] "
                }
                else {
                    sb += "  [TUNNEL] "
                }
                
                let pointer = thread.callstack[i].currentPointer
                if !pointer.isNull {
                    sb += "<SOMEWHERE IN "
                    sb += String(describing: pointer.container!.path)
                    sb += ">\n"
                }
            }
        }
        
        return sb
    }
    
    var _threads: [Thread]
    var _threadCounter: Int
    var _startOfRoot: Pointer
}
