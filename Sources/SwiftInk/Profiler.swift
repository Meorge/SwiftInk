import Foundation

/// Simple ink profiler that logs every instruction in the story and counts frequency and timing.
///
/// To use:
/// ```
/// var profiler = story.StartProfiling()
/// // play your story for a bit...
/// var reportStr = profiler.Report()
/// story.EndProfiling()
/// ```
public class Profiler {
    /// The root node in the hierarchical tree of recorded ink timings.
    public var rootNode: ProfileNode {
        _rootNode
    }
    
    public init() {
        _rootNode = ProfileNode()
    }
    
    /// Generate a printable report based on the data recording during profiling.
    public func Report() -> String {
        var sb = ""
        sb += "\(_numContinues) CONTINUES / LINES:\n"
        sb += "TOTAL TIME: \(Profiler.FormatMillisecs(_continueTotal))\n"
        sb += "SNAPSHOTTING: \(Profiler.FormatMillisecs(_snapTotal))\n"
        sb += "OTHER: \(Profiler.FormatMillisecs(_continueTotal - (_stepTotal + _snapTotal)))\n"
        sb += "\(_rootNode)"
        return sb
    }
    
    public func PreContinue() {
        _continueWatch.Reset()
        _continueWatch.Start()
    }
    
    public func PostContinue() {
        _continueWatch.Stop()
        _continueTotal += Millisecs(_continueWatch)
        _numContinues += 1
    }
    
    public func PreStep() {
        _currStepStack = nil
        _stepWatch.Reset()
        _stepWatch.Start()
    }
    
    public func Step(_ callstack: CallStack) {
        _stepWatch.Stop()
        
        var stack: [String] = []
        for i in 0 ..< callstack.elements.count {
            var stackElementName: String = ""
            if !callstack.elements[i].currentPointer.isNull {
                let objPath = callstack.elements[i].currentPointer.path!
                
                for c in 0 ..< objPath.length {
                    let comp = objPath.GetComponent(c)
                    if !comp.isIndex {
                        stackElementName = comp.name!
                        break
                    }
                }
            }
            
            stack[i] = stackElementName
        }
        
        _currStepStack = stack
        
        let currObj = callstack.currentElement.currentPointer.Resolve()
        
        var stepType: String? = nil
        let controlCommandStep = currObj as? ControlCommand
        if controlCommandStep != nil {
            stepType = "\(controlCommandStep!.commandType) CC"
        }
        else {
            stepType = "\(currObj!.self)"
        }
        
        _currStepDetails = StepDetails(type: stepType!, obj: currObj)
        
        _stepWatch.Start()
    }
    
    public func PostStep() {
        _stepWatch.Stop()
        
        let duration = Millisecs(_stepWatch)
        _stepTotal += duration
        
        _rootNode.AddSample(_currStepStack!, duration)
        
        
        _currStepDetails!.time = duration
        _stepDetails.append(_currStepDetails!)
    }
    
    
    /// Generate a printable report specifying the average and maximum times spent
    /// stepping over different internal ink instruction types.
    /// This report type is primarily used to profile the ink engine itself rather
    /// than your own specific ink.
    public func StepLengthReport() -> String {
        var sb = ""
        
        sb += "TOTAL: \(_rootNode.totalMillisecs)ms"
        
        
        // TODO: Complete
        return sb
    }
    
    /// Create a large log of all the internal instructions that were evaluated while profiling was active.
    /// Log is in a tab-separated format, for easy loading into a spreadsheet application.
    public func Megalog() -> String {
        var sb = ""
        
        sb += "Step type\tDescription\tPath\tTime\n"
        
        for step in _stepDetails {
            sb += "\(step.type)"
            sb += "\t"
            sb += "\(step.obj!)"
            sb += "\t"
            sb += "\(step.obj!.path)"
            sb += "\t"
            sb += "\(step.time)" // TODO: Foramt "F8"
            sb += "\n"
        }
        
        return sb
    }
    
    public func PreSnapshot() {
        _snapWatch.Reset()
        _snapWatch.Start()
    }
    
    public func PostSnapshot() {
        _snapWatch.Stop()
        _snapTotal += Millisecs(_snapWatch)
    }
    
    func Millisecs(_ watch: Stopwatch) -> Double {
        watch.elapsedTime * 1000.0
    }
    
    // TODO: do the formatting stuff!!
    public static func FormatMillisecs(_ num: Double) -> String {
        if num > 5000 {
            return "\(num / 1000.0) secs"
        }
        else if num > 1000 {
            return "\(num / 1000.0) secs"
        }
        else if num > 100 {
            return "\(num) ms"
        }
        else if num > 1 {
            return "\(num) ms"
        }
        else if num > 0.01 {
            return "\(num) ms"
        }
        else {
            return "\(num) ms"
        }
    }
    
