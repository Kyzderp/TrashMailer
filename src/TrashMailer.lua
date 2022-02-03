TrashMailer = TrashMailer or {}
local TM = TrashMailer
TM.name = "TrashMailer"
TM.version = "0.0.0"

local defaultOptions = {
    mailTypesSeparately = false, -- If the recipient is the same. Also if not separate, then use minimum threshold
    onlySendDeconIfNotMaxed = true, -- If the current character isn't maxed for that crafting line, don't consider intricates trash
    checkOnLogin = true,
    blacksmithing = {
        to = "",
        threshold = 4,
    },
    clothing = {
        to = "",
        threshold = 4,
    },
    woodworking = {
        to = "",
        threshold = 4,
    },
    jewelrycrafting = {
        to = "",
        threshold = 4,
    },
    enchanting = {
        to = "",
        threshold = 4,
    },
    maps = {
        to = "",
        threshold = 4,
    },
    paintings = {
        to = "",
        threshold = 1,
    },
}

local tradeskillToName = {
    [CRAFTING_TYPE_BLACKSMITHING] = "blacksmithing",
    [CRAFTING_TYPE_CLOTHIER] = "clothing",
    [CRAFTING_TYPE_WOODWORKING] = "woodworking",
    [CRAFTING_TYPE_JEWELRYCRAFTING] = "jewelrycrafting",
}

local nameToTitleAbbreviation = {
    blacksmithing = "Smith",
    clothing = "Cloth",
    woodworking = "Wood",
    jewelrycrafting = "Jewel",
    enchanting = "Glyphs",
    maps = "Maps",
    paintings = "Paintings",
}

---------------------------------------------------------------------
-- Mail formatting
---------------------------------------------------------------------
local function GetMailTitle(trashTypes)
    local trashNames = {}
    for _, trashType in pairs(trashTypes) do
        table.insert(trashNames, nameToTitleAbbreviation[trashType])
    end
    return table.concat(trashNames, "/")
end

local function GetMailBody()
    return string.format("yeet\n\nauto sent via %s v%s by Kyzeragon\nexcuse any derps while I continue testing kthxbai",
        TM.name, TM.version)
end

---------------------------------------------------------------------
-- Mailer
---------------------------------------------------------------------
-- The items we still need to send
-- [1] = {trashTypes = {trashType}, recipient = options.to, items = items},
local mailQueue = {}

-- Cleanup
local function CloseTrashMailbox()
    if (not SCENE_MANAGER:IsShowing("mailInbox") and not SCENE_MANAGER:IsShowing("mailSend")) then
        CloseMailbox()
    end
end

-- On success, we should send the next mail in the queue
local function OnSendTrashSuccess()
    EVENT_MANAGER:UnregisterForEvent(TM.name .. "SendSuccess", EVENT_MAIL_SEND_SUCCESS)
    EVENT_MANAGER:UnregisterForEvent(TM.name .. "SendFail", EVENT_MAIL_SEND_FAILED)
    CloseTrashMailbox()

    zo_callLater(TM.SendTrashMail, 500)
end

-- On failure, stop sending
local function OnSendTrashFailed(_, result)
    d(GetString("SI_SENDMAILRESULT", result))
    EVENT_MANAGER:UnregisterForEvent(TM.name .. "SendSuccess", EVENT_MAIL_SEND_SUCCESS)
    EVENT_MANAGER:UnregisterForEvent(TM.name .. "SendFail", EVENT_MAIL_SEND_FAILED)
    CloseTrashMailbox()
end

