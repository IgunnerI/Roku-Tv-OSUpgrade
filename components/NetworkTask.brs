sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    port = CreateObject("roMessagePort")
    device = CreateObject("roDeviceInfo")
    device.SetMessagePort(port)
    device.EnableLinkStatusEvent(true)
    m.top.ObserveField("request", port)
    m.lastStatus = ""
    publishStatus(device)

    ' wait(0) sleeps until a link event or a diagnostics request arrives.
    while true
        msg = wait(0, port)
        msgType = type(msg)
        if msgType = "roDeviceInfoEvent" then
            publishStatus(device)
        else if msgType = "roSGNodeEvent" and msg.GetField() = "request" then
            runDiagnostics(device, msg.GetData())
            publishStatus(device)
        end if
    end while
end sub

' Reads status from roDeviceInfo rather than parsing the event payload, so it
' works whatever the event carries. Only publishes when something changed.
sub publishStatus(device as object)
    status = {
        linkUp: device.GetLinkStatus()
        connectionType: device.GetConnectionType()
        address: firstAddress(device)
        networkName: ""
    }
    info = device.GetConnectionInfo()
    if type(info) = "roAssociativeArray" and info.ssid <> invalid then status.networkName = info.ssid.ToStr()
    key = FormatJson(status)
    if key <> m.lastStatus then
        m.lastStatus = key
        m.top.status = status
    end if
end sub

function firstAddress(device as object) as string
    addrs = device.GetIPAddrs()
    if type(addrs) = "roAssociativeArray" then
        for each name in addrs
            return addrs[name].ToStr()
        end for
    end if
    return ""
end function

sub runDiagnostics(device as object, runId as integer)
    config = DiagConfig()
    facts = {
        linkUp: device.GetLinkStatus()
        connectionType: device.GetConnectionType()
        hasAddress: firstAddress(device) <> ""
        probes: []
    }
    steps = []
    if facts.linkUp then steps.Push("Network link: OK") else steps.Push("Network link: down")
    if facts.hasAddress then steps.Push("Local address: assigned") else steps.Push("Local address: none")

    if facts.linkUp and facts.hasAddress then
        destinations = DiagDestinations()
        for i = 0 to destinations.Count() - 1
            dest = destinations[i]
            kind = "other"
            for attempt = 1 to config.maxAttempts
                m.top.progress = { runId: runId, text: "Checking " + dest.name + " of " + destinations.Count().ToStr() + ", attempt " + attempt.ToStr() + " of " + config.maxAttempts.ToStr() + "…" }
                kind = probeOnce(dest, config.timeoutMs)
                if not DiagShouldRetry(kind) or attempt = config.maxAttempts then exit for
                sleep(config.backoffMs * attempt)
            end for
            facts.probes.Push({ kind: kind })
            steps.Push(dest.name + ": " + DiagKindText(kind))
            if kind = "ok" then exit for
        end for
    end if

    m.top.result = { runId: runId, verdict: DiagClassify(facts), steps: steps }
end sub

' One bounded HEAD request. Sends no identifiers or body of our own.
function probeOnce(dest as object, timeoutMs as integer) as string
    port = CreateObject("roMessagePort")
    xfer = CreateObject("roUrlTransfer")
    xfer.SetMessagePort(port)
    xfer.SetUrl(dest.url)
    xfer.EnableFreshConnection(true)
    if not xfer.AsyncHead() then return "other"
    msg = wait(timeoutMs, port)
    if msg = invalid then
        xfer.AsyncCancel()
        return "timeout"
    end if
    if type(msg) <> "roUrlEvent" then return "other"
    return DiagProbeKind(msg.GetResponseCode(), dest.expect)
end function
