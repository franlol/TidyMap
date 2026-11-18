-------------------------------------------------------------------------------
-- TidyMap - Minimap icon (optional): click opens the options, drag moves
-- it along the edge of the map. It follows the map's shape: a circle for a
-- round map, the edge of the square for the others.
-------------------------------------------------------------------------------

local _, ns = ...

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
    local a = math.rad(ns.db.icon.angle)
    local c, s = math.cos(a), math.sin(a)
    local half = Minimap:GetWidth() / 2
    local round = GetMinimapShape() == "ROUND"
    -- on the edge of the map: the circle, or the square (the longer side
    -- of the direction reaches the edge first)
    local r = round and half or half / math.max(math.abs(c), math.abs(s))
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", c * r, s * r)
    icon:SetTexture(round and "Interface\\AddOns\\TidyMap\\Media\\IconRound"
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

local function Apply()
    btn:SetShown(not ns.db.icon.hide)
    Place()
end

ns.Module(function() end, Apply)
