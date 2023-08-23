import Foundation

public class CallStack {
    public class Element {
        public var currentPointer: Pointer
        
        public var inExpressionEvaluation: Bool
        public var temporaryVariables: [String: Object]
        public var type: PushPopType
        
        /// When this callstack element is actually a function evaluation called from the game, we need to keep track of the size of the evaluation stack when it was called so that we know whether there was any return value.
        public var evaluationStackHeightWhenPushed: Int
        
        // MARK: name misspelled!!! this is UNFORGIVABLE
        /// When functions are called, we trim whitespace from the start and end of what they generate, so we make sure we know where the function's start and end are.
        public var functionStartInOuputStream: Int
        
        public init(_ type: PushPopType, _ pointer: Pointer, _ inExpressionEvaluation: Bool = false) {
            self.currentPointer = pointer
            self.inExpressionEvaluation = inExpressionEvaluation
            self.temporaryVariables = [:]
            self.type = type
        }
        
        public func Copy() -> Element {
            var copy = Element(self.type, currentPointer, self.inExpressionEvaluation)
            copy.temporaryVariables = temporaryVariables
            copy.evaluationStackHeightWhenPushed = evaluationStackHeightWhenPushed
            copy.functionStartInOuputStream = functionStartInOuputStream
            return copy
        }
    }
    
    public class Thread {
        public var callstack: [Element]
        public var threadIndex: Int
        public var previousPointer: Pointer
        
        public init() {
            callstack = []
        }
        
        public convenience init(_ jThreadObj: [String: Any], _ storyContext: Story) throws {
            self.init()
            
            var jThreadCallstack = jThreadObj["callstack"] as! Array<Any>
            for jElTok in jThreadCallstack {
                var jElementObj = jElTok as! Dictionary<String, Any>
                var pushPopType = PushPopType(rawValue: jElementObj["type"] as! Int)
                
                var pointer = Pointer.Null
                
                var currentContainerPathStr: String? = nil
                var currentContainerPathStrToken: Any?
                if let currentContainerPathStrToken = jElementObj["cPath"] {
                    currentContainerPathStr = String(describing: currentContainerPathStrToken)
                    
                    var threadPointerResult = storyContext.ContentAtPath(Path(currentContainerPathStr))
                    pointer.container = threadPointerResult.container
                    pointer.index = jElementObj["idx"] as! Int
                    
                    if threadPointerResult.obj == nil {
                        throw StoryError.exactInternalStoryLocationNotFound(pathStr: currentContainerPathStr ?? "nil")
                    }
                    else if threadPointerResult.approximate {
                        storyContext.Warning("When loading state, exact internal story location couldn't be found: '\(currentContainerPathStr)', so it was approximated to '\(pointer.container.path)' to recover. Has the story changed since this save data was created?")
                    }
                }
                
                var inExpressionEvaluation = jElementObj["exp"] as! Bool
                
                var el = Element(pushPopType!, pointer, inExpressionEvaluation)
                
                if let temps = jElementObj["temp"] {
                    // TODO: Handle the JSON stuff in here!!
                }
                else {
                    el.temporaryVariables = [:]
                }
                
                callstack.append(el)
            }
            
            var prevContentObjPath: Any?
            if let prevContentObjPath = jThreadObj["previousContentObject"] {
                var prevPath = Path(String(describing: prevContentObjPath))
                previousPointer = storyContext.PointerAtPath(prevPath)
            }
        }
        
        public func Copy() -> Thread {
            var copy = Thread()
            copy.threadIndex = threadIndex
            for e in callstack {
                copy.callstack.append(e.Copy())
            }
            copy.previousPointer = previousPointer
            return copy
        }
        
        // TODO: Write JSON!!
        public func WriteJson() {
            
        }
    }
    
    public var elements: [Element] {
        callStack
    }
    
    public var depth: Int {
        elements.count
    }
    
