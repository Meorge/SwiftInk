import XCTest
@testable import SwiftInk

final class SwiftInkTests: XCTestCase {
    func testB001() throws {
        let jsonString = """
{
        "inkVersion": 19,
        "root": [
          [
            "^Hello, world!",
            "\\n",
            null
          ],
          "done",
          null
        ],
        "listDefs": {}
      }
"""
        
        let s = try Story(jsonString)
        XCTAssert(try! s.ContinueMaximally() == "Hello, world!\n")
    }
    
    func testB002() throws {
        let jsonString = """
{
  "inkVersion": 19,
  "root": [
    [
      "nop",
      "^I'm after an nop!",
      "^\\n",
      null
    ],
    "done",
    null
  ],
  "listDefs": {}
}
"""
        let s = try Story(jsonString)
        XCTAssert(try! s.ContinueMaximally() == "I'm after an nop!\n")
    }
    
    func testB003() throws {
        let jsonString = """
{
  "inkVersion": 19,
  "root": [
    "ev",
    42,
    "out",
    "/ev",
    "^\\n",
    "done",
    null
  ],
  "listDefs": {}
}
"""
        let s = try Story(jsonString)
        let result = try! s.ContinueMaximally()
        print("The Result: '\(result)'")
        XCTAssert(result == "42\n")
    }
    
    func testB004() throws {
        let jsonString = """
{
  "inkVersion": 19,
  "root": [
    "ev",
    9007199254740992,
    "out",
    "/ev",
    "^\\n",
    "done",
    null
  ],
  "listDefs": {}
}
"""
        let s = try Story(jsonString)
        let result = try! s.ContinueMaximally()
        print("The Result: '\(result)'")
        XCTAssert(result == "9007199254740992\n")
    }
    
    func testB005() throws {
        let jsonString = """
{
  "inkVersion": 19,
  "root": [
    [
      "^Choose A or B:",
      "\\n",
      [
        "ev",
        {
          "^->": "0.2.$r1"
        },
        {
          "temp=": "$r"
        },
        "str",
        {
          "->": ".^.s"
        },
        [
          {
            "#n": "$r1"
          }
        ],
        "/str",
        "/ev",
        {
          "*": "0.c-0",
          "flg": 18
        },
        {
          "s": [
            "^A",
            {
              "->": "$r",
              "var": true
            },
            null
          ]
        }
      ],
      [
        "ev",
        {
          "^->": "0.3.$r1"
        },
        {
          "temp=": "$r"
        },
        "str",
        {
          "->": ".^.s"
        },
        [
          {
            "#n": "$r1"
          }
        ],
        "/str",
        "/ev",
        {
          "*": "0.c-1",
          "flg": 18
        },
        {
          "s": [
            "^B",
            {
              "->": "$r",
              "var": true
            },
            null
          ]
        }
      ],
      {
        "c-0": [
          "ev",
          {
            "^->": "0.c-0.$r2"
          },
          "/ev",
          {
            "temp=": "$r"
          },
          {
            "->": "0.2.s"
          },
          [
            {
              "#n": "$r2"
            }
          ],
          "\\n",
          {
            "->": "0.g-0"
          },
          {
            "#f": 5
          }
        ],
        "c-1": [
          "ev",
          {
            "^->": "0.c-1.$r2"
          },
          "/ev",
          {
            "temp=": "$r"
          },
          {
            "->": "0.3.s"
          },
          [
            {
              "#n": "$r2"
            }
          ],
          "\\n",
          {
            "->": "0.g-0"
          },
          {
            "#f": 5
          }
        ],
        "g-0": [
          "done",
          null
        ]
      }
    ],
    "done",
    null
  ],
  "listDefs": {}
}
"""
        let s = try Story(jsonString)
        var result = try! s.ContinueMaximally()
        XCTAssert(result == "Choose A or B:\n")
        try! s.ChooseChoiceIndex(0)
        result = try! s.ContinueMaximally()
        print("B005 output: '\(result)'")
        XCTAssert(result == "A\n")
    }
    
