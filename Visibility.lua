-------------------------------------------------------------------------------
-- TidyMap - The whole minimap by situation
--
-- Always, only out of combat, or only in combat. Out of its situation the
-- map fades out completely and stops taking clicks. No partial opacity:
-- the game draws the tracking icons at full strength whatever the map's
-- opacity. The mouse over it can bring it back. Only the opacity of
-- Blizzard's minimap group changes (icons, header, TidyMap's map frame);
-- combat comes from PLAYER_REGEN_DISABLED / ENABLED, like Blizzard's frames.
-------------------------------------------------------------------------------

local _, ns = ...

local inCombat = false
local alpha                -- current opacity of the group (nil: untouched)
local savedAlpha           -- Blizzard's own, kept before the first change
local mouseOff = false     -- TidyMap turned the map's mouse off

local function On() return ns.P and ns.P.enabled end

-- the opacity wanted now (0-1)
local function Target()
    local v = ns.P.visibility
    if ns.IsEditing() then return 1 end
    local shown = v.when == "always"
        or (v.when == "outCombat" and not inCombat)
        or (v.when == "inCombat" and inCombat)
    if not shown and v.mouse and (ns.MapHolder() or MinimapCluster):IsMouseOver() then shown = true end
    return shown and 1 or 0
end

-- Fully gone: no clicks, and the map itself hidden (only that takes the
-- tracking icons away)
-- Shown again, the map stays blank until its zoom changes: one step and
-- back (Zoom.lua ignores it)
local function Redraw()
    local z = Minimap:GetZoom()
    ns.redrawingZoom = true
    Minimap:SetZoom(z > 0 and z - 1 or z + 1)
    Minimap:SetZoom(z)
    ns.redrawingZoom = false
end

local function SetMapMouse(on)
    if on == not mouseOff then return end
    Minimap:EnableMouse(on)
    Minimap:EnableMouseWheel(on)
    Minimap:SetShown(on)
    if on then Redraw() end
    mouseOff = not on
end

-- Blizzard's group: icons, header, and TidyMap's frame holding the map
local function Set(a)
    alpha = a
    MinimapCluster:SetAlpha(a)
    SetMapMouse(a > 0.01)
end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, elapsed)
    if not On() then
        self:Hide()
        return
    end
    local target = Target()
    local fade = ns.P.visibility.fade
    if fade <= 0 or not alpha then
        Set(target)
    elseif alpha ~= target then
        local step = elapsed / fade
        Set(target > alpha and math.min(target, alpha + step) or math.max(target, alpha - step))
    end
    -- nothing to follow: always shown at full opacity, and there already
    local v = ns.P.visibility
    if v.when == "always" and alpha == target then self:Hide() end
end)

local function Apply()
    savedAlpha = savedAlpha or MinimapCluster:GetAlpha()
    if On() then
        driver:Show()
    else
        driver:Hide()
        if alpha then
            MinimapCluster:SetAlpha(savedAlpha)
            alpha = nil
        end
        SetMapMouse(true)
    end
end

ns.ApplyVisibility = Apply

local function Start()
    inCombat = InCombatLockdown() and true or false
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event)
        inCombat = event == "PLAYER_REGEN_DISABLED"
        if On() then driver:Show() end
    end)
end

ns.Module(Start, Apply)
