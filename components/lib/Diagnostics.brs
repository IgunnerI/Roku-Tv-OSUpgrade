' Network diagnostics: configuration and pure classification.
' The I/O lives in components/NetworkTask.brs; everything here is testable
' off-device (tests/test_diagnostics.brs).

' Test destinations, tried in order until one succeeds. Plain HTTP on purpose:
' a sign-in page (captive portal) can only be detected without TLS.
' Requests are HEAD only and run only when the user selects "Run check".
' Any change here must also update docs/PRIVACY.md and scripts/privacy-audit.mjs.
function DiagDestinations() as object
    return [
        { name: "Destination 1", url: "http://connectivitycheck.gstatic.com/generate_204", expect: 204 }
        { name: "Destination 2", url: "http://www.msftconnecttest.com/connecttest.txt", expect: 200 }
    ]
end function

function DiagConfig() as object
    return {
        timeoutMs: 4000    ' per attempt, enforced with wait() + AsyncCancel()
        maxAttempts: 2     ' per destination
        backoffMs: 1000    ' multiplied by the attempt number before a retry
    }
end function

' Maps an roUrlEvent response code to a probe kind.
' Negative codes are libcurl error numbers, negated (Roku convention; not
' confirmed against current documentation, see docs/ASSESSMENT.md).
function DiagProbeKind(code as integer, expect as integer) as string
    if code = expect then return "ok"
    if code = -6 then return "dns"            ' CURLE_COULDNT_RESOLVE_HOST
    if code = -28 then return "timeout"       ' CURLE_OPERATION_TIMEDOUT
    if code = -7 or code = -5 then return "connect" ' couldn't connect / resolve proxy
    if code > 0 then return "intercepted"     ' something answered, but not as expected
    return "other"
end function

' Retry only failures that could be transient.
function DiagShouldRetry(kind as string) as boolean
    return kind = "dns" or kind = "timeout" or kind = "connect" or kind = "other"
end function

' facts: { linkUp, connectionType, hasAddress, probes: [ { kind } ] }
' probes hold the final result per destination tried.
function DiagClassify(facts as object) as string
    if not facts.linkUp or facts.connectionType = "" then return "disconnected"
    if not facts.hasAddress then return "no_address"
    n = facts.probes.Count()
    if n = 0 then return "unknown"
    counts = { dns: 0, timeout: 0, connect: 0, intercepted: 0, other: 0 }
    for each probe in facts.probes
        if probe.kind = "ok" then return "online"
        counts[probe.kind] = counts[probe.kind] + 1
    end for
    if counts.dns = n then return "dns_suspected"
    if counts.timeout = n then return "timeout"
    if counts.intercepted > 0 then return "intercepted"
    if counts.connect > 0 then return "unreachable"
    return "unknown"
end function

' User-facing wording. Never claims the internet is definitely down.
function DiagVerdictText(verdict as string) as object
    texts = {
        online: { title: "Internet reachable", advice: "At least one test destination answered normally." }
        disconnected: { title: "Not connected to a network", advice: "The TV reports no active network link. Open Roku Settings > Network to connect, and check the cable or that Wi-Fi is in range." }
        no_address: { title: "Connected, but no address assigned", advice: "The TV has a link but no IP address. Restart your router, then use Roku Settings > Network > Check connection." }
        dns_suspected: { title: "Possible DNS problem", advice: "The test destination names could not be looked up. Restart your router. If you use custom DNS on your router, check it." }
        timeout: { title: "Test destinations timed out", advice: "No answer within the time limit. The connection may be slow or congested. Try again in a moment." }
        intercepted: { title: "Unexpected response", advice: "Your network answered, but not as expected. A sign-in page (hotel or guest Wi-Fi) or a network filter may be in the way." }
        unreachable: { title: "Local network OK, test destinations unreachable", advice: "This does not prove the internet is down. Your router or provider may be having trouble. Restart the router and try again." }
        unknown: { title: "Result unclear", advice: "The check could not determine the problem. Try again, or use Roku Settings > Network > Check connection." }
    }
    if texts.DoesExist(verdict) then return texts[verdict]
    return texts.unknown
end function

function DiagKindText(kind as string) as string
    texts = { ok: "OK", dns: "Name lookup failed", timeout: "Timed out", connect: "Could not connect", intercepted: "Unexpected response", other: "Failed" }
    if texts.DoesExist(kind) then return texts[kind]
    return "Failed"
end function
