' Tile catalog, loaded from pkg:/data/catalog.json.
'
' kind values (see docs/ASSESSMENT.md, "Application launching"):
'   "in_app"      supported in-app navigation; needs target (a Settings section)
'   "store_page"  opens the Roku Channel Store page for channelId via
'                 roAppManager.ShowChannelStoreSpringboard. This is NOT a launch:
'                 Roku documents no API for a channel to launch another channel.
'   "placeholder" informational only; selecting it does nothing but explain
'   "unsupported" destination that cannot be opened on this platform
function CatalogLoad() as object
    return CatalogParse(ReadAsciiFile("pkg:/data/catalog.json"))
end function

function CatalogParse(raw as string) as object
    data = ParseJson(raw)
    valid = []
    if type(data) <> "roArray" then return valid
    for each entry in data
        if CatalogEntryValid(entry) then valid.Push(entry)
    end for
    return valid
end function

function CatalogEntryValid(entry as dynamic) as boolean
    if type(entry) <> "roAssociativeArray" then return false
    if not CatalogIsText(entry.id) or not CatalogIsText(entry.label) or not CatalogIsText(entry.kind) then return false
    if entry.kind = "store_page" then return CatalogIsText(entry.channelId)
    if entry.kind = "in_app" then return CatalogIsText(entry.target)
    return entry.kind = "placeholder" or entry.kind = "unsupported"
end function

' Second line on a tile. installed is true/false once checked, invalid before.
function CatalogStatusText(entry as object, installed as dynamic) as string
    if entry.kind = "in_app" then return "Launcher"
    if entry.kind = "store_page" then
        if installed = invalid then return "Store page"
        if installed then return "Installed · Store page"
        return "Not found · Store page"
    end if
    if entry.kind = "placeholder" then return "Placeholder"
    return "Unsupported"
end function

function CatalogIsText(value as dynamic) as boolean
    t = type(value)
    return (t = "roString" or t = "String") and value <> ""
end function
