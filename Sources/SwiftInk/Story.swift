import Foundation

public class Story: Object {
    
    /// The current version of the ink story file format.
    public let inkVersionCurrent = 21
    
    /**
     Version numbers are for engine itself and story file, rather
     than the story state save format
      - old engine, new format: always fail
      - new engine, old format: possibly cope, based on this number
     When incrementing the version number above, the question you
     should ask yourself is:
      - Will the engine be able to load an old story file from
        before I made these changes to the engine?
        If possible, you should support it, though it's not as
        critical as loading old save games, since it's an
        in-development problem only.
     */
    
    /// The minimum legacy version of ink that can be loaded by the current version of the code.
    public let inkVersionMinimumCompatible = 18;
    
    /**
     The list of `Choice` objects available at the current point in
     the `Story`. This list will be populated as the `Story` is stepped
     through with the `Continue()` method. Once `canContinue` becomes
     `false`, this list will be populated, and is usually
     (but not always) on the final `Continue()` step.
     */
    public var currentChoices: [Choice] {
        // Don't include invisible choices for external usage.
        var choices: [Choice] = []
        for c in _state.currentChoices {
            if !(c.isInvisibleDefault ?? false) {
                c.index = choices.count
                choices.append(c)
            }
        }
        return choices
    }
    
    /// The latest line of text to be generated from a `Continue()` call.
    public var currentText: String {
        state.currentText
    }
    

    /// Gets a list of tags as defined with `'#'` in source that were seen
    /// during the latest `Continue()` call.
    public var currentTags: [String] {
        return state.currentTags
    }
    
    /// Any errors generated during evaluation of the `Story`.
    public var currentErrors: [String] {
        state.currentErrors
    }
    
    /// Any warnings generated during evaluation of the `Story`.
    public var currentWarnings: [String] {
        state.currentWarnings
    }
    
    /// The current flow name if using multi-flow functionality - see `SwitchFlow`
    public var currentFlowName: String {
        state.currentFlowName
    }
    
    /// Is the default flow currently active? By definition, will also
    /// return `true` if not using multi-flow functionality - see `SwitchFlow`
    public var currentFlowIsDefaultFlow: Bool {
        state.currentFlowIsDefaultFlow
    }
    
    /// Names of currently alive flows (not including the default flow)
    public var aliveFlowNames: [String] {
        state.aliveFlowNames
    }
    
    /// Whether the `currentErrors` list contains any errors.
    /// THIS MAY BE REMOVED - you should be setting an error handler directly
    /// using `Story.onError`.
    public var hasError: Bool {
        state.hasError
    }
    
    /// Whether the `currentWarnings` list contains any warnings.
    public var hasWarning: Bool {
        state.hasWarning
    }
    
    /// The `VariablesState` object contains all the global variables in the story.
    /// However, note that there's more to the state of a `Story` than just the
    /// global variables. This is a convenience accessor to the full state object.
    public var variablesState: VariablesState {
        state.variablesState!
    }
    
    public var listDefinitions: ListDefinitionsOrigin? {
        _listDefinitions
    }
    
    /// The entire current state of the story including (but not limited to):
    /// - Global variables
    /// - Temporary variables
    /// - Read/visit and turn counts
    /// - The callstack and evaluation stacks
    /// - The current threads
    public var state: StoryState {
        _state
    }
    
    /// Error handler for all runtime errors in ink - i.e. problems
    /// with the source ink itself that are only discovered when playing
    /// the story.
    ///
    /// It's strongly recommended that you assign an error handler to your
    /// story instance to avoid getting exceptions for ink errors.
    public var onError: [ErrorHandler] = []
    
    /// Callback for when `ContinueInterval` is complete
    public var onDidContinue: [() -> Void] = []
    
    /// Callback for when a choice is about to be executed
    public var onMakeChoice: [(Choice) -> Void] = []
    
    /// Callback for when a function is about to be evaluated
    public var onEvaluateFunction: [(String, [Any?]) -> Void] = []
    
    /// Callback for when a function has been evaluated.
    /// This is necessary because evaluating a function can cause continuing.
    public var onCompleteEvaluateFunction: [(String, [Any?], String, Any?) -> Void] = []
    
    /// Callback for when a path string is chosen.
    public var onChoosePathString: [(String, [Any?]) -> Void] = []
    
    /// Start recording ink profiling information during calls to `Continue()` on this story.
    /// - Returns: a `Profiler` instance that you can request a report from when you're finished.
    public func StartProfiling() -> Profiler {
        IfAsyncWeCant("start profiling")
        _profiler = Profiler()
        return _profiler!
    }
    
    /// Stop recording ink profiling information during calls to `Continue()` on this story.
    public func EndProfiling() {
        _profiler = nil
    }
    
    
    /// Creates a new `Story` with the given content container and list definitions.
    ///
    /// When creating a `Story` using this constructor, you need to
    /// call `ResetState()` on it before use. Intended for compiler use only.
    /// For normal use, use the constructor that takes a JSON string.
    public init(_ contentContainer: Container?, _ lists: [ListDefinition]? = nil) {
        _mainContentContainer = contentContainer
        
        if lists != nil {
            _listDefinitions = ListDefinitionsOrigin(lists!)
        }
        
        _externals = [:]
    }
    
    /// Construct a `Story` object using a JSON string compiled with inklecate.
    /// - Parameter jsonString: The JSON string generated with inklecate.
    public convenience init(_ jsonString: String) throws {
        self.init(nil)
        
        // TODO: Swift should be able to handle this well!
        var rootObject: [String: Any?] = SimpleJson.TextToDictionary(jsonString)
        
        guard let formatFromFile = rootObject["inkVersion"] as? Int else {
            throw StoryError.inkVersionNotFound
        }
        
        if formatFromFile > inkVersionCurrent {
            throw StoryError.storyInkVersionIsNewer
        }
        else if formatFromFile < inkVersionMinimumCompatible {
            throw StoryError.storyInkVersionTooOld
        }
        else if formatFromFile != inkVersionCurrent {
            print("Warning: Version of ink used to build story doesn't match current version of engine. Non-critical, but recommend synchronising.")
        }
        
        var rootToken = rootObject["root"]
        if rootToken == nil {
            throw StoryError.rootNodeNotFound
        }
        
        if let listDefsObj = rootObject["listDefs"] {
            _listDefinitions = Json.JTokenToListDefinitions(listDefsObj)
        }
        
        _mainContentContainer = Json.JTokenToRuntimeObject(rootToken) as! Container
        
        ResetState()
    }
    
    // TODO: Complete!
    /// Returns a JSON string representing the story itself.
    public func ToJson() -> String {
        return ""
    }
    
    // TODO: Complete!
    /// Writes a JSON string representing the story itself to a stream.
    public func ToJson(_ stream: Stream) {
        
    }
    
