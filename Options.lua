-------------------------------------------------------------------------------
-- TidyMap - Options window (LibFlatyUI-1.0)
--
--   Look     : styles (one click), shape, border, glow
--   Map      : zoom, the minimap icon, language
--   Profiles : profile in use, new, copy, reset, delete
-- Every change shows at once on the real minimap. Options that do not
-- apply are greyed out, never hidden.
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local UI = LibStub("LibFlatyUI-1.0"):New({ accent = ns.ACCENT })
UI.OnChange = function() UI.RefreshAll() end
local STRINGS = { confirm = "Click again to confirm", search = "Search...", accept = "Accept",
    cancel = "Cancel", reset = "Reset", none = "None" }
UI.strings = setmetatable({}, { __index = function(_, key) return L[STRINGS[key]] end })

local win

-- getter / setter of a setting in the profile; every change is applied
local function Bind(tbl, key)
    return function() return ns.P[tbl][key] end,
        function(v)
            ns.P[tbl][key] = v
            ns.ApplyAll()
        end
end
local function Apply() ns.ApplyAll() end

-------------------------------------------------------------------------------
-- Look
-------------------------------------------------------------------------------
local function ShapeTiles()
    local out = {}
    for _, o in ipairs(UI.ShapeList()) do
        out[#out + 1] = { o[1], L[(o[2]:gsub("^Flaty: ", ""))], UI.GetShape(o[1]).mask }
    end
    return out
end

local function BuildLook(container)
    local page = UI.Page(container, 2)

    -- styles replace shape, border and glow: they ask first
    local card = page:Add(1, UI.Card(page.content, L["Style"], L["Sets shape, border and glow."]))
    local list = {}
    for _, s in ipairs(ns.STYLES) do
        list[#list + 1] = { L[s.name], function() ns.ApplyStyle(s.key) UI.RefreshAll() end, confirm = L["Sure?"] }
    end
    card:Add(UI.Buttons(card, { list[1], list[2] }))
    card:Add(UI.Buttons(card, { list[3], list[4] }))

    card = page:Add(1, UI.Card(page.content, L["Shape"]))
    card:Add(UI.Tiles(card, nil, ShapeTiles, function() return ns.P.shape end, function(v)
        ns.P.shape = v
        ns.ApplyAll()
    end))

    card = page:Add(2, UI.Card(page.content, L["Border"]))
    local hasBorder = function() return ns.P.border.size > 0 end
    local g, s = Bind("border", "size")
    card:Add(UI.Slider(card, L["Size"], 0, 8, 1, g, s, { format = UI.px }))
    g, s = Bind("border", "class")
    card:Add(UI.Check(card, L["Class color"], g, s, { enableIf = hasBorder }))
    card:Add(UI.Swatch(card, L["Color"], function() return ns.P.border.color end, Apply,
        { alpha = true, enableIf = function() return hasBorder() and not ns.P.border.class end }))

    card = page:Add(2, UI.Card(page.content, L["Glow"]))
    g, s = Bind("glow", "on")
    card:Add(UI.Switch(card, L["Glow"], g, s))
    card:Add(UI.Swatch(card, L["Color"], function() return ns.P.glow.color end, Apply,
        { alpha = true, enableIf = function() return ns.P.glow.on end }))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Map
-------------------------------------------------------------------------------
local function Rebuild()
    -- the window is built again in the new language, same page and place
    local current = win.current
    local point, _, relPoint, x, y = win:GetPoint(1)
    win:Hide()
    win = nil
    wipe(UI.widgets)
    wipe(UI.pages)
    ns.ToggleOptions()
    win:ClearAllPoints()
    win:SetPoint(point, UIParent, relPoint, x, y)
    win:Select(current)
end

local function BuildMap(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["Zoom"], L["The mouse wheel zooms the map."]))
    local g, s = Bind("zoom", "auto")
    card:Add(UI.Check(card, L["Zoom out by itself"], g, s))
    g, s = Bind("zoom", "delay")
    card:Add(UI.Slider(card, L["After"], 3, 60, 1, g, s, { sub = true,
        format = function(v) return ("%d s"):format(v) end, enableIf = function() return ns.P.zoom.auto end }))

    card = page:Add(2, UI.Card(page.content, "TidyMap"))
    card:Add(UI.Check(card, L["Minimap icon"], function() return not ns.db.icon.hide end, function(v)
        ns.db.icon.hide = not v
        ns.ApplyAll()
    end))
    card:Add(UI.Segmented(card, L["Language"], { { "enUS", "English" }, { "esES", "Español" } },
        function() return ns.db.language or "enUS" end, function(v)
            ns.SetLanguagePref(v)
            Rebuild()
        end))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------
local function ProfileList(othersOnly)
    local out = {}
    for _, name in ipairs(ns.ProfileNames()) do
        if not othersOnly or name ~= ns.profileName then out[#out + 1] = { name, name } end
    end
    return out
end

local function BuildProfiles(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["This character"],
        L["Several characters can share a profile."]))
    card:Add(UI.Dropdown(card, L["Profile in use"], function() return ProfileList(false) end,
        function() return ns.profileName end, function(v) ns.UseProfile(v) UI.RefreshAll() end))
    local newName = ""
    card:Add(UI.Input(card, L["New profile"], function() return newName end, function(v)
        v = strtrim(v or "")
        if v == "" then return end
        ns.UseProfile(v)
        newName = ""
        UI.RefreshAll()
    end))

    card = page:Add(2, UI.Card(page.content, L["Manage"]))
    local hasOthers = function() return #ProfileList(true) > 0 end
    card:Add(UI.Buttons(card, {
        { L["Copy from"] .. "...", function(self)
            UI.Menu(self, ProfileList(true), function(name)
                UI.Dialog(L["This replaces every setting of the profile in use. Continue?"], L["Copy"], function()
                    ns.CopyProfile(name)
                    UI.RefreshAll()
                end)
            end)
        end },
    }, { enableIf = hasOthers }))
    card:Add(UI.Buttons(card, {
        { L["Reset this profile"], function() ns.ResetProfile() UI.RefreshAll() end, "danger", confirm = true },
    }))
    card:Add(UI.Buttons(card, {
        { L["Delete profile"] .. "...", function(self)
            UI.Menu(self, ProfileList(true), function(name)
                UI.Dialog(L["Delete the profile \"%s\"?"]:format(name), L["Delete"], function()
                    ns.DeleteProfile(name)
                    UI.RefreshAll()
                end)
            end)
        end, "danger" },
    }, { enableIf = hasOthers }))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local function Build()
    win = UI.Window({ name = "TidyMapOptions", title = "TidyMap", version = ns.version,
        logo = "Interface\\AddOns\\TidyMap\\Media\\Icon", width = 640, height = 470, navWidth = 110 })
    win:AddNav("look", L["Look"], BuildLook)
    win:AddNav("map", L["Map"], BuildMap)
    win:AddNav("profiles", L["Profiles"], BuildProfiles)
    UI.OnRefresh = function()
        win:SetSubtitle(L["Profile: %s"]:format(ns.profileName or ""))
    end
    win:Select("look")
end

function ns.ToggleOptions()
    if not win then
        Build()
        win:Show()
        return
    end
    win:Toggle()
end
