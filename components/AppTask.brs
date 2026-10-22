sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    port = CreateObject("roMessagePort")
    m.top.ObserveField("openStore", port)
    apps = CreateObject("roAppManager")

    ' An empty minimum version means any installed version (assumption; see
    ' docs/ASSESSMENT.md). The result only feeds the tile's status line.
    installed = {}
    for each channelId in m.top.checkIds
        installed[channelId] = apps.IsAppInstalled(channelId, "")
    end for
    m.top.installed = installed

    while true
        msg = wait(0, port)
        if type(msg) = "roSGNodeEvent" and msg.GetField() = "openStore" then
            apps.ShowChannelStoreSpringboard(msg.GetData())
        end if
    end while
end sub
