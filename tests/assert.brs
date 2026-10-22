' Minimal assertion helpers for the off-device test run (npm test).
function TestState() as object
    globals = GetGlobalAA()
    if globals.testState = invalid then globals.testState = { passed: 0, failed: 0 }
    return globals.testState
end function

' Compares JSON forms case-insensitively: BrightScript associative-array keys
' are case-insensitive, and dotted assignment may change a key's case.
sub AssertEqual(actual as dynamic, expected as dynamic, name as string)
    state = TestState()
    if LCase(FormatJson(actual)) = LCase(FormatJson(expected)) then
        state.passed = state.passed + 1
    else
        state.failed = state.failed + 1
        print "FAIL: " + name + " expected " + FormatJson(expected) + " got " + FormatJson(actual)
    end if
end sub