    // TODO: Complete!
    func ToJson(_ writer: JSONEncoder) {
        
    }
    
    /// Reset the story back to its initial state as it was when it was first constructed.
    public func ResetState() {
        // TODO: Could make this possible
        IfAsyncWeCant("ResetState")
        
        _state = StoryState(self)
        _state.variablesState?.variableChangedEvent += VariableStateDidChangeEvent
        
        ResetGlobals()
    }
    
    func ResetErrors() {
        _state.ResetErrors()
    }
    
    /// Unwinds the callstack.
    ///
    /// Useful to reset the story's evaluation without actually changing any
    /// meaningful state, for example if you want to exit a section of story
    /// prematurely and tell it to go elsewhere with a call to `ChoosePathString()`.
    /// Doing so without calling `ResetCallstack()` could cause unexpected
    /// issues if, for example, the story was in a tunnel already.
    public func ResetCallstack() {
        IfAsyncWeCant("ResetCallstack")
        _state.ForceEnd()
    }
    
    func ResetGlobals() {
        if _mainContentContainer?.namedContent.keys.contains("global decl") ?? false {
            var originalPointer = state.currentPointer
            
            ChoosePath(Path("global decl"), incrementingTurnIndex: false)
            
            // Continue, but without validating external bindings,
            // since we may be doing this reset at initialisation time.
            ContinueInternal()
            
            state.currentPointer = originalPointer
        }
        
        state.variablesState?.SnapshotDefaultGlobals()
    }
    
    public func SwitchFlow(_ flowName: String) throws {
        IfAsyncWeCant("switch flow")
        if _asyncSaving {
            throw StoryError.cannotSwitchFlowDueToBackgroundSavingMode(flowName: flowName)
        }
        state.SwitchFlow_Internal(flowName)
    }
    
    public func RemoveFlow(_ flowName: String) throws {
        try state.RemoveFlow_Internal(flowName)
    }
    
    /// Continue the story for one line of content, if possible.
    ///
    /// If you're not sure if there's more content available (for example if you
    /// want to check whether you're at a choice point or the end of the story),
    /// you should call `canContinue` before calling this function.
    /// - Returns: The next line of text content.
    public func Continue() -> String {
        ContinueAsync(0)
        return currentText
    }
    
    /// Check whether more content would be available if you were to call `Continue()` - i.e.
    /// are we mid-story rather than at a choice point or an end.
    public var canContinue: Bool {
        state.canContinue
    }
    
    /// If `ContinueAsync()` was called (with milliseconds limit > 0) then this property
    /// will return `false` if the ink evaluation isn't yet finished, and you need to call
    /// it again in order for the `Continue()` to fully complete.
    public var asyncContinueComplete {
        return !_asyncContinueActive
    }
    
    /// An "asynchronous" version of `Continue()` that only partially evaluates the ink,
    /// with a budget of a certain time limit. It will exit ink evaluation early if
    /// the evaluation isn't complete within the time limit, with the
    /// `asyncContinueComplete` property being `false`.
    /// This is useful if ink evaluation takes a long time, and you want to distribute
    /// it over multiple game frames for smoother animation.
    /// If you pass a limit of zero, then it will fully evaluate the ink in the same
    /// way as calling `Continue()` (and, in fact, this is exactly what `Continue()` does internally).
    public func ContinueAsync(_ millisecsLimitAsync: Float) {
        if !_hasValidatedExternals {
            ValidateExternalBindings()
        }
        ContinueInternal(millisecsLimitAsync)
    }
    
    
    func ContinueInternal(_ millisecsLimitAsync: Float = 0.0) throws {
        _profiler?.PreContinue()
        
        var isAsyncTimeLimited = millisecsLimitAsync > 0
        
        _recursiveContinueCount += 1
        
        // Doing either:
        // - full run through non-async (so not active and don't want to be)
        // - Starting async run-through
        if !_asyncContinueActive {
            _asyncContinueActive = isAsyncTimeLimited
            
            if !canContinue {
                throw StoryError.cannotContinue
            }
            
            _state.didSafeExit = false
            _state.ResetOutput()
            
            // It's possible for ink to call game to call ink to call game etc
            // In this case, we only want to batch observe variable changes
            // for the outermost call
            if _recursiveContinueCount == 1 {
                _state.variablesState?.batchObservingVariableChanges = true
            }
        }
        
        // Start timing
        var durationStopwatch = Stopwatch()
        durationStopwatch.Start()
        
        var outputStreamEndsInNewline = false
        _sawLookaheadUnsafeFunctionAfterNewline = false
        repeat {
            do {
                outputStreamEndsInNewline = ContinueSingleStep()
            }
            catch {
                AddError(e)
                break
            }
            
            if outputStreamEndsInNewline {
                break
            }
                
            // Run out of async time?
            if _asyncContinueActive && durationStopwatch.elapsedTime > (Double(millisecsLimitAsync) / 1000.0) {
                break
            }
        } while canContinue
        
        durationStopwatch.Stop()
        
        // 4 outcomes:
        // - got newline (so finished this line of text)
        // - can't continue (e.g. choices or ending)
        // - ran out of time during evaluation
        // - error
        
        // Successfully finished evaluation in time (or in error)
        if outputStreamEndsInNewline || !canContinue {
            // Need to rewind, due to evaluating further than we should?
            if _stateSnapshotAtLastNewline != nil {
                RestoreStateSnapshot()
            }
            
            // Finished a section of content / reached a choice point?
            if !canContinue {
                if state.callStack.canPopThread {
                    AddError("Thread available to pop, threads should always be flat by the end of evaluation?")
                }
                
                if state.generatedChoices.count == 0 && !state.didSafeExit && _temporaryEvaluationContainer == nil {
                    if state.callStack.CanPop(.Tunnel) {
                        AddError("unexpectedly reached end of content. Do you need a '->->' to return from a tunnel?")
                    }
                    else if state.callStack.CanPop(.Function) {
                        AddError("unexpectedly reached end of content. Do you need to add '~ return' to your script?")
                    }
                    else if !state.callStack.canPop {
                        AddError("ran out of content. Do you need to add '-> DONE' or '-> END' to your script?")
                    }
                    else {
                        AddError("unexpectedly reached end of content for unknown reason. Please debug compiler!")
                    }
                }
            }
            
            state.didSafeExit = false
            _sawLookaheadUnsafeFunctionAfterNewline = false
            
            if _recursiveContinueCount == 1 {
                _state.variablesState?.batchObservingVariableChanges = false
            }
            
            _asyncContinueActive = false
            onDidContinue.Invoke()
        }
        
        _recursiveContinueCount -= 1
        
        _profiler?.PostContinue()
        
        // Report any errors that occurred during evaluation.
        // This may either have been StoryErrors that were thrown
        // and caught during evaluation, or directly added with AddError().
        if state.hasError || state.hasWarning {
            if onError.isEmpty {
                if state.hasError {
                    for err in state.currentErrors {
                        onError.Invoke(err, .error)
                    }
                }
                
                if state.hasWarning {
                    for err in state.currentWarnings {
                        onError.Invoke(err, .warning)
                    }
                }
                
                ResetErrors()
            }
            // Throw an exception since there's no error handler
            else {
                var sb = ""
                sb += "Ink had "
                if state.hasError {
                    sb += "\(state.currentErrors.count) \(state.currentErrors.count == 1 ? "error" : "errors")"
                    if state.hasWarning {
                        sb += " and "
                    }
                }
                
                if state.hasWarning {
                    sb += "\(state.currentWarnings.count) \(state.currentWarnings.count == 1 ? "warning" : "warnings")"
                }
                sb += ". It is strongly suggested that you assign an error handler to story.onError. The first issue was: "
                sb += state.hasError ? state.currentErrors[0] : state.currentWarnings[0]
                
                // If you get this exception, please assign an error handler to your story.
                throw StoryError.errorsOnContinue(sb)
            }
        }
    }
    
