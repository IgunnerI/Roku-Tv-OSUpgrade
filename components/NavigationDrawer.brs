sub init()
    m.top.items = [
        { id: "home", label: "Home" }
        { id: "network", label: "Settings" }
        { id: "diagnostics", label: "Network check" }
        { id: "privacy", label: "Privacy" }
        { id: "about", label: "About" }
    ]
    m.bar = m.top.FindNode("bar")
    m.labels = []
    list = m.top.FindNode("list")
    y = 170
    for each item in m.top.items
        label = list.CreateChild("Label")
        label.font = "font:MediumSystemFont"
        label.color = "0x969696FF"
        label.translation = [64, y]
        label.width = 380
        label.height = 48
        label.vertAlign = "center"
        label.text = item.label
        m.labels.Push(label)
        y = y + 76
    end for
    m.current = 0
    onFocusIndex()
end sub

sub onFocusIndex()
    m.labels[m.current].color = "0x969696FF"
    m.current = m.top.focusIndex
    m.labels[m.current].color = "0xF2F0EAFF"
    m.bar.translation = [40, m.labels[m.current].translation[1]]
end sub
