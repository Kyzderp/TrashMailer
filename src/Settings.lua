TrashMailer = TrashMailer or {}
local TM = TrashMailer

function TM.CreateSettingsMenu()
    local LAM = LibAddonMenu2
    local panelData = {
        type = "panel",
        name = TM.name,
        displayName = "|c3bdb5eTrashMailer|r",
        author = "Kyzeragon",
        version = TM.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            text = "One man's trash is another man's treasure.",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Combine same recipient",
            tooltip = "If the recipient is the same for multiple trash types, combine them into the same mails instead of sending separate mails",
            default = true,
            getFunc = function() return not TM.savedOptions.mailTypesSeparately end,
            setFunc = function(value)
                TM.savedOptions.mailTypesSeparately = not value
            end,
            width = "full",
        },
        {
            type = "editbox",
            name = "Intricates - blacksmithing",
            width = "full",
            tooltip = "The @name or character name to send intricate blacksmithing items to",
            getFunc = function() return TM.savedOptions.blacksmithing.to end,
            setFunc = function(name)
                name = string.gsub(name, "^%s+", "")
                name = string.gsub(name, "%s+$", "")
                TM.savedOptions.blacksmithing.to = name
            end,
            isMultiline = false,
            isExtraWide = false,
        },
        {
            type = "editbox",
            name = "Intricates - clothing",
            width = "full",
            tooltip = "The @name or character name to send intricate clothing items to",
            getFunc = function() return TM.savedOptions.clothing.to end,
            setFunc = function(name)
                name = string.gsub(name, "^%s+", "")
                name = string.gsub(name, "%s+$", "")
                TM.savedOptions.clothing.to = name
            end,
            isMultiline = false,
            isExtraWide = false,
        },
        {
            type = "editbox",
            name = "Intricates - woodworking",
            width = "full",
            tooltip = "The @name or character name to send intricate woodworking items to",
            getFunc = function() return TM.savedOptions.woodworking.to end,
            setFunc = function(name)
                name = string.gsub(name, "^%s+", "")
                name = string.gsub(name, "%s+$", "")
                TM.savedOptions.woodworking.to = name
            end,
            isMultiline = false,
            isExtraWide = false,
        },
        {
            type = "editbox",
            name = "Intricates - jewelrycrafting",
            width = "full",
            tooltip = "The @name or character name to send intricate jewelry to",
            getFunc = function() return TM.savedOptions.jewelrycrafting.to end,
            setFunc = function(name)
                name = string.gsub(name, "^%s+", "")
                name = string.gsub(name, "%s+$", "")
                TM.savedOptions.jewelrycrafting.to = name
            end,
            isMultiline = false,
            isExtraWide = false,
        },
        {
            type = "editbox",
            name = "Non-crafted glyphs",
            width = "full",
            tooltip = "The @name or character name to send non-crafted glyphs to",
            getFunc = function() return TM.savedOptions.enchanting.to end,
            setFunc = function(name)
                name = string.gsub(name, "^%s+", "")
                name = string.gsub(name, "%s+$", "")
                TM.savedOptions.enchanting.to = name
            end,
            isMultiline = false,
            isExtraWide = false,
        },
        {
            type = "editbox",
            name = "Treasure maps (pre-Greymoor)",
            width = "full",
            tooltip = "The @name or character name to send treasure maps to. Pre-Greymoor but DLC treasure maps do not drop leads. Base-game treasure maps only drop Ancestral Nord, Ancestral Orc, and Ancestral High Elf styles. Post-Greymoor treasure maps (which are not included to send as trash) drop the currently more expensive Ancestral motifs.",
            getFunc = function() return TM.savedOptions.maps.to end,
            setFunc = function(name)
                name = string.gsub(name, "^%s+", "")
                name = string.gsub(name, "%s+$", "")
                TM.savedOptions.maps.to = name
            end,
            isMultiline = false,
            isExtraWide = false,
        },
        {
            type = "editbox",
            name = "Base-game paintings",
            width = "full",
            tooltip = "The @name or character name to send base-game paintings to. These are the Sturdy or Bolted paintings found in treasure chests",
            getFunc = function() return TM.savedOptions.paintings.to end,
            setFunc = function(name)
                name = string.gsub(name, "^%s+", "")
                name = string.gsub(name, "%s+$", "")
                TM.savedOptions.paintings.to = name
            end,
            isMultiline = false,
            isExtraWide = false,
        },
    }

    TM.addonPanel = LAM:RegisterAddonPanel("TrashMailerOptions", panelData)
    LAM:RegisterOptionControls("TrashMailerOptions", optionsData)
end
