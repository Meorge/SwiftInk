import Foundation
import SwiftyJSON

/// Contains all story state information,
/// including global variables, read counts, the pointer to the current
/// point in the story, the call stack (for tunnels, functions, etc),
/// and a few other smaller bits and pieces. You can save the current
/// state using the JSON serialisation functions `ToJson` and `LoadJson`.
public class StoryState {
    
    // Backwards compatible changes since v8:
    // v10: dynamic tags
    // v9: multi-flows
    /// The current version of the state save file JSON-based format.
    public let kInkSaveStateVersion = 10
    let kMinCompatibleLoadVersion = 8
    
    // TODO: Make this more like a C# action where multiple closures can be added
    /// Callback for when a state is loaded
    public var onDidLoadState: (() -> Void)?
    
    /// Exports the current state to JSON format, in order to save the game,
    /// and returns it as a string.
    /// - Returns: The save state in JSON format.
    public func writeJSON() throws -> JSON {
        var obj = JSON()
        
        // Flows
        var flowsObj = JSON()
        
        // Multi-flow
        if _namedFlows != nil && !_namedFlows!.isEmpty {
            for namedFlow in _namedFlows! {
                flowsObj[namedFlow.key] = namedFlow.value.writeJSON()
            }
        }
        // Single flow
        // NOTE: In the original C# code, this branch would be executed
        // when _namedFlows was null. Here it can never be nil, so instead
        // we're checking if it's empty or not. This might not be the correct
        // behavior.
        else
        {
            flowsObj[_currentFlow.name!] = _currentFlow.writeJSON()
        }
        
        obj["flows"] = flowsObj
        
        
        obj["currentFlowName"].string = _currentFlow.name!
        obj["variablesState"] = try variablesState!.writeJSON()
        obj["evalStack"] = writeListRuntimeObjs(evaluationStack)
        
        if !divertedPointer!.isNull {
            obj["currentDivertTarget"].string = divertedPointer!.path!.componentsString
        }
        
        obj["visitCounts"] = JSON(_visitCounts)
        obj["turnIndices"] = JSON(_turnIndices)
        
        obj["turnIdx"] = JSON(currentTurnIndex)
        obj["storySeed"] = JSON(storySeed)
        obj["previousRandom"] = JSON(previousRandom)
        
        obj["inkSaveVersion"] = JSON(kInkSaveStateVersion)
        obj["inkFormatVersion"] = JSON(Story.inkVersionCurrent)
        
        return obj
    }
    
    /// Loads a previously saved state in JSON format.
    /// - Parameter json: The JSON string to load.
    public func loadJSON(_ json: JSON) throws {
        guard let jSaveVersion = json["inkSaveVersion"].int else {
            fatalError("ink save format incorrect, can't load")
        }
        
        if jSaveVersion < kMinCompatibleLoadVersion {
            fatalError("ink save format isn't compatible with the current version (saw '\(jSaveVersion)', but minimum is \(kMinCompatibleLoadVersion)), so can't load.")
        }
        
        // Flows: Always exists in latest format (even if there's just one default)
        // but this dictionary doesn't exist in prev format
        if let flowsObjDict = json["flows"].dictionary {
            // Single default flow
            if flowsObjDict.count == 1 {
                _namedFlows = [:]
            }
            
            // Multi-flow, need to create flows dict
            else if _namedFlows == nil {
                _namedFlows = [:]
            }
            
            // Multi-flow, already have a flows dict
            else {
                _namedFlows!.removeAll()
            }
            
            // Load up each flow (there may only be one)
            for namedFlowObj in flowsObjDict {
                let name = namedFlowObj.key
                let flowObj = namedFlowObj.value.dictionary
                
                // Load up this flow using JSON data
                let flow = try Flow(name, story!, flowObj!)
                
                if flowsObjDict.count == 1 {
                    _currentFlow = try Flow(name, story!, flowObj!)
                }
                else {
                    _namedFlows![name] = flow
                }
            }
            
            if _namedFlows != nil && _namedFlows!.count > 1 {
                let currFlowName = json["currentFlowName"].string!
                _currentFlow = _namedFlows![currFlowName]!
            }
        }
        
        // Old format: individually load up callstack, output stream, choices in current/default flow
        else {
            _namedFlows = nil
            _currentFlow.name = kDefaultFlowName
            try _currentFlow.callStack!.setJSONToken(json["callstackThreads"].dictionaryValue, withStoryContext: story!)
            _currentFlow.outputStream = try jsonArrayToRuntimeObjList(jsonArray: json["outputStream"].arrayValue)
            _currentFlow.currentChoices = try jsonArrayToRuntimeObjList(jsonArray: json["currentChoices"].arrayValue).map { $0 as! Choice }
            
            var choiceThreadsObj = json["choiceThreads"].dictionary
            try _currentFlow.loadFlow(withChoiceThreadsJSON: choiceThreadsObj!, forStory: story!)
        }
        
        markOutputStreamDirty()
        _aliveFlowNamesDirty = true
        
        try variablesState?.setJSONToken(json["variablesState"])
        variablesState?.callStack = _currentFlow.callStack
        
        evaluationStack = try jsonArrayToRuntimeObjList(jsonArray: json["evalStack"].arrayValue)
        
        if let currentDivertTargetPath = json["currentDivertTarget"].string {
            divertedPointer = try story?.pointer(at: Path(fromComponentsString: currentDivertTargetPath))
        }
        
        _visitCounts = json["visitCounts"].dictionary!.mapValues { $0.intValue }
        _turnIndices = json["turnIndices"].dictionary!.mapValues { $0.intValue }
        
        currentTurnIndex = json["turnIdx"].intValue
        storySeed = json["storySeed"].intValue
        
        // Not optional, but bug in inkjs means it's actually missing in inkjs saves
        if let previousRandomObj = json["previousRandom"].int {
            previousRandom = previousRandomObj
        }
        else {
            previousRandom = 0
        }
        
    }
    
