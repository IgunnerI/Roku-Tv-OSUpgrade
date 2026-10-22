sub init()
    m.frame = m.top.FindNode("frame")
    m.body = m.top.FindNode("body")
    m.name = m.top.FindNode("name")
    m.sub = m.top.FindNode("sub")
    m.w = 380
    m.h = 200
    layout()
end sub

sub onLabel()
    m.name.text = m.top.label
end sub

sub onStatus()
    m.sub.text = m.top.status
end sub

sub onSize()
    m.w = m.top.size[0]
    m.h = m.top.size[1]
    layout()
end sub

sub layout()
    m.body.width = m.w
    m.body.height = m.h
    pad = 28
    m.name.width = m.w - pad * 2
    m.sub.width = m.w - pad * 2
    m.name.height = 44
    m.sub.height = 36
    if m.h >= 160 then
        m.name.translation = [pad, m.h - 104]
        m.sub.translation = [pad, m.h - 56]
    else
        m.name.translation = [pad, 14]
        m.sub.translation = [pad, 60]
    end if
    onFocused()
end sub

' Focused: 5px amber ring. Unfocused: 2px subtle border.
sub onFocused()
    if m.top.focused then
        ring = 5
        m.frame.color = "0xF2B84BFF"
    else
        ring = 2
        m.frame.color = "0x333333FF"
    end if
    m.frame.translation = [-ring, -ring]
    m.frame.width = m.w + ring * 2
    m.frame.height = m.h + ring * 2
end sub
