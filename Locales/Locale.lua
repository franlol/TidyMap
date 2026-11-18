-------------------------------------------------------------------------------
-- TidyMap - Translations
-- Keys are the English texts. L["Text"] is that text in the active language,
-- or the key itself (English) when there is no translation.
-------------------------------------------------------------------------------

local _, ns = ...

ns.translations = {}

local active

ns.L = setmetatable({}, {
    __index = function(_, key)
        return active and active[key] or key
    end,
})

-- "enUS" or "esES"; anything else is English
function ns.SetLanguage(lang)
    ns.language = ns.translations[lang] and lang or "enUS"
    active = ns.translations[lang]
end