    /// Gets the visit/read count of a particular `Container` at the given path.
    ///
    /// For a knot or stitch, the path string will be in the form
    /// ```
    /// knot
    /// knot.stitch
    /// ```
    /// - Parameter pathString: The dot-separated path string of the specific knot or stitch.
    /// - Returns: The number of times the specific knot or stitch has been encountered by the ink engine.
    public func visitCounts(atPathString pathString: String) throws -> Int {
        if _patch != nil {
            guard let container = story!.contentAtPath(Path(fromComponentsString: pathString))?.container else {
                throw StoryError.contentAtPathNotFound(path: pathString)
            }
            
            if let visitCountOut = _patch?.visitCounts[container] {
                return visitCountOut
            }
        }
        
        if let visitCountOut = _visitCounts[pathString] {
            return visitCountOut
        }
        
        return 0
    }
    
    public func visitCounts(forContainer container: Container) throws -> Int {
        if !container.visitsShouldBeCounted {
            try story?.error("Read count for target (\(container.name!) - on \(container.debugMetadata!)) unknown")
            return 0
        }
        
        if let count = _patch?.visitCounts[container] {
            return count
        }
        
        return _visitCounts[container.path.description] ?? 0
    }
    
    public func incrementVisitCount(forContainer container: Container) throws {
        if _patch != nil {
            var currCount = try visitCounts(forContainer: container)
            currCount += 1
            _patch!._visitCounts[container] = currCount
            return
        }
        
        if var count = _visitCounts[container.path.description] {
            count += 1
            _visitCounts[container.path.description] = count
        }
    }
    
    public func recordTurnIndexVisit(toContainer container: Container) {
        if _patch != nil {
            _patch!._turnIndices[container] = currentTurnIndex
            return
        }
        
        _turnIndices[container.path.description] = currentTurnIndex
    }
    
    public func turnsSince(forContainer container: Container) throws -> Int {
        if !container.turnIndexShouldBeCounted {
            try story?.error("TURNS_SINCE() for target (\(container.name!) - on \(container.debugMetadata!)) unknown.")
        }
        
        if let index = _patch?.turnIndices[container] {
            return currentTurnIndex - index
        }
        
        if let index = _turnIndices[container.path.description] {
            return currentTurnIndex - index
        }
        
        return -1
    }
    
    public var callstackDepth: Int {
        callStack.depth
    }
    
    // REMEMBER! REMEMBER! REMEMBER!
    // When adding state, update the Copy method, and serialisation.
    // REMEMBER! REMEMBER! REMEMBER!
    
    public var outputStream: [Object] {
        _currentFlow.outputStream
    }
    
    public var currentChoices: [Choice] {
        // If we can continue generating text content rather than choices,
        // then we reflect the choice list as being empty, since choices
        // should always come at the end.
        canContinue ? [] : _currentFlow.currentChoices
    }
    
    public var generatedChoices: [Choice] {
        _currentFlow.currentChoices
    }
    
    // TODO: Consider removing currentErrors / currentWarnings altogether
    // and relying on client error handler code immediately handling StoryExceptions etc
    // Or is there a specific reason we need to collect potentially multiple
    // errors before throwing/exiting?
    private(set) var currentErrors: [String] = []
    private(set) var currentWarnings: [String] = []
    private(set) var variablesState: VariablesState?
    public var callStack: CallStack {
        _currentFlow.callStack!
    }
    
