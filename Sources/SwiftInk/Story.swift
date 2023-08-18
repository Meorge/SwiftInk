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
            if !c.isInvisibleByDefault {
                c.index = choices.count
                choices.add(c)
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
        state.variablesState
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
    
    private var _profiler: Profiler
}

