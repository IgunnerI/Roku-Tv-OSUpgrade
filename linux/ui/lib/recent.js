// Recent tiles: an ordering of tiles selected in this launcher, kept in the
// launcher browser's localStorage on this box only.

export function recentPush(list, id, max) {
  return [id, ...list.filter((item) => item !== id)].slice(0, max);
}

export function recentFilter(list, knownIds, max) {
  if (!Array.isArray(list)) return [];
  return list.filter((item) => typeof item === "string" && knownIds.has(item)).slice(0, max);
}

const KEY = "amber.recent";

export function recentLoad(storage) {
  try {
    return JSON.parse(storage.getItem(KEY) || "[]");
  } catch {
    return [];
  }
}

export function recentSave(storage, list) {
  try {
    storage.setItem(KEY, JSON.stringify(list));
  } catch {
    // Storage unavailable: Recent still works for this session.
  }
}

export function recentClear(storage) {
  try {
    storage.removeItem(KEY);
  } catch {
    // Nothing stored.
  }
}