    private(set) var evaluationStack: [Object] = []
    public var divertedPointer: Pointer?
    
    private(set) var currentTurnIndex: Int
    public var storySeed: Int
    public var previousRandom: Int
    public var didSafeExit: Bool
    
    public var story: Story?
    
    /// String representation of the location where the story currently is.
    public var currentPathString: String? {
        currentPointer.isNull ? nil : currentPointer.path!.description
    }
    
    public var currentPointer: Pointer {
        get {
            callStack.currentElement.currentPointer
        }
        set {
            callStack.currentElement.currentPointer = newValue
        }
    }
    
    public var previousPointer: Pointer {
        get {
            callStack.currentThread.previousPointer
        }
        set {
            callStack.currentThread.previousPointer = newValue
        }
    }
    
    public var canContinue: Bool {
        !currentPointer.isNull && !hasError
    }
    
    public var hasError: Bool {
        currentErrors.count > 0
    }
    
    public var hasWarning: Bool {
        currentWarnings.count > 0
    }
    
    public var currentText: String {
        if _outputStreamTextDirty {
            var sb = ""
            
            var inTag = false
            for outputObj in outputStream {
                if !inTag, let textContent = outputObj as? StringValue {
                    sb += textContent.value!
                }
                else {
                    if let controlCommand = outputObj as? ControlCommand {
                        if controlCommand.commandType == .beginTag {
                            inTag = true
                        }
                        else if controlCommand.commandType == .endTag {
                            inTag = false
                        }
                    }
                }
            }
            
            _currentText = cleanOutputWhitespace(sb)
            _outputStreamTextDirty = false
        }
        
        return _currentText
    }
    var _currentText: String = ""
    
    public func cleanOutputWhitespace(_ str: String) -> String {
        var sb = ""
        
        var currentWhitespaceStart = -1
        var startOfLine = 0
        
        let charArray = Array(str.unicodeScalars)
        for i in 0 ..< charArray.count {
            let c = charArray[i]
            
            let isInlineWhitespace = c == " " || c == "\t"
            
            if isInlineWhitespace && currentWhitespaceStart == -1 {
                currentWhitespaceStart = i
            }
            
            if !isInlineWhitespace {
                if c != "\n" && currentWhitespaceStart > 0 && currentWhitespaceStart != startOfLine {
                    sb += " "
                }
                currentWhitespaceStart = -1
            }
            
            if c == "\n" {
                startOfLine = i + 1
            }
            
            if !isInlineWhitespace {
                sb += String(c)
            }
        }
        
        return sb
    }
    
    public var currentTags: [String] {
        if _outputStreamTagsDirty {
            _currentTags = []
            
            var inTag = false
            var sb = ""
            
            for outputObj in outputStream {
                if let controlCommand = outputObj as? ControlCommand {
                    if controlCommand.commandType == .beginTag {
                        if inTag && !sb.isEmpty {
                            let txt = cleanOutputWhitespace(sb)
                            _currentTags.append(txt)
                            sb = ""
                        }
                        inTag = true
                    }
                    
                    else if controlCommand.commandType == .endTag {
                        if !sb.isEmpty {
                            let txt = cleanOutputWhitespace(sb)
                            _currentTags.append(txt)
                            sb = ""
                        }
                        inTag = false
                    }
                }
                
                else if inTag {
                    if let strVal = outputObj as? StringValue {
                        sb += strVal.value!
                    }
                }
                
                else {
                    if let tag = outputObj as? Tag, !tag.text.isEmpty {
                        _currentTags.append(tag.text)
                    }
                }
            }
            
            if !sb.isEmpty {
                let txt = cleanOutputWhitespace(sb)
                _currentTags.append(txt)
                sb = ""
            }
            
            _outputStreamTagsDirty = false
        }
        
        return _currentTags
    }
    var _currentTags: [String] = []
    
    public var currentFlowName: String {
        _currentFlow.name!
    }
    
    public var currentFlowIsDefaultFlow: Bool {
        _currentFlow.name == kDefaultFlowName
    }
    
    public var aliveFlowNames: [String] {
        if _aliveFlowNamesDirty {
            _aliveFlowNames = []
            
            if _namedFlows != nil {
                for flowName in _namedFlows!.keys {
                    if flowName != kDefaultFlowName {
                        _aliveFlowNames.append(flowName)
                    }
                }
            }
            
            _aliveFlowNamesDirty = false
        }
        
        return _aliveFlowNames
    }
    
    var _aliveFlowNames: [String] = []
    
    public var inExpressionEvaluation: Bool {
        get {
            callStack.currentElement.inExpressionEvaluation
        }
        set {
            callStack.currentElement.inExpressionEvaluation = newValue
        }
    }
    
