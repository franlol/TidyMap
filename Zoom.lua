-------------------------------------------------------------------------------
-- TidyMap - Zoom, and Blizzard's zoom buttons
-- The mouse wheel already zooms the map (the game's own). After a zoom in:
--   out      : the map zooms back out once the set time has passed
--   remember : the level is kept (per character, indoors and outdoors apart,
--              as the game zooms them apart) and set again after a reload,
--              a login or a loading screen
--   blizzard : nothing, the game's own behaviour
-------------------------------------------------------------------------------

local _, ns = ...

local timer
local restored = {}     -- [indoors / outdoors] = set again this session

local function On() return ns.P and ns.P.enabled end
local function Mode() return ns.P.zoom.mode end
local function Place() return IsIndoors() and "indoors" or "outdoors" end

local function Levels()
    ns.db.zoomLevels = ns.db.zoomLevels or {}
    local t = ns.db.zoomLevels[ns.charKey] or {}
    ns.db.zoomLevels[ns.charKey] = t
    return t
end

local function Cancel()
    if timer then
        timer:Cancel()
        timer = nil
    end
end

local function OnZoom()
    Cancel()
    if not On() then return end
    if Mode() == "remember" then
        Levels()[Place()] = Minimap:GetZoom()
    elseif Mode() == "out" and Minimap:GetZoom() > 0 then
        timer = C_Timer.NewTimer(ns.P.zoom.delay, function()
            timer = nil
            Minimap:SetZoom(0)
        end)
    end
end

-- The kept level, once per session for indoors and once for outdoors
local function Restore()
    if not On() or Mode() ~= "remember" then return end
    local place = Place()
    if restored[place] then return end
    restored[place] = true
    local level = Levels()[place]
    if level then
        Minimap:SetZoom(math.min(level, Minimap:GetZoomLevels() - 1))
    end
end

-- Blizzard's + and - buttons show while the mouse is over the map; off:
-- faded and not clickable (the wheel still zooms)
local saved = {}   -- [button] = Blizzard's own alpha and mouse
local function ApplyButtons()
    local show = not ns.P.enabled or ns.P.zoom.buttons
    for _, b in ipairs({ Minimap.ZoomIn, Minimap.ZoomOut }) do
        if b then
            saved[b] = saved[b] or { alpha = b:GetAlpha(), mouse = b:IsMouseEnabled() }
            b:SetAlpha(show and saved[b].alpha or 0)
            b:EnableMouse(show and saved[b].mouse or false)
        end
    end
end

local function Start()
    hooksecurefunc(Minimap, "SetZoom", OnZoom)
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_INDOORS")
    f:SetScript("OnEvent", function(_, event)
        -- a loading screen: the game may have reset the level
        if event == "PLAYER_ENTERING_WORLD" then wipe(restored) end
        Restore()
    end)
end

ns.Module(Start, function()
    ApplyButtons()
    Restore()
    OnZoom()
end)
