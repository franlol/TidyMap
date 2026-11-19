-------------------------------------------------------------------------------
-- TidyMap - Options window (LibFlatyUI-1.0)
--
--   Look     : on / off, styles (one click), corners, border, glow
--   Icons    : Blizzard's icons around the map (zone, clock and
--              coordinates too): clean mode, shown / on hover / hidden,
--              place on the edge (also by dragging them on the map)
--   Texts    : each text's font, size, outline, shadow and color
--   Addons   : other addons' minimap buttons: flat look, into the addon menu
--   Map      : zoom, the minimap icon, language
--   Profiles : profile in use, new, copy, reset, delete
-- "Unlock icons" (header, = Icons > Lock icons): drag icons on the map.
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
ns.selected = ns.selected or "calendar"

local MODES = function()
    return { { "show", L["Show"] }, { "hover", L["On hover"] }, { "hide", L["Hide"] } }
end
local MODE_TAG = {
    show = function() return L["Shown"], UI.theme.success end,
    hover = function() return L["On hover"], ns.ACCENT end,
    hide = function() return L["Hidden"], UI.theme.muted end,
}

local function Sel() return ns.P.elements[ns.selected] end

-- The plate of the flat look: padding (negative: inside the picture's empty
-- margins), corners (the map's or its own), border size, border color (the
-- map's or its own), background color
local function PlateRows(card, cfg, enableIf)
    local function Get(k) return function() return cfg()[k] end end
    local function Set(k) return function(v) cfg()[k] = v ns.ApplyAll() end end
    card:Add(UI.Slider(card, L["Padding"], -10, 10, 1, Get("pad"), Set("pad"), { format = UI.px, enableIf = enableIf }))
    card:Add(UI.Check(card, L["Corners like the map"], Get("mapCorners"), Set("mapCorners"), { enableIf = enableIf }))
    card:Add(UI.Slider(card, L["Corners"], 0, 100, 1, Get("corners"), Set("corners"),
        { sub = true, format = Pct, enableIf = Both(enableIf, function() return not cfg().mapCorners end) }))
    card:Add(UI.Slider(card, L["Border"], 0, 4, 1, Get("edge"), Set("edge"), { format = UI.px, enableIf = enableIf }))
    local hasEdge = Both(enableIf, function() return cfg().edge > 0 end)
    card:Add(UI.Check(card, L["Border color like the map"], Get("mapColor"), Set("mapColor"), { sub = true, enableIf = hasEdge }))
    card:Add(UI.Swatch(card, L["Border color"], function() return cfg().edgeColor end, Apply,
        { alpha = true, sub = true, enableIf = Both(hasEdge, function() return not cfg().mapColor end) }))
    card:Add(UI.Swatch(card, L["Background color"], function() return cfg().bgColor end, Apply,
        { alpha = true, enableIf = enableIf }))
end

-- Where a text sits: a point of the map and an offset from it
local POINTS = function()
    return {
        { "TOPLEFT", L["Top left"] }, { "TOP", L["Top"] }, { "TOPRIGHT", L["Top right"] },
        { "LEFT", L["Left"] }, { "CENTER", L["Center"] }, { "RIGHT", L["Right"] },
        { "BOTTOMLEFT", L["Bottom left"] }, { "BOTTOM", L["Bottom"] }, { "BOTTOMRIGHT", L["Bottom right"] },
    }
end
local function AnchorRows(card, cfg, key, enableIf, showIf)
    local function Get(k, d) return function() return cfg()[k] or d end end
    local function Set(k) return function(v) cfg()[k] = v ns.ApplyElement(key()) end end
    -- a new point starts with no offset: the text goes right to it
    card:Add(UI.Dropdown(card, L["Anchor"], POINTS, Get("point", "CENTER"), function(v)
        local c = cfg()
        c.point, c.x, c.y = v, 0, 0
        ns.ApplyElement(key())
        UI.RefreshAll()
    end, { enableIf = enableIf, showIf = showIf }))
    card:Add(UI.Slider(card, "X", -150, 150, 1, Get("x", 0), Set("x"),
        { format = UI.px, enableIf = enableIf, showIf = showIf }))
    card:Add(UI.Slider(card, "Y", -150, 150, 1, Get("y", 0), Set("y"),
        { format = UI.px, enableIf = enableIf, showIf = showIf }))
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
        tag = function(e) return MODE_TAG[ns.ElementMode(e.key)]() end,
        selected = function(e) return e.key == ns.selected end,
        onSelect = function(_, e) ns.selected = e.key UI.RefreshAll() end,
        rows = #ns.ELEMENTS,
        enableIf = On,
    }))

    card = right:Add(1, UI.Card(right.content, ElementName(ns.selected)))
    local title = card
    local free = On
    -- the coordinates: shown or not is the game's own option
    card:Add(UI.Segmented(card, L["Show"], MODES(), function() return ns.ElementMode(ns.selected) == "hide" and "hide" or Sel().mode end, function(v)
        if ns.selected == "coords" then
            C_CVar.SetCVar("minimapShowPlayerCoords", v == "hide" and "0" or "1")
        end
        Sel().mode = v
        ApplySel()
    end, { enableIf = free }))
    local placed = Both(free, function() return ns.ElementMode(ns.selected) ~= "hide" end)
    card:Add(UI.Segmented(card, L["Decimals"], { { "0", "0" }, { "1", "1" } },
        function() return C_CVar.GetCVarBool("coordsByTenths") and "1" or "0" end,
        function(v) C_CVar.SetCVar("coordsByTenths", v) end,
        { enableIf = Both(placed, function() return ns.selected == "coords" end) }))
    card:Add(UI.Segmented(card, L["Look"], { { "flat", L["Flat"] }, { "blizzard", "Blizzard" } },
        function() return Sel().look end, function(v)
            Sel().look = v
            ApplySel()
        end, { enableIf = placed }))
    card:Add(UI.Slider(card, L["Size"], 50, 200, 5, function() return Sel().size end, function(v)
        Sel().size = v
        ApplySel()
    end, { format = Pct, enableIf = placed }))
    -- icons on the edge (angle, distance); texts at a point of the map
    local isText = function() return ns.IsTextElement(ns.selected) end
    local isIcon = function() return not isText() end
    card:Add(UI.Slider(card, L["Angle"], 0, 359, 1, function() return Sel().angle end, function(v)
        Sel().angle = v
        ApplySel()
    end, { format = function(v) return ("%d°"):format(v) end, enableIf = placed, showIf = isIcon }))
    card:Add(UI.Slider(card, L["Distance"], -20, 40, 1, function() return Sel().dist end, function(v)
        Sel().dist = v
        ApplySel()
    end, { format = UI.px, enableIf = placed, showIf = isIcon }))
    AnchorRows(card, Sel, function() return ns.selected end, placed, isText)
    card:Add(UI.Heading(card, L["Flat look"]))
    PlateRows(card, Sel, Both(placed, function() return Sel().look == "flat" end))
    card:Add(UI.Buttons(card, {
        { L["Reset this icon"], function()
            local d = ns.defaults.elements[ns.selected]
            for _, k in ipairs({ "angle", "dist", "point", "x", "y", "look", "size", "pad", "edge", "mapColor", "mapCorners", "corners" }) do
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
    -- Blizzard's icons and other addons' buttons alike
    card:Add(UI.Check(card, L["Lock icons"], function() return not ns.unlocked end, function(v)
        ns.unlocked = not v
        ns.ApplyAll()
    end, { enableIf = On, tip = L["Unlocked: drag any icon along the edge of the map, other addons' buttons too. Their clicks wait until locked again."] }))
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
    end

    left:Layout()
    right:Layout()
end

-------------------------------------------------------------------------------
-- Texts: every text of the map (Blizzard's zone, clock and coordinates)
-- with its whole look: font, size, outline, shadow (color, offset) and
-- color, and its background (the same plate as on the Icons page).
-------------------------------------------------------------------------------
local OUTLINES = function()
    return { { "", L["None"] }, { "OUTLINE", L["Thin"] }, { "THICKOUTLINE", L["Thick"] } }
end
local STYLE_KEYS = { "font", "outline", "shadow", "shadowX", "shadowY" }
local PLATE_KEYS = { "look", "pad", "mapCorners", "corners", "edge", "mapColor", "edgeColor", "bgColor" }

local function TextCard(page, col, key, title)
    local function C() return ns.P.texts[key] end
    local function Get(k) return function() return C()[k] end end
    local function Set(k) return function(v) C()[k] = v ns.ApplyAll() end end
    -- greyed while its icon is hidden (Icons page)
    local shown = Both(On, function() return ns.ElementMode(key) ~= "hide" end)

    local card = page:Add(col, UI.Card(page.content, title))
    card:Add(UI.Dropdown(card, L["Font"], function() return UI.MediaList("font") end,
        function() return UI.ResolveMedia(C().font) or C().font end, Set("font"), { enableIf = shown }))
    card:Add(UI.Slider(card, L["Size"], 6, 32, 1, Get("size"), Set("size"), { format = UI.px, enableIf = shown }))
    card:Add(UI.Segmented(card, L["Outline"], OUTLINES(), Get("outline"), Set("outline"), { enableIf = shown }))
    card:Add(UI.Check(card, L["Shadow"], Get("shadow"), Set("shadow"), { enableIf = shown }))
    local shadow = Both(shown, function() return C().shadow end)
    card:Add(UI.Swatch(card, L["Shadow color"], function() return C().shadowColor end, Apply,
        { alpha = true, sub = true, enableIf = shadow }))
    card:Add(UI.Slider(card, L["Shadow X"], -4, 4, 1, Get("shadowX"), Set("shadowX"),
        { format = UI.px, sub = true, enableIf = shadow }))
    card:Add(UI.Slider(card, L["Shadow Y"], -4, 4, 1, Get("shadowY"), Set("shadowY"),
        { format = UI.px, sub = true, enableIf = shadow }))
    if key == "zone" then
        card:Add(UI.Check(card, L["PvP colors"], Get("pvp"), Set("pvp"), { enableIf = shown }))
        card:Add(UI.Swatch(card, L["Text color"], function() return C().color end, Apply,
            { alpha = true, sub = true, enableIf = Both(shown, function() return not C().pvp end) }))
    else
        card:Add(UI.Swatch(card, L["Text color"], function() return C().color end, Apply,
            { alpha = true, enableIf = shown }))
    end

    -- where it sits (the same settings as on the Icons page)
    local function E() return ns.P.elements[key] end
    card:Add(UI.Heading(card, L["Position"]))
    AnchorRows(card, E, function() return key end, shown)

    -- its background: the icon's flat plate (the same settings as on the
    -- Icons page), or Blizzard's own art
    card:Add(UI.Heading(card, L["Background"]))
    card:Add(UI.Segmented(card, L["Look"], { { "flat", L["Flat"] }, { "blizzard", "Blizzard" } },
        function() return E().look end, function(v)
            E().look = v
            ns.ApplyElement(key)
        end, { enableIf = shown }))
    PlateRows(card, E, Both(shown, function() return E().look == "flat" end))

    -- font, outline and shadow to the other texts (they keep size and color)
    card:Add(UI.Buttons(card, {
        { L["Use this style for all texts"], function()
            for _, other in ipairs({ "zone", "clock", "coords" }) do
                local t = ns.P.texts[other]
                if other ~= key then
                    for _, k in ipairs(STYLE_KEYS) do t[k] = C()[k] end
                    local sc = C().shadowColor
                    t.shadowColor = { r = sc.r, g = sc.g, b = sc.b, a = sc.a }
                end
            end
            ns.ApplyAll()
            UI.RefreshAll()
        end, "danger", confirm = true },
    }, { enableIf = On }))
    card:Add(UI.Buttons(card, {
        { L["Reset this text"], function()
            ns.P.texts[key] = ns.Copy(ns.defaults.texts[key])
            -- its background too (where it sits stays)
            local d = ns.defaults.elements[key]
            for _, k in ipairs(PLATE_KEYS) do E()[k] = ns.Copy(d[k]) end
            ns.ApplyAll()
            UI.RefreshAll()
        end, "danger", confirm = true },
    }, { enableIf = On }))
end

local function BuildTexts(container)
    local page = UI.Page(container, 2)
    TextCard(page, 1, "zone", L["Zone"])
    TextCard(page, 2, "clock", L["Clock"])
    TextCard(page, 1, "coords", L["Coordinates"])
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
    g, s = Bind("buttons", "border")
    card:Add(UI.Check(card, L["Black border"], g, s,
        { sub = true, enableIf = Both(Both(has, ns.CanFlattenButtons), function() return ns.P.buttons.flat end) }))

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
    -- the same as Icons > Lock icons, at hand on every page
    win:AddHeaderButton(L["Unlock icons"], function()
        ns.unlocked = not ns.unlocked
        ns.ApplyAll()
        UI.RefreshAll()
    end, function() return ns.unlocked end, L["Drag them along the edge of the map, or click one for its settings."])
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
