-------------------------------------------------------------------------------
-- TidyMap - Other addons' minimap buttons (the ones made with LibDBIcon)
--
-- Only LibDBIcon's own functions, never their frames:
--   · into the addon menu: AddButtonToCompartment + Hide (Blizzard's addon
--     menu on the map collects them)
--   · flat look: RemoveButtonBorder / RemoveButtonBackground
--   · Clean mode: ShowOnEnter (they show with the mouse over the map)
--   · Lock icons: Lock / Unlock
-- Whatever TidyMap changed is undone when it is turned off or unchecked.
-------------------------------------------------------------------------------

local _, ns = ...

local function On() return ns.P and ns.P.enabled end
local function DBI() return LibStub("LibDBIcon-1.0", true) end

-- what TidyMap changed, per button name (to undo only that)
local inMenu, flat, hover = {}, {}, {}

-- the buttons TidyMap locked: kept across sessions (LibDBIcon saves the lock
-- in that addon's settings, so it would look like the addon's own)
local function Locked()
    ns.db.lockedButtons = ns.db.lockedButtons or {}
    return ns.db.lockedButtons
end

-- Addons already in the addon menu on their own (AddonCompartmentFunc in
-- their TOC; the button carries the addon's name): adding the button too
-- would list them twice, so only the map button is hidden
local function HasOwnEntry(name)
    if not C_AddOns.DoesAddOnExist(name) then return false end
    local func = C_AddOns.GetAddOnMetadata(name, "AddonCompartmentFunc")
    return func ~= nil and func ~= ""
end

local function ApplyButton(dbi, name)
    if not dbi:GetMinimapButton(name) then return end
    local on = On()
    local P = ns.P.buttons

    if on and P.menu[name] and HasOwnEntry(name) then
        dbi:Hide(name)
        inMenu[name] = "own"
    elseif on and P.menu[name] and dbi.AddButtonToCompartment then
        dbi:AddButtonToCompartment(name)
        dbi:Hide(name)
        inMenu[name] = true
    elseif inMenu[name] then
        if inMenu[name] == true then dbi:RemoveButtonFromCompartment(name) end
        dbi:Refresh(name)   -- shown again, unless its addon hides it
        inMenu[name] = nil
    end

    -- (older LibDBIcon copies, before about v55, have no border functions)
    if dbi.RemoveButtonBorder then
        if on and P.flat then
            dbi:RemoveButtonBorder(name)
            dbi:RemoveButtonBackground(name)
            flat[name] = true
        elseif flat[name] then
            dbi:ResetButtonBorder(name)
            dbi:ResetButtonBackground(name)
            flat[name] = nil
        end
    end

    -- Lock icons: TidyMap locks only the ones not locked already (by their
    -- addon), and unlocks only the ones it locked
    if dbi.Lock then
        local b, mine = dbi:GetMinimapButton(name), Locked()
        if on and ns.P.locked then
            if not mine[name] and not (b.db and b.db.lock) then
                dbi:Lock(name)
                mine[name] = true
            end
        elseif mine[name] then
            dbi:Unlock(name)
            mine[name] = nil
        end
    end

    if on and ns.P.clean then
        dbi:ShowOnEnter(name, true)
        hover[name] = true
    elseif hover[name] then
        dbi:ShowOnEnter(name, false)
        hover[name] = nil
    end
end

local function Apply()
    local dbi = DBI()
    if not dbi then return end
    for _, name in ipairs(dbi:GetButtonList()) do ApplyButton(dbi, name) end
end

-- The buttons on the map now, sorted: { name, icon }
function ns.AddonButtons()
    local dbi, out = DBI(), {}
    if not dbi then return out end
    for _, name in ipairs(dbi:GetButtonList()) do
        local b = dbi:GetMinimapButton(name)
        out[#out + 1] = { name = name, icon = b and b.dataObject and b.dataObject.icon }
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

function ns.HasAddonButtons() return DBI() ~= nil end

-- The running LibDBIcon can remove the round border (newer copies)
function ns.CanFlattenButtons()
    local dbi = DBI()
    return dbi and dbi.RemoveButtonBorder and true or false
end

-- New buttons (addons that load later) get the same treatment
local listening = false
local function Listen()
    local dbi = DBI()
    if listening or not dbi then return end
    listening = true
    dbi.RegisterCallback(ns, "LibDBIcon_IconCreated", function(_, _, name)
        ApplyButton(dbi, name)
    end)
end

local function Start()
    Listen()
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self)
        if listening then
            self:UnregisterEvent("ADDON_LOADED")
            return
        end
        Listen()
        Apply()
    end)
end

ns.Module(Start, Apply)
