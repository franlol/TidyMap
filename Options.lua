-------------------------------------------------------------------------------
-- TidyMap - Options window (LibFlatyUI-1.0)
--
--   Look     : on / off, styles (one click), corners, border, glow
--   Icons    : Blizzard's icons around the map: clean mode, shown / on
--              hover / hidden, place on the edge (also by dragging them
--              on the map while this window is open)
--   Texts    : font and outline, sizes of zone, clock and coordinates
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
local function On() return ns.P.enabled end
local function Both(a, b) return function() return a() and b() end end
local function Pct(v) return ("%d%%"):format(v) end

local function BuildLook(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, "TidyMap", L["Off: the minimap looks like Blizzard's."]))
    card:Add(UI.Switch(card, L["Enabled"], function() return ns.P.enabled end, function(v)
        ns.P.enabled = v
        ns.ApplyAll()
    end))

    -- a style sets corners, border and glow at once
    card = page:Add(1, UI.Card(page.content, L["Style"]))
    local list = {}
    for _, s in ipairs(ns.STYLES) do
        list[#list + 1] = { L[s.name], function() ns.ApplyStyle(s.key) UI.RefreshAll() end }
    end
    card:Add(UI.Buttons(card, { list[1], list[2] }, { enableIf = On }))
    card:Add(UI.Buttons(card, { list[3], list[4] }, { enableIf = On }))

    card = page:Add(1, UI.Card(page.content, L["Shape"]))
    card:Add(UI.Slider(card, L["Corners"], 0, 100, 1, function() return ns.P.corners end, function(v)
        ns.P.corners = v
        ns.ApplyAll()
    end, { format = Pct, enableIf = On }))

    card = page:Add(2, UI.Card(page.content, L["Border"]))
    local hasBorder = Both(On, function() return ns.P.border.size > 0 end)
    local g, s = Bind("border", "size")
    card:Add(UI.Slider(card, L["Size"], 0, 8, 1, g, s, { format = UI.px, enableIf = On }))
    g, s = Bind("border", "class")
    card:Add(UI.Check(card, L["Class color"], g, s, { enableIf = hasBorder }))
    card:Add(UI.Swatch(card, L["Color"], function() return ns.P.border.color end, Apply,
        { alpha = true, enableIf = Both(hasBorder, function() return not ns.P.border.class end) }))

    card = page:Add(2, UI.Card(page.content, L["Glow"]))
    g, s = Bind("glow", "on")
    card:Add(UI.Switch(card, L["Glow"], g, s, { enableIf = On }))
    card:Add(UI.Swatch(card, L["Color"], function() return ns.P.glow.color end, Apply,
        { alpha = true, enableIf = Both(On, function() return ns.P.glow.on end) }))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Icons: Blizzard's icons around the map. A list on the left, the picked
-- one on the right. With the window open they can also be dragged on the
-- map, or clicked to pick them here.
-------------------------------------------------------------------------------
ns.selected = ns.selected or "zone"

local MODES = function()
    return { { "show", L["Show"] }, { "hover", L["On hover"] }, { "hide", L["Hide"] } }
end
local MODE_TAG = {
    show = function() return L["Shown"], UI.theme.success end,
    hover = function() return L["On hover"], ns.ACCENT end,
    hide = function() return L["Hidden"], UI.theme.muted end,
}

local function Sel() return ns.P.elements[ns.selected] end
local function ElementName(key)
    for _, e in ipairs(ns.ELEMENTS) do
        if e.key == key then return L[e.name] end
    end
    return key
end
local function ApplySel() ns.ApplyElement(ns.selected) end

local function BuildIcons(container)
    local left, right = UI.Split(container, 210)

    local card = left:Add(1, UI.Card(left.content, L["Clean mode"],
        L["Shown icons only appear with the mouse over the map."]))
    card:Add(UI.Switch(card, L["Clean mode"], function() return ns.P.clean end, function(v)
        ns.P.clean = v
        ns.ApplyAll()
    end, { enableIf = On }))

    card = left:Add(1, UI.Card(left.content, L["Icons"]))
    card:Add(UI.List(card, {
        items = function() return ns.ELEMENTS end,
        label = function(e) return L[e.name] end,
        tag = function(e) return MODE_TAG[ns.ElementMode(e.key)]() end,
        selected = function(e) return e.key == ns.selected end,
        onSelect = function(_, e) ns.selected = e.key UI.RefreshAll() end,
        rows = #ns.ELEMENTS,
        enableIf = On,
    }))

    card = right:Add(1, UI.Card(right.content, ElementName(ns.selected)))
    local title = card
    card:Add(UI.Segmented(card, L["Show"], MODES(), function() return Sel().mode end, function(v)
        Sel().mode = v
        ApplySel()
    end, { enableIf = On }))
    local placed = Both(On, function() return Sel().mode ~= "hide" end)
    card:Add(UI.Slider(card, L["Angle"], 0, 359, 1, function() return Sel().angle end, function(v)
        Sel().angle = v
        ApplySel()
    end, { format = function(v) return ("%d°"):format(v) end, enableIf = placed }))
    card:Add(UI.Slider(card, L["Distance"], -20, 40, 1, function() return Sel().dist end, function(v)
        Sel().dist = v
        ApplySel()
    end, { format = UI.px, enableIf = placed }))
    card:Add(UI.Buttons(card, {
        { L["Reset position"], function()
            local d = ns.defaults.elements[ns.selected]
            Sel().angle, Sel().dist = d.angle, d.dist
            ApplySel()
            UI.RefreshAll()
        end },
    }, { enableIf = placed }))

    card = right:Add(1, UI.Card(right.content, L["All icons"]))
    card:Add(UI.Buttons(card, {
        { L["Reset all icons"], function()
            for key, d in pairs(ns.defaults.elements) do
                local t = ns.P.elements[key]
                t.mode, t.angle, t.dist = d.mode, d.angle, d.dist
            end
            ns.ApplyAll()
            UI.RefreshAll()
        end, "danger", confirm = true },
    }, { enableIf = On }))

    -- the card's title follows the picked icon
    local paint = UI.OnRefresh
    UI.OnRefresh = function()
        if paint then paint() end
        title.title:SetText(ElementName(ns.selected))
    end

    left:Layout()
    right:Layout()
end

-------------------------------------------------------------------------------
-- Texts: one font for all, a size each
-------------------------------------------------------------------------------
local OUTLINES = function()
    return { { "", L["None"] }, { "OUTLINE", L["Thin"] }, { "THICKOUTLINE", L["Thick"] } }
end

local function SizeSlider(card, key, opts)
    local g, s = Bind("texts", key)
    opts = opts or {}
    opts.format = UI.px
    opts.enableIf = opts.enableIf or On
    return UI.Slider(card, L["Size"], 8, 24, 1, g, s, opts)
end

local function BuildTexts(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["Font"], L["For every text of the map."]))
    card:Add(UI.Dropdown(card, L["Font"], function() return UI.MediaList("font") end,
        function() return UI.ResolveMedia(ns.P.texts.font) or ns.P.texts.font end,
        function(v) ns.P.texts.font = v ns.ApplyAll() end, { enableIf = On }))
    local g, s = Bind("texts", "outline")
    card:Add(UI.Segmented(card, L["Outline"], OUTLINES(), g, s, { enableIf = On }))

    card = page:Add(2, UI.Card(page.content, L["Zone"]))
    card:Add(SizeSlider(card, "zone"))
    g, s = Bind("texts", "zoneBar")
    card:Add(UI.Check(card, L["Bar behind the name"], g, s, { enableIf = On }))

    card = page:Add(2, UI.Card(page.content, L["Clock"]))
    card:Add(SizeSlider(card, "clock"))

    card = page:Add(2, UI.Card(page.content, L["Coordinates"]))
    card:Add(UI.Check(card, L["Show"], function() return C_CVar.GetCVarBool("minimapShowPlayerCoords") end,
        function(v) C_CVar.SetCVar("minimapShowPlayerCoords", v and "1" or "0") end))
    card:Add(SizeSlider(card, "coords", { enableIf = Both(On, function() return C_CVar.GetCVarBool("minimapShowPlayerCoords") end) }))

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

    local card = page:Add(1, UI.Card(page.content, L["Zoom"],
        L["After you zoom in with the mouse wheel, the map zooms back out by itself."]))
    local g, s = Bind("zoom", "auto")
    card:Add(UI.Check(card, L["Zoom back out"], g, s, { enableIf = On }))
    g, s = Bind("zoom", "delay")
    card:Add(UI.Slider(card, L["After"], 3, 60, 1, g, s, { sub = true,
        format = function(v) return ("%d s"):format(v) end,
        enableIf = Both(On, function() return ns.P.zoom.auto end) }))
    g, s = Bind("zoom", "buttons")
    card:Add(UI.Check(card, L["Zoom buttons on hover"], g, s, { enableIf = On }))

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
    win:AddNav("icons", L["Icons"], BuildIcons)
    win:AddNav("texts", L["Texts"], BuildTexts)
    win:AddNav("map", L["Map"], BuildMap)
    win:AddNav("profiles", L["Profiles"], BuildProfiles)
    UI.OnRefresh = function()
        win:SetSubtitle(L["Profile: %s"]:format(ns.profileName or ""))
        local other = ns.ConflictingAddon()
        win:SetStatus(other and ("|cffff7359" .. L["%s is also loaded: both change the minimap. Disable one of them and reload."]:format(other) .. "|r") or "")
    end
    -- while the window is open, the icons can be dragged on the map
    win:HookScript("OnShow", function() ns.SetEditing(true) end)
    win:HookScript("OnHide", function() ns.SetEditing(false) end)
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

-- An icon clicked or dragged on the map: its settings
function ns.SelectElement(key)
    ns.selected = key
    if not win then Build() end
    if not win:IsShown() then win:Show() end
    win:Select("icons")
    UI.RefreshAll()
end