    func testB006() throws {
        let jsonString = """
{
  "inkVersion": 19,
  "root": [
    "^This is not printed:\\n",
    42,
    "^Neither is this:\\n",
    3.145,
    "done",
    null
  ],
  "listDefs": {}
}
"""
        let s = try Story(jsonString)
        let result = try! s.ContinueMaximally()
        print("B006 output: '\(result)'")
        XCTAssert(result == """
This is not printed:
Neither is this:

""")
    }
    
    func testB007() throws {
        let jsonString = """
{
  "inkVersion": 19,
  "root": [

    "^\\"string\\" + 1 =  ",
    "ev",
    "^string",
    1,
    "+",
    "/ev",
    "out",
    "\\n",

    "^1 + \\"string\\" =  ",
    "ev",
    1,
    "^string",
    "+",
    "/ev",
    "out",
    "\\n",

    "^\\"foo\\" + \\"bar\\" =  ",
    "ev",
    "^foo",
    "^bar",
    "+",
    "/ev",
    "out",
    "\\n",

    "^\\"string\\" + 1.125  =  ",
    "ev",
    "^string",
    1.125,
    "+",
    "/ev",
    "out",
    "\\n",

    "^1.125 + \\"string\\"  =  ",
    "ev",
    1.125,
    "^string",
    "+",
    "/ev",
    "out",
    "\\n",

    "^\\"42\\" == 42 =  ",
    "ev",
    "^42",
    42,
    "==",
    0,
    "+",
    "/ev",
    "out",
    "\\n",

    "^42 == \\"42\\" =  ",
    "ev",
    42,
    "^42",
    "==",
    0,
    "+",
    "/ev",
    "out",
    "\\n",

    "^\\"42\\" == 43 =  ",
    "ev",
    "^42",
    43,
    "==",
    0,
    "+",
    "/ev",
    "out",
    "\\n",

    "^43 == \\"42\\" =  ",
    "ev",
    43,
    "^42",
    "==",
    0,
    "+",
    "/ev",
    "out",
    "\\n",

    "^\\"42\\" != 42 =  ",
    "ev",
    "^42",
    42,
    "!=",
    0,
    "+",
    "/ev",
    "out",
    "\\n",

    "^42 != \\"42\\" =  ",
    "ev",
    42,
    "^42",
    "!=",
    0,
    "+",
    "/ev",
    "out",
    "\\n",

    "^43 != \\"42\\" =  ",
    "ev",
    43,
    "^42",
    "!=",
    0,
    "+",
    "/ev",
    "out",
    "\\n",

    "^\\"42\\" != 43 =  ",
    "ev",
    "^42",
    43,
    "!=",
    0,
    "+",
    "/ev",
    "out",
    "\\n",

    "done",
    null
  ],
  "listDefs": {}
}
"""
        let s = try Story(jsonString)
        let result = try! s.ContinueMaximally()
        print("B006 output: '\(result)'")
        XCTAssert(result == """
"string" + 1 = string1
1 + "string" = 1string
"foo" + "bar" = foobar
"string" + 1.125 = string1.125
1.125 + "string" = 1.125string
"42" == 42 = 1
42 == "42" = 1
"42" == 43 = 0
43 == "42" = 0
"42" != 42 = 0
42 != "42" = 0
43 != "42" = 1
"42" != 43 = 1

""")
    }
    
    func testFogg() throws {
        let jsonString = try String(contentsOfFile: "./fogg.ink.json")
        let s = try Story(jsonString)
        
        while true {
            print(try s.Continue())
            if !s.canContinue {
                if s.currentChoices.count > 0 {
                    for (i, choice) in s.currentChoices.enumerated() {
                        print("\(i): \(choice.text!)")
                    }
                    var playerChoice: Int? = nil
                    while playerChoice == nil {
                        playerChoice = Int(readLine() ?? "0")
                    }
                    
                    try s.ChooseChoiceIndex(playerChoice!)
                }
                else {
                    print("STORY DONE")
                    break
                }
            }
        }
    }
}
