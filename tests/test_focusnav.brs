sub TestFocusNav()
    L = { cols: 4, recentCount: 2, gridCount: 7 }  ' grid rows: 0-3, 4-6

    AssertEqual(NavMove({ area: "grid", index: 1 }, "right", L), { area: "grid", index: 2, openDrawer: false }, "grid right")
    AssertEqual(NavMove({ area: "grid", index: 3 }, "right", L), { area: "grid", index: 3, openDrawer: false }, "grid right edge stays")
    AssertEqual(NavMove({ area: "grid", index: 6 }, "right", L), { area: "grid", index: 6, openDrawer: false }, "last tile right stays")
    AssertEqual(NavMove({ area: "grid", index: 4 }, "left", L), { area: "grid", index: 4, openDrawer: true }, "left at column 0 opens drawer")
    AssertEqual(NavMove({ area: "grid", index: 5 }, "left", L), { area: "grid", index: 4, openDrawer: false }, "grid left")
    AssertEqual(NavMove({ area: "grid", index: 1 }, "down", L), { area: "grid", index: 5, openDrawer: false }, "grid down")
    AssertEqual(NavMove({ area: "grid", index: 3 }, "down", L), { area: "grid", index: 6, openDrawer: false }, "down into shorter row lands on last")
    AssertEqual(NavMove({ area: "grid", index: 5 }, "down", L), { area: "grid", index: 5, openDrawer: false }, "bottom row down stays")
    AssertEqual(NavMove({ area: "grid", index: 6 }, "up", L), { area: "grid", index: 2, openDrawer: false }, "grid up")
    AssertEqual(NavMove({ area: "grid", index: 3 }, "up", L), { area: "recent", index: 1, openDrawer: false }, "up into recent clamps column")
    AssertEqual(NavMove({ area: "grid", index: 0 }, "up", { cols: 4, recentCount: 0, gridCount: 7 }), { area: "grid", index: 0, openDrawer: false }, "up with no recent stays")

    AssertEqual(NavMove({ area: "recent", index: 0 }, "right", L), { area: "recent", index: 1, openDrawer: false }, "recent right")
    AssertEqual(NavMove({ area: "recent", index: 1 }, "right", L), { area: "recent", index: 1, openDrawer: false }, "recent right edge stays")
    AssertEqual(NavMove({ area: "recent", index: 0 }, "left", L), { area: "recent", index: 0, openDrawer: true }, "recent left edge opens drawer")
    AssertEqual(NavMove({ area: "recent", index: 1 }, "down", L), { area: "grid", index: 1, openDrawer: false }, "recent down keeps column")
    AssertEqual(NavMove({ area: "recent", index: 1 }, "up", L), { area: "recent", index: 1, openDrawer: false }, "recent up stays")
    AssertEqual(NavMove({ area: "recent", index: 1 }, "OK", L), { area: "recent", index: 1, openDrawer: false }, "non-direction key ignored")

    ' Exhaustive: no key from any valid position leaves focus out of range.
    for each key in ["up", "down", "left", "right"]
        for i = 0 to L.gridCount - 1
            r = NavMove({ area: "grid", index: i }, key, L)
            AssertEqual(NavInRange(r, L), true, "grid " + i.ToStr() + " " + key + " in range")
        end for
        for i = 0 to L.recentCount - 1
            r = NavMove({ area: "recent", index: i }, key, L)
            AssertEqual(NavInRange(r, L), true, "recent " + i.ToStr() + " " + key + " in range")
        end for
    end for

    AssertEqual(NavClamp({ area: "recent", index: 3 }, { cols: 4, recentCount: 0, gridCount: 7 }), { area: "grid", index: 0 }, "clamp after recent cleared")
    AssertEqual(NavClamp({ area: "recent", index: 3 }, L), { area: "recent", index: 1 }, "clamp recent index")
    AssertEqual(NavClamp({ area: "grid", index: 9 }, L), { area: "grid", index: 6 }, "clamp grid index")
end sub

function NavInRange(r as object, L as object) as boolean
    if r.area = "grid" then return r.index >= 0 and r.index < L.gridCount
    return r.index >= 0 and r.index < L.recentCount
end function
