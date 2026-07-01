local M = {}

local function is_explicit_status(status)
    return status == "reading" or status == "complete" or status == "abandoned"
end

function M.isNewStatus(status, percent_finished)
    return percent_finished == nil and not is_explicit_status(status)
end

function M.getEffectiveStatus(status, percent_finished)
    if is_explicit_status(status) then
        return status
    end
    if M.isNewStatus(status, percent_finished) then
        return "new"
    end
    return "reading"
end

-- True when the "Mark new and updated books as TBR" library setting is enabled.
function M.isAutoTBREnabled()
    local ok, ConfigManager = pcall(require, "config/manager")
    if not ok then return false end
    local cfg = ConfigManager.get()
    return cfg and cfg.group_view
        and cfg.group_view.mark_new_as_tbr == true
end

local IMAGE_EXTS = {
    jpg = true, jpeg = true, png = true, gif = true, bmp = true,
    tiff = true, tif = true, webp = true, svg = true, ico = true,
    heic = true, heif = true, avif = true,
}

local AUTO_TBR_MTIME_KEY = "zen_auto_tbr_mtime"

-- True for image files, which should never be auto-marked as To Be Read.
function M.isImageFile(file_path)
    if not file_path then return false end
    local ext = file_path:match("^.+%.([^%.]+)$")
    if not ext then return false end
    return IMAGE_EXTS[ext:lower()] == true
end

local function saveAutoTBRMtime(doc_settings, modification, flush)
    if modification == nil then return end
    doc_settings:saveSetting(AUTO_TBR_MTIME_KEY, modification)
    if flush and type(doc_settings.flush) == "function" then
        pcall(doc_settings.flush, doc_settings)
    end
end

local function getSidecarMtime(DocSettings, file_path, lfs)
    if type(DocSettings.findSidecarFile) ~= "function" then return nil end
    local ok, sidecar_file = pcall(DocSettings.findSidecarFile, DocSettings, file_path)
    if not ok or not sidecar_file then return nil end
    return lfs.attributes(sidecar_file, "modification")
end

function M.autoMarkNewBookAsTBR(file_path, status, percent_finished, doc_settings)
    if not file_path
            or status == "abandoned"
            or M.isImageFile(file_path)
            or not M.isAutoTBREnabled() then
        return status
    end

    local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")
    if not ok_lfs then return status end
    local attr = lfs.attributes(file_path)
    if not attr or attr.mode ~= "file" then return status end
    local current_mtime = attr.modification

    local ok_ds, DocSettings = pcall(require, "docsettings")
    if not ok_ds or not DocSettings then return status end
    if not doc_settings then
        local ok_doc, doc = pcall(DocSettings.open, DocSettings, file_path)
        if not ok_doc then return status end
        doc_settings = doc
    end

    local summary = doc_settings:readSetting("summary") or {}
    local stored_status = summary.status
    local stored_percent = doc_settings:readSetting("percent_finished")
    local current_status = stored_status ~= nil and stored_status or status
    local current_percent = stored_percent ~= nil and stored_percent or percent_finished
    local stored_mtime = tonumber(doc_settings:readSetting(AUTO_TBR_MTIME_KEY))
    local is_new = M.isNewStatus(current_status, current_percent)
    local is_updated = stored_mtime ~= nil
        and current_mtime ~= nil
        and current_mtime ~= stored_mtime
    if not is_updated and stored_mtime == nil and not is_new and current_mtime ~= nil then
        local sidecar_mtime = getSidecarMtime(DocSettings, file_path, lfs)
        is_updated = sidecar_mtime ~= nil and current_mtime > sidecar_mtime
    end

    if stored_status == "abandoned" then return stored_status end
    if not is_new and not is_updated then
        if stored_mtime == nil then
            saveAutoTBRMtime(doc_settings, current_mtime, true)
        end
        return current_status
    end

    summary.status = "abandoned"
    saveAutoTBRMtime(doc_settings, current_mtime, false)
    require("apps/filemanager/filemanagerutil").saveSummary(doc_settings, summary)
    require("ui/widget/booklist").setBookInfoCacheProperty(
        file_path, "status", "abandoned"
    )
    return "abandoned"
end

function M.getEffectiveStatusFromInfo(book_info)
    if type(book_info) ~= "table" then
        return "new"
    end
    return M.getEffectiveStatus(book_info.status, book_info.percent_finished)
end

function M.getEffectiveStatusFromFile(file_path)
    local ok_bl, BookList = pcall(require, "ui/widget/booklist")
    if not ok_bl or type(BookList) ~= "table" or type(BookList.getBookInfo) ~= "function" then
        return "new"
    end
    local book_info = BookList.getBookInfo(file_path)
    if book_info
            and book_info.status == "reading"
            and book_info.percent_finished == nil then
        local ok_ds, DocSettings = pcall(require, "docsettings")
        if ok_ds and DocSettings and DocSettings:hasSidecarFile(file_path) then
            local ok_doc, doc = pcall(DocSettings.open, DocSettings, file_path)
            if ok_doc and doc then
                local summary = doc:readSetting("summary")
                return M.getEffectiveStatus(
                    summary and summary.status,
                    doc:readSetting("percent_finished")
                )
            end
        end
    end
    return M.getEffectiveStatusFromInfo(book_info)
end

return M