    func ContinueSingleStep() -> Bool {
        _profiler?.PreStep()
        
        // Run main step function (walks through content)
        Step()
        
        _profiler?.PostStep()
        
        // Run out of content and we have a default invisible choice that we can follow?
        if !canContinue && !state.callStack.elementIsEvaluateFromGame {
            TryFollowDefaultInvisibleChoice()
        }
        
        _profiler?.PreSnapshot()
        
        // Don't save/rewind during string evaluation, which is e.g. used for choices
        if !state.inStringEvaluation {
            // We previously found a newline, but were we just double checking that
            // it wouldn't immediately be removed by glue?
            if _stateSnapshotAtLastNewline != nil {
                // Has proper text or a tag been added? Then we know that the newline
                // that was previously added is definitely the end of the line.
                var change = CalculateNewlineOutputStateChange(_stateSnapshotAtLastNewline!.currentText, state.currentText, _stateSnapshotAtLastNewline!.currentTags.count, state.currentTags.count)
                
                // The last time we saw a newline, it was definitely the end of the line, so we
                // want to rewind to that point.
                if change == .extendedBeyondNewline || _sawLookaheadUnsafeFunctionAfterNewline {
                    RestoreStateSnapshot()
                    
                    // Hit a newline for sure, we're done
                    return true
                }
                
                // Newline that previously existed is no longer valid - e.g.
                // glue was encountered that caused it to be removed
                else if change == .newlineRemoved {
                    DiscardSnapsot()
                }
            }
            
            // Current content ends in a newline - approaching end of our evaluation
            if state.outputStreamEndsInNewLine {
                // If we can continue evaluation for a bit:
                // Create a snapshot in case we need to rewind.
                // We're going to continue stepping in case we see glue or some
                // non-text content such as choices.
                if canContinue {
                    // Don't bother to record the state beyond the current newline.
                    // e.g.:
                    // Hello world\n           // record state at the end of here
                    // ~ complexCalculation()  // don't actually need this unless it generates text
                    if _stateSnapshotAtLastNewline == nil {
                        StateSnapshot()
                    }
                }
                
                // Can't continue, so we're about to exit - make sure we
                // don't have an old state hanging around
                else {
                    DiscardSnapshot()
                }
            }
        }
        
        _profiler?.PostSnapshot()
        
        return false
    }
    
    // Assumption: prevText is the snapshot where we saw a newline, and we're checking whether we're really done
    // with that line. Therefore prevText will definitely end in a newline.
    //
    // We take tags into account too, so that a tag following a content line:
    //   Content
    //   # tag
    // ...doesn't cause the tag to be wrongly associated with the content above.
    enum OutputStateChange {
        case noChange
        case extendedBeyondNewline
        case newlineRemoved
    }
    
    func CalculateNewlineOutputStateChange(_ prevText: String, _ currText: String, _ prevTagCount: Int, _ currTagCount: Int) -> OutputStateChange {
        // Simple case: nothing's changed, and we still have a newline
        // at the end of the current content
        var currTextArray = Array(currText.unicodeScalars)
        
        var newlineStillExists = currText.count >= prevText.count && prevText.count > 0 && currTextArray[prevText.count - 1] == "\n"
        if prevTagCount == currTagCount && prevText.count == currText.count && newlineStillExists {
            return .noChange
        }
        
        // Old newline has been removed, it wasn't the end of the line after all
        if !newlineStillExists {
            return .newlineRemoved
        }
        
        // Tag added - definitely the start of a new line
        if currTagCount > prevTagCount {
            return .extendedBeyondNewline
        }
        
        // There must be new content - check whether it's just whitespace
        for i in prevText.count ..< currText.count {
            var c = currTextArray[i]
            if c != " " && c != "\t" {
                return .extendedBeyondNewline
            }
        }
        
        // There's new text but it's just spaces and tabs, so there's still the potential
        // for glue to kill the newline
        return .noChange
    }
    
    /// Continue the story until the next choice point or until it runs out of content.
    ///
    /// This is opposed to the `Continue()` method, which only evaluates one line of
    /// output at a time.
    /// - Returns: The resulting text evaluated by the ink engine, concatenated together.
    public func ContinueMaximally() -> String {
        IfAsyncWeCant("ContinueMaximally")
        
        var sb = ""
        while canContinue {
            sb += Continue()
        }
        
        return sb
    }
    
    public func ContentAtPath(_ path: Path) -> SearchResult? {
        return _mainContentContainer?.ContentAtPath(path)
    }
    
    public func KnotContainerWIthName(_ name: String) -> Container? {
        if let namedContainer = _mainContentContainer?.namedContent[name] {
            return namedContainer as? Container
        }
        return nil
    }
    
    public func PointerAtPath(_ path: Path) -> Pointer {
        if path.length == 0 {
            return Pointer.Null
        }
        
        // I think??? the original code seemed to use a constructor that didn't exist????
        // so just gonna assume we use default values here
        var p = Pointer(nil, 0)
        
        var pathLengthToUse = path.length
        
        var result: SearchResult?
        if path.lastComponent?.isIndex ?? false {
            pathLengthToUse = path.length - 1
            result = _mainContentContainer?.ContentAtPath(path, partialPathLength: pathLengthToUse)
            p.container = result?.container
            p.index = path.lastComponent!.index
        }
        else {
            result = _mainContentContainer?.ContentAtPath(path)
            p.container = result?.container
            p.index = -1
        }
        
        if result?.obj == nil || result?.obj == _mainContentContainer && pathLengthToUse > 0 {
            Error("Failed to find content at path '\(path)', and no approximation of it was possible.")
        }
        else if result?.approximate ?? false {
            Warning("Failed to find content at path '\(path)', so it was approximated to '\(result.obj.path)'")
        }
        
        return p
    }
    
