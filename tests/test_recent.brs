sub TestRecent()
    AssertEqual(RecentPush([], "a", 4), ["a"], "push into empty")
    AssertEqual(RecentPush(["a", "b"], "c", 4), ["c", "a", "b"], "push new to front")
    AssertEqual(RecentPush(["a", "b", "c"], "b", 4), ["b", "a", "c"], "existing moves to front, no duplicate")
    AssertEqual(RecentPush(["a", "b", "c", "d"], "e", 4), ["e", "a", "b", "c"], "bounded at max")

    known = { a: true, b: true }
    AssertEqual(RecentFilter(["a", "x", 3, "b"], known, 4), ["a", "b"], "filter drops unknown and non-strings")
    AssertEqual(RecentFilter(["a", "b"], known, 1), ["a"], "filter bounded")
end sub
