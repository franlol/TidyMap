-------------------------------------------------------------------------------
-- TidyMap - The minimap's look: corners, border and glow
--
-- Position and size stay with Edit Mode. TidyMap only cuts the map to a
-- rounded square (the game's own mask), hides Blizzard's round frame art and
-- draws a flat border and glow behind it (LibFlatyUI shapes). Turned off,
-- the map gets Blizzard's own mask and frame back.
-------------------------------------------------------------------------------

local _, ns = ...
local Flaty = LibStub("LibFlatyUI-1.0")

-- Blizzard's own: the minimap mask (an atlas) and the zone map's mask
local BLIZZARD_MASK = "ui-hud-minimap-frame-generic-mask"
local BLIZZARD_HYBRID_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local border   -- Flaty shape border behind the minimap

local function On()
    return ns.P and ns.P.enabled
end

local function Shape()
    return Flaty.GetShape(Flaty.Rounded(ns.P and ns.P.corners or 0))
end

-- Addons that place buttons around the minimap ask this (a common
-- convention, LibDBIcon reads it). Half round or more counts as round.
function GetMinimapShape()
    if not On() then return "ROUND" end
    return (ns.P.corners or 0) >= 50 and "ROUND" or "SQUARE"
end

-- The map and the zone map shown in some places (HybridMinimap)
local function ApplyMask()
    local on = On()
    local mask = on and Shape().mask or BLIZZARD_MASK
    Minimap:SetMaskTexture(mask)
    if HybridMinimap then
        HybridMinimap.MapCanvas:SetUseMaskTexture(false)
        HybridMinimap.CircleMask:SetTexture(on and mask or BLIZZARD_HYBRID_MASK,
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        HybridMinimap.MapCanvas:SetUseMaskTexture(true)
    end
    -- Blizzard's round frame art (and the ring of the rotating mode): faded,
    -- so its own Show / Hide calls change nothing
    local alpha = on and 0 or 1
    MinimapCompassTexture:SetAlpha(alpha)
    if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:SetAlpha(alpha) end
end

local function ClassColor()
    local _, class = UnitClass("player")
    local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
    if c then return { c.r, c.g, c.b, 1 } end
end

local function Apply()
    ApplyMask()
    if not On() then
        border:SetBorder(0)
        border:SetGlow(nil)
        return
    end
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
        hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", function()
            if On() then ApplyMask() end
        end)
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
