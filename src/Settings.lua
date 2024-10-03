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
            type = "description",
            text = "Mail-sending will automatically trigger upon log in, or if you use |c99FF99/sendtrash|r. To send all trash regardless of minimum number of attachment thresholds, |c99FF99/sendalltrash|r. To delete empty TrashMailer mails, |c99FF99/cleantrashmails|r",
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
            type = "checkbox",
            name = "Auto delete after Take All",
            tooltip = "After you use Take All (Player), try to automatically delete any empty TrashMailer mails and any completely empty mails (no subject, body, or attachments). You can also trigger this with the command |c99FF99/cleantrashmails|r",
            default = false,
            getFunc = function() return TM.savedOptions.autoDelete end,
            setFunc = function(value)
                TM.savedOptions.autoDelete = value
                TM.InitializeReceivedMailHandler()
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
                {
                    type = "editbox",
                    name = "Recipes",
                    width = "full",
                    tooltip = "The @name or character name to send recipes to. These include provisioning recipes and furnishing plans",
                    getFunc = function() return TM.savedOptions.recipes.to end,
                    setFunc = function(name)
                        UpdateRecipient("recipes", name)
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
                    type = "description",
                    text = "Sending all crafting materials is intended to help those without ESO+ manage their inventory more easily. Anything that fits under the crafting item filter would be sent to the specified name, ignoring the other categories below. The other categories together do not currently encompass every crafting item.",
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = "Send ALL crafting materials",
                    tooltip = "Use the ALL crafting materials mode, instead of specific categories",
                    default = false,
                    getFunc = function() return TM.savedOptions.sendAllCraftingMats end,
                    setFunc = function(value)
                        TM.savedOptions.sendAllCraftingMats = value
                    end,
                    width = "full",
                },
                {
                    type = "editbox",
                    name = "ALL crafting materials",
                    width = "full",
                    tooltip = "The @name or character name to send ALL crafting materials to. This means anything that fits in the crafting bag!",
                    getFunc = function() return TM.savedOptions.allcraftingmats.to end,
                    setFunc = function(name)
                        UpdateRecipient("allcraftingmats", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                    disabled = function() return not TM.savedOptions.sendAllCraftingMats end,
                },
                {
                    type = "divider",
                    width = "full",
                },
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
                    disabled = function() return TM.savedOptions.sendAllCraftingMats end,
                },
                {
                    type = "editbox",
                    name = "Mid-level materials",
                    width = "full",
                    tooltip = "The @name or character name to send mid-level materials to. These are materials like Void Cloth, Mahogany, etc. any of the 4 gear crafting types that are NOT either level 1 or CP 160. This is mainly intended to aid in non-ESO+ inventory management, keeping the low and high level materials for daily writs",
                    getFunc = function() return TM.savedOptions.midlevelmats.to end,
                    setFunc = function(name)
                        UpdateRecipient("midlevelmats", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                    disabled = function() return TM.savedOptions.sendAllCraftingMats end,
                },
                {
                    type = "editbox",
                    name = "Furnishing materials",
                    width = "full",
                    tooltip = "The @name or character name to send furnishing materials to. This includes Heartwood, Mundane Runes, etc. but ALSO Dwarven Construct Repair Parts!",
                    getFunc = function() return TM.savedOptions.furnishingmats.to end,
                    setFunc = function(name)
                        UpdateRecipient("furnishingmats", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                    disabled = function() return TM.savedOptions.sendAllCraftingMats end,
                },
                {
                    type = "editbox",
                    name = "Trait materials",
                    width = "full",
                    tooltip = "The @name or character name to send trait materials to. This includes armor, weapon, and jewelry trait materials, but ALSO Nirncrux!",
                    getFunc = function() return TM.savedOptions.traitmats.to end,
                    setFunc = function(name)
                        UpdateRecipient("traitmats", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                    disabled = function() return TM.savedOptions.sendAllCraftingMats end,
                },
                {
                    type = "editbox",
                    name = "Provisioning materials",
                    width = "full",
                    tooltip = "The @name or character name to send provisioning materials to. This includes food and drink ingredients, but ALSO Perfect Roe and Aetherial Dust!",
                    getFunc = function() return TM.savedOptions.provisioningmats.to end,
                    setFunc = function(name)
                        UpdateRecipient("provisioningmats", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                    disabled = function() return TM.savedOptions.sendAllCraftingMats end,
                },
                {
                    type = "editbox",
                    name = "Alchemy materials",
                    width = "full",
                    tooltip = "The @name or character name to send alchemy materials to. This includes potion and poison ingredients, and ALSO Dragon Rheum!",
                    getFunc = function() return TM.savedOptions.alchemymats.to end,
                    setFunc = function(name)
                        UpdateRecipient("alchemymats", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                    disabled = function() return TM.savedOptions.sendAllCraftingMats end,
                },
                {
                    type = "editbox",
                    name = "Enchanting materials",
                    width = "full",
                    tooltip = "The @name or character name to send enchanting materials to. This includes Aspect, Essence, and Potency runestones",
                    getFunc = function() return TM.savedOptions.enchantingmats.to end,
                    setFunc = function(name)
                        UpdateRecipient("enchantingmats", name)
                    end,
                    isMultiline = false,
                    isExtraWide = false,
                    disabled = function() return TM.savedOptions.sendAllCraftingMats end,
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
