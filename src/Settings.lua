TrashMailer = TrashMailer or {}
local TM = TrashMailer

local selectedRecipient
local function GetAllRecipients()
    local unique = {}
    -- Multiple types can have the same recipient
    for type, _ in pairs(TM.nameToTitleAbbreviation) do
        local name = TM.savedOptions[type].to
        if (name and name ~= "") then
            unique[name] = true
        end
    end

    -- Return an indexed table
    local recipients = {}
    for name, _ in pairs(unique) do
        table.insert(recipients, name)
    end
    return recipients
end

-- When a recipient is changed, we also need to update mail title default if necessary
local function UpdateRecipient(type, name)
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    TM.savedOptions[type].to = name

    if (name and name ~= "") then
        if (not TM.savedOptions.mailTitles[name]) then
            TM.savedOptions.mailTitles[name] = "<<1>>"
        end
    end
end

---------------------------------------------------------------------
-- SETTINGS
---------------------------------------------------------------------
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
            type = "submenu",
            name = "Deconstruction Fodder",
            controls = {
                {
                    type = "description",
                    title = "Blacksmithing intricates",
                    text = nil,
                    width = "full",
                },
                {
                    type = "editbox",
                    name = "Recipient",
                    width = "full",
                    tooltip = "The @name or character name to send intricate blacksmithing items to",
                    getFunc = function() return TM.savedOptions.blacksmithing.to end,
                    setFunc = function(name)
                        UpdateRecipient("blacksmithing", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                },
                {
                    type = "slider",
                    name = "Minimum items",
                    tooltip = "The minimum number of intricate blacksmithing items before sending. If combining recipients, the lowest threshold of the item types will be used",
                    min = 1,
                    max = 6,
                    step = 1,
                    default = 4,
                    width = full,
                    getFunc = function() return TM.savedOptions.blacksmithing.threshold end,
                    setFunc = function(value)
                        TM.savedOptions.blacksmithing.threshold = value
                    end,
                },
                {
                    type = "editbox",
                    name = "Clothing intricates",
                    width = "full",
                    tooltip = "The @name or character name to send intricate clothing items to",
                    getFunc = function() return TM.savedOptions.clothing.to end,
                    setFunc = function(name)
                        UpdateRecipient("clothing", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                },
                {
                    type = "editbox",
                    name = "Woodworking intricates",
                    width = "full",
                    tooltip = "The @name or character name to send intricate woodworking items to",
                    getFunc = function() return TM.savedOptions.woodworking.to end,
                    setFunc = function(name)
                        UpdateRecipient("woodworking", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                },
                {
                    type = "editbox",
                    name = "Jewelrycrafting intricates",
                    width = "full",
                    tooltip = "The @name or character name to send intricate jewelry to",
                    getFunc = function() return TM.savedOptions.jewelrycrafting.to end,
                    setFunc = function(name)
                        UpdateRecipient("jewelrycrafting", name)
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
                        UpdateRecipient("enchanting", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                },
            },
        },
        {
            type = "submenu",
            name = "Looted Items",
            controls = {
                {
                    type = "editbox",
                    name = "Treasure maps (pre-Greymoor)",
                    width = "full",
                    tooltip = "The @name or character name to send treasure maps to. Pre-Greymoor but DLC treasure maps do not drop leads. Base-game treasure maps only drop Ancestral Nord, Ancestral Orc, and Ancestral High Elf styles. Post-Greymoor treasure maps (which are not included to send as trash) drop the currently more expensive Ancestral motifs.",
                    getFunc = function() return TM.savedOptions.maps.to end,
                    setFunc = function(name)
                        UpdateRecipient("maps", name)
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
                        UpdateRecipient("paintings", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                },
            },
        },
        {
            type = "submenu",
            name = "Crafting Materials",
            controls = {
                {
                    type = "editbox",
                    name = "Non-racial style materials",
                    width = "full",
                    tooltip = "The @name or character name to send non-racial style materials to",
                    getFunc = function() return TM.savedOptions.stylemats.to end,
                    setFunc = function(name)
                        UpdateRecipient("stylemats", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                },
            },
        },
        -- TODO: add TEST button
        {
            type = "submenu",
            name = "Mail Title",
            controls = {
                {
                    type = "dropdown",
                    name = "Select recipient",
                    tooltip = "Choose a recipient to edit",
                    choices = GetAllRecipients(),
                    getFunc = function()
                        return selectedRecipient
                    end,
                    setFunc = function(name)
                        d("selected " .. tostring(name))
                        selectedRecipient = name
                    end,
                    width = "full",
                    reference = "TrashMailer_RecipientDropdown"
                },
                {
                    type = "editbox",
                    name = "Mail title",
                    width = "full",
                    tooltip = "The mail title for this recipient. \"<<1>>\" will be replaced by the item types in the mail, e.g. \"Smith/Glyphs\"",
                    default = "<<1>>",
                    getFunc = function()
                        if (not selectedRecipient) then return "" end
                        return TM.savedOptions.mailTitles[selectedRecipient]
                    end,
                    setFunc = function(title)
                        title = string.gsub(title, "^%s+", "")
                        title = string.gsub(title, "%s+$", "")
                        TM.savedOptions.mailTitles[selectedRecipient] = title
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                    disabled = function() return selectedRecipient == null end,
                },
            },
        },
    }

    TM.addonPanel = LAM:RegisterAddonPanel("TrashMailerOptions", panelData)
    LAM:RegisterOptionControls("TrashMailerOptions", optionsData)
end