    public init(forStory story: Story) {
        self.story = story
        self.currentTurnIndex = -1
        self.didSafeExit = false
        
        // Seed the shuffle random numbers
        self.storySeed = Int.random(in: 0 ..< 100)
        self.previousRandom = 0
        
        _currentFlow = Flow(kDefaultFlowName, story)
        
        markOutputStreamDirty()
        _aliveFlowNamesDirty = true
        
        evaluationStack = []
        
        variablesState = VariablesState(withCallstack: callStack, listDefsOrigin: story.listDefinitions!)
        
        _visitCounts = [:]
        _turnIndices = [:]
        
        goToStart()
    }
    
    public func goToStart() {
        callStack.currentElement.currentPointer = Pointer.startOf(container: story!.mainContentContainer)
    }
    
    internal func switchFlow_Internal(_ flowName: String) {
        _namedFlows = [:]
        _namedFlows![kDefaultFlowName] = _currentFlow
        
        if flowName == _currentFlow.name {
            return
        }
        
        var flow = _namedFlows![flowName]
        if flow == nil {
            flow = Flow(flowName, story!)
            _namedFlows![flowName] = flow
            _aliveFlowNamesDirty = true
        }
        
        _currentFlow = _namedFlows![flowName]!
        variablesState?.callStack = _currentFlow.callStack
        
        // Cause text to be regenerated from output stream if necessary
        markOutputStreamDirty()
    }
    
    internal func switchToDefaultFlow_Internal() {
        if _namedFlows == nil || !_namedFlows!.isEmpty {
            return
        }
        switchFlow_Internal(kDefaultFlowName)
    }
    
    internal func removeFlow_Internal(_ flowName: String) throws {
        if flowName == kDefaultFlowName {
            throw StoryError.cannotDestroyDefaultFlow
        }
        
        // If we're currently in the flow that's being removed, switch back to default
        if _currentFlow.name == flowName {
            switchToDefaultFlow_Internal()
        }
        
        
        _namedFlows?.removeValue(forKey: flowName)
        _aliveFlowNamesDirty = true
    }
    
    // Warning: Any Object content referenced within the StoryState will
    // be re-referenced rather than cloned. This is generally okay though since
    // Objects are treated as immutable after they've been set up.
    // (e.g. we don't edit a StringValue after it's been created and added.)
    // I wonder if there's a sensible way to enforce that...??
    public func copyAndStartPatching() -> StoryState {
        let copy = StoryState(forStory: story!)
        
        copy._patch = StatePatch(copying: _patch)
        
        // Hijack the new default flow to become a copy of our current one
        // If the patch is applied, then this new flow will replace the old one in _namedFlows
        copy._currentFlow.name = _currentFlow.name
        copy._currentFlow.callStack = CallStack(copying: _currentFlow.callStack!)
        copy._currentFlow.currentChoices.append(contentsOf: _currentFlow.currentChoices)
        copy._currentFlow.outputStream.append(contentsOf: _currentFlow.outputStream)
        copy.markOutputStreamDirty()
        
        // The copy of the state has its own copy of the named flows dictionary,
        // except with the current flow replaced with the copy above
        // (Assuming we're in multi-flow mode at all. If we're not then
        // the above copy is simply the default flow copy and we're done)
        copy._namedFlows = [:]
        if _namedFlows != nil {
            for namedFlow in _namedFlows! {
                copy._namedFlows![namedFlow.key] = namedFlow.value
            }
        }
        copy._namedFlows![_currentFlow.name!] = copy._currentFlow
        copy._aliveFlowNamesDirty = true
        
        if hasError {
            copy.currentErrors = currentErrors
        }
        
        if hasWarning {
            copy.currentWarnings = currentWarnings
        }
        
        // ref copy - exactly the same variables state
        // we're expecting not to read it only while in patch mode
        // (though the callstack will be modified)
        copy.variablesState = variablesState
        copy.variablesState?.callStack = copy.callStack
        copy.variablesState?.patch = copy._patch
        
        copy.evaluationStack.append(contentsOf: evaluationStack)
        
        if divertedPointer != nil && !divertedPointer!.isNull {
            copy.divertedPointer = divertedPointer
        }
        
        copy.previousPointer = previousPointer
        
        // visit counts and turn indices will be read only, not modified
        // while in patch mode
        copy._visitCounts = _visitCounts
        copy._turnIndices = _turnIndices
        
        copy.currentTurnIndex = currentTurnIndex
        copy.storySeed = storySeed
        copy.previousRandom = previousRandom
        
        copy.didSafeExit = didSafeExit
        
        return copy
    }
    
