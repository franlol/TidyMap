-------------------------------------------------------------------------------
-- TidyMap - Zoom out by itself
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
    if not z.auto or Minimap:GetZoom() == 0 then return end
    timer = C_Timer.NewTimer(z.delay, function()
        timer = nil
        Minimap:SetZoom(0)
    end)
end

local function Start()
    hooksecurefunc(Minimap, "SetZoom", OnZoom)
end

ns.Module(Start, OnZoom)