    public var currentElement: Element {
        var thread = _threads[_threads.count - 1]
        var cs = thread.callstack
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
    
    public init(_ storyContext: Story) {
        _startOfRoot = Pointer.StartOf(storyContext.rootContentContainer)
        Reset()
    }
    
    public init(_ toCopy: CallStack) {
        _threads = []
        for otherThread in toCopy._threads {
            _threads.append(otherThread.Copy())
        }
        _threadCounter = toCopy._threadCounter
        _startOfRoot = toCopy._startOfRoot
    }
    
    public func Reset() {
        _threads = []
        _threads.append(Thread())
        
        _threads[0].callstack.append(Element(.Tunnel, _startOfRoot))
    }
    
    public func SetJsonToken(_ jObject: [String: Any?], _ storyContext: Story) {
        // TODO: Implement!
    }
    
    public func WriteJson() {
        // TODO: Implement!
    }
    
    public func PushThread() {
        var newThread = currentThread.Copy()
        _threadCounter += 1
        newThread.threadIndex = _threadCounter
        _threads.append(newThread)
    }
    
    public func ForkThread() -> Thread {
        var forkedThread = currentThread.Copy()
        _threadCounter += 1
        forkedThread.threadIndex = _threadCounter
        return forkedThread
    }
    
    public func PopThread() {
        if canPopThread {
            _threads.popLast()
        }
        else {
            fatalError("Can't pop thread")
        }
    }
    
    public var canPopThread: Bool {
        _threads.count > 1 && !elementIsEvaluateFromGame
    }
    
    public var elementIsEvaluateFromGame: Bool {
        currentElement.type == .FunctionEvaluationFromGame
    }
    
    public func Push(_ type: PushPopType, externalEvaluationStackHeight: Int = 0, outputStreamLengthWithPushed: Int = 0) {
        // When pushing to callstack, maintain the current content path, but jump out of expressions by default
        var element = Element(type, currentElement.currentPointer, false)
        
        element.evaluationStackHeightWhenPushed = externalEvaluationStackHeight
        element.functionStartInOuputStream = outputStreamLengthWithPushed
        
        currentThread.callstack.append(element)
    }
    
    public func CanPop(_ type: PushPopType? = nil) -> Bool {
        if !canPop {
            return false
        }
        
        if type == nil {
            return true
        }
        
        return currentElement.type == type
    }
    
    public func Pop(_ type: PushPopType? = nil) {
        if CanPop(type) {
            currentThread.callstack.popLast()
        }
        else {
            fatalError("Mismatched push/pop in Callstack")
        }
    }
    
    /// Get variable value, dereferencing a variable pointer if necessary
    public func GetTemporaryVariableWithName(_ name: String, _ contextIndex: Int = -1) -> Object? {
        var _contextIndex = contextIndex
        if _contextIndex == -1 {
            _contextIndex = currentElementIndex + 1
        }
        
        var contextElement = callStack[_contextIndex - 1]
        
        if let varValue = contextElement.temporaryVariables[name] {
            return varValue
        }
        else {
            return nil
        }
    }
    
    public func SetTemporaryVariable(_ name: String, _ value: Object?, _ declareNew: Bool, _ contextIndex: Int = -1) {
        var _contextIndex = contextIndex
        if _contextIndex == -1 {
            _contextIndex = currentElementIndex + 1
        }
        
        var contextElement = callStack[_contextIndex - 1]
        
        if !declareNew && !contextElement.temporaryVariables.keys.contains(name) {
            fatalError("Could not find temporary variable to set: \(name)")
        }
        
        if let oldValue = contextElement.temporaryVariables[name] {
            ListValue.RetainListOriginsForAssignment(oldValue, value!)
        }
        
        contextElement.temporaryVariables[name] = value
    }
    
    /// Find the most appropriate context for this variable.
    /// Are we referencing a temporary or global variable?
    /// Note that the compiler will have warned us about potential conflicts,
    /// so anything that happens here should be safe!
    public func ContextForVariableNamed(_ name: String) -> Int {
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
    
    public func ThreadWithIndex(_ index: Int) -> Thread? {
        return _threads.first { $0.threadIndex == index }
    }
    
    private var callStack: [Element] {
        return currentThread.callstack
    }
    
    public var callStackTrace: String {
        var sb = ""
        
        for t in 0 ..< _threads.count {
            var thread = _threads[t]
            var isCurrent = (t == _threads.count - 1)
            sb += "=== THREAD \(t+1)/\(_threads.count) \(isCurrent ? "(current)" : "")===\n"
            
            for i in 0 ..< thread.callstack.count {
                if thread.callstack[i].type == .Function {
                    sb += "  [FUNCTION] "
                }
                else {
                    sb += "  [TUNNEL] "
                }
                
                var pointer = thread.callstack[i].currentPointer
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
