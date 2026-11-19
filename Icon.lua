-------------------------------------------------------------------------------
-- TidyMap - Minimap icon (optional): click opens the options, drag moves
-- it along the edge of the map. It follows the map's shape and corners.
-------------------------------------------------------------------------------

local _, ns = ...
local Flaty = LibStub("LibFlatyUI-1.0")

local SIZE = 24
local btn = CreateFrame("Button", "TidyMapIcon", Minimap)
btn:SetSize(SIZE, SIZE)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)
btn:RegisterForClicks("AnyUp")
btn:RegisterForDrag("LeftButton")
local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()

local atan2 = math.atan2 or atan2

local function Place()
    -- on the edge of the map's shape (Blizzard's round map when TidyMap is off)
    local corners = ns.P.enabled and ns.P.corners or 100
    local x, y = Flaty.ShapeEdge(Flaty.Rounded(corners), ns.db.icon.angle,
        Minimap:GetWidth() / 2, Minimap:GetHeight() / 2, 0)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    icon:SetTexture(corners >= 50 and "Interface\\AddOns\\TidyMap\\Media\\IconRound"
        or "Interface\\AddOns\\TidyMap\\Media\\Icon")
end

local function FollowCursor()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ns.db.icon.angle = math.deg(atan2(cy / scale - my, cx / scale - mx))
    Place()
end

btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", FollowCursor)
    GameTooltip:Hide()
end)
btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
btn:SetScript("OnClick", function() ns.ToggleOptions() end)
-- a little dimmed, full brightness under the mouse
icon:SetVertexColor(0.85, 0.85, 0.85)
btn:SetScript("OnEnter", function(self)
    icon:SetVertexColor(1, 1, 1)
    ns.Tooltip(self)
end)
btn:SetScript("OnLeave", function()
    icon:SetVertexColor(0.85, 0.85, 0.85)
    GameTooltip:Hide()
end)

-- Clean mode: only with the mouse over the map, like the other icons
ns.faders[#ns.faders + 1] = { frame = btn, hover = function() return ns.P.enabled and ns.P.clean end }

local function Apply()
    -- TidyMap off: the map is Blizzard's alone (the options still open
    -- with /tidymap and from the addon menu)
    btn:SetShown(ns.P.enabled and not ns.db.icon.hide)
    Place()
end

ns.Module(function() end, Apply)
