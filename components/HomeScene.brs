sub init()
    m.cols = 4
    m.maxRecent = 4
    m.tileW = 380
    m.gap = 36

    m.home = m.top.FindNode("home")
    m.settings = m.top.FindNode("settings")
    m.drawer = m.top.FindNode("drawer")
    m.message = m.top.FindNode("message")
    m.netDot = m.top.FindNode("netDot")
    m.netLabel = m.top.FindNode("netLabel")
    m.recentEmpty = m.top.FindNode("recentEmpty")

    m.catalog = CatalogLoad()
    m.byId = {}
    for each entry in m.catalog
        m.byId[entry.id] = entry
    end for
    m.installed = {}

    ' All tiles are created once here and reused; nothing is rebuilt per key.
    m.gridTiles = makeTiles(m.top.FindNode("grid"), m.catalog.Count(), 200)
    for i = 0 to m.catalog.Count() - 1
        m.gridTiles[i].label = m.catalog[i].label
    end for
    m.recentTiles = makeTiles(m.top.FindNode("recentRow"), m.maxRecent, 110)
    m.recent = RecentFilter(RecentLoad(), m.byId, m.maxRecent)

    m.diag = { state: "idle", progress: "", verdict: "", steps: [] }
    m.diagHistory = []
    m.diagRunId = 0
    m.net = invalid
    m.device = readDevice()

    m.mode = "home"          ' "home" | "drawer" | "settings"
    m.focus = { area: "grid", index: 0 }
    m.drawerItems = m.drawer.items
    refreshTiles()
    refreshNetIndicator()
    if m.catalog.Count() = 0 then m.message.text = "The app catalog could not be loaded."

    m.settings.ObserveField("action", "onSettingsAction")
    m.top.SetFocus(true)

    ' Background work starts after the first layout is in place.
    m.netTask = CreateObject("roSGNode", "NetworkTask")
    m.netTask.ObserveField("status", "onNetStatus")
    m.netTask.ObserveField("progress", "onDiagProgress")
    m.netTask.ObserveField("result", "onDiagResult")
    m.netTask.control = "RUN"

    m.appTask = CreateObject("roSGNode", "AppTask")
    m.appTask.checkIds = storeChannelIds()
    m.appTask.ObserveField("installed", "onInstalled")
    m.appTask.control = "RUN"
end sub

function makeTiles(parent as object, count as integer, height as integer) as object
    tiles = []
    for i = 0 to count - 1
        tile = parent.CreateChild("AppTile")
        tile.size = [m.tileW, height]
        tile.translation = [(i mod m.cols) * (m.tileW + m.gap), (i \ m.cols) * (height + m.gap)]
        tiles.Push(tile)
    end for
    return tiles
end function

function storeChannelIds() as object
    ids = []
    for each entry in m.catalog
        if entry.kind = "store_page" then ids.Push(entry.channelId)
    end for
    return ids
end function

function readDevice() as object
    info = CreateObject("roDeviceInfo")
    os = info.GetOSVersion()
    ui = info.GetUIResolution()
    app = CreateObject("roAppInfo")
    return {
        appVersion: app.GetVersion()
        model: info.GetModelDisplayName()
        osVersion: os.major.ToStr() + "." + os.minor.ToStr() + "." + os.revision.ToStr() + " build " + os.build.ToStr()
        uiResolution: ui.name
    }
end function

function navLayout() as object
    return { cols: m.cols, recentCount: m.recent.Count(), gridCount: m.gridTiles.Count() }
end function

' ---- Rendering -------------------------------------------------------------

sub refreshTiles()
    for i = 0 to m.gridTiles.Count() - 1
        entry = m.catalog[i]
        m.gridTiles[i].status = CatalogStatusText(entry, installedFor(entry))
    end for
    for i = 0 to m.recentTiles.Count() - 1
        tile = m.recentTiles[i]
        tile.visible = i < m.recent.Count()
        if tile.visible then
            entry = m.byId[m.recent[i]]
            tile.label = entry.label
            tile.status = CatalogStatusText(entry, installedFor(entry))
        end if
    end for
    m.recentEmpty.visible = m.recent.Count() = 0
    m.focus = NavClamp(m.focus, navLayout())
    applyFocus()
end sub

function installedFor(entry as object) as dynamic
    if entry.kind = "store_page" and m.installed.DoesExist(entry.channelId) then return m.installed[entry.channelId]
    return invalid
end function

' Clears every tile's focus and sets the current one: at most 12 field writes.
sub applyFocus()
    for each tile in m.gridTiles
        tile.focused = false
    end for
    for each tile in m.recentTiles
        tile.focused = false
    end for
    if m.mode <> "home" then return
    if m.focus.area = "recent" then
        m.recentTiles[m.focus.index].focused = true
    else if m.gridTiles.Count() > 0 then
        m.gridTiles[m.focus.index].focused = true
    end if
end sub

sub refreshNetIndicator()
    if m.net = invalid then
        m.netLabel.text = ""
        m.netDot.visible = false
        return
    end if
    m.netDot.visible = true
    if m.net.linkUp and m.net.connectionType <> "" then
        m.netLabel.text = SettingsConnectionName(m.net.connectionType)
        m.netLabel.color = "0x969696FF"
        m.netDot.color = "0x969696FF"
    else
        ' Amber only when something needs attention.
        m.netLabel.text = "Offline"
        m.netLabel.color = "0xF2F0EAFF"
        m.netDot.color = "0xF2B84BFF"
    end if
end sub

