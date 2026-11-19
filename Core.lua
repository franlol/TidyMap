-------------------------------------------------------------------------------
-- TidyMap - Settings, profiles, styles, slash command
--
-- TidyMapDB = {
--     language  = "enUS" | "esES",
--     icon      = { hide, minimapPos, lock },  (account-wide, LibDBIcon's)
--     profiles  = { [name] = settings },
--     profileOf = { [character] = name },
-- }
-- ns.P is the profile in use. Every change applies at once.
-------------------------------------------------------------------------------

local ADDON, ns = ...
local L = ns.L

ns.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or ""
if ns.version:find("^@") then ns.version = "dev" end

local function C(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end
ns.ACCENT = { 0.96, 0.72, 0.32 }

-- the plate behind an icon (flat look): its padding, its
-- border (0 = none; the map's border color or its own) and its color
local function Plate(t)
    t.pad = t.pad or 2
    t.mapCorners = t.mapCorners ~= false   -- the map's corners, or its own
    t.corners = t.corners or 0
    t.edge = t.edge or 1
    t.mapColor = t.mapColor ~= false
    t.edgeColor = t.edgeColor or C(0, 0, 0, 1)
    t.bgColor = t.bgColor or C(0.05, 0.05, 0.06, 0.9)
    return t
end
local function Icon(angle, dist)
    return Plate({ mode = "show", angle = angle, dist = dist, look = "flat", size = 100 })
end
local function Text(size, t)
    t.font = LibStub("LibFlatyUI-1.0").Media("font", "Flaty: Inter")
    t.size = size
    t.outline = ""
    t.shadow = true
    t.shadowColor = C(0, 0, 0, 1)
    t.shadowX, t.shadowY = 1, -1
    return t
end

ns.defaults = {
    enabled = true,     -- off: the minimap looks like Blizzard's
    corners = 8,        -- 0 square ... 100 round (%)
    border = { size = 1, color = C(0, 0, 0, 1), class = false },
    glow = { on = false, color = C(0.96, 0.72, 0.32, 0.6) },
    -- after a zoom in: "out" (back out after delay s), "remember" or "blizzard"
    zoom = { mode = "out", delay = 10, buttons = true },
    clean = false,      -- every shown icon only on hover
    -- the whole minimap by situation: always, only out of combat or only in
    -- combat (hidden: fully gone, as the tracking icons can't fade), fade
    -- time, and whether the mouse over it brings it back
    visibility = { when = "always", fade = 0.3, mouse = true },
    -- Blizzard's icons: shown / on hover / hidden, angle on the edge
    -- (0 right, 90 up), distance past the edge (px), look (Blizzard's art
    -- or flat) and size (% of Blizzard's). The texts (zone, clock,
    -- coordinates) sit at a point of the map instead: point, x, y (set from
    -- their angle and distance the first time)
    -- The flat look of each icon: padding around it, border size, border
    -- color (the map's, or its own) and background color.
    elements = {
        zone = Icon(90, 12),
        clock = Icon(270, 10),
        calendar = Icon(42, 0),
        tracking = Icon(138, 0),
        mail = Icon(162, 0),
        compartment = Icon(20, 0),
        daynight = Icon(64, 0),
        coords = Icon(270, -14),
    },
    -- each text of the map (Blizzard's zone, clock and coordinates): font,
    -- size, outline, shadow (its color and offset) and color (the zone can
    -- keep Blizzard's PvP colors instead)
    texts = {
        zone = Text(12, { pvp = true, color = C(1, 0.82, 0, 1) }),
        clock = Text(12, { color = C(1, 1, 1, 1) }),
        coords = Text(10, { color = C(1, 1, 1, 1) }),
    },
    -- other addons' minimap buttons (LibDBIcon): flat look, and the ones
    -- moved into the addon menu ([name] = true); hover: only on hover (Clean
    -- mode does it too); lock: not draggable (own setting, the header's
    -- "Unlock icons" leaves them alone)
    buttons = { flat = true, border = false, borderCorners = 0, borderSize = 1, hover = false, lock = false, menu = {} },
}

-- Icons unlocked (dragged on the map): for this session only, every login
-- starts locked
ns.unlocked = false

local ACCOUNT = {
    icon = { hide = false, minimapPos = 225 },
}

-- Styles: one click sets the whole look (corners, border, glow)
ns.STYLES = {
    { key = "clean", name = "Clean", look = {
        corners = 8, border = { size = 1, color = C(0, 0, 0, 1), class = false },
        glow = { on = false } } },
    { key = "classic", name = "Classic", look = {
        corners = 100, border = { size = 2, color = C(0.78, 0.63, 0.32, 1), class = false },
        glow = { on = false } } },
    { key = "glow", name = "Glow", look = {
        corners = 20, border = { size = 1, color = C(0.05, 0.05, 0.05, 1), class = false },
        glow = { on = true, color = C(0.96, 0.72, 0.32, 0.6) } } },
    { key = "minimal", name = "Minimal", look = {
        corners = 0, border = { size = 0, color = C(0, 0, 0, 1), class = false },
        glow = { on = false } } },
}

local function Copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = Copy(v) end
    return c
end
ns.Copy = Copy

-- Missing keys of t from def (the rest is kept)
local function Fill(t, def)
    for k, v in pairs(def) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {} end
            Fill(t[k], v)
        elseif t[k] == nil then
            t[k] = v
        end
    end
end

-- def's values into t, table by table (keys def does not have are kept)
local function Merge(t, def)
    for k, v in pairs(def) do
        if type(v) == "table" and not v.r then
            if type(t[k]) ~= "table" then t[k] = {} end
            Merge(t[k], v)
        else
            t[k] = Copy(v)
        end
    end
end

-------------------------------------------------------------------------------
-- Modules: start() once at login, apply() after every change
-------------------------------------------------------------------------------
ns.modules = {}
function ns.Module(start, apply)
    ns.modules[#ns.modules + 1] = { start = start, apply = apply }
end

function ns.ApplyAll()
    for _, m in ipairs(ns.modules) do
        if m.apply then m.apply() end
    end
end

function ns.ApplyStyle(key)
    for _, s in ipairs(ns.STYLES) do
        if s.key == key then
            Merge(ns.P, s.look)
            ns.ApplyAll()
            return
        end
    end
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------
local DEFAULT = "Default"

-- Forever: characters have a surname, so it is part of the key
local function CharKey()
    local name, surname = UnitName("player")
    if surname and surname ~= "" then name = name .. " " .. surname end
    return (name or "?") .. " - " .. (GetRealmName() or "?")
end

-- Older settings in the current form
local OLD_SHAPES = { square = 0, slightly = 8, rounded = 20, round = 100 }
local function Migrate(p)
    -- the lock is not saved any more (every login starts locked)
    p.locked = nil
    -- one font / outline and a size per text became a full style per text
    -- (the text colors moved here from the header pieces)
    local t = p.texts
    if type(t) == "table" and (t.font ~= nil or type(t.zone) == "number") then
        local new = {}
        for _, key in ipairs({ "zone", "clock", "coords" }) do
            local h = type(p.header) == "table" and p.header[key] or {}
            new[key] = { font = t.font, outline = t.outline, size = type(t[key]) == "number" and t[key] or nil,
                color = h.color, pvp = h.pvp }
            h.color, h.pvp = nil, nil
        end
        p.texts = new
    end
    -- TidyMap's own header is gone: zone, clock and coordinates are
    -- Blizzard's icons again, shown / on hover / hidden as the header had them
    if type(p.header) == "table" then
        for _, key in ipairs({ "zone", "clock", "coords" }) do
            local h, e = p.header[key], type(p.elements) == "table" and p.elements[key]
            if type(h) == "table" and type(e) == "table" and h.mode then e.mode = h.mode end
        end
        p.header = nil
    end
    -- the addon buttons' black border: a shape became corners (%)
    if type(p.buttons) == "table" and p.buttons.borderShape then
        local CORNERS = { square = 0, rounded = 50, round = 100 }
        p.buttons.borderCorners = p.buttons.borderCorners or CORNERS[p.buttons.borderShape]
        p.buttons.borderShape = nil
    end
    -- the map's opacities are gone (hidden is fully hidden)
    if type(p.visibility) == "table" then
        p.visibility.opacity, p.visibility.faded = nil, nil
    end
    -- the zoom on / off became a choice
    if type(p.zoom) == "table" and p.zoom.auto ~= nil then
        p.zoom.mode = p.zoom.mode or (p.zoom.auto and "out" or "blizzard")
        p.zoom.auto = nil
    end
    if type(p.shape) == "string" then
        p.corners = p.corners or OLD_SHAPES[p.shape]
        p.shape = nil
    end
end

local function FillProfile(p)
    Migrate(p)
    Fill(p, ns.defaults)
end

local function SetProfile(name)
    local db = ns.db
    db.profiles[name] = db.profiles[name] or {}
    db.profileOf[ns.charKey] = name
    ns.profileName = name
    ns.P = db.profiles[name]
    FillProfile(ns.P)
end

function ns.UseProfile(name)
    SetProfile(name)
    ns.ApplyAll()
end

function ns.CopyProfile(from)
    local src = ns.db.profiles[from]
    if not src or from == ns.profileName then return end
    wipe(ns.P)
    for k, v in pairs(Copy(src)) do ns.P[k] = v end
    FillProfile(ns.P)
    ns.ApplyAll()
end

function ns.ResetProfile()
    wipe(ns.P)
    Fill(ns.P, ns.defaults)
    ns.ApplyAll()
end

function ns.DeleteProfile(name)
    if name == ns.profileName then return end
    ns.db.profiles[name] = nil
    for char, p in pairs(ns.db.profileOf) do
        if p == name then ns.db.profileOf[char] = nil end
    end
end

function ns.ProfileNames()
    local list = {}
    for name in pairs(ns.db.profiles) do list[#list + 1] = name end
    table.sort(list)
    return list
end

-------------------------------------------------------------------------------
-- Loading
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        TidyMapDB = TidyMapDB or {}
        ns.db = TidyMapDB
        Fill(ns.db, ACCOUNT)
        ns.db.profiles = ns.db.profiles or {}
        ns.db.profileOf = ns.db.profileOf or {}
        ns.SetLanguage(ns.db.language or "enUS")
    else
        ns.charKey = CharKey()
        SetProfile(ns.db.profileOf[ns.charKey] or DEFAULT)
        for _, m in ipairs(ns.modules) do m.start() end
        ns.ApplyAll()
        local other = ns.ConflictingAddon()
        if other then
            print("|cfff5b852TidyMap|r: " .. L["%s is also loaded: both change the minimap. Disable one of them and reload."]:format(other))
        end
    end
end)

-- Other minimap addons that restyle the same map
local CONFLICTS = { "SexyMap", "BasicMinimap", "Mappy", "Chinchilla", "SimpleMinimap" }
function ns.ConflictingAddon()
    for _, name in ipairs(CONFLICTS) do
        if C_AddOns.IsAddOnLoaded(name) then return name end
    end
end

function ns.SetLanguagePref(lang)
    ns.db.language = lang
    ns.SetLanguage(lang)
end

-------------------------------------------------------------------------------
-- Opening the options: /tidymap, or the minimap icon (Icon.lua)
-------------------------------------------------------------------------------
SLASH_TIDYMAP1 = "/tidymap"
SlashCmdList.TIDYMAP = function() ns.ToggleOptions() end
