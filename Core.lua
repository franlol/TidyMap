-------------------------------------------------------------------------------
-- TidyMap - Settings, profiles, styles, slash command
--
-- TidyMapDB = {
--     language  = "enUS" | "esES",
--     icon      = { hide, angle },          (account-wide)
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

ns.defaults = {
    enabled = true,     -- off: the minimap looks like Blizzard's
    corners = 8,        -- 0 square ... 100 round (%)
    border = { size = 1, color = C(0, 0, 0, 1), class = false },
    glow = { on = false, color = C(0.96, 0.72, 0.32, 0.6) },
    zoom = { auto = true, delay = 10, buttons = true },
    clean = false,      -- every shown icon only on hover
    -- Blizzard's icons: shown / on hover / hidden, angle on the edge
    -- (0 right, 90 up), distance past the edge (px), look (Blizzard's art
    -- or flat) and size (% of Blizzard's)
    elements = {
        zone = { mode = "show", angle = 90, dist = 12, look = "flat", size = 100 },
        clock = { mode = "show", angle = 270, dist = 10, look = "flat", size = 100 },
        calendar = { mode = "show", angle = 42, dist = 0, look = "flat", size = 100 },
        tracking = { mode = "show", angle = 138, dist = 0, look = "flat", size = 100 },
        mail = { mode = "show", angle = 162, dist = 0, look = "flat", size = 100 },
        compartment = { mode = "show", angle = 20, dist = 0, look = "flat", size = 100 },
        daynight = { mode = "show", angle = 64, dist = 0, look = "flat", size = 100 },
        coords = { mode = "show", angle = 270, dist = -14, look = "flat", size = 100 },
    },
    -- the texts on and around the map: one font, a size each
    texts = {
        font = LibStub("LibFlatyUI-1.0").Media("font", "Flaty: Inter"),
        outline = "",
        zone = 12, clock = 12, coords = 10,
    },
    -- TidyMap's header: its own zone name and clock (on: Blizzard's zone and
    -- clock icons stay hidden). Each piece: shown / on hover / hidden, top or
    -- bottom, outside or inside the map, extra distance, background (none,
    -- flat, pill) and its color, text color (zone: Blizzard's PvP colors)
    header = {
        on = true,
        zone = { mode = "show", place = "top", side = "outside", offset = 0, bg = "pill",
            bgColor = C(0.05, 0.05, 0.06, 0.9), pvp = true, color = C(1, 0.82, 0, 1) },
        clock = { mode = "show", place = "bottom", side = "outside", offset = 0, bg = "pill",
            bgColor = C(0.05, 0.05, 0.06, 0.9), color = C(1, 1, 1, 1) },
    },
    -- other addons' minimap buttons (LibDBIcon): flat look, and the ones
    -- moved into the addon menu ([name] = true)
    buttons = { flat = true, menu = {} },
}

local ACCOUNT = {
    icon = { hide = false, angle = 225 },
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
-- Opening the options: /tidymap, the addon compartment, the minimap icon
-------------------------------------------------------------------------------
SLASH_TIDYMAP1 = "/tidymap"
SlashCmdList.TIDYMAP = function() ns.ToggleOptions() end

function ns.Tooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("TidyMap", ns.version, ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.5, 0.5, 0.5)
    GameTooltip:AddDoubleLine(L["Profile"], ns.profileName or "?", 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["Click"], L["Open the options"], 1, 0.82, 0, 1, 1, 1)
    GameTooltip:Show()
end

-- Named in the TOC (AddonCompartmentFunc...)
function TidyMap_OnCompartmentClick() ns.ToggleOptions() end
function TidyMap_OnCompartmentEnter(_, button) ns.Tooltip(button) end
function TidyMap_OnCompartmentLeave() GameTooltip:Hide() end
