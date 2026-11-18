-------------------------------------------------------------------------------
-- TidyMap - Zoom back out by itself, and Blizzard's zoom buttons
-- The mouse wheel already zooms the map (the game's own). After a zoom in,
-- the map goes back to fully zoomed out once the set time has passed.
-------------------------------------------------------------------------------

local _, ns = ...

local timer

local function Cancel()
    if timer then
        timer:Cancel()
        timer = nil
    end
end

local function OnZoom()
    Cancel()
    local z = ns.P.zoom
    if not ns.P.enabled or not z.auto or Minimap:GetZoom() == 0 then return end
    timer = C_Timer.NewTimer(z.delay, function()
        timer = nil
        Minimap:SetZoom(0)
    end)
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
end

ns.Module(Start, function()
    ApplyButtons()
    OnZoom()
end)