    public func restoreAfterPatch() {
        // VariablesState was being borrowed by the patched
        // state, so restore it with our own callstack.
        // _patch will be nil normally, but if you're in the
        // middle of a save, it may contain a _patch for save purposes.
        variablesState?.callStack = callStack
        variablesState?.patch = _patch // usually nil
    }
    
    public func applyAnyPatch() {
        if _patch == nil {
            return
        }
        
        variablesState?.applyPatch()
        
        for pathToCount in _patch?._visitCounts ?? [:] {
            applyCountChanges(pathToCount.key, pathToCount.value, isVisit: true)
        }
        
        for pathToIndex in _patch?.turnIndices ?? [:] {
            applyCountChanges(pathToIndex.key, pathToIndex.value, isVisit: false)
        }
        
        _patch = nil
    }
    
    func applyCountChanges(_ container: Container, _ newCount: Int, isVisit: Bool) {
        if isVisit {
            _visitCounts[container.path.description] = newCount
        }
        else {
            _turnIndices[container.path.description] = newCount
        }
    }
    
    public func resetErrors() {
        currentErrors = []
        currentWarnings = []
    }
    
    public func resetOutput(_ objs: [Object]? = nil) {
        _currentFlow.outputStream = []
        if objs != nil {
            _currentFlow.outputStream.append(contentsOf: objs!)
        }
        markOutputStreamDirty()
    }
    
    /// Push to output stream, but split out newlines in text for consistency
    /// in dealing with them later.
    public func pushToOutputStream(_ obj: Object) {
        if let text = obj as? StringValue {
            if let listText = trySplittingHeadTailWhitespace(text) {
                for textObj in listText {
                    pushToOutputStreamIndividual(textObj)
                }
                markOutputStreamDirty()
                return
            }
        }
        
        pushToOutputStreamIndividual(obj)
        
        markOutputStreamDirty()
    }
    
    public func popFromOutputStream(count: Int) {
        _currentFlow.outputStream.removeLast(count)
        markOutputStreamDirty()
    }
    