    // Maximum snapshot stack:
    // - stateSnapshotDuringSave -- not retained, but returned to game code
    // - _stateSnapshotAtLastNewline (has older patch)
    // - _state (current, being patched)
    func StateSnapshot() {
        _stateSnapshotAtLastNewline = _state
        _state = _state.CopyAndStartPatching()
    }
    
    func RestoreStateSnapshot() {
        // Patched state had temporarily hijacked our
        // VariablesState and set its own callstack on it,
        // so we need to restore that.
        // If we're in the middle of saving, we may also
        // need to give the VariablesState the old patch.
        _stateSnapshotAtLastNewline?.RestoreAfterPatch()
        
        _state = _stateSnapshotAtLastNewline!
        _stateSnapshotAtLastNewline = nil
        
        // If save completed while the above snapshot was
        // active, we need to apply any changes made since
        // the save was started but before the snapshot was made.
        if !_asyncSaving {
            _state.ApplyAnyPatch()
        }
    }
    
    func DiscardSnapshot() {
        // Normally we want to integrate the patch
        // into the main global/counts dictionaries.
        // However, if we're in the middle of async
        // saving, we simply stay in a "patching" state,
        // albeit with the newer cloned patch.
        if !_asyncSaving {
            _state.ApplyAnyPatch()
        }
        
        // No longer need the snapshot.
        _stateSnapshotAtLastNewline = nil
    }
    
    /// Advanced usage!
    /// If you have a large story, and saving state to JSON takes too long for your
    /// framerate, you can temporarily freeze a copy of the state for saving on
    /// a separate thread. Internally, the engine maintains a "diff patch".
    /// When you're finished saving your state, call `BackgroundSaveComplete()`
    /// and that diff patch will be applied, allowing the story to continue
    /// in its usual mode.
    /// - Returns: The state for background thread save.
    public func CopyStateForBackgroundThreadSave() throws -> StoryState {
        IfAsyncWeCant("start saving on a background thread")
        if _asyncSaving {
            throw StoryError.cantSaveOnBackgroundThreadTwice
        }
        var stateToSave = _state
        _state = _state.CopyAndStartPatching()
        _asyncSaving = true
        return stateToSave
    }
    
    /// Releases the "frozen" save state started by `CopyStateForBackgroundThreadSave()`,
    /// applying its patch that it was using internally.
    public func BackgroundSaveComplete() {
        // CopyStateForBackgroundThreadSave() must be called outside
        // of any async ink evaluation, since otherwise you'd be saving
        // during an intermediate state.
        // However, it's possible to *complete* the save in the middle of
        // a glue-lookahead when there's a state stored in _stateSnapshotAtLastNewline.
        // This state will have its own patch that is newer than the save patch.
        // We hold off on the final apply until the glue-lookahead is finished.
        // In that case, the apply is always done, it's just that it may
        // apply the looked-ahead changes OR it may simply apply the changes
        // made during the save process to the old _stateSnapshotAtLastNewline state.
        if _stateSnapshotAtLastNewline == nil {
            _state.ApplyAnyPatch()
        }
        _asyncSaving = false
    }
    
    func Step() {
        var shouldAddToStream = true
        
        // Get current content
        var pointer = state.currentPointer
        if pointer.isNull {
            return
        }
        
        // Step directly to the first element of content in a container (if necessary)
        var containerToEnter = pointer.Resolve() as? Container
        while containerToEnter != nil {
            // Mark container as being entered
            VisitContainer(containerToEnter, atStart: true)
            
            // No content? the most we can do is step past it
            if containerToEnter?.content.count == 0 {
                break
            }
            
            pointer.Pointer.StartOf(containerToEnter!)
            containerToEnter = pointer.Resolve() as? Container
        }
        state.currentPointer = pointer
        
        _profiler?.Step(state.callStack)
        
        // Is the current content object:
        // - Normal content
        // - Or a logic/flow statement - if so, do it
        // Stop flow if we hit a stack pop when we're unable to pop (e.g. return/done statement in knot
        // that was diverted to rather than called as a function)
        var currentContentObj = pointer.Resolve()
        var isLogicOrFlowControl = PerformLogicAndFlowControl(currentContentObj)
        
        // Has flow been forced to end by flow control above?
        if state.currentPointer.isNull {
            return
        }
        
        if isLogicOrFlowControl {
            shouldAddToStream = false
        }
        
        // Choice with condition
        if let choicePoint = currentContentObj as? ChoicePoint {
            if let choice = ProcessChoice(choicePoint) {
                state.generatedChoices.append(choice)
            }
            
            currentContentObj = nil
            shouldAddToStream = false
        }
        
        // If the container has no content, then it will be
        // the "content" itself, but we skip over it.
        if currentContentObj is Container {
            shouldAddToStream = false
        }
        
        // Content to add to evaluation stack or the output stream
        if shouldAddToStream {
            // If we're pushing a variable pointer onto the evaluation stack, ensure that it's specific
            // to our current (possibly temporary) context index. And make a copy of the pointer
            // so that we're not editing the original runtime object.
            if let varPointer = currentContentObj as? VariablePointerValue, varPointer.contextIndex == -1 {
                // Create new object so we're not overwriting the story's own data
                var contextIdx = state.callStack.ContextForVariableNamed(varPointer.variableName)
                currentContentObj = VariablePointerValue(varPointer.variableName, contextIdx)
            }
            
            // Expression evaluation content
            if state.inExpressionEvaluation {
                state.PushEvaluationStack(currentContentObj)
            }
            
            // Output stream content (i.e. not expression evaluation)
            else {
                state.PushToOutputStream(currentContentObj)
            }
        }
        
        // Increment the content pointer, following diverts if necessary
        NextContent()
        
        // Starting a thread should be done after the increment to thecontent pointer,
        // so that when returning from the thread, it returns to the content after this instruction.
        if let controlCmd = currentContentObj as? ControlCommand, controlCmd.commandType == .startThread {
            state.callStack.PushThread()
        }
    }
    
    /// Mark a container as having been visited
    func VisitContainer(_ container: Container, _ atStart: Bool) {
        if !container.countingAtStartOnly || atStart {
            if container.visitsShouldBeCounted {
                state.IncrementVisitCountForContainer(container)
            }
            
            if container.turnIndexShouldBeCounted {
                state.RecordTurnIndexVisitToContainer(container)
            }
        }
    }
    
    var _prevContainers: [Container] = []
    
