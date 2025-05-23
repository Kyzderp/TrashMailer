TrashMailer = TrashMailer or {}
local TM = TrashMailer

--[[
* GetMailAttachmentInfo(*id64* _mailId_)
** _Returns:_ *integer* _numAttachments_, *integer* _attachedMoney_, *integer* _codAmount_

* ReadMail(*id64* _mailId_)
** _Returns:_ *string* _body_

* DeleteMail(*id64* _mailId_)

* GetNextMailId(*id64:nilable* _lastMailId_)
** _Returns:_ *id64:nilable* _nextMailId_

* RequestReadMail(*id64* _mailId_)
** _Returns:_ *[RequestReadMailResult|#RequestReadMailResult]* _result_

h5. RequestReadMailResult
* REQUEST_READ_MAIL_RESULT_ALREADY_REQUESTED
* REQUEST_READ_MAIL_RESULT_ANOTHER_REQUEST_PENDING
* REQUEST_READ_MAIL_RESULT_NOT_IN_MAIL_INTERACTION
* REQUEST_READ_MAIL_RESULT_NO_SUCH_MAIL
* REQUEST_READ_MAIL_RESULT_SUCCESS_CACHED
* REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED

* IsReadMailInfoReady(*id64* _mailId_)
** _Returns:_ *bool* _isReady_

* EVENT_MAIL_READABLE (*id64* _mailId_)

* GetNumMailItemsByCategory(*[MailCategory|#MailCategory]* _category_)
** _Returns:_ *integer* _numMail_

* GetMailIdByIndex(*[MailCategory|#MailCategory]* _category_, *luaindex* _index_)
** _Returns:_ *id64* _mailId_

h5. MailCategory
* MAIL_CATEGORY_INFO_ONLY_SYSTEM_MAIL
* MAIL_CATEGORY_PLAYER_MAIL
* MAIL_CATEGORY_SYSTEM_MAIL
]]

local function StartsWith(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

local mailsToCheck = {}

local function GetMailsToCheck()
    mailsToCheck = {}
    local numMails = GetNumMailItemsByCategory(MAIL_CATEGORY_PLAYER_MAIL)
    for i = 1, numMails do
        local mailId = GetMailIdByIndex(MAIL_CATEGORY_PLAYER_MAIL, i)
        table.insert(mailsToCheck, mailId)
    end

    d("Found " .. #mailsToCheck .. " player mails to check")
end

local function GetNextMailToCheck()
    if (#mailsToCheck < 1) then
        return nil
    end

    return table.remove(mailsToCheck)
end

local noSuchMailRetries = 0
local hadNoSuchMailError = false
local function MaybeFinishScanningMails()
    -- Retry the whole thing twice if there were any "no such mail" errors
    if (hadNoSuchMailError and noSuchMailRetries < 2) then
        d("There were errors reading mail, retrying...")
        noSuchMailRetries = noSuchMailRetries + 1
        hadNoSuchMailError = false
        GetMailsToCheck()
        TM.TryDeleteMail(GetNextMailToCheck())
    else
        d("Finished scanning mails")
    end
end

local function OnMailReadable(_, mailId)
    -- Only read this mail
    EVENT_MANAGER:UnregisterForEvent(TM.name .. "Readable", EVENT_MAIL_READABLE, OnMailReadable)

    local _, _, subject = GetMailItemInfo(mailId)
    local body = ReadMail(mailId)
    local deleted = false
    if (StartsWith(body, "auto sent via " .. TM.name)
        or (body == "" and subject == "")) then
        if (GetMailAttachmentInfo(mailId) == 0) then
            d("Deleting " .. subject)
            DeleteMail(mailId)
            deleted = true
        else
            d(subject .. " still has items")
        end
    else
        d(subject .. " is not from trash mailer")
    end

    local next = GetNextMailToCheck()
    if (not next) then
        MaybeFinishScanningMails()
        return
    end

    -- It should be fine to go fast when not deleting? IDK
    if (deleted) then
        zo_callLater(function() TM.TryDeleteMail(next) end, 200)
    else
        TM.TryDeleteMail(next)
    end
end

local mailResults = {
    [REQUEST_READ_MAIL_RESULT_ALREADY_REQUESTED] = "ALREADY_REQUESTED",
    [REQUEST_READ_MAIL_RESULT_ANOTHER_REQUEST_PENDING] = "ANOTHER_REQUEST_PENDING",
    [REQUEST_READ_MAIL_RESULT_NOT_IN_MAIL_INTERACTION] = "NOT_IN_MAIL_INTERACTION",
    [REQUEST_READ_MAIL_RESULT_NO_SUCH_MAIL] = "NO_SUCH_MAIL",
    [REQUEST_READ_MAIL_RESULT_SUCCESS_CACHED] = "SUCCESS_CACHED",
    [REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED] = "SUCCESS_SERVER_REQUESTED",
}

-- Request reading the mail, then listen for the mail readable event
local retries = 0
local function TryDeleteMail(mailId)
    local result = RequestReadMail(mailId)
    if (result == REQUEST_READ_MAIL_RESULT_SUCCESS_CACHED or result == REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED) then
        EVENT_MANAGER:RegisterForEvent(TM.name .. "Readable", EVENT_MAIL_READABLE, OnMailReadable)
    elseif (result == REQUEST_READ_MAIL_RESULT_NO_SUCH_MAIL) then
        hadNoSuchMailError = true
        -- Not sure why this happens
        d("can't read mail (" .. mailResults[result] .. "), skipping")
        local next = GetNextMailToCheck()
        if (not next) then
            MaybeFinishScanningMails()
            return
        end
        TryDeleteMail(next)
    else
        if (retries > 5) then
            d("too many retries")
            return
        end
        retries = retries + 1
        d("can't read mail (" .. mailResults[result] .. "), trying again " .. tostring(retries))
        zo_callLater(function() TryDeleteMail(mailId) end, 500)
    end
end
TM.TryDeleteMail = TryDeleteMail

function TM.DeleteTrashMails()
    retries = 0
    noSuchMailRetries = 0
    hadNoSuchMailError = false
    d("Attempting to delete empty TrashMailer mails")
    CloseMailbox()
    RequestOpenMailbox()

    GetMailsToCheck()
    TryDeleteMail(GetNextMailToCheck())
end

-- * EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE (*[MailTakeAttachmentResult|#MailTakeAttachmentResult]* _result_, *[MailCategory|#MailCategory]* _category_, *bool* _headersRemoved_)
local function OnMailTakeAll(_, result, category)
    if (category ~= MAIL_CATEGORY_PLAYER_MAIL) then return end
    if (result == MAIL_TAKE_ATTACHMENT_RESULT_SUCCESS or result == MAIL_TAKE_ATTACHMENT_RESULT_FAIL_NOTHING_TO_CLAIM) then
        TM.DeleteTrashMails()
    end
end

function TM.InitializeReceivedMailHandler()
    EVENT_MANAGER:UnregisterForEvent(TM.name .. "TakeAll", EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, OnMailTakeAll)

    if (TM.savedOptions.autoDelete) then
        EVENT_MANAGER:RegisterForEvent(TM.name .. "TakeAll", EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE, OnMailTakeAll)
    end
end

