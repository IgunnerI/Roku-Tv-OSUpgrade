' Builds the text and buttons for each Settings section from plain data.
' Pure: tested off-device in tests/test_settings.brs.
'
' data: {
'   net: { linkUp, connectionType, address, networkName } or invalid
'   diag: { state: "idle" | "running" | "done", progress, verdict, steps: [] }
'   diagHistory: [ string ]
'   recentCount: integer
'   device: { appVersion, model, osVersion, uiResolution }
' }
' Returns { heading, body, buttons: [ { label, action } ] }.
' An empty action means the button is shown but does nothing (e.g. while busy).

function SettingsSections() as object
    return [
        { id: "network", label: "Network" }
        { id: "diagnostics", label: "Diagnostics" }
        { id: "recent", label: "Recent apps" }
        { id: "privacy", label: "Privacy" }
        { id: "recovery", label: "Recovery help" }
        { id: "about", label: "About" }
    ]
end function

function SettingsContent(section as string, data as object) as object
    if section = "network" then return SettingsNetwork(data.net)
    if section = "diagnostics" then return SettingsDiagnostics(data.diag, data.diagHistory)
    if section = "recent" then return SettingsRecent(data.recentCount)
    if section = "privacy" then return SettingsPrivacy()
    if section = "recovery" then return SettingsRecovery()
    return SettingsAbout(data.device)
end function

function SettingsConnectionName(connectionType as string) as string
    if connectionType = "WiFiConnection" then return "Wi-Fi"
    if connectionType = "WiredConnection" then return "Wired"
    if connectionType = "" then return "None"
    return "Connected"
end function

function SettingsNetwork(net as dynamic) as object
    if net = invalid then
        body = "Reading network status…"
    else
        link = "Down"
        if net.linkUp then link = "Up"
        body = "Connection: " + SettingsConnectionName(net.connectionType) + chr(10)
        body = body + "Link: " + link + chr(10)
        body = body + "Local address: " + SettingsOrDash(net.address) + chr(10)
        body = body + "Network name: " + SettingsOrDash(net.networkName) + chr(10) + chr(10)
        body = body + "Read-only. Network changes are made in Roku Settings > Network; this app cannot change them."
    end if
    return { heading: "Network", body: body, buttons: [{ label: "Run diagnostics", action: "showDiagnostics" }] }
end function

function SettingsDiagnostics(diag as object, history as object) as object
    nl = chr(10)
    if diag.state = "running" then
        body = diag.progress
        buttons = [{ label: "Checking…", action: "" }]
    else if diag.state = "done" then
        verdict = DiagVerdictText(diag.verdict)
        body = verdict.title + nl + verdict.advice + nl
        for each line in diag.steps
            body = body + nl + line
        end for
        buttons = [{ label: "Run again", action: "runDiagnostics" }, { label: "Clear results", action: "clearDiagnostics" }]
    else
        body = "Checks the network link, the local address, and whether up to two test destinations answer (connectivitycheck.gstatic.com, then www.msftconnecttest.com)." + nl + nl
        body = body + "Runs only when you select it, gives up after a short time limit, and keeps results on this TV."
        buttons = [{ label: "Run check", action: "runDiagnostics" }]
    end if
    if history.Count() > 0 then
        body = body + nl + nl + "Earlier results:"
        for each line in history
            body = body + nl + line
        end for
    end if
    return { heading: "Diagnostics", body: body, buttons: buttons }
end function

function SettingsRecent(count as integer) as object
    body = "Recent shows tiles you selected in this launcher, newest first. It cannot see what you watch in other channels." + chr(10) + chr(10)
    if count = 1 then
        body = body + "1 tile is listed."
    else
        body = body + count.ToStr() + " tiles are listed."
    end if
    return { heading: "Recent apps", body: body, buttons: [{ label: "Clear recent apps", action: "clearRecent" }] }
end function

function SettingsPrivacy() as object
    nl = chr(10)
    body = "This launcher collects no analytics and sends no usage data." + nl + nl
    body = body + "Stored on this TV only: the Recent list. Diagnostics results are kept in memory until you close the app." + nl + nl
    body = body + "Network requests made by this app: only the diagnostics check, and only when you run it." + nl + nl
    body = body + "Roku OS, the Channel Store and other channels are outside this app's control and may send their own data."
    return { heading: "Privacy", body: body, buttons: [{ label: "Clear all local data", action: "clearAll" }] }
end function

function SettingsRecovery() as object
    nl = chr(10)
    body = "1. Roku Settings > Network > Check connection." + nl
    body = body + "2. Restart your router: unplug it for 30 seconds." + nl
    body = body + "3. Restart the TV: Roku Settings > System > Power > System restart." + nl
    body = body + "4. On Wi-Fi, move the router closer or try a wired connection." + nl
    body = body + "5. On hotel or guest Wi-Fi, complete the sign-in from Roku Settings > Network." + nl + nl
    body = body + "These steps happen in Roku's own menus. This app does not change network settings."
    return { heading: "Recovery help", body: body, buttons: [] }
end function

function SettingsAbout(device as object) as object
    nl = chr(10)
    body = "Amber Launcher " + device.appVersion + nl
    body = body + "A static, privacy-first home screen for Roku." + nl + nl
    body = body + "Device: " + SettingsOrDash(device.model) + nl
    body = body + "Roku OS: " + SettingsOrDash(device.osVersion) + nl
    body = body + "Interface: " + SettingsOrDash(device.uiResolution) + nl + nl
    body = body + "The Home button always returns to Roku's own home screen; apps cannot change that."
    return { heading: "About", body: body, buttons: [] }
end function

function SettingsOrDash(value as dynamic) as string
    t = type(value)
    if (t = "roString" or t = "String") and value <> "" then return value
    return "—"
end function
