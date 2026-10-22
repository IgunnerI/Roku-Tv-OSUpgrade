sub Main()
    TestFocusNav()
    TestRecent()
    TestCatalog()
    TestDiagnostics()
    TestSettings()
    state = TestState()
    print "Passed: " + state.passed.ToStr() + "  Failed: " + state.failed.ToStr()
    ' scripts/test.sh fails the run unless this line reports zero failures.
end sub
