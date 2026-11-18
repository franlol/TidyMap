-------------------------------------------------------------------------------
-- TidyMap - The minimap's look: shape, border and glow
--
-- Position and size stay with Edit Mode. TidyMap only cuts the map to a
-- shape (the game's own mask), hides Blizzard's round frame art and draws a
-- flat border and glow behind it (LibFlatyUI shapes).
-------------------------------------------------------------------------------

local _, ns = ...
local Flaty = LibStub("LibFlatyUI-1.0")

local border   -- Flaty shape border behind the minimap

local function Shape()
    return Flaty.GetShape(ns.P and ns.P.shape)
end

-- Addons that place buttons around the minimap ask this (a common
-- convention, LibDBIcon reads it)
function GetMinimapShape()
    return Shape().key == "round" and "ROUND" or "SQUARE"
end

-- The map and the zone map shown in some places (HybridMinimap)
local function ApplyMask()
    local mask = Shape().mask
    Minimap:SetMaskTexture(mask)
    if HybridMinimap then
        HybridMinimap.MapCanvas:SetUseMaskTexture(false)
        HybridMinimap.CircleMask:SetTexture(mask)
        HybridMinimap.MapCanvas:SetUseMaskTexture(true)
    end
    -- Blizzard's round frame art (and the ring of the rotating mode); faded,
    -- so its own Show / Hide calls change nothing
    MinimapCompassTexture:SetAlpha(0)
    if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:SetAlpha(0) end
end

local function ClassColor()
    local _, class = UnitClass("player")
    local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    if c then return { c.r, c.g, c.b, 1 } end
end

local function Apply()
    ApplyMask()
    local b, g = ns.P.border, ns.P.glow
    local color = b.class and ClassColor() or { b.color.r, b.color.g, b.color.b, b.color.a or 1 }
    border:SetShape(Shape().key)
    border:SetBorder(b.size, b.size > 0 and color or nil)
    border:SetGlow(g.on and { g.color.r, g.color.g, g.color.b, g.color.a or 1 } or nil)
end

local function Start()
    border = Flaty.ShapeBorder(Minimap)
    -- the game sets its own mask again when the map turns (rotating mode)
    if MinimapCluster.UpdateMinimapConfig then
        hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", ApplyMask)
    end
    if not HybridMinimap then
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(self, _, name)
            if name == "Blizzard_HybridMinimap" then
                self:UnregisterEvent("ADDON_LOADED")
                ApplyMask()
            end
        end)
    end
end

ns.Module(Start, Apply)
