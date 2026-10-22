sub TestDiagnostics()
    AssertEqual(DiagProbeKind(204, 204), "ok", "expected code ok")
    AssertEqual(DiagProbeKind(200, 204), "intercepted", "200 where 204 expected")
    AssertEqual(DiagProbeKind(-6, 204), "dns", "curl resolve error")
    AssertEqual(DiagProbeKind(-28, 204), "timeout", "curl timeout")
    AssertEqual(DiagProbeKind(-7, 204), "connect", "curl connect error")
    AssertEqual(DiagProbeKind(-35, 204), "other", "other curl error")

    AssertEqual(DiagShouldRetry("ok"), false, "no retry on ok")
    AssertEqual(DiagShouldRetry("intercepted"), false, "no retry when server answered")
    AssertEqual(DiagShouldRetry("timeout"), true, "retry on timeout")

    up = { linkUp: true, connectionType: "WiFiConnection", hasAddress: true }
    AssertEqual(DiagClassify({ linkUp: false, connectionType: "", hasAddress: false, probes: [] }), "disconnected", "no link")
    AssertEqual(DiagClassify({ linkUp: true, connectionType: "WiFiConnection", hasAddress: false, probes: [] }), "no_address", "no address")
    AssertEqual(DiagClassify(withProbes(up, ["dns", "ok"])), "online", "one success is enough")
    AssertEqual(DiagClassify(withProbes(up, ["dns", "dns"])), "dns_suspected", "all dns")
    AssertEqual(DiagClassify(withProbes(up, ["timeout", "timeout"])), "timeout", "all timeouts")
    AssertEqual(DiagClassify(withProbes(up, ["intercepted", "timeout"])), "intercepted", "portal")
    AssertEqual(DiagClassify(withProbes(up, ["connect", "timeout"])), "unreachable", "mixed connect failures")
    AssertEqual(DiagClassify(withProbes(up, ["dns", "timeout"])), "unknown", "mixed dns and timeout")
    AssertEqual(DiagClassify(withProbes(up, [])), "unknown", "no probes")

    ' Every verdict has wording, and none claims the internet is definitely down.
    for each verdict in ["online", "disconnected", "no_address", "dns_suspected", "timeout", "intercepted", "unreachable", "unknown", "bogus"]
        text = DiagVerdictText(verdict)
        AssertEqual(text.title <> "" and text.advice <> "", true, "wording for " + verdict)
        AssertEqual(Instr(1, LCase(text.title + text.advice), "internet is down") = 0 or Instr(1, LCase(text.advice), "does not prove") > 0, true, "no definitive outage claim: " + verdict)
    end for

    ' Bounded worst case: attempts x (timeout + backoff) per destination.
    config = DiagConfig()
    worst = 0
    for each dest in DiagDestinations()
        for attempt = 1 to config.maxAttempts
            worst = worst + config.timeoutMs
            if attempt < config.maxAttempts then worst = worst + config.backoffMs * attempt
        end for
    end for
    AssertEqual(worst <= 20000, true, "worst-case diagnostics under 20 s (" + worst.ToStr() + " ms)")
end sub

function withProbes(base as object, kinds as object) as object
    probes = []
    for each kind in kinds
        probes.Push({ kind: kind })
    end for
    return { linkUp: base.linkUp, connectionType: base.connectionType, hasAddress: base.hasAddress, probes: probes }
end function