    // TODO: VisitChangedContainersDueToDivert() and onwards!
    func VisitChangedContainersDueToDivert() {
        var previousPointer = state.previousPointer
        var pointer = state.currentPointer
        
        // Unless we're pointing *directly* at a piece of content, we don't do
        // counting here. Otherwise, the main stepping function will do the counting.
        if pointer.isNull || pointer.index == -1 {
            return
        }
        
        // First, find the previously open set of containers
        _prevContainers = []
        if !previousPointer.isNull {
            var prevAncestor = previousPointer.Resolve() as? Container ?? previousPointer.container
            while prevAncestor != nil {
                _prevContainers.append(prevAncestor!)
                prevAncestor = prevAncestor!.parent as? Container
            }
        }
        
        // If the new object is a container itself, it will be visited automatically at the next actual
        // content step. However, we need to walk up the new ancestry to see if there are more new containers
        var currentChildOfContainer = pointer.Resolve()
        
        // Invalid pointer? May happen if attempting to...(???)
        if currentChildOfContainer == nil {
            return
        }
        
        var currentContainerAncestor = currentChildOfContainer?.parent as? Container
        
        var allChildrenEnteredAtStart = true
        while currentContainerAncestor != nil && (_prevContainers.contains(currentContainerAncestor!) || currentContainerAncestor!.countingAtStartOnly) {
            // Check whether this ancestor container is being entered at the start,
            // by checking whether the child object is the first.
            var enteringAtStart = currentContainerAncestor!.content.count > 0 && currentChildOfContainer == currentContainerAncestor!.content[0] && allChildrenEnteredAtStart
            
            // Don't count it as entering at start if we're entering random somewhere within
            // a container B that happens to be nested at index 0 of container A. It only counts
            // if we're diverting directly to the first leaf node.
            if !enteringAtStart {
                allChildrenEnteredAtStart = false
            }
            
            // Mark a visit to this container
            VisitContainer(currentContainerAncestor!, enteringAtStart)
            
            currentChildOfContainer = currentContainerAncestor
            currentContainerAncestor = currentContainerAncestor!.parent as? Container
        }
    }
    
    func PopChoiceStringAndTags(_ tags: inout [String]?) -> String? {
        var choiceOnlyStrVal = state.PopEvaluationStack() as! StringValue
        
        while state.evaluationStack.count > 0 && state.PeekEvaluationStack() is Tag {
            if tags == nil {
                tags = []
            }
            var tag = state.PopEvaluationStack() as! Tag
            tags?.insert(tag.text, at: 0) // popped in reverse order
        }
        
        return choiceOnlyStrVal.value
    }
    
    func ProcessChoice(_ choicePoint: ChoicePoint) -> Choice? {
        var showChoice = true
        
        // Don't create choice if choice point doesn't pass conditional
        if choicePoint.hasCondition {
            var conditionValue = state.PopEvaluationStack()
            if !IsTruthy(conditionValue!) {
                showChoice = false
            }
        }
        
        var startText = ""
        var choiceOnlyText = ""
        var tags: [String]? = nil
        
        if choicePoint.hasChoiceOnlyContent {
            choiceOnlyText = PopChoiceStringAndTags(&tags)
        }
        
        if choicePoint.hasStartContent {
            startText = PopChoiceStringAndTags(&tags)
        }
        
        // Don't create choice if player has already read this content
        if choicePoint.onceOnly {
            var visitCount = state.VisitCountForContainer(choicePoint.choiceTarget)
            if visitCount > 0 {
                showChoice = false
            }
        }
        
        // We go through the full process of creating the choice above so
        // that we consume the content for it, since otherwise it'll
        // be shown on the output stream.
        if !showChoice {
            return nil
        }
        
        var choice = Choice()
        choice.targetPath = choicePoint.pathOnChoice
        choice.sourcePath = choicePoint.path.description
        choice.isInvisibleDefault = choicePoint.isInvisibleDefault
        choice.tags = tags
        
        // We need to capture the state of the callstack at the point where
        // the choice was generated, since after the generation of this choice
        // we may go on to pop out from a tunnel (possible if the choice was
        // wrapped in a conditional), or we may pop out from a thread,
        // at which point that thread is discarded.
        // Fork clones the thread, gives it a new ID, but without affecting
        // the thread stack itself.
        choice.threadAtGeneration = state.callStack.ForkThread()
        
        // Set final text for the choice
        choice.text = (startText + choiceOnlyText).trimmingCharacters(in: [" ", "\t"])
        
        return choice
    }
    
    // Does the expression result represented by this object evaluate to true?
    // e.g. is it a Number that's not equal to 1?
    func IsTruthy(_ obj: Object) -> Bool {
        if let val = obj as? (any BaseValue) {
            if let divTarget = val as? DivertTargetValue {
                Error("Shouldn't use a divert target (to \(divTarget.targetPath)) as a conditional value. Did you intend a function call likeThis() or a read count check likeThis? (no arrows)")
                return false
            }
            
            return val.isTruthy
        }
        return false
    }
    
