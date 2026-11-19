-------------------------------------------------------------------------------
-- TidyMap - Options window (LibFlatyUI-1.0)
--
--   Look     : on / off, styles (one click), corners, border, glow
--   Header   : TidyMap's own zone name and clock: shown / on hover /
--              hidden, place, background, colors
--   Icons    : Blizzard's icons around the map: clean mode, shown / on
--              hover / hidden, place on the edge (also by dragging them
--              on the map while this window is open)
--   Texts    : font and outline, sizes of zone, clock and coordinates
--   Addons   : other addons' minimap buttons: flat look, into the addon menu
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

-- The plate of the flat look (icons and header pieces alike): padding
-- (negative: inside the picture's empty margins), corners (the map's or its
-- own), border size, border color (the map's or its own), background color.
-- cornersIf: corners apply (a pill has round ends of its own)
local function PlateRows(card, cfg, enableIf, cornersIf)
    local function Get(k) return function() return cfg()[k] end end
    local function Set(k) return function(v) cfg()[k] = v ns.ApplyAll() end end
    card:Add(UI.Slider(card, L["Padding"], -10, 10, 1, Get("pad"), Set("pad"), { format = UI.px, enableIf = enableIf }))
    local shaped = cornersIf and Both(enableIf, cornersIf) or enableIf
    card:Add(UI.Check(card, L["Map's corners"], Get("mapCorners"), Set("mapCorners"), { enableIf = shaped }))
    card:Add(UI.Slider(card, L["Corners"], 0, 100, 1, Get("corners"), Set("corners"),
        { sub = true, format = Pct, enableIf = Both(shaped, function() return not cfg().mapCorners end) }))
    card:Add(UI.Slider(card, L["Border"], 0, 4, 1, Get("edge"), Set("edge"), { format = UI.px, enableIf = enableIf }))
    local hasEdge = Both(enableIf, function() return cfg().edge > 0 end)
    card:Add(UI.Check(card, L["Map's border color"], Get("mapColor"), Set("mapColor"), { sub = true, enableIf = hasEdge }))
    card:Add(UI.Swatch(card, L["Border color"], function() return cfg().edgeColor end, Apply,
        { alpha = true, sub = true, enableIf = Both(hasEdge, function() return not cfg().mapColor end) }))
    card:Add(UI.Swatch(card, L["Background color"], function() return cfg().bgColor end, Apply,
        { alpha = true, enableIf = enableIf }))
end
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
        tag = function(e)
            if ns.InHeader(e.key) then return L["In the header"], UI.theme.muted end
            return MODE_TAG[ns.ElementMode(e.key)]()
        end,
        selected = function(e) return e.key == ns.selected end,
        onSelect = function(_, e) ns.selected = e.key UI.RefreshAll() end,
        rows = #ns.ELEMENTS,
        enableIf = On,
    }))

    card = right:Add(1, UI.Card(right.content, ElementName(ns.selected)))
    local title = card
    -- zone and clock belong to TidyMap's header while it is on
    local free = Both(On, function() return not ns.InHeader(ns.selected) end)
    -- zone, clock and coordinates: set on the Header page while it is on
    -- (the line is always there, empty otherwise: no layout jumps)
    local inHeader = card:Add(UI.Note(card, " "))
    card:Add(UI.Segmented(card, L["Show"], MODES(), function() return Sel().mode end, function(v)
        Sel().mode = v
        ApplySel()
    end, { enableIf = free }))
    local placed = Both(free, function() return Sel().mode ~= "hide" end)
    card:Add(UI.Segmented(card, L["Look"], { { "flat", L["Flat"] }, { "blizzard", "Blizzard" } },
        function() return Sel().look end, function(v)
            Sel().look = v
            ApplySel()
        end, { enableIf = placed }))
    card:Add(UI.Slider(card, L["Size"], 50, 200, 5, function() return Sel().size end, function(v)
        Sel().size = v
        ApplySel()
    end, { format = Pct, enableIf = placed }))
    card:Add(UI.Slider(card, L["Angle"], 0, 359, 1, function() return Sel().angle end, function(v)
        Sel().angle = v
        ApplySel()
    end, { format = function(v) return ("%d°"):format(v) end, enableIf = placed }))
    card:Add(UI.Slider(card, L["Distance"], -20, 40, 1, function() return Sel().dist end, function(v)
        Sel().dist = v
        ApplySel()
    end, { format = UI.px, enableIf = placed }))
    card:Add(UI.Heading(card, L["Flat look"]))
    PlateRows(card, Sel, Both(placed, function() return Sel().look == "flat" end))
    card:Add(UI.Buttons(card, {
        { L["Reset this icon"], function()
            local d = ns.defaults.elements[ns.selected]
            for _, k in ipairs({ "angle", "dist", "look", "size", "pad", "edge", "mapColor", "mapCorners", "corners" }) do
                Sel()[k] = d[k]
            end
            for _, k in ipairs({ "edgeColor", "bgColor" }) do
                local c = d[k]
                Sel()[k] = { r = c.r, g = c.g, b = c.b, a = c.a }
            end
            ApplySel()
            UI.RefreshAll()
        end, "danger", confirm = true },
    }, { enableIf = On }))

    card = right:Add(1, UI.Card(right.content, L["All icons"]))
    card:Add(UI.Buttons(card, {
        { L["Reset all icons"], function()
            for key, d in pairs(ns.defaults.elements) do
                ns.P.elements[key] = ns.Copy(d)
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
        inHeader.text:SetText(ns.InHeader(ns.selected)
            and L["Part of TidyMap's header: set it on the Header page."] or " ")
    end

    left:Layout()
    right:Layout()
end

-------------------------------------------------------------------------------
-- Header: TidyMap's own zone name and clock, the same options for both
-------------------------------------------------------------------------------
local function HeaderOn() return ns.P.enabled and ns.P.header.on end

local function PieceCard(page, col, key, title)
    local function C() return ns.P.header[key] end
    local function Get(k) return function() return C()[k] end end
    local function Set(k) return function(v) C()[k] = v ns.ApplyAll() end end
    local shown = Both(HeaderOn, function() return C().mode ~= "hide" end)

    local card = page:Add(col, UI.Card(page.content, title))
    card:Add(UI.Segmented(card, L["Show"], MODES(), Get("mode"), Set("mode"), { enableIf = HeaderOn }))
    card:Add(UI.Segmented(card, L["Place"], { { "top", L["Top"] }, { "bottom", L["Bottom"] } },
        Get("place"), Set("place"), { enableIf = shown }))
    card:Add(UI.Segmented(card, L["Side"], { { "outside", L["Outside"] }, { "inside", L["Inside"] } },
        Get("side"), Set("side"), { enableIf = shown }))
    card:Add(UI.Slider(card, L["Distance"], -10, 40, 1, Get("offset"), Set("offset"),
        { format = UI.px, enableIf = shown }))
    card:Add(UI.Segmented(card, L["Background"], { { "none", L["None"] }, { "flat", L["Flat"] }, { "pill", L["Pill"] } },
        Get("bg"), Set("bg"), { enableIf = shown }))
    PlateRows(card, C, Both(shown, function() return C().bg ~= "none" end), function() return C().bg == "flat" end)
    if key == "zone" then
        card:Add(UI.Check(card, L["PvP colors"], Get("pvp"), Set("pvp"), { enableIf = shown }))
        card:Add(UI.Swatch(card, L["Text color"], function() return C().color end, Apply,
            { alpha = true, sub = true, enableIf = Both(shown, function() return not C().pvp end) }))
    else
        card:Add(UI.Swatch(card, L["Text color"], function() return C().color end, Apply,
            { alpha = true, enableIf = shown }))
    end
    if key == "coords" then
        card:Add(UI.Segmented(card, L["Decimals"], { { 0, "0" }, { 1, "1" }, { 2, "2" } },
            Get("decimals"), Set("decimals"), { enableIf = shown }))
    end
end

local function BuildHeader(container)
    local page = UI.Page(container, 2)

    local card = page:Add(1, UI.Card(page.content, L["Header"],
        L["TidyMap's own zone name, clock and coordinates. Off: Blizzard's, on the Icons page."]))
    card:Add(UI.Switch(card, L["TidyMap header"], function() return ns.P.header.on end, function(v)
        ns.P.header.on = v
        ns.ApplyAll()
    end, { enableIf = On }))

    PieceCard(page, 1, "zone", L["Zone"])
    PieceCard(page, 2, "clock", L["Clock"])
    PieceCard(page, 2, "coords", L["Coordinates"])

    page:Layout()
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

    card = page:Add(2, UI.Card(page.content, L["Clock"]))
    card:Add(SizeSlider(card, "clock"))

    card = page:Add(2, UI.Card(page.content, L["Coordinates"]))
    -- Blizzard's own coordinates (TidyMap's header has its own)
    card:Add(UI.Check(card, L["Blizzard's coordinates"], function() return C_CVar.GetCVarBool("minimapShowPlayerCoords") end,
        function(v) C_CVar.SetCVar("minimapShowPlayerCoords", v and "1" or "0") end,
        { enableIf = function() return not ns.P.header.on end }))
    card:Add(SizeSlider(card, "coords", { enableIf = Both(On, function()
        return ns.P.header.on or C_CVar.GetCVarBool("minimapShowPlayerCoords")
    end) }))

    page:Layout()
end

-------------------------------------------------------------------------------
-- Addons: other addons' minimap buttons (LibDBIcon)
-------------------------------------------------------------------------------
local function BuildAddons(container)
    local page = UI.Page(container, 2)
    local has = Both(On, ns.HasAddonButtons)

    local card = page:Add(1, UI.Card(page.content, L["Addon buttons"]))
    local g, s = Bind("buttons", "flat")
    card:Add(UI.Check(card, L["Flat look"], g, s, { enableIf = Both(has, ns.CanFlattenButtons),
        tip = L["No round border or background."] }))

    card = page:Add(2, UI.Card(page.content, L["Into the addon menu"],
        L["Checked buttons leave the map and wait in the addon menu."]))
    card:Add(UI.List(card, {
        items = ns.AddonButtons,
        label = function(b) return b.name end,
        lead = "icon",
        icon = function(b) return b.icon or 134400 end,
        checked = function(b) return ns.P.buttons.menu[b.name] and true or false end,
        onCheck = function(b, v)
            ns.P.buttons.menu[b.name] = v or nil
            ns.ApplyAll()
        end,
        rows = 9,
        empty = L["No addon buttons on the map."],
        enableIf = has,
    }))

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
    local g, s = Bind("zoom", "mode")
    card:Add(UI.Segmented(card, L["After zooming in"], {
        { "out", L["Zoom back out"] }, { "remember", L["Remember"] }, { "blizzard", L["Leave it"] },
    }, g, s, { enableIf = On }))
    g, s = Bind("zoom", "delay")
    card:Add(UI.Slider(card, L["After"], 3, 60, 1, g, s, { sub = true,
        format = function(v) return ("%d s"):format(v) end,
        enableIf = Both(On, function() return ns.P.zoom.mode == "out" end) }))
    g, s = Bind("zoom", "buttons")
    card:Add(UI.Check(card, L["Zoom buttons on hover"], g, s, { enableIf = On }))

    -- the whole map by situation
    card = page:Add(1, UI.Card(page.content, L["Visibility"]))
    g, s = Bind("visibility", "when")
    card:Add(UI.Segmented(card, L["Show the map"], {
        { "always", L["Always"] }, { "outCombat", L["Out of combat"] }, { "inCombat", L["In combat"] },
    }, g, s, { enableIf = On }))
    g, s = Bind("visibility", "opacity")
    card:Add(UI.Slider(card, L["Opacity"], 10, 100, 5, g, s, { format = Pct, enableIf = On }))
    local situational = Both(On, function() return ns.P.visibility.when ~= "always" end)
    g, s = Bind("visibility", "faded")
    card:Add(UI.Slider(card, L["Faded opacity"], 0, 90, 5, g, s, { format = Pct, enableIf = situational }))
    g, s = Bind("visibility", "fade")
    card:Add(UI.Slider(card, L["Fade time"], 0, 2, 0.1, g, s,
        { format = function(v) return ("%.1f s"):format(v) end, enableIf = situational }))
    g, s = Bind("visibility", "mouse")
    card:Add(UI.Check(card, L["Show it with the mouse over"], g, s, { enableIf = situational }))

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
    win:AddNav("header", L["Header"], BuildHeader)
    win:AddNav("icons", L["Icons"], BuildIcons)
    win:AddNav("texts", L["Texts"], BuildTexts)
    win:AddNav("addons", L["Addons"], BuildAddons)
    win:AddNav("map", L["Map"], BuildMap)
    win:AddNav("profiles", L["Profiles"], BuildProfiles)
    UI.OnRefresh = function()
        win:SetSubtitle(L["Profile: %s"]:format(ns.profileName or ""))
        local other = ns.ConflictingAddon()
        win:SetStatus(other and ("|cffff7359" .. L["%s is also loaded: both change the minimap. Disable one of them and reload."]:format(other) .. "|r") or "")
    end
    -- "Move icons" (window header): outlines on the map's icons, to drag
    -- them along the edge or click them; off again when the window closes
    win:AddHeaderButton(L["Move icons"], function()
        ns.SetEditing(not ns.IsEditing())
        UI.RefreshAll()
    end, function() return ns.IsEditing() end, L["Drag them along the edge of the map, or click one for its settings."])
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
