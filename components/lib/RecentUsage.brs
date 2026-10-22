' Recent tiles: an ordering of tiles selected inside this launcher only.
' Roku does not expose usage of other channels, and this does not try to.
' Stored on-device in the registry; never transmitted.

' Moves id to the front, dropping duplicates and anything beyond maxItems.
function RecentPush(list as object, id as string, maxItems as integer) as object
    result = [id]
    for each item in list
        if item <> id and result.Count() < maxItems then result.Push(item)
    end for
    return result
end function

' Keeps only string ids that exist in knownIds (an associative array), in order.
function RecentFilter(list as object, knownIds as object, maxItems as integer) as object
    result = []
    for each item in list
        t = type(item)
        if (t = "roString" or t = "String") and knownIds.DoesExist(item) and result.Count() < maxItems then
            result.Push(item)
        end if
    end for
    return result
end function

function RecentLoad() as object
    section = CreateObject("roRegistrySection", "launcher")
    if not section.Exists("recent") then return []
    data = ParseJson(section.Read("recent"))
    if type(data) <> "roArray" then return []
    return data
end function

sub RecentSave(list as object)
    section = CreateObject("roRegistrySection", "launcher")
    section.Write("recent", FormatJson(list))
    section.Flush()
end sub

sub RecentClear()
    section = CreateObject("roRegistrySection", "launcher")
    section.Delete("recent")
    section.Flush()
end sub
