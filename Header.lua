-------------------------------------------------------------------------------
-- TidyMap - The header: TidyMap's own zone name, clock and coordinates
--
-- Its own frames, so they can sit anywhere around the map without moving
-- Blizzard's. Blizzard still does the work: the zone text and its PvP color
-- come from Blizzard's own Minimap_Update (hooked), the time from
-- GameTime_GetTime (local or realm time, 12 / 24 h, as set in Blizzard's
-- clock), and a click on the clock does what Blizzard's clock does.
-------------------------------------------------------------------------------

local _, ns = ...
local Flaty = LibStub("LibFlatyUI-1.0")

local FLAT = "Interface\\Buttons\\WHITE8X8"
local GAP = 3     -- between the map and a piece, and between two pieces
local PAD_X, PAD_Y = 8, 3

local function On() return ns.P and ns.P.enabled and ns.P.header.on end

-------------------------------------------------------------------------------
-- Background: none, flat (the map's corner shape) or pill (round ends).
-- Two layers: the border (the map's border color) and the plate.
-------------------------------------------------------------------------------
local function Layer(f, sub)
    return {
        l = f:CreateTexture(nil, "BACKGROUND", nil, sub),
        c = f:CreateTexture(nil, "BACKGROUND", nil, sub),
        r = f:CreateTexture(nil, "BACKGROUND", nil, sub),
    }
end

-- one layer of w x h, centered on the frame
local function PaintLayer(L, f, kind, w, h, color, corners)
    if not color or kind == "none" then
        L.l:Hide() L.c:Hide() L.r:Hide()
        return
    end
    for _, t in pairs(L) do t:SetVertexColor(color[1], color[2], color[3], color[4]) end
    L.c:ClearAllPoints()
    if kind == "pill" then
        -- half circles at both ends, a plain middle
        local round = Flaty.GetShape("r100").mask
        local cap = h / 2
        L.l:SetTexture(round) L.l:SetTexCoord(0, 0.5, 0, 1)
        L.r:SetTexture(round) L.r:SetTexCoord(0.5, 1, 0, 1)
        L.c:SetTexture(FLAT) L.c:SetTexCoord(0, 1, 0, 1)
        L.c:SetSize(math.max(0, w - 2 * cap), h)
        L.c:SetPoint("CENTER", f, "CENTER")
        L.l:SetSize(cap, h) L.l:ClearAllPoints() L.l:SetPoint("RIGHT", L.c, "LEFT")
        L.r:SetSize(cap, h) L.r:ClearAllPoints() L.r:SetPoint("LEFT", L.c, "RIGHT")
        L.l:Show() L.c:Show() L.r:Show()
    else
        L.c:SetTexture(Flaty.GetShape(Flaty.Rounded(corners or ns.P.corners)).mask)
        L.c:SetTexCoord(0, 1, 0, 1)
        L.c:SetSize(w, h)
        L.c:SetPoint("CENTER", f, "CENTER")
        L.l:Hide() L.r:Hide()
        L.c:Show()
    end
end

-------------------------------------------------------------------------------
-- The two pieces
-------------------------------------------------------------------------------
local function NewPiece(key)
    local f = CreateFrame("Button", nil, Minimap)
    f:SetFrameLevel(Minimap:GetFrameLevel() + 10)
    f.key = key
    f.edge = Layer(f, -8)
    f.plate = Layer(f, -7)
    -- a font from the start: text can arrive before the first apply
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("CENTER")
    f:Hide()
    return f
end

local zone, clock, coords = NewPiece("zone"), NewPiece("clock"), NewPiece("coords")
local pieces = { zone, clock, coords }   -- also the order they stack in

-- zone and coordinates: not clickable, so clicks reach the map (pings)
zone:EnableMouse(false)
coords:EnableMouse(false)

-- the clock: Blizzard's own click (its clock settings, or stop the alarm)
-- and tooltip (local and realm time)
clock:RegisterForClicks("LeftButtonUp")
clock:SetScript("OnClick", function()
    if TimeManagerClockButton and TimeManagerClockButton_OnClick then
        TimeManagerClockButton_OnClick(TimeManagerClockButton)
    end
end)
clock:SetScript("OnEnter", function(self)
    if not GameTime_UpdateTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTime_UpdateTooltip()
    GameTooltip:Show()
end)
clock:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function Cfg(f) return ns.P.header[f.key] end
local function Mode(f) return ns.EffectiveMode(Cfg(f).mode) end

for _, f in ipairs(pieces) do
    ns.faders[#ns.faders + 1] = { frame = f, mode = function() return On() and Mode(f) or "hide" end }
end

local function UpdateZoneText()
    zone.text:SetText(MinimapZoneText and MinimapZoneText:GetText() or GetMinimapZoneText())
    local c = Cfg(zone)
    if c.pvp and MinimapZoneText then
        zone.text:SetTextColor(MinimapZoneText:GetTextColor())
    else
        zone.text:SetTextColor(c.color.r, c.color.g, c.color.b, c.color.a or 1)
    end
end

-- Where the player is on the zone's map, with 0-2 decimals. Empty where the
-- game does not tell (instances).
local formats = {}
local function UpdateCoordsText()
    local c = Cfg(coords)
    local d = c.decimals or 1
    formats[d] = formats[d] or ("%%.%df, %%.%df"):format(d, d)
    local text = ""
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        local x, y = pos:GetXY()
        if x and y and (x > 0 or y > 0) then text = formats[d]:format(x * 100, y * 100) end
    end
    coords.text:SetText(text)
    coords.text:SetTextColor(c.color.r, c.color.g, c.color.b, c.color.a or 1)
end

local function UpdateClockText()
    if GameTime_GetTime then clock.text:SetText((GameTime_GetTime(true))) end
    local c = Cfg(clock).color
    clock.text:SetTextColor(c.r, c.g, c.b, c.a or 1)
end

-- Size to the text, background, and the alpha / mouse of its mode
local function Paint(f)
    local t = ns.P.texts
    Flaty.SetFontFile(f.text, t.font, t[f.key], t.outline)
    local c = Cfg(f)
    local w = math.max(2, (f.text:GetStringWidth() or 0) + 2 * (PAD_X + c.pad))
    local h = math.max(2, (f.text:GetStringHeight() or 10) + 2 * (PAD_Y + c.pad))
    f:SetSize(w, h)
    -- no text (coordinates in an instance): no background either
    local kind = (f.text:GetText() or "") ~= "" and c.bg or "none"
    local bg = { c.bgColor.r, c.bgColor.g, c.bgColor.b, c.bgColor.a or 1 }
    local corners = ns.PlateCorners(c)
    PaintLayer(f.plate, f, kind, w, h, bg, corners)
    PaintLayer(f.edge, f, kind, w + 2 * c.edge, h + 2 * c.edge, ns.PlateEdgeColor(c), corners)

    local mode = Mode(f)
    if ns.IsEditing() then
        f:SetAlpha(mode == "hide" and 0.35 or 1)
    elseif mode == "show" then
        f:SetAlpha(1)
    elseif mode == "hover" then
        f:SetAlpha(ns.HoverAlpha())
    else
        f:SetAlpha(0)
    end
    if f == clock then f:EnableMouse(mode ~= "hide" or ns.IsEditing()) end
end

-- Top or bottom, outside or inside, plus the extra distance. Two pieces in
-- the same place stack: the second one further out (or further in).
local function Place(f, under)
    local c = Cfg(f)
    local top, out = c.place == "top", c.side == "outside"
    local d = GAP + c.offset
    f:ClearAllPoints()
    if under then
        if top == out then
            f:SetPoint("BOTTOM", under, "TOP", 0, GAP)
        else
            f:SetPoint("TOP", under, "BOTTOM", 0, -GAP)
        end
    elseif top then
        if out then f:SetPoint("BOTTOM", Minimap, "TOP", 0, d)
        else f:SetPoint("TOP", Minimap, "TOP", 0, -d) end
    else
        if out then f:SetPoint("TOP", Minimap, "BOTTOM", 0, -d)
        else f:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, d) end
    end
end

local function Apply()
    if not On() then
        for _, f in ipairs(pieces) do f:Hide() end
        return
    end
    UpdateZoneText()
    UpdateClockText()
    UpdateCoordsText()
    for _, f in ipairs(pieces) do
        f:Show()
        Paint(f)
    end
    -- each piece stacks on the last shown one in the same place
    for i, f in ipairs(pieces) do
        local c, under = Cfg(f), nil
        for j = i - 1, 1, -1 do
            local o = Cfg(pieces[j])
            if o.place == c.place and o.side == c.side and Mode(pieces[j]) ~= "hide" then
                under = pieces[j]
                break
            end
        end
        Place(f, under)
    end
end
ns.ApplyHeader = Apply

local function Start()
    if Minimap_Update then
        hooksecurefunc("Minimap_Update", function()
            if On() then
                UpdateZoneText()
                Paint(zone)
            end
        end)
    end
    -- the clock text, once a second (only while it shows)
    C_Timer.NewTicker(1, function()
        if On() and clock:IsShown() then
            local before = clock.text:GetText()
            UpdateClockText()
            if clock.text:GetText() ~= before then Paint(clock) end
        end
    end)
    -- the coordinates, ten times a second while they can be seen
    C_Timer.NewTicker(0.1, function()
        if On() and coords:IsShown() and coords:GetAlpha() > 0 then
            local before = coords.text:GetText()
            UpdateCoordsText()
            if coords.text:GetText() ~= before then Paint(coords) end
        end
    end)
end

ns.Module(Start, Apply)
