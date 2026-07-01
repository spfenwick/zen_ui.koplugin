local function apply_auto_tbr()
    local FileChooser = require("ui/widget/filechooser")
    if FileChooser._zen_auto_tbr_patched then return end
    FileChooser._zen_auto_tbr_patched = true

    local book_status = require("common/book_status")
    local orig_genItemTableFromPath = FileChooser.genItemTableFromPath

    local function mark_items(items)
        if not book_status.isAutoTBREnabled() or type(items) ~= "table" then return end
        for _i, item in ipairs(items) do
            if type(item) == "table" and item.is_file == true then
                local path = item.path or item.file or item.filepath
                if type(path) == "string" and path ~= "" then
                    local status = book_status.autoMarkNewBookAsTBR(path)
                    if status == "abandoned" then
                        item.status = status
                    end
                end
            end
        end
    end

    function FileChooser:genItemTableFromPath(path, ...)
        local items = orig_genItemTableFromPath(self, path, ...)
        if not self._dummy and self.name == "filemanager" then
            mark_items(items)
        end
        return items
    end
end

return apply_auto_tbr