    var _continueWatch = Stopwatch()
    var _stepWatch = Stopwatch()
    var _snapWatch = Stopwatch()
    
    var _continueTotal: Double = 0.0
    var _snapTotal: Double = 0.0
    var _stepTotal: Double = 0.0
    
    var _currStepStack: [String]?
    var _currStepDetails: StepDetails?
    var _rootNode: ProfileNode
    var _numContinues: Int = 0
    
    struct StepDetails {
        public var type: String
        public var obj: Object? = nil
        public var time: Double = 0.0
    }
    
    var _stepDetails: [StepDetails] = []
}

/// Node used in the hierarchical tree of timings used by the Profiler.
/// Each node corresponds to a single lien viewable in a UI-based representation.
public class ProfileNode: CustomStringConvertible {
    public let key: String?
    
    /// Whether this node contains any sub-nodes - i.e. does it call anything else
    /// that has been recorded?
    public var hasChildren: Bool {
        _nodes.count > 0
    }
    
    /// Total number of milliseconds this node has been active for.
    public var totalMillisecs: Int {
        Int(_totalMillisecs)
    }
    
    public init() {
        self.key = nil
    }
    
    public init(_ key: String) {
        self.key = key
    }
    
    public func AddSample(_ stack: [String], _ duration: Double) {
        AddSample(stack, -1, duration)
    }
    
    func AddSample(_ stack: [String], _ stackIdx: Int, _ duration: Double) {
        _totalSampleCount += 1
        _totalMillisecs += duration
        
        if stackIdx == stack.count - 1 {
            _selfSampleCount += 1
            _selfMillisecs += duration
        }
        
        if stackIdx + 1 < stack.count {
            AddSampleToNode(stack, stackIdx + 1, duration)
        }
    }
    
    func AddSampleToNode(_ stack: [String], _ stackIdx: Int, _ duration: Double) {
        let nodeKey = stack[stackIdx]

        var node: ProfileNode
        if _nodes.keys.contains(nodeKey) {
            node = ProfileNode(nodeKey)
            _nodes[nodeKey] = node
        }
        else {
            node = _nodes[nodeKey]!
        }
        
        node.AddSample(stack, stackIdx, duration)
    }
    
    public var descendingOrderedNodes: [Dictionary<String, ProfileNode>.Element] {
        return _nodes.sorted { $0.value._totalMillisecs > $1.value._totalMillisecs }
    }
    
    func PrintHierarchy(_ sb: String, _ indent: Int) -> String {
        var new = sb
        new = Pad(new, indent)
        
        new += "\(key ?? "nil key"): \(ownReport)\n"
        
        for keyNode in descendingOrderedNodes {
            new = keyNode.value.PrintHierarchy(new, indent + 1)
        }
        
        return new
    }
    
    /// Generates a string giving timing information for this single node, including
    /// total milliseconds spent on the piece of ink, the time spent within itself
    /// (v.s. spent in chiildren), as well as the number of samples (instruction steps)
    /// recorded for both too.
    public var ownReport: String {
        var sb = ""
        sb += "total \(Profiler.FormatMillisecs(_totalMillisecs)), self \(Profiler.FormatMillisecs(_selfMillisecs))"
        sb += " (\(_selfSampleCount) self samples, \(_totalSampleCount) total)"
        return sb
    }
    
    func Pad(_ sb: String, _ spaces: Int) -> String {
        var new = sb
        for _ in 0 ..< spaces {
            new += "   "
        }
        return new
    }
    
    public var description: String {
        return PrintHierarchy("", 0)
    }
    
    var _nodes: [String: ProfileNode] = [:]
    var _selfMillisecs: Double = 0.0
    var _totalMillisecs: Double = 0.0
    var _selfSampleCount: Int = 0
    var _totalSampleCount: Int = 0
}

class Stopwatch {
    func Start() {
        startTime = CFAbsoluteTimeGetCurrent()
        endTime = 0.0
        running = true
    }
    
    func Stop() {
        endTime = CFAbsoluteTimeGetCurrent()
        running = false
    }
    
    func Reset() {
        startTime = 0.0
        endTime = 0.0
        running = false
    }
    
    private(set) var running: Bool = false
    private var startTime: CFAbsoluteTime = 0.0
    private var endTime: CFAbsoluteTime = 0.0
    
    public var elapsedTime: CFTimeInterval {
        endTime - startTime
    }
}