    // At both the start and the end of the string, split out the new lines like so:
    //
    //  "   \n  \n     \n  the string \n is awesome \n     \n     "
    //      ^-----------^                           ^-------^
    //
    // Excess newlines are converted into single newlines, and spaces discarded.
    // Outside spaces are significant and retained. "Interior" newlines within
    // the main string are ignored, since this is for the purpose of gluing only.
    //
    //  - If no splitting is necessary, null is returned.
    //  - A newline on its own is returned in a list for consistency.
    func trySplittingHeadTailWhitespace(_ single: StringValue) -> [StringValue]? {
        let str = single.value!
        
        var headFirstNewlineIdx = -1
        var headLastNewlineIdx = -1
        
        let charArray = Array(str.unicodeScalars)
        
        // Look for where the left side starts?
        for i in 0 ..< charArray.count {
            let c = charArray[i]
            if c == "\n" {
                if headFirstNewlineIdx == -1 {
                    headFirstNewlineIdx = i
                }
                headLastNewlineIdx = i
            }
            else if c == " " || c == "\t" {
                continue
            }
            else {
                break
            }
        }
        
        var tailLastNewlineIdx = -1
        var tailFirstNewlineIdx = -1
        for i in (0...charArray.count-1).reversed() {
            let c = charArray[i]
            if c == "\n" {
                if tailLastNewlineIdx == -1 {
                    tailLastNewlineIdx = i
                }
                tailFirstNewlineIdx = i
            }
            else if c == " " || c == "\t" {
                continue
            }
            else {
                break
            }
        }
        
        // No splitting to be done?
        if headFirstNewlineIdx == -1 && tailLastNewlineIdx == -1 {
            return nil
        }
        
        var listTexts: [StringValue] = []
        var innerStrStart = 0
        var innerStrEnd = str.count
        
        if headFirstNewlineIdx != -1 {
            if headFirstNewlineIdx > 0 {
                let startIndex = str.index(str.startIndex, offsetBy: innerStrStart)
                let endIndex = str.index(str.startIndex, offsetBy: headFirstNewlineIdx)
                let leadingSpaces = StringValue(String(str[startIndex ..< endIndex]))
                listTexts.append(leadingSpaces)
            }
            listTexts.append(StringValue("\n"))
            innerStrStart = headLastNewlineIdx + 1
        }
        
        if tailLastNewlineIdx != -1 {
            innerStrEnd = tailFirstNewlineIdx
        }
        
        if innerStrEnd > innerStrStart {
            let startIndex = str.index(str.startIndex, offsetBy: innerStrStart)
            let endIndex = str.index(str.startIndex, offsetBy: innerStrEnd)
            let innerStrText = String(str[startIndex ..< endIndex])
            listTexts.append(StringValue(innerStrText))
        }
        
        if tailLastNewlineIdx != -1 && tailFirstNewlineIdx > headLastNewlineIdx {
            listTexts.append(StringValue("\n"))
            if tailLastNewlineIdx < str.count - 1 {
                let numSpaces = (str.count - tailLastNewlineIdx) - 1
                let startIndex = str.index(str.startIndex, offsetBy: tailLastNewlineIdx + 1)
                let endIndex = str.index(str.startIndex, offsetBy: tailLastNewlineIdx + 1 + numSpaces)
                let trailingSpaces = StringValue(String(str[startIndex ..< endIndex]))
                listTexts.append(trailingSpaces)
            }
        }
        return listTexts
    }
    
    
    func pushToOutputStreamIndividual(_ obj: Object) {
        let glue = obj as? Glue
        let text = obj as? StringValue
        
        var includeInOutput = true
        
        // New glue, so comp away any whitespace from the end of the stream
        if glue != nil {
            trimNewlinesFromOutputStream()
            includeInOutput = true
        }
        
        // New text: do we really want to append it, if it's whitespace?
        // Two different reasons for whitespace to be thrown away:
        // - Function start/end trimming
        // - User defined glue: <>
        // We also need to know when to stop trimming, when there's non-whitespace.
        else if text != nil {
            // Where does the current function call begin?
            var functionTrimIndex = -1
            let currentEl = callStack.currentElement
            if currentEl.type == .function {
                functionTrimIndex = currentEl.functionStartInOuputStream
            }
            
            // Do 2 things:
            // - Find latest glue
            // - Check whether we're in the middle of string evaluation
            // If we're in string eval within the current function, we
            // don't want to trim back further than the length of the current string.
            var glueTrimIndex = -1
            if !outputStream.isEmpty {
                for i in (0 ... outputStream.count - 1).reversed() {
                    let o = outputStream[i]
                    let c = o as? ControlCommand
                    let g = o as? Glue
                    
                    // Find latest glue
                    if g != nil {
                        glueTrimIndex = i
                        break
                    }
                    
                    // Don't function-trim past the start of a string evaluation section
                    else if c != nil && c?.commandType == .beginString {
                        if i >= functionTrimIndex {
                            functionTrimIndex = -1
                        }
                        break
                    }
                }
            }
            
            // Where is the most aggressive (earliest) trim point?
            var trimIndex = -1
            if glueTrimIndex != -1 && functionTrimIndex != -1 {
                trimIndex = min(functionTrimIndex, glueTrimIndex)
            }
            else if glueTrimIndex != -1 {
                trimIndex = glueTrimIndex
            }
            else {
                trimIndex = functionTrimIndex
            }
            
            // So, are we trimming then?
            if trimIndex != -1 {
                // Whiletrimming, we want to throw all newlines away,
                // whether due to glue or the start of a function
                if text!.isNewline {
                    includeInOutput = false
                }
                
                // Able to completely reset when normal text is pushed
                else if text!.isNonWhitespace {
                    if glueTrimIndex > -1 {
                        removeExistingGlue()
                    }
                    
                    // Tell all functions in callstack that we have seen proper text,
                    // so trimming whitespace at the start is done.
                    if functionTrimIndex > -1 {
                        let callstackElements = callStack.elements
                        for i in (0 ... callstackElements.count - 1).reversed() {
                            let el = callstackElements[i]
                            if el.type == .function {
                                el.functionStartInOuputStream = -1
                            }
                            else {
                                break
                            }
                        }
                    }
                }
            }
            
            // De-duplicate newlines, and don't ever lead with a newline
            else if text!.isNewline {
                if outputStreamEndsInNewLine || !outputStreamContainsContent {
                    includeInOutput = false
                }
            }
        }
        
        if includeInOutput {
            _currentFlow.outputStream.append(obj)
            markOutputStreamDirty()
        }
    }
    
    func trimNewlinesFromOutputStream() {
        var removeWhitespaceFrom = -1
        
        // Work back from the end, and try to find the point where
        // we need to start removing content.
        // - Simply work backwards to find the first newline in a string of whitespace
        // e.g. This is the content   \n   \n\n
        //                            ^---------^ whitespace to remove
        //                        ^--- first while loop stops here
        var i = outputStream.count - 1
        while i >= 0 {
            let obj = outputStream[i]
            let cmd = obj as? ControlCommand
            let txt = obj as? StringValue
            
            if cmd != nil || (txt != nil && txt!.isNonWhitespace) {
                break
            }
            
            else if (txt != nil && txt!.isNewline) {
                removeWhitespaceFrom = i
            }
            
            i -= 1
        }
        
        // Remove the whitespace
        if removeWhitespaceFrom >= 0 {
            i = removeWhitespaceFrom
            while i < outputStream.count {
                if outputStream[i] as? StringValue != nil {
                    _currentFlow.outputStream.remove(at: i)
                }
                else {
                    i += 1
                }
            }
        }
        
        markOutputStreamDirty()
    }
    
