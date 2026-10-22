' Pure focus logic for the home screen. No SceneGraph calls, so it can be
' unit-tested off-device (tests/test_focusnav.brs).
'
' state:  { area: "recent" | "grid", index: integer }
' layout: { cols: integer, recentCount: integer, gridCount: integer }
' Returns { area, index, openDrawer }. openDrawer is true when Left is
' pressed at the first column; focus is otherwise unchanged at an edge.
function NavMove(state as object, key as string, layout as object) as object
    result = { area: state.area, index: state.index, openDrawer: false }
    cols = layout.cols
    index = state.index

    if state.area = "grid" then
        col = index mod cols
        if key = "left" then
            if col = 0 then result.openDrawer = true else result.index = index - 1
        else if key = "right" then
            if col < cols - 1 and index + 1 < layout.gridCount then result.index = index + 1
        else if key = "down" then
            if index + cols < layout.gridCount then
                result.index = index + cols
            else if index - col + cols < layout.gridCount then
                ' The next row exists but is shorter: land on its last tile.
                result.index = layout.gridCount - 1
            end if
        else if key = "up" then
            if index >= cols then
                result.index = index - cols
            else if layout.recentCount > 0 then
                result.area = "recent"
                result.index = NavMin(col, layout.recentCount - 1)
            end if
        end if
    else
        if key = "left" then
            if index = 0 then result.openDrawer = true else result.index = index - 1
        else if key = "right" then
            if index + 1 < layout.recentCount then result.index = index + 1
        else if key = "down" then
            if layout.gridCount > 0 then
                result.area = "grid"
                result.index = NavMin(index, layout.gridCount - 1)
            end if
        end if
    end if
    return result
end function

' Moves focus back into range after the layout changes (e.g. history cleared).
function NavClamp(state as object, layout as object) as object
    if state.area = "recent" then
        if layout.recentCount > 0 then return { area: "recent", index: NavMin(state.index, layout.recentCount - 1) }
        return { area: "grid", index: 0 }
    end if
    if layout.gridCount = 0 then return { area: "grid", index: 0 }
    return { area: "grid", index: NavMin(state.index, layout.gridCount - 1) }
end function

function NavMin(a as integer, b as integer) as integer
    if a < b then return a
    return b
end function
