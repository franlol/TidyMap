-------------------------------------------------------------------------------
-- TidyMap - The map's place and size, TidyMap's own (not Edit Mode)
--
-- While TidyMap is on, the minimap lives in TidyMap's own frame on the
-- screen (Minimap:SetParent: the map is not a protected frame, and Blizzard
-- never anchors it again). Its place and size are saved in the profile.
-- The first time, they are taken from where Edit Mode had it, so nothing
-- jumps. Blizzard's icons follow the map (Elements.lua places them on its
-- edge). Turned off, the map goes back into Blizzard's container.
--
-- "Move map" (header): a box over the map, like Sigil's frames. Drag it
-- (snaps to the grid and the screen center; Shift moves freely), wheel to
-- resize, click for the Map page; arrows around it nudge 1 px (Shift 10).
-------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local FLAT = "Interface\\Buttons\\WHITE8X8"
local GRID_STEP = 32
local SNAP = 6

local holder          -- TidyMap's frame holding the map
local home            -- Blizzard's own: parent, points, scale, level of the map
local inHolder = false
local mover, grid

ns.movingMap = false  -- the box is shown (until the window closes)

local function On() return ns.P and ns.P.enabled end

local function SaveHome()
    if home then return end
    local points = {}
    for i = 1, Minimap:GetNumPoints() do points[i] = { Minimap:GetPoint(i) } end
    home = { parent = Minimap:GetParent(), points = points, scale = Minimap:GetScale(),
        level = Minimap:GetFrameLevel() }
end

local function GoHome()
    if not inHolder then return end
    Minimap:SetParent(home.parent)
    Minimap:ClearAllPoints()
    for _, p in ipairs(home.points) do Minimap:SetPoint(unpack(p)) end
    Minimap:SetScale(home.scale)
    Minimap:SetFrameLevel(home.level)
    holder:Hide()
    inHolder = false
end