    func removeExistingGlue() {
        for i in (0...outputStream.count - 1).reversed() {
            let c = outputStream[i]
            if c is Glue {
                _currentFlow.outputStream.remove(at: i)
            }
            else if c is ControlCommand { // e.g. BeginString
                break;
            }
        }
        
        markOutputStreamDirty()
    }
    
    public var outputStreamEndsInNewLine: Bool {
        if outputStream.count > 0 {
            for i in (0...outputStream.count - 1).reversed() {
                let obj = outputStream[i]
                
                if obj is ControlCommand { // e.g. BeginString
                    break
                }
                if let text = outputStream[i] as? StringValue {
                    if text.isNewline {
                        return true
                    }
                    else if text.isNonWhitespace {
                        break
                    }
                }
            }
        }
        
        return false
    }
    
    public var outputStreamContainsContent: Bool {
        for content in outputStream {
            if content is StringValue {
                return true
            }
        }
        return false
    }
    
    public var inStringEvaluation: Bool {
        if outputStream.isEmpty {
            return false
        }
        
        for i in (0...outputStream.count-1).reversed() {
            if let cmd = outputStream[i] as? ControlCommand, cmd.commandType == .beginString {
                return true
            }
        }
        
        return false
    }
    
    public func pushEvaluationStack(_ obj: Object) {
        // Include metadata about the origin List for list values when
        // they're used, so that lower level functions can make use
        // of the origin list to get related items, or make comparisons
        // with theinteger values etc.
        if let listValue = obj as? ListValue {
            // Update origin when list is has something to indicate the list origin
            let rawList = listValue.value!
            if rawList.originNames != nil {
                rawList.origins = []
                
                for n in rawList.originNames! {
                    if let def = story?.listDefinitions?._lists[n], !rawList.origins.contains(def) {
                        rawList.origins.append(def)
                    }
                }
            }
        }
        
        // MARK: Maybe issue here due to object vs struct tomfoolery in Swift, when dealing with lists?
        evaluationStack.append(obj)
    }
    
    public func popEvaluationStack() -> Object? {
        evaluationStack.popLast()
    }
    
    public func peekEvaluationStack() -> Object? {
        evaluationStack.last
    }
    
    public func popEvaluationStack(count numberOfObjects: Int) throws -> [Object] {
        if numberOfObjects > evaluationStack.count {
            throw StoryError.poppingTooManyObjects
        }
        
        var popped: [Object] = []
        for _ in 0 ..< numberOfObjects {
            popped.append(popEvaluationStack()!)
        }
        
        // NOTE: Not in original C# but it seems like the order is backwards otherwise??
        popped.reverse()
        
        return popped
    }
    
    /// Ends the current ink flow, unwrapping the callstack but without
    /// affecting any variables.
    ///
    /// Useful if the ink is (say) in the middle of a nested tunnel, and you
    /// want it to reset so that you can divert elsewhere using `ChoosePathString()`.
    /// Otherwise, after finishing the content you diverted to, it would continue where it left off.
    /// Calling this is equivalent to calling `-> END` in ink.
    public func forceEnd() {
        callStack.reset()
        
        _currentFlow.currentChoices = []
        
        currentPointer = Pointer.null
        previousPointer = Pointer.null
        
        didSafeExit = true
    }
    
    func trimWhitespaceFromFunctionEnd() {
        assert(callStack.currentElement.type == .function)
        
        var functionStartPoint = callStack.currentElement.functionStartInOuputStream
        
        // If the start point has become -1, it means that some non-whitespace
        // text has been pushed, so it's safe to go as far back as we're able.
        if functionStartPoint == -1 {
            functionStartPoint = 0
        }
        
        // Trim whitespace from END of function call
        for i in (functionStartPoint ... outputStream.count - 1).reversed() {
            let obj = outputStream[i]
            let txt = obj as? StringValue
            let cmd = obj as? ControlCommand
            
            if txt == nil {
                continue
            }
            if cmd != nil {
                break
            }
            
            if txt!.isNewline || txt!.isInlineWhitespace {
                _currentFlow.outputStream.remove(at: i)
                markOutputStreamDirty()
            }
            else {
                break
            }
        }
    }
    