sub pushSettingsData()
    m.settings.data = {
        net: m.net
        diag: m.diag
        diagHistory: m.diagHistory
        recentCount: m.recent.Count()
        device: m.device
    }
end sub

' ---- Modes ------------------------------------------------------------------

sub openDrawer()
    m.mode = "drawer"
    m.drawer.focusIndex = 0
    m.drawer.visible = true
    applyFocus()
end sub

sub closeDrawer()
    m.drawer.visible = false
    m.mode = "home"
    applyFocus()
end sub

sub openSettings(sectionId as string)
    m.drawer.visible = false
    pushSettingsData()
    m.settings.callFunc("open", sectionId)
    m.home.visible = false
    m.settings.visible = true
    m.mode = "settings"
    applyFocus()
end sub

' Returns to home with the focus it had before (m.focus is never reset).
sub closeSettings()
    m.settings.visible = false
    m.home.visible = true
    m.mode = "home"
    applyFocus()
end sub

' ---- Keys -------------------------------------------------------------------

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.mode = "settings" then
        if m.settings.callFunc("handleKey", key) = "close" then closeSettings()
        return true
    end if
    if m.mode = "drawer" then return drawerKey(key)
    return homeKey(key)
end function

function homeKey(key as string) as boolean
    m.message.text = ""
    if key = "options" then
        openDrawer()
        return true
    end if
    if key = "OK" then
        activateFocused()
        return true
    end if
    if key = "up" or key = "down" or key = "left" or key = "right" then
        moved = NavMove(m.focus, key, navLayout())
        if moved.openDrawer then
            openDrawer()
        else if moved.area <> m.focus.area or moved.index <> m.focus.index then
            m.focus = { area: moved.area, index: moved.index }
            applyFocus()
        end if
        return true
    end if
    ' Back is not handled here, so Roku closes the app as usual.
    return false
end function

function drawerKey(key as string) as boolean
    index = m.drawer.focusIndex
    if key = "up" and index > 0 then
        m.drawer.focusIndex = index - 1
    else if key = "down" and index < m.drawerItems.Count() - 1 then
        m.drawer.focusIndex = index + 1
    else if key = "back" or key = "right" or key = "options" then
        closeDrawer()
    else if key = "OK" then
        id = m.drawerItems[index].id
        if id = "home" then closeDrawer() else openSettings(id)
    end if
    return true
end function

sub activateFocused()
    if m.focus.area = "recent" then
        if m.focus.index >= m.recent.Count() then return
        entry = m.byId[m.recent[m.focus.index]]
    else
        if m.focus.index >= m.catalog.Count() then return
        entry = m.catalog[m.focus.index]
    end if

    if entry.kind = "in_app" then
        openSettings(entry.target)
    else if entry.kind = "store_page" then
        ' Not a launch: Roku has no documented API for opening another channel.
        recordRecent(entry.id)
        m.appTask.openStore = entry.channelId
        m.message.text = "Opening the Channel Store page for " + entry.label + ". Start it from there."
    else if entry.kind = "placeholder" then
        m.message.text = entry.label + " is a placeholder and cannot be opened."
    else
        m.message.text = entry.label + " cannot be opened on Roku."
    end if
end sub

sub recordRecent(id as string)
    updated = RecentPush(m.recent, id, m.maxRecent)
    if FormatJson(updated) = FormatJson(m.recent) then return
    m.recent = updated
    RecentSave(m.recent)
    ' Keep focus on the tile that was selected; it may have moved in Recent.
    if m.focus.area = "recent" then m.focus.index = 0
    refreshTiles()
end sub

' ---- Settings actions ---------------------------------------------------------

sub onSettingsAction()
    action = m.settings.action
    if action = "runDiagnostics" then
        startDiagnostics()
    else if action = "clearDiagnostics" then
        clearDiagnostics()
    else if action = "clearRecent" then
        clearRecent()
    else if action = "clearAll" then
        clearRecent()
        clearDiagnostics()
    end if
    pushSettingsData()
end sub

sub startDiagnostics()
    if m.diag.state = "running" then return
    m.diagRunId = m.diagRunId + 1
    m.diag = { state: "running", progress: "Starting check…", verdict: "", steps: [] }
    m.netTask.request = m.diagRunId
end sub

sub clearDiagnostics()
    m.diagHistory = []
    if m.diag.state <> "running" then m.diag = { state: "idle", progress: "", verdict: "", steps: [] }
end sub

sub clearRecent()
    RecentClear()
    m.recent = []
    refreshTiles()
end sub

' ---- Task results -----------------------------------------------------------

sub onNetStatus()
    m.net = m.netTask.status
    refreshNetIndicator()
    if m.mode = "settings" then pushSettingsData()
end sub

sub onDiagProgress()
    progress = m.netTask.progress
    if progress.runId <> m.diagRunId or m.diag.state <> "running" then return
    m.diag.progress = progress.text
    if m.mode = "settings" then pushSettingsData()
end sub

sub onDiagResult()
    result = m.netTask.result
    ' Ignore stale results (e.g. a run whose results were cleared).
    if result.runId <> m.diagRunId or m.diag.state <> "running" then return
    m.diag = { state: "done", progress: "", verdict: result.verdict, steps: result.steps }
    ' Bounded, in-memory only.
    m.diagHistory.Unshift("Check " + result.runId.ToStr() + ": " + DiagVerdictText(result.verdict).title)
    while m.diagHistory.Count() > 4
        m.diagHistory.Pop()
    end while
    if m.mode = "settings" then pushSettingsData()
end sub

sub onInstalled()
    m.installed = m.appTask.installed
    refreshTiles()
end sub
