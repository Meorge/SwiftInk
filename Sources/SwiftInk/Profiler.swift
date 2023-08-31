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
    public func report() -> String {
        var sb = ""
        sb += "\(_numContinues) CONTINUES / LINES:\n"
        sb += "TOTAL TIME: \(Profiler.formatMillisecs(_continueTotal))\n"
        sb += "SNAPSHOTTING: \(Profiler.formatMillisecs(_snapTotal))\n"
        sb += "OTHER: \(Profiler.formatMillisecs(_continueTotal - (_stepTotal + _snapTotal)))\n"
        sb += "\(_rootNode)"
        return sb
    }
    
    public func preContinue() {
        _continueWatch.reset()
        _continueWatch.start()
    }
    
    public func postContinue() {
        _continueWatch.stop()
        _continueTotal += millisecs(forStopwatch: _continueWatch)
        _numContinues += 1
    }
    
    public func preStep() {
        _currStepStack = nil
        _stepWatch.reset()
        _stepWatch.start()
    }
    
    public func step(_ callstack: CallStack) {
        _stepWatch.stop()
        
        var stack: [String] = []
        for i in 0 ..< callstack.elements.count {
            var stackElementName: String = ""
            if !callstack.elements[i].currentPointer.isNull {
                let objPath = callstack.elements[i].currentPointer.path!
                
                for c in 0 ..< objPath.length {
                    let comp = objPath.getComponent(atIndex: c)
                    if !comp.isIndex {
                        stackElementName = comp.name!
                        break
                    }
                }
            }
            
            stack[i] = stackElementName
        }
        
        _currStepStack = stack
        
        let currObj = callstack.currentElement.currentPointer.resolve()
        
        var stepType: String? = nil
        let controlCommandStep = currObj as? ControlCommand
        if controlCommandStep != nil {
            stepType = "\(controlCommandStep!.commandType) CC"
        }
        else {
            stepType = "\(currObj!.self)"
        }
        
        _currStepDetails = StepDetails(type: stepType!, obj: currObj)
        
        _stepWatch.start()
    }
    
    public func postStep() {
        _stepWatch.stop()
        
        let duration = millisecs(forStopwatch: _stepWatch)
        _stepTotal += duration
        
        _rootNode.addSample(withStack: _currStepStack!, forDuration: duration)
        
        
        _currStepDetails!.time = duration
        _stepDetails.append(_currStepDetails!)
    }
    
    
    /// Generate a printable report specifying the average and maximum times spent
    /// stepping over different internal ink instruction types.
    /// This report type is primarily used to profile the ink engine itself rather
    /// than your own specific ink.
    public func stepLengthReport() -> String {
        var sb = ""
        
        sb += "TOTAL: \(_rootNode.totalMillisecs)ms"
        
        // Group step details by type
        var averageStepTimes = Dictionary(grouping: _stepDetails, by: { $0.type })
            .mapValues { stepDetails in
                stepDetails.map { $0.time }.reduce(0.0, +) / Double(stepDetails.count)
            }
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
            .map { "\($0.0): \($0.1)ms" }
        
        sb += "AVERAGE STEP TIMES: \(averageStepTimes.joined(separator: ", "))"
        
        
        var stepTimesGrouped2 = Dictionary(grouping: _stepDetails, by: { $0.type })
        
        var sortedKvPairs: [(String, Double)] = []
        for kvPair in stepTimesGrouped2 {
            let key = "\(kvPair.key) (x\(kvPair.value.count))"
            let sum = kvPair.value.map { $0.time }.reduce(0.0, +)
            sortedKvPairs.append((key, sum))
        }
        
        sortedKvPairs.sort { $0.1 > $1.1 }
        let accumStepTimes = sortedKvPairs.map { "\($0.0): \($0.1)" }
        
        sb += "ACCUMULATED STEP TIMES: \(accumStepTimes.joined(separator: ", "))"
        
        return sb
    }
    
    /// Create a large log of all the internal instructions that were evaluated while profiling was active.
    /// Log is in a tab-separated format, for easy loading into a spreadsheet application.
    public func megalog() -> String {
        var sb = ""
        
        sb += "Step type\tDescription\tPath\tTime\n"
        
        let fmt = NumberFormatter()
        fmt.minimumFractionDigits = 8
        fmt.maximumFractionDigits = 8
        fmt.numberStyle = .decimal
        
        for step in _stepDetails {
            sb += "\(step.type)"
            sb += "\t"
            sb += "\(step.obj!)"
            sb += "\t"
            sb += "\(step.obj!.path)"
            sb += "\t"
            sb += fmt.string(for: step.time)!
            sb += "\n"
        }
        
        return sb
    }
    
    public func preSnapshot() {
        _snapWatch.reset()
        _snapWatch.start()
    }
    
    public func postSnapshot() {
        _snapWatch.stop()
        _snapTotal += millisecs(forStopwatch: _snapWatch)
    }
    
    func millisecs(forStopwatch watch: Stopwatch) -> Double {
        watch.elapsedTime * 1000.0
    }
    
    
    public static func formatMillisecs(_ num: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        if num > 5000 {
            fmt.minimumFractionDigits = 1
            fmt.maximumFractionDigits = 1
            return "\(fmt.string(for: num / 1000.0)!) secs"
        }
        else if num > 1000 {
            fmt.minimumFractionDigits = 2
            fmt.maximumFractionDigits = 2
            return "\(fmt.string(for: num / 1000.0)!) secs"
        }
        else if num > 100 {
            fmt.minimumFractionDigits = 0
            fmt.maximumFractionDigits = 0
            return "\(fmt.string(for: num)!) ms"
        }
        else if num > 1 {
            fmt.minimumFractionDigits = 1
            fmt.maximumFractionDigits = 1
            return "\(fmt.string(for: num)!) ms"
        }
        else if num > 0.01 {
            fmt.minimumFractionDigits = 3
            fmt.maximumFractionDigits = 3
            return "\(fmt.string(for: num)!) ms"
        }
        else {
            return "\(fmt.string(for: num)!) ms"
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
    
    public func addSample(withStack stack: [String], forDuration duration: Double) {
        addSample(withStack: stack, atStackIndex: -1, forDuration: duration)
    }
    
    func addSample(withStack stack: [String], atStackIndex stackIdx: Int, forDuration duration: Double) {
        _totalSampleCount += 1
        _totalMillisecs += duration
        
        if stackIdx == stack.count - 1 {
            _selfSampleCount += 1
            _selfMillisecs += duration
        }
        
        if stackIdx + 1 < stack.count {
            addSampleToNode(withStack: stack, atStackIndex: stackIdx + 1, forDuration: duration)
        }
    }
    
    func addSampleToNode(withStack stack: [String], atStackIndex stackIdx: Int, forDuration duration: Double) {
        let nodeKey = stack[stackIdx]

        var node: ProfileNode
        if _nodes.keys.contains(nodeKey) {
            node = ProfileNode(nodeKey)
            _nodes[nodeKey] = node
        }
        else {
            node = _nodes[nodeKey]!
        }
        
        node.addSample(withStack: stack, atStackIndex: stackIdx, forDuration: duration)
    }
    
    public var descendingOrderedNodes: [Dictionary<String, ProfileNode>.Element] {
        return _nodes.sorted { $0.value._totalMillisecs > $1.value._totalMillisecs }
    }
    
    func printHierarchy(withInitialString sb: String, withIndentation indent: Int) -> String {
        var new = sb
        new = pad(new, withSpaces: indent)
        
        new += "\(key ?? "nil key"): \(ownReport)\n"
        
        for keyNode in descendingOrderedNodes {
            new = keyNode.value.printHierarchy(withInitialString: new, withIndentation: indent + 1)
        }
        
        return new
    }
    
    /// Generates a string giving timing information for this single node, including
    /// total milliseconds spent on the piece of ink, the time spent within itself
    /// (v.s. spent in chiildren), as well as the number of samples (instruction steps)
    /// recorded for both too.
    public var ownReport: String {
        var sb = ""
        sb += "total \(Profiler.formatMillisecs(_totalMillisecs)), self \(Profiler.formatMillisecs(_selfMillisecs))"
        sb += " (\(_selfSampleCount) self samples, \(_totalSampleCount) total)"
        return sb
    }
    
    func pad(_ sb: String, withSpaces spaces: Int) -> String {
        var new = sb
        for _ in 0 ..< spaces {
            new += "   "
        }
        return new
    }
    
    public var description: String {
        return printHierarchy(withInitialString: "", withIndentation: 0)
    }
    
    var _nodes: [String: ProfileNode] = [:]
    var _selfMillisecs: Double = 0.0
    var _totalMillisecs: Double = 0.0
    var _selfSampleCount: Int = 0
    var _totalSampleCount: Int = 0
}

class Stopwatch {
    func start() {
        startTime = CFAbsoluteTimeGetCurrent()
        endTime = 0.0
        running = true
    }
    
    func stop() {
        endTime = CFAbsoluteTimeGetCurrent()
        running = false
    }
    
    func reset() {
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
