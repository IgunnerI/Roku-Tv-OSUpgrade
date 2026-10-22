// Pure focus logic for the home screen. Same rules as the Roku app
// (components/lib/FocusNav.brs). Tested in tests/ui-lib.test.mjs.
//
// state:  { area: "recent" | "grid", index }
// layout: { cols, recentCount, gridCount }
// Returns { area, index, openDrawer }.
export function navMove(state, key, layout) {
  const result = { area: state.area, index: state.index, openDrawer: false };
  const { cols } = layout;
  const index = state.index;

  if (state.area === "grid") {
    const col = index % cols;
    if (key === "left") {
      if (col === 0) result.openDrawer = true;
      else result.index = index - 1;
    } else if (key === "right") {
      if (col < cols - 1 && index + 1 < layout.gridCount) result.index = index + 1;
    } else if (key === "down") {
      if (index + cols < layout.gridCount) result.index = index + cols;
      // The next row exists but is shorter: land on its last tile.
      else if (index - col + cols < layout.gridCount) result.index = layout.gridCount - 1;
    } else if (key === "up") {
      if (index >= cols) result.index = index - cols;
      else if (layout.recentCount > 0) {
        result.area = "recent";
        result.index = Math.min(col, layout.recentCount - 1);
      }
    }
  } else {
    if (key === "left") {
      if (index === 0) result.openDrawer = true;
      else result.index = index - 1;
    } else if (key === "right") {
      if (index + 1 < layout.recentCount) result.index = index + 1;
    } else if (key === "down" && layout.gridCount > 0) {
      result.area = "grid";
      result.index = Math.min(index, layout.gridCount - 1);
    }
  }
  return result;
}

// Moves focus back into range after the layout changes (e.g. history cleared).
export function navClamp(state, layout) {
  if (state.area === "recent") {
    if (layout.recentCount > 0) return { area: "recent", index: Math.min(state.index, layout.recentCount - 1) };
    return { area: "grid", index: 0 };
  }
  return { area: "grid", index: Math.max(0, Math.min(state.index, layout.gridCount - 1)) };
}