    /// Checks whether `contentObj` is a control or flow object rather than a piece of content,
    /// and performs the required command if necessary.
    /// - Returns: `true` if an object was logic or flow control, `false` if it was normal content.
    /// - Parameter contentObj: Content object.
    ///
    func PerformLogicAndFlowControl(_ contentObj: Object?) throws -> Bool {
        if contentObj == nil {
            return false
        }
        
        
        // Divert
        if let currentDivert = contentObj as? Divert {
            if currentDivert.isConditional {
                var conditionValue = state.PopEvaluationStack()
                
                // False conditional? Cancel divert
                if !IsTruthy(conditionValue) {
                    return true
                }
            }
            
            if currentDivert.hasVariableTarget {
                var varName = currentDivert.variableDivertName
                var varContents = state.variablesState?.GetVariableWithName(varName)
                if varContents == nil {
                    Error("Tried to divert using a target from a variable that could not be found (\(varName))")
                }
                else if !(varContents is DivertTargetValue) {
                    var errorMessage = "Tried to divert to a target from a variable, but the variable (\(varName)) didn't contain a divert target, it "
                    if let intContent = varContents as? IntValue {
                        errorMessage += "was empty/null (the value 0)."
                    }
                    else {
                        errorMessage += "contained '\(varContents!)'."
                    }
                    
                    Error(errorMessage)
                }
                
                var target = varContents as! DivertTargetValue
                state.divertedPointer = PointerAtPath(target.targetPath)
            }
            
            else if currentDivert.isExternal {
                CallExternalFunction(currentDivert.targetPathString, currentDivert.externalArgs)
                return true
            }
            else {
                state.divertedPointer = currentDivert.targetPointer
            }
            
            if currentDivert.pushesToStack {
                state.callStack.Push(currentDivert.stackPushType!, outputStreamLengthWithPushed: state.outputStream.count)
            }
            
            if (state.divertedPointer?.isNull ?? false) && !currentDivert.isExternal {
                // Human-readable name available - runtime divert is part of a hand-written divert that to missing content
                if currentDivert.debugMetadata?.sourceName != nil {
                    Error("Divert target doesn't exist: \(currentDivert.debugMetadata.sourceName)")
                }
                else {
                    Error("Divert resolution failed: \(currentDivert)")
                }
            }
            
            return true
        }
        
        // Start/end an expression evaluation? Or print out the result?
        else if let evalCommand = contentObj as? ControlCommand {
            switch evalCommand.commandType {
            case .evalStart:
                assert(!state.inExpressionEvaluation, "Already in expression evaluation?")
                state.inExpressionEvaluation = true
                break
            case .evalEnd:
                assert(state.inExpressionEvaluation, "Not in expression evaluation mode")
                state.inExpressionEvaluation = false
                break
            case .evalOutput:
                // If the expression turned out to be empty, there may not be anything on the stack
                if !state.evaluationStack.isEmpty {
                    var output = state.PopEvaluationStack()
                    
                    // Functions may evaluate to Void, in which case we skip output
                    if !(output is Void) {
                        // TODO: Should we really always blanket convert to string?
                        // It would be okay to have numbers in the output stream, the
                        // only problem is when exporting text for viewing, it skips over numbers etc.
                        var text = StringValue(String(describing: output))
                        state.PushToOutputStream(text)
                    }
                }
                break
            case .noOp:
                break
            case .duplicate:
                state.PushEvaluationStack(state.PeekEvaluationStack())
                break
            case .popEvaluatedValue:
                state.PopEvaluationStack()
                break
            case .popFunction:
                fallthrough
            case .popTunnel:
                var popType = evalCommand.commandType == .popFunction ? PushPopType.Function : PushPopType.Tunnel
                
                // Tunnel onwards is allowed to specify an optional override
                // divert to go to immediately after returning: ->-> target
                var overrideTunnelReturnTarget: DivertTargetValue? = nil
                if popType == .Tunnel {
                    var popped = state.PopEvaluationStack()
                    overrideTunnelReturnTarget = popped as? DivertTargetValue
                    if overrideTunnelReturnTarget == nil {
                        Assert(popped is Void, "Expected void if ->-> doesn't override target")
                    }
                }
                
                if state.TryExitFunctionEvaluationFromGame() {
                    break
                }
                else if state.callStack.currentElement.type != popType || !state.callStack.canPop {
                    var names: [PushPopType: String] = [:]
                    names[.Function] = "function return statement (~ return)"
                    names[.Tunnel] = "tunnel onwards statement (->->)"
                    
                    var expected = names[state.callStack.currentElement.type]
                    if !state.callStack.canPop {
                        expected = "end of flow (-> END or choice)"
                    }
                    
                    var errorMsg = "Found \(names[popType]), when expected \(expected)"
                    Error(errorMsg)
                }
                
                else {
                    state.PopCallstack()
                    
                    // Does tunnel onwards override by diverting to a new ->-> target?
                    if overrideTunnelReturnTarget != nil {
                        state.divertedPointer = PointerAtPath(overrideTunnelReturnTarget?.targetPath)
                    }
                }
                
                break
            case .beginString:
                state.PushToOutputStream(evalCommand)
                
                assert(state.inExpressionEvaluation, "Expected to be in an expression when evaluating a string")
                state.inExpressionEvaluation = false
                break
                
            // Leave it to story.currentText and story.currentTags to sort out the text from the tags.
            // This is mostly because we can't always rely on the existence of endTag, and we don't want
            // to try and flatten dynamic tags to strings every time \n is pushed to output.
            case .beginTag:
                state.PushToOutputStream(evalCommand)
                break
                
            case .endTag:
                // EndTag has 2 modes:
                // - When in string evaluation (for choices)
                // - Normal
                //
                // The only way you could have an EndTag in the middle of
                // string evaluation is if we're currently generating text for a
                // choice, such as:
                //
                //    + choice # tag
                //
                // In the above case, the ink will be run twice:
                // - First, to generate the choice text. String evaluation
                //   will be on, and the final string will be pushed to the
                //   evaluation stack, ready to be popped to make a Choice
                //   object.
                // - Second, when ink generates text after choosing the choice.
                //   On this occasion, it's not in string evaluation mode.
                //
                // On the writing side, we disallow manually putting tags within
                // strings like this:
                //
                //    {"hello # world"}
                //
                // So we know that the tag must be being generated as part of
                // choice content. Therefore, when the tag has been generated,
                // we push it onto the evaluation stack in the exact same way
                // as the string for the choice content.
                if state.inStringEvaluation {
                    var contentStackForTag: [Object] = []
                    var outputCountConsumed = 0
                    
                    for i in (0...state.outputStream.count - 1).reversed() {
                        var obj = state.outputStream[i]
                        
                        outputCountConsumed += 1
                        
                        if let command = obj as? ControlCommand {
                            if command.commandType == .beginTag {
                                break
                            }
                            else {
                                Error("Unexpected ControlCommand while extracting tag from choice")
                                break
                            }
                        }
                        
                        if obj is StringValue {
                            contentStackForTag.append(obj)
                        }
                    }
                    
                    // Consume the content that was produced for this string
                    state.PopFromOutputStream(outputCountConsumed)
                    
                    var sb = ""
                    for strVal in contentStackForTag.map({ $0 as! StringValue }) {
                        sb += strVal.value
                    }
                    
                    var choiceTag = Tag(state.CleanOutputWhitespace(sb))
                    
                    // Pushing to the evaluation stack means it gets picked up
                    // when a Choice is generated from the next Choice Point.
                    state.PushEvaluationStack(choiceTag)
                }
                
                // Otherwise! Simply push endTag, so that in the output stream we
                // have a structure of: [BeginTag, "the tag content", EndTag]
                else {
                    state.PushToOutputStream(evalCommand)
                }
                break
                
            // Dynamic strings and tags are built in the same way
            case .endString:
                // Since we're iterating backward through the content,
                // build a stack so that when we build the string,
                // it's in the right order
                var contentStackForString: [Object] = []
                var contentToRetain: [Object] = []
                
                var outputCountConsumed = 0
                for i in (0...state.outputStream.count - 1).reversed() {
                    var obj = state.outputStream[i]
                    
                    outputCountConsumed += 1
                    
                    if let command = obj as? ControlCommand, command.commandType == .beginString {
                        break
                    }
                    
                    if obj is Tag {
                        contentToRetain.append(obj)
                    }
                    
                    if obj is StringValue {
                        contentStackForString.append(obj)
                    }
                }
                
                // Consume the content that was produced for this string
                state.PopFromOutputStream(outputCountConsumed)
                
                // Rescue the tags that we want actually to keep on the output stack
                // rather than consume as part of the string we're building.
                // At the time of writing, this only applies to Tag objects generated
                // by choices, which are pushed to the stack during string generation.
                for rescuedTag in contentToRetain {
                    state.PushToOutputStream(rescuedTag)
                }
                
                // Build string out of the content we collected
                var sb = ""
                for c in contentStackForString {
                    sb += String(describing: c)
                }
                
                // Return to expression evaluation (from content mode)
                state.inExpressionEvaluation = true
                state.PushEvaluationStack(StringValue(sb))
                break
                
            case .choiceCount:
                var choiceCount = state.generatedChoices.count
                state.PushEvaluationStack(IntValue(choiceCount))
                break
                
            case .turns:
                state.PushEvaluationStack(IntValue(state.currentTurnIndex + 1))
                break
                
            case .turnsSince:
                fallthrough
                
            case .readCount:
                var target = state.PopEvaluationStack()
                if !(target is DivertTargetValue) {
                    var extraNote = ""
                    if target is IntValue {
                        extraNote = ". Did you accidentally pass a read count ('knot_name') instead of a target ('-> knot_name')?"
                    }
                    Error("TURNS_SINCE expected a divert target (knot, stitch, label name), but saw \(target)\(extraNote)")
                    break
                }
                
                var divertTarget = target as! DivertTargetValue
                var eitherCount = 0 // value not explicitly defined in C# code, so I assume it defaults to 0?
                if var container = ContentAtPath(divertTarget.targetPath)?.correctObj as? Container {
                    if evalCommand.commandType == .turnsSince {
                        eitherCount = state.TurnsSinceForContainer(container)
                    }
                    else {
                        eitherCount = state.VisitCountForContainer(container)
                    }
                }
                else {
                    if evalCommand.commandType == .turnsSince {
                        eitherCount = -1 // turn count, default to never/unknown
                    }
                    else {
                        eitherCount = 0 // visit count, assume 0 to default to allowing entry
                    }
                    
                    Warning("Failed to find container for \(evalCommand) lookup at \(divertTarget.targetPath)")
                }
                
                state.PushEvaluationStack(IntValue(eitherCount))
                break
                
            case .random:
                guard var maxInt = state.PopEvaluationStack() as? IntValue else {
                    Error("Invalid value for maximum parameter of RANDOM(min, max)")
                }
                
                guard var minInt = state.PopEvaluationStack() as? IntValue else {
                    Error("Invalid value for minimum parameter of RANDOM(min, max)")
                }
                
                // +1 because it's inclusive of min and max, for e.g. RANDOM(1,6) for a dice roll.
                var randomRange: Int
                do {
                    randomRange = checked(maxInt.value! - minInt.value! + 1)
                }
                catch {
                    randomRange = Int.max
                    Error("RANDOM() was called with a range that exceeds the size that ink numbers can use.")
                }
                if randomRange <= 0 {
                    Error("RANDOM() was called with minimum as \(minInt.value!) and maximum as \(maxInt.value!). The maximum must be larger")
                }
                
                var resultSeed = state.storySeed + state.previousRandom
                var random = Random(resultSeed)
                
                var nextRandom = random.Next()
                var chosenValue = (nextRandom % randomRange) + minInt.value!
                state.PushEvaluationStack(IntValue(chosenValue))
                
                // Next random number (rather than keeping the Random object around)
                state.previousRandom = nextRandom
                break
                
            case .seedRandom:
                guard let seed = state.PopEvaluationStack() as? IntValue else {
                    Error("Invalid value passed to SEED_RANDOM()")
                }
                
                // Story seed affects both RANDOM and shuffle behavior
                state.storySeed = seed.value
                state.previousRandom = 0
                
                // SEED_RANDOM returns nothing
                state.PushEvaluationStack(Void())
                break
                
            case .visitIndex:
                var count = state.VisitCountForContainer(state.currentPointer.container) - 1 // index not count
                state.PushEvaluationStack(IntValue(count))
                break
                
            case .sequenceShuffleIndex:
                var shuffleIndex = NextSequenceShuffleIndex()
                state.PushEvaluationStack(IntValue(shuffleIndex))
                break
                
            case .startThread:
                // Handled in main step function
                break
                
            case .done:
                // We may exist in the context of the initial
                // act of creating the thread, or in the context of
                // evaluating the content.
                if state.callStack.canPopThread {
                    state.callStack.PopThread()
                }
                
                // In normal flow - allow safe exit without warning
                else {
                    state.didSafeExit = true
                    
                    // Stop flow in current thread
                    state.currentPointer = Pointer.Null
                }
                
                break
                
            // Force flow to end completely
            case .end:
                state.ForceEnd()
                break
                
            case .listFromInt:
                guard let intVal = state.PopEvaluationStack() as? IntValue else {
                    throw StoryError.nonIntWhenCreatingListFromNumericalValue
                }
                
                var listNameVal = state.PopEvaluationStack() as! StringValue
                
                var generatedListValue: ListValue? = nil
                
                if let foundListDef = listDefinitions?.TryListGetDefinition(listNameVal.value!) {
                    if let foundItem = foundListDef.TryGetItemWithValue(intVal.value!) {
                        generatedListValue = ListValue(foundItem, intVal.value!)
                    }
                }
                else {
                    throw StoryError.failedToFindList(called: listNameVal.value!)
                }
                
                if generatedListValue == nil {
                    generatedListValue = ListValue()
                }
                
                state.PushEvaluationStack(generatedListValue)
                break
                
            case .listRange:
                var max = state.PopEvaluationStack() as? BaseValue
                var min = state.PopEvaluationStack() as? BaseValue
                
                var targetList = state.PopEvaluationStack() as? ListValue
                
                if targetList == nil || min == nil || max == nil {
                    throw StoryError.expectedListMinAndMaxForListRange
                }
                
//                var result = targetList!.value!.ListWithSubrange(min?.value, max?.value)
                var result: InkList
                state.PushEvaluationStack(ListValue(result))
                break
                
            case .listRandom:
                guard let listVal = state.PopEvaluationStack() as? ListValue else {
                    throw StoryError.expectedListForListRandom
                }
                
                var list = listVal.value!
                
                var newList: InkList? = nil
                
                // List was empty: return empty list
                if list.count == 0 {
                    newList = InkList()
                }
                
                // Non-empty source list
                else {
                    var resultSeed = state.storySeed + state.previousRandom
                    var random = Random(resultSeed)
                    
                    var nextRandom = random.Next()
                    var listItemIndex = nextRandom % list.count
                    
                    // Iterate through to get the random element
                    var listEnumerator = list.internalDict.enumerated().makeIterator()
                    for i in 0 ..< listItemIndex {
                        listEnumerator.next()
                    }
                    var randomItem = listEnumerator.next()!.element
                    
                    // Origin list is simply the origin of the one element
                    newList = InkList(randomItem.key.originName!, self)
                    newList?.internalDict[randomItem.key] = randomItem.value
                    
                    state.previousRandom = nextRandom
                }
                
                state.PushEvaluationStack(ListValue(newList!))
                break
                
            default:
                Error("unhandled ControlCommand: \(evalCommand)")
                break
            }
            
            return true
        }
        
        // Variable assignment
        else if let varAss = contentObj as? VariableAssignment {
            var assignedVal = state.PopEvaluationStack()
            
            // When in temporary evaluation, don't create new variables purely within
            // the temporary context, but attempt to create them globally
            // var prioritiseHigherInCallstack = _temporaryEvaluationContainer != nil
            
            state.variablesState?.Assign(varAss, assignedVal)
            return true
        }
        
        // Variable reference
        else if let varRef = contentObj as? VariableReference {
            var foundValue: Object? = nil
            
            // Explicit read count value
            if varRef.pathForCount != nil {
                var container = varRef.containerForCount
                var count = state.VisitCountForContainer(container!)
                foundValue = IntValue(count)
            }
            
            // Normal variable reference
            else {
                foundValue = state.variablesState?.GetVariableWithName(varRef.name)
                
                if foundValue == nil {
                    Warning("Variable not found: '\(varRef.name)'. Using default value of 0 (false). This can happen with temporary variables if the declaration hasn't yet been hit. Globals are always given a default value on load if a value doesn't exist in the save state.")
                    foundValue = IntValue(0)
                }
            }
            
            state.PushEvaluationStack(foundValue!)
            return true
        }
        
        // Native function call
        else if let function = contentObj as? NativeFunctionCall {
            var funcParams = try state.PopEvaluationStack(function.numberOfParameters)
            var result = function.Call(funcParams)
            state.PushEvaluationStack(result)
            return true
        }
        
        // No control content, must be ordinary content
        return false
    }
    