-- Sends up to 6 items at a time to recipients
local function SendTrashMail()
    if (#mailQueue == 0) then
        d("Done sending mail.")
        return
    end

    CloseTrashMailbox()    
    RequestOpenMailbox()

    local mailData = mailQueue[1]

    local attachedItemsString = string.format("Items to send to %s:", mailData.recipient)
    for i = 1, MAIL_MAX_ATTACHED_ITEMS do
        local item = table.remove(mailData.items, 1)
        local itemLink = GetItemLink(item.bagId, item.slotIndex, LINK_STYLE_BRACKETS)
        attachedItemsString = string.format("%s %s", attachedItemsString, itemLink)

        QueueItemAttachment(item.bagId, item.slotIndex, i)

        -- Out of items, which also means should remove whole data from mail queue
        if (#mailData.items == 0) then
            table.remove(mailQueue, 1)
            break
        end
    end
    d(attachedItemsString)
    
    EVENT_MANAGER:RegisterForEvent(TM.name .. "SendSuccess", EVENT_MAIL_SEND_SUCCESS, OnSendTrashSuccess)
    EVENT_MANAGER:RegisterForEvent(TM.name .. "SendFail", EVENT_MAIL_SEND_FAILED, OnSendTrashFailed)

    SendMail(mailData.recipient, GetMailTitle(mailData.trashTypes), GetMailBody())

    CloseTrashMailbox()
end
TM.SendTrashMail = SendTrashMail

---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------
local function DumpMailQueue()
    for _, data in ipairs(mailQueue) do
        local mailString = "send to " .. data.recipient
        for i, item in pairs(data.items) do
            local itemLink = GetItemLink(item.bagId, item.slotIndex, LINK_STYLE_BRACKETS)
            mailString = string.format("%s (%d)%s", mailString, i, itemLink)
        end
        d(mailString)
    end
end
---------------------------------------------------------------------
-- Inventory checker
---------------------------------------------------------------------
local function CollectTrash()
    if (IsUnitInCombat("player")) then
        return
    end

    local foundTrash = {
        blacksmithing = {},
        clothing = {},
        woodworking = {},
        jewelrycrafting = {},
        enchanting = {},
        maps = {},
        paintings = {},
    }

    -- Collect the trash items into types
    local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
    for _, item in pairs(bagCache) do
        if (not IsItemBound(item.bagId, item.slotIndex)) then
            local itemLink = GetItemLink(item.bagId, item.slotIndex, LINK_STYLE_BRACKETS)
            local itemType, specializedType = GetItemLinkItemType(itemLink)

            -- Intricates
            if (GetItemTraitInformationFromItemLink(itemLink) == ITEM_TRAIT_INFORMATION_INTRICATE) then
                local tradeskillType = GetItemLinkCraftingSkillType(itemLink)
                if (TM.savedOptions.onlySendDeconIfNotMaxed) then
                    local skillType, skillId = GetCraftingSkillLineIndices(tradeskillType)
                    local _, level = GetSkillLineInfo(skillType, skillId)
                    if (level == 50) then
                        table.insert(foundTrash[tradeskillToName[tradeskillType]], {bagId = item.bagId, slotIndex = item.slotIndex})
                    end
                else
                    table.insert(foundTrash[tradeskillToName[tradeskillType]], {bagId = item.bagId, slotIndex = item.slotIndex})
                end

            -- Not crafted glyphs
            elseif (not IsItemLinkCrafted(itemLink)
                and (itemType == ITEMTYPE_GLYPH_ARMOR or itemType == ITEMTYPE_GLYPH_JEWELRY or itemType == ITEMTYPE_GLYPH_WEAPON)) then
                if (TM.savedOptions.onlySendDeconIfNotMaxed) then
                    local skillType, skillId = GetCraftingSkillLineIndices(CRAFTING_TYPE_ENCHANTING)
                    local _, level = GetSkillLineInfo(skillType, skillId)
                    if (level == 50) then
                        table.insert(foundTrash.enchanting, {bagId = item.bagId, slotIndex = item.slotIndex})
                    end
                else
                    table.insert(foundTrash.enchanting, {bagId = item.bagId, slotIndex = item.slotIndex})
                end

            -- Treasure maps pre-Greymoor
            elseif (itemType == ITEMTYPE_TROPHY and specializedType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP) then
                if (TM.TREASURE_MAPS[GetItemId(item.bagId, item.slotIndex)]) then
                    table.insert(foundTrash.maps, {bagId = item.bagId, slotIndex = item.slotIndex})
                end

            -- Paintings basegame only
            elseif (itemType == ITEMTYPE_FURNISHING) then
                if (TM.PAINTINGS[GetItemId(item.bagId, item.slotIndex)]) then
                    table.insert(foundTrash.paintings, {bagId = item.bagId, slotIndex = item.slotIndex})
                end
            end
        end
    end

    -- Debug
    -- d("foundTrash")
    -- for trashType, items in pairs(foundTrash) do
    --     local trashString = trashType
    --     for _, item in pairs(items) do
    --         local itemLink = GetItemLink(item.bagId, item.slotIndex, LINK_STYLE_BRACKETS)
    --         trashString = string.format("%s %s", trashString, itemLink)
    --     end
    --     d(trashString)
    -- end

    -- Translate the trash into mail queue
    mailQueue = {}
    for trashType, items in pairs(foundTrash) do
        local options = TM.savedOptions[trashType]
        if (#items > 0 and options.to ~= "") then
            table.insert(mailQueue, {trashTypes = {trashType}, recipient = options.to, items = items})
        end
    end

    -- Debug
    -- d("initial")
    -- DumpMailQueue()

    -- If not sending separately, compress into same-recipient queues
    if (not TM.savedOptions.mailTypesSeparately) then
        local uniqueMailQueue = {}
        for _, data in ipairs(mailQueue) do
            -- Existing recipient
            if (uniqueMailQueue[data.recipient]) then
                table.insert(uniqueMailQueue[data.recipient].trashTypes, data.trashTypes[1])
                -- Append items
                for i = 1, #data.items do
                    uniqueMailQueue[data.recipient].items[#uniqueMailQueue[data.recipient].items + 1] = data.items[i]
                end

            -- New recipient
            else
                uniqueMailQueue[data.recipient] = data
            end
        end

        -- Put back into mailQueue
        mailQueue = {}
        for _, data in pairs(uniqueMailQueue) do
            table.insert(mailQueue, data)
        end
    end

    -- Debug
    -- d("aftermerge")
    -- DumpMailQueue()

    -- Filter out any mails that don't have enough items
    local tempMailQueue = {}
    for _, data in ipairs(mailQueue) do
        local minThreshold = 50
        for _, trashType in ipairs(data.trashTypes) do
            local threshold = TM.savedOptions[trashType].threshold
            if (threshold < minThreshold) then
                minThreshold = threshold
            end
        end
        if (#data.items >= minThreshold) then
            table.insert(tempMailQueue, data)
        else
            d(string.format("only %d items to send to %s", #data.items, data.recipient))
        end
    end
    mailQueue = tempMailQueue

    -- Debug
    -- d("afterfilter")
    DumpMailQueue()
end
TM.CollectTrash = CollectTrash

---------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------
local function SendTrash()
    CollectTrash()
    SendTrashMail()
end

---------------------------------------------------------------------
-- Init
---------------------------------------------------------------------
-- Post-char load
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(TM.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED)

    -- Initial check
    if (TM.savedOptions.checkOnLogin) then
        zo_callLater(SendTrash, 5000)
    end
end

-- Pre-char load
local function Initialize()
    TM.savedOptions = ZO_SavedVars:NewAccountWide("TrashMailerSavedVariables", 1, "Options", defaultOptions)

    TM.CreateSettingsMenu()

    EVENT_MANAGER:RegisterForEvent(TM.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

-- Register
local function OnAddOnLoaded(_, addonName)
    if (addonName == TM.name) then
        EVENT_MANAGER:UnregisterForEvent(TM.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end
EVENT_MANAGER:RegisterForEvent(TM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

SLASH_COMMANDS["/sendtrash"] = SendTrash
