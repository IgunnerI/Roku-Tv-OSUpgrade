sub TestSettings()
    data = {
        net: { linkUp: true, connectionType: "WiredConnection", address: "192.168.1.20", networkName: "" }
        diag: { state: "idle", progress: "", verdict: "", steps: [] }
        diagHistory: []
        recentCount: 1
        device: { appVersion: "0.1.1", model: "Test TV", osVersion: "11.5.0 build 1", uiResolution: "FHD" }
    }
    for each section in SettingsSections()
        content = SettingsContent(section.id, data)
        AssertEqual(content.heading <> "" and content.body <> "", true, "content for " + section.id)
        AssertEqual(content.buttons.Count() <= 2, true, "at most two buttons in " + section.id)
    end for

    net = SettingsContent("network", data)
    AssertEqual(Instr(1, net.body, "Connection: Wired") > 0, true, "network shows wired")
    AssertEqual(Instr(1, net.body, "Network name: —") > 0, true, "missing network name shows dash")
    AssertEqual(SettingsContent("network", { net: invalid }).body, "Reading network status…", "network before first status")

    data.diag = { state: "running", progress: "Checking Destination 1 of 2, attempt 1 of 2…", verdict: "", steps: [] }
    running = SettingsContent("diagnostics", data)
    AssertEqual(running.buttons, [{ label: "Checking…", action: "" }], "no re-run while running")

    data.diag = { state: "done", progress: "", verdict: "online", steps: ["Network link: OK"] }
    data.diagHistory = ["Check 1: Internet reachable"]
    done = SettingsContent("diagnostics", data)
    AssertEqual(done.buttons.Count(), 2, "run again and clear after a run")
    AssertEqual(Instr(1, done.body, "Earlier results:") > 0, true, "history listed")

    AssertEqual(Instr(1, SettingsContent("recent", data).body, "1 tile is listed.") > 0, true, "singular count")
    AssertEqual(SettingsContent("privacy", data).buttons[0].action, "clearAll", "privacy offers clear all")
end sub
