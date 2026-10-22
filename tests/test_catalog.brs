sub TestCatalog()
    shipped = CatalogLoad()
    raw = ParseJson(ReadAsciiFile("pkg:/data/catalog.json"))
    AssertEqual(shipped.Count(), raw.Count(), "every shipped catalog entry is valid")
    ids = {}
    for each entry in shipped
        AssertEqual(ids.DoesExist(entry.id), false, "unique id " + entry.id)
        ids[entry.id] = true
    end for

    AssertEqual(CatalogParse("not json").Count(), 0, "bad json gives empty catalog")
    AssertEqual(CatalogParse("[{" + chr(34) + "id" + chr(34) + ":1}]").Count(), 0, "invalid entry dropped")
    AssertEqual(CatalogEntryValid({ id: "x", label: "X", kind: "store_page" }), false, "store_page needs channelId")
    AssertEqual(CatalogEntryValid({ id: "x", label: "X", kind: "in_app" }), false, "in_app needs target")
    AssertEqual(CatalogEntryValid({ id: "x", label: "X", kind: "launch", channelId: "1" }), false, "unknown kind rejected")
    AssertEqual(CatalogEntryValid({ id: "x", label: "X", kind: "placeholder" }), true, "placeholder ok")

    store = { kind: "store_page" }
    AssertEqual(CatalogStatusText(store, invalid), "Store page", "status before check")
    AssertEqual(CatalogStatusText(store, true), "Installed · Store page", "status installed")
    AssertEqual(CatalogStatusText(store, false), "Not found · Store page", "status not installed")
    AssertEqual(CatalogStatusText({ kind: "placeholder" }, invalid), "Placeholder", "placeholder status")
end sub
