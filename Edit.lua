-------------------------------------------------------------------------------
-- TidyMap - Editing on the map itself, while the icons are unlocked
-- Every Blizzard icon gets an outline: drag it along the edge of the shape,
-- or click it to open its settings. The map itself keeps its clicks (pings).
-- Other addons' buttons move with LibDBIcon's own drag (Buttons.lua).
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local overlays = {}
local editing = false
local atan2 = math.atan2 or atan2

local function Paint(o, hot)
    local A = ns.ACCENT
    o:SetBackdropColor(A[1], A[2], A[3], hot and 0.35 or 0.15)
    o:SetBackdropBorderColor(A[1], A[2], A[3], 1)
end

-- Angle of the cursor around the map's center, 0-359
local function CursorAngle()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    return math.floor(math.deg(atan2(cy / scale - my, cx / scale - mx)) + 0.5) % 360
end

local function Overlay(key)
    if overlays[key] then return overlays[key] end
    local o = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    o:SetFrameStrata("HIGH")
    o:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    Paint(o, false)
    o:RegisterForClicks("LeftButtonUp")
    o:RegisterForDrag("LeftButton")
    o:SetScript("OnEnter", function(self)
        Paint(self, true)
        local e
        for _, x in ipairs(ns.ELEMENTS) do if x.key == key then e = x end end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L[e.name], 1, 1, 1)
        GameTooltip:AddLine(L["Drag along the edge · Click for its settings"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    o:SetScript("OnLeave", function(self)
        Paint(self, false)
        GameTooltip:Hide()
    end)
    o:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            ns.P.elements[key].angle = CursorAngle()
            ns.ApplyElement(key)
        end)
    end)
    o:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        ns.SelectElement(key)
    end)
    o:SetScript("OnClick", function() ns.SelectElement(key) end)
    overlays[key] = o
    return o
end

-- Elements.lua calls this after placing an icon
function ns.OnElementPlaced(key, f)
    local o = overlays[key]
    if not editing or not ns.P.enabled then
        if o then o:Hide() end
        return
    end
    o = Overlay(key)
    -- the icon's size on screen, at least 16 px
    local k = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    o:SetSize(math.max(16, f:GetWidth() * k), math.max(16, f:GetHeight() * k))
    o:ClearAllPoints()
    o:SetPoint("CENTER", f, "CENTER")
    o:Show()
end

-- Unlocked: the outlines stay (window open or not) until locked again or the
-- next login (unlocked is never saved)
local function ApplyLock()
    ns.SetEditing(ns.P.enabled and ns.unlocked)
end
ns.Module(function() end, ApplyLock)

function ns.SetEditing(on)
    editing = on and true or false
    if not editing then
        for _, o in pairs(overlays) do o:Hide() end
    end
    ns.SetElementsEditing(editing)
end