    /// Change the current position of the story to the given path. From here, you can
    /// call `Continue()` to evaluate the next line.
    ///
    /// The path string is a dot-separated path as used internally by the engine.
    /// These examples should work:
    ///
    ///     myKnot
    ///     myKnot.myStitch
    ///
    /// Note however that this won't necessarily work:
    ///
    ///     myKnot.myStitch.myLabelledChoice
    ///
    /// ...because of the way that content is nested within a weave structure.
    ///
    /// By default this will reset the callstack beforehand, which means that any
    /// tunnels, threads, or functions you were in at the time of calling will be
    /// discarded. This is different from the behavior of `ChooseChoiceIndex()`, which
    /// will always keep the callstack, since the choices are known to come from the
    /// correct state, and known their source thread.
    ///
    /// You have the option of passing `false` to the `resetCallstack` parameter if you
    /// don't want this behavior, and will leave any active threads, tunnels, or
    /// function calls intact.
    ///
    /// This is potentially dangerous! If you're in the middle of a tunnel,
    /// it'll redirect only the innermost tunnel, meaning that when you tunnel-return
    /// using `->->`, it'll return to where you were before. This may be what you want, though.
    /// However, if you're in the middle of a function, `ChoosePathString()` will throw an exception.
    /// - Parameter path: A dot-separated path string, as specified in the discussion.
    /// - Parameter resetCallstack: Whether to reset the callstack first.
    /// - Parameter arguments: Optional set of arguments to pass, if path is to a knot that takes them.
    public func ChoosePathString(_ path: String, resetCallstack: Bool = true, _ arguments: Any?...) throws {
        IfAsyncWeCant("call ChoosePathString right now")
        if onChoosePathString != nil {
            onChoosePathString(path, arguments)
        }
        if resetCallstack {
            ResetCallstack()
        }
        else {
            // ChoosePathString is potentially dangerous since you can call it when the stack is
            // pretty much in any state. Let's catch one of the worst offenders.
            if state.callStack.currentElement.type == .Function {
                var funcDetail = ""
                if let container = state.callStack.currentElement.currentPointer.container {
                    funcDetail = "(\(container.path.description)) "
                }
                throw StoryError.choosePathStringCalledDuringFunction(funcDetail: funcDetail, pathString: path.description, stackTrace: state.callStack.callStackTrace)
            }
        }
        
        try state.PassArgumentsToEvaluationStack(arguments)
        ChoosePath(Path(path))
    }
    
