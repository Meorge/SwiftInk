import XCTest
@testable import SwiftInk

final class SwiftInkTests: XCTestCase {
    func testB001() throws {
        try loadStoryAndTest(named: "B001")
    }
    
    func testB002() throws {
        try loadStoryAndTest(named: "B002")
    }
    
    func testB003() throws {
        try loadStoryAndTest(named: "B003")
    }
    
    func testB004() throws {
        try loadStoryAndTest(named: "B004")
    }
    
    func testB005() throws {
        try loadStoryAndTest(named: "B005", withChoices: [0])
    }
    
    func testB006() throws {
        try loadStoryAndTest(named: "B006")
    }
    
    func testB007() throws {
        try loadStoryAndTest(named: "B007")
    }
    
    func testFogg() throws {
        try loadStoryAndTest(named: "fogg", withChoices: [0, 1])
    }
    
    func loadStoryAndRun(named storyName: String, withChoices choices: [Int] = []) throws -> String {
        guard let fp = Bundle.module.path(forResource: "TestData/\(storyName)/\(storyName)", ofType: "json") else {
            fatalError("ouch")
        }
        
        let url = URL(fileURLWithPath: fp)
        let jsonString = try String(contentsOf: url)
        let s = try Story(jsonString)
        
        var output = ""
        var choiceNum = 0
        
        while true {
            output += try s.ContinueMaximally()
            if !s.currentChoices.isEmpty {
                try s.ChooseChoiceIndex(choices[choiceNum])
                choiceNum += 1
            }
            else {
                return output
            }
        }
    }
    
    func loadStoryAndTest(named storyName: String, withChoices choices: [Int] = []) throws {
        let output = try loadStoryAndRun(named: storyName, withChoices: choices)
        
        guard let expectedOutputFilepath = Bundle.module.path(forResource: "TestData/\(storyName)/\(storyName)-output", ofType: "txt") else {
            fatalError("ouch")
        }
        
        let url = URL(fileURLWithPath: expectedOutputFilepath)
        let expectedOutput = try String(contentsOf: url)
        
        print("TEST FOR \"\(storyName)\"")
        print("EXPECTED:")
        print(expectedOutput)
        print("==========")
        print("RECEIVED:")
        print(output)
        print("==========")
        XCTAssert(output == expectedOutput)
    }
}