-- The map's center (offset from the screen's center, UIParent units) and
-- size (% of UIParent's scale) where it is now
local function Measure()
    local x, y = Minimap:GetCenter()
    local k = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local ux, uy = UIParent:GetCenter()
    return math.floor(x * k - ux + 0.5), math.floor(y * k - uy + 0.5),
        math.floor(k / home.scale * 100 + 0.5)
end

-- Where Edit Mode had it (first use, or Reset position)
local function TakeFromBlizzard()
    GoHome()
    local x, y, size = Measure()
    ns.P.position = { x = x, y = y, size = math.max(50, math.min(200, size)) }
end

-- The map's size on screen in UIParent units
local function MapSize()
    local k = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return Minimap:GetWidth() * k, Minimap:GetHeight() * k
end

local function Place()
    local p = ns.P.position
    local f = p.size / 100
    holder:SetScale(f)
    holder:SetSize(Minimap:GetSize())
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", UIParent, "CENTER", p.x / f, p.y / f)
end

local function Apply()
    SaveHome()
    if not On() then
        GoHome()
        if mover then mover:Hide() end
        if grid then grid:Hide() end
        return
    end
    if not ns.P.position then TakeFromBlizzard() end
    holder:SetFrameStrata(MinimapCluster:GetFrameStrata())
    holder:SetFrameLevel(MinimapCluster:GetFrameLevel())
    holder:Show()
    if not inHolder then
        Minimap:SetParent(holder)
        Minimap:ClearAllPoints()
        Minimap:SetPoint("CENTER", holder, "CENTER")
        Minimap:SetScale(home.scale)
        Minimap:SetFrameLevel(math.max(home.level, holder:GetFrameLevel() + 1))
        inHolder = true
    end
    Place()
    ns.ShowMover(ns.movingMap)
end

-- The frame the whole map fades with (Visibility.lua)
function ns.MapHolder() return inHolder and holder or nil end

function ns.ResetMapPosition()
    TakeFromBlizzard()
    ns.ApplyAll()
end

-------------------------------------------------------------------------------
-- Grid (behind everything while moving), as Sigil's
-------------------------------------------------------------------------------
local function BuildGrid()
    grid = grid or CreateFrame("Frame", nil, UIParent)
    grid:SetAllPoints(UIParent)
    grid:SetFrameStrata("BACKGROUND")
    grid:EnableMouse(false)
    grid.lines = grid.lines or {}
    for _, t in ipairs(grid.lines) do t:Hide() end
    local physH = select(2, GetPhysicalScreenSize())
    local px = 768 / (physH or 768) / UIParent:GetScale()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local used = 0
    local function Line(vertical, offset, center)
        used = used + 1
        local t = grid.lines[used]
        if not t then
            t = grid:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(FLAT)
            grid.lines[used] = t
        end
        t:ClearAllPoints()
        if center then t:SetVertexColor(1, 0.2, 0.2, 0.8) else t:SetVertexColor(0, 0, 0, 0.45) end
        local thick = center and px * 2 or px
        if vertical then
            t:SetSize(thick, h)
            t:SetPoint("CENTER", grid, "CENTER", offset, 0)
        else
            t:SetSize(w, thick)
            t:SetPoint("CENTER", grid, "CENTER", 0, offset)
        end
        t:Show()
    end
    for i = 1, math.floor(w / 2 / GRID_STEP) do Line(true, i * GRID_STEP) Line(true, -i * GRID_STEP) end
    for i = 1, math.floor(h / 2 / GRID_STEP) do Line(false, i * GRID_STEP) Line(false, -i * GRID_STEP) end
    Line(true, 0, true)
    Line(false, 0, true)
end

-- Snap one axis: the map's center or edges onto a grid line (0 is the
-- screen's center)
local function Snap(c, half)
    local best, dist = 0, SNAP + 1
    for _, e in ipairs({ c - half, c, c + half }) do
        local d = math.floor(e / GRID_STEP + 0.5) * GRID_STEP - e
        if math.abs(d) < dist then best, dist = d, math.abs(d) end
    end
    return dist <= SNAP and best or 0
end

-- Kept on the screen
local function Clamp(c, half, limit)
    return math.max(-limit + half, math.min(limit - half, c))
end

-------------------------------------------------------------------------------
-- The box over the map
-------------------------------------------------------------------------------
local function Paint(m, hot)
    local A = ns.ACCENT
    m:SetBackdropColor(A[1], A[2], A[3], hot and 0.35 or 0.2)
    m:SetBackdropBorderColor(A[1], A[2], A[3], 1)
end

local function Tip(m)
    GameTooltip:SetOwner(m, "ANCHOR_TOP")
    GameTooltip:SetText(L["Minimap"], 1, 1, 1)
    GameTooltip:AddLine(L["Drag to move · Wheel to resize · Click for its settings"], 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L["Shift: no snapping · Arrows: 1 px (Shift 10)"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function BuildMover()
    local m = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    m:SetFrameStrata("HIGH")
    m:SetAllPoints(Minimap)
    m:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    Paint(m, false)
    m.label = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    m.label:SetPoint("CENTER")
    m.label:SetText(L["Minimap"])
    m:RegisterForClicks("LeftButtonUp")
    m:RegisterForDrag("LeftButton")
    m:EnableMouseWheel(true)
    m:SetScript("OnEnter", function(self) Paint(self, true) Tip(self) end)
    m:SetScript("OnLeave", function(self) Paint(self, false) GameTooltip:Hide() end)
    -- a click without dragging opens the Map page
    m:SetScript("OnMouseDown", function(self) self.moved = nil end)
    m:SetScript("OnClick", function(self)
        if not self.moved and ns.SelectPage then ns.SelectPage("map") end
    end)
    m:SetScript("OnMouseWheel", function(self, delta)
        local p = ns.P.position
        p.size = math.max(50, math.min(200, p.size + delta * 5))
        Place()
        ns.ApplyAll()
        if ns.RefreshOptions then ns.RefreshOptions() end
        Tip(self)
    end)
    m:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self.moved = true
        local p = ns.P.position
        local s = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        local x0, y0 = p.x, p.y
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local nx, ny = x0 + (x - cx) / s, y0 + (y - cy) / s
            local w, h = MapSize()
            if not IsShiftKeyDown() then
                nx, ny = nx + Snap(nx, w / 2), ny + Snap(ny, h / 2)
            end
            p.x = math.floor(Clamp(nx, w / 2, UIParent:GetWidth() / 2) + 0.5)
            p.y = math.floor(Clamp(ny, h / 2, UIParent:GetHeight() / 2) + 0.5)
            Place()
        end)
    end)
    m:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        -- Blizzard's icons re-place on the map's new spot
        ns.ApplyAll()
    end)

    -- arrows outside each side: 1 px a click, 10 with Shift
    local ARROWS = {
        { "up", "BOTTOM", "TOP", 0, 4, 0, 1 },
        { "down", "TOP", "BOTTOM", 0, -4, 0, -1 },
        { "left", "RIGHT", "LEFT", -4, 0, -1, 0 },
        { "right", "LEFT", "RIGHT", 4, 0, 1, 0 },
    }
    for _, a in ipairs(ARROWS) do
        local b = ns.UI.IconButton(m, a[1], 16, function()
            local n = IsShiftKeyDown() and 10 or 1
            local p = ns.P.position
            local w, h = MapSize()
            p.x = Clamp(p.x + a[6] * n, w / 2, UIParent:GetWidth() / 2)
            p.y = Clamp(p.y + a[7] * n, h / 2, UIParent:GetHeight() / 2)
            Place()
            ns.ApplyAll()
        end)
        b:SetPoint(a[2], m, a[3], a[4], a[5])
    end
    return m
end

function ns.ShowMover(on)
    on = on and On() and inHolder
    if on then
        mover = mover or BuildMover()
        BuildGrid()
    end
    if mover then mover:SetShown(on and true or false) end
    if grid then grid:SetShown(on and true or false) end
end

function ns.SetMovingMap(on)
    ns.movingMap = on and true or false
    ns.ShowMover(ns.movingMap)
end

local function Start()
    holder = CreateFrame("Frame", nil, UIParent)
    holder:SetClampedToScreen(true)
    holder:Hide()
    -- the screen's size changes (resolution, UI scale): the grid follows
    local f = CreateFrame("Frame")
    f:RegisterEvent("UI_SCALE_CHANGED")
    f:RegisterEvent("DISPLAY_SIZE_CHANGED")
    f:SetScript("OnEvent", function()
        if grid and grid:IsShown() then BuildGrid() end
    end)
end

ns.Module(Start, Apply)