    func IfAsyncWeCant(_ activityStr: String) throws {
        if _asyncContinueActive {
            throw StoryError.cannotPerformActionBecauseAsync(activityStr: activityStr)
        }
    }
    
    public func ChoosePath(_ p: Path, incrementingTurnIndex: Bool = true) {
        state.SetChosenPath(p, incrementingTurnIndex)
        
        // Take a note of newly visited containers for read counts etc
        VisitChangedContainersDueToDivert()
    }
    
    /// Chooses the `Choice` from the `currentChoices` array with the given
    /// index. Internally, this sets the current content path to that
    /// pointed to by the `Choice`, ready to continue story evaluation.
    public func ChooseChoiceIndex(_ choiceIdx: Int) {
        var choices = currentChoices
        assert(choiceIdx >= 0 && choiceIdx < choices.count, "choice out of range")
        
        // Replace callstack with the one from the thread at the choosing point,
        // so that we can jump into the right place in the flow.
        // This is important in case the flow was forked by a new thread, which
        // can create multiple leading edges for the story, each of
        // which has its own context.
        var choiceToChoose = choices[choiceIdx]
        if onMakeChoice != nil {
            onMakeChoice(choiceToChoose)
        }
        state.callStack.currentThread = choiceToChoose.threadAtGeneration
        
        ChoosePath(choiceToChoose.targetPath!)
    }
    
    // Stopped at HasFunction (line 1804)
    
    private var _mainContentContainer: Container?
    private var _listDefinitions: ListDefinitionsOrigin?
    
    struct ExternalFunctionDef {
        var function: ExternalFunction
        var lookaheadSafe: Bool
    }
    
    private var _externals: [String: ExternalFunctionDef]
    private var _variableObservers: [String: VariableObserver]
    private var _hasValidatedExternals: Bool
    
    private var _temporaryEvaluationContainer: Container?
    
    private var _state: StoryState
    
    private var _asyncContinueActive: Bool
    private var _stateSnapshotAtLastNewline: StoryState? = nil
    private var _sawLookaheadUnsafeFunctionAfterNewline: Bool = false
    
    private var _recursiveContinueCount: Int = 0
    
    private var _asyncSaving: Bool = false
    
    private var _profiler: Profiler?
}

