sub init()
    m.sections = SettingsSections()
    m.menuBar = m.top.FindNode("menuBar")
    m.heading = m.top.FindNode("heading")
    m.body = m.top.FindNode("body")

    m.menuLabels = []
    menu = m.top.FindNode("menu")
    y = 170
    for each section in m.sections
        label = menu.CreateChild("Label")
        label.font = "font:MediumSystemFont"
        label.translation = [176, y]
        label.width = 420
        label.height = 48
        label.vertAlign = "center"
        label.text = section.label
        m.menuLabels.Push(label)
        y = y + 72
    end for

    ' Two reusable buttons; hidden when a section has fewer.
    m.buttonNodes = []
    buttons = m.top.FindNode("buttons")
    for i = 0 to 1
        group = buttons.CreateChild("Group")
        group.translation = [i * 400, 0]
        frame = group.CreateChild("Rectangle")
        body = group.CreateChild("Rectangle")
        body.width = 360
        body.height = 72
        body.color = "0x171717FF"
        label = group.CreateChild("Label")
        label.font = "font:SmallSystemFont"
        label.color = "0xF2F0EAFF"
        label.width = 360
        label.height = 72
        label.horizAlign = "center"
        label.vertAlign = "center"
        m.buttonNodes.Push({ group: group, frame: frame, label: label })
    end for

    m.sectionIndex = 0
    m.area = "menu"      ' "menu" | "buttons"
    m.buttonIndex = 0
    m.content = { heading: "", body: "", buttons: [] }
end sub

' Opens at a section id, with focus in the section list.
function open(sectionId as string) as boolean
    for i = 0 to m.sections.Count() - 1
        if m.sections[i].id = sectionId then m.sectionIndex = i
    end for
    m.area = "menu"
    m.buttonIndex = 0
    render()
    return true
end function

' Returns "handled", or "close" when Back is pressed in the section list.
function handleKey(key as string) as string
    if m.area = "menu" then
        if key = "up" and m.sectionIndex > 0 then
            m.sectionIndex = m.sectionIndex - 1
            render()
        else if key = "down" and m.sectionIndex < m.sections.Count() - 1 then
            m.sectionIndex = m.sectionIndex + 1
            render()
        else if (key = "right" or key = "OK") and m.content.buttons.Count() > 0 then
            m.area = "buttons"
            m.buttonIndex = 0
            renderFocus()
        else if key = "back" then
            return "close"
        end if
    else
        if key = "left" then
            if m.buttonIndex = 0 then m.area = "menu" else m.buttonIndex = m.buttonIndex - 1
            renderFocus()
        else if key = "right" and m.buttonIndex < m.content.buttons.Count() - 1 then
            m.buttonIndex = m.buttonIndex + 1
            renderFocus()
        else if key = "back" then
            m.area = "menu"
            renderFocus()
        else if key = "OK" then
            activate(m.content.buttons[m.buttonIndex].action)
        end if
    end if
    return "handled"
end function

sub activate(action as string)
    if action = "" then return
    if action = "showDiagnostics" then
        open("diagnostics")
        return
    end if
    m.top.action = action
end sub

' Rebuilds the visible section. Called on section change and data change.
sub render()
    data = m.top.data
    if data = invalid or data.diag = invalid then return
    m.content = SettingsContent(m.sections[m.sectionIndex].id, data)
    m.heading.text = m.content.heading
    m.body.text = m.content.body
    count = m.content.buttons.Count()
    for i = 0 to m.buttonNodes.Count() - 1
        node = m.buttonNodes[i]
        node.group.visible = i < count
        if i < count then node.label.text = m.content.buttons[i].label
    end for
    ' Keep focus valid if the number of buttons changed (e.g. "Run again").
    if m.area = "buttons" then
        if count = 0 then
            m.area = "menu"
        else if m.buttonIndex >= count then
            m.buttonIndex = count - 1
        end if
    end if
    renderFocus()
end sub

sub renderFocus()
    for i = 0 to m.menuLabels.Count() - 1
        if i = m.sectionIndex then m.menuLabels[i].color = "0xF2F0EAFF" else m.menuLabels[i].color = "0x969696FF"
    end for
    ' Amber bar marks the section while the list has focus; grey while in buttons.
    m.menuBar.translation = [146, m.menuLabels[m.sectionIndex].translation[1]]
    if m.area = "menu" then m.menuBar.color = "0xF2B84BFF" else m.menuBar.color = "0x333333FF"

    for i = 0 to m.buttonNodes.Count() - 1
        frame = m.buttonNodes[i].frame
        if m.area = "buttons" and i = m.buttonIndex then
            ring = 5
            frame.color = "0xF2B84BFF"
        else
            ring = 2
            frame.color = "0x333333FF"
        end if
        frame.translation = [-ring, -ring]
        frame.width = 360 + ring * 2
        frame.height = 72 + ring * 2
    end for
end sub