    public func popCallstack(_ popType: PushPopType? = nil) {
        // Add the end of a function call, trim any whitespace from the end.
        // (typo?)
        if callStack.currentElement.type == .function {
            trimWhitespaceFromFunctionEnd()
        }
        
        callStack.pop(popType)
    }
    
    // Don't make public since the method needs to be wrapped in Story for visit counting
    func setChosenPath(_ path: Path, _ incrementingTurnIndex: Bool) throws {
        // Changing direction, assume we need to clear current set of choices
        _currentFlow.currentChoices = []
        
        var newPointer = try story!.pointer(at: path)
        if !newPointer.isNull && newPointer.index == -1 {
            newPointer.index = 0
        }
        
        currentPointer = newPointer
        
        if incrementingTurnIndex {
            currentTurnIndex += 1
        }
    }
    
    public func startFunctionEvaluationFromGame(_ funcContainer: Container, _ arguments: Any...) throws {
        callStack.push(.functionEvaluationFromGame, externalEvaluationStackHeight: evaluationStack.count)
        callStack.currentElement.currentPointer = Pointer.startOf(container: funcContainer)
        
        try passArgumentsToEvaluationStack(arguments)
    }
    
    public func passArgumentsToEvaluationStack(_ arguments: Any...) throws {
        for i in 0 ..< arguments.count {
            let a = arguments[i]
            if !(a is Int || a is Float || a is Double || a is String || a is Bool || a is InkList) {
                throw StoryError.invalidArgument(argName: String(describing: type(of: a)))
            }
            
            pushEvaluationStack(createValue(fromAny: a)!)
        }
    }
    
    public func tryExitFunctionEvaluationFromGame() -> Bool {
        if callStack.currentElement.type == .functionEvaluationFromGame {
            currentPointer = Pointer.null
            didSafeExit = true
            return true
        }
        return false
    }
    
    public func completeFunctionEvaluationFromGame() throws -> Any? {
        if callStack.currentElement.type != .functionEvaluationFromGame {
            throw StoryError.expectedExternalFunctionEvaluationComplete(stackTrace: callStack.callStackTrace)
        }
        
        let originalEvaluationStackHeight = callStack.currentElement.evaluationStackHeightWhenPushed
        
        // Do we have a returned value?
        // Potentially pop multiple values off the stack, in case we need
        // to clean up after ourselves (e.g. caller of EvaluateFunction may
        // have passed too many arguments, and we currently have no way to check for that)
        var returnedObj: Object? = nil
        while evaluationStack.count > originalEvaluationStackHeight {
            let poppedObj = popEvaluationStack()
            if returnedObj == nil {
                returnedObj = poppedObj
            }
        }
        
        // Finally, pop the external function evaluation
        popCallstack(.functionEvaluationFromGame)
        
        // What did we get back?
        if returnedObj != nil {
            if returnedObj is Void {
                return nil
            }
            
            // Some kind of value, if not void
            let returnVal = returnedObj as! (any BaseValue)
            
            // DivertTargets get returned as the string of components
            // (rather than a Path, which isn't public)
            if returnVal.valueType == .divertTarget {
                return (returnVal as! DivertTargetValue).value?.description
            }
            
            // Xcode gets angry if I try ot return returnVal.value (generic type)
            // without casting first, so I have to do this...
            // There's probably a beter way.
            if let intVal = returnVal as? IntValue {
                return intVal.value
            }
            else if let boolVal = returnVal as? BoolValue {
                return boolVal.value
            }
            else if let floatVal = returnVal as? FloatValue {
                return floatVal.value
            }
            else if let stringVal = returnVal as? StringValue {
                return stringVal.value
            }
            else if let listVal = returnVal as? ListValue {
                return listVal.value
            }
            else if let ptrVal = returnVal as? VariablePointerValue {
                return ptrVal.value
            }
        }
        
        return nil
    }
    
    public func addError(_ message: String, isWarning: Bool) {
        if !isWarning {
            currentErrors.append(message)
        }
        else {
            currentWarnings.append(message)
        }
    }
    
    func markOutputStreamDirty() {
        _outputStreamTextDirty = true
        _outputStreamTagsDirty = true
    }
    
    // REMEMBER! REMEMBER! REMEMBER!
    // When adding state, update the Copy method and serialisation
    // REMEMBER! REMEMBER! REMEMBER!
    
    var _visitCounts: [String: Int] = [:]
    var _turnIndices: [String:Int] = [:]
    var _outputStreamTextDirty = true
    var _outputStreamTagsDirty = true
    
    var _patch: StatePatch?
    
    var _currentFlow: Flow
    var _namedFlows: [String: Flow]? = nil
    let kDefaultFlowName = "DEFAULT_FLOW"
    var _aliveFlowNamesDirty = true
}
