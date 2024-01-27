local live_preview = require("live-preview")

local function escape_spaces(str)
    return str:gsub(" ", "\\ ")
end

local function is_markdown()
    return vim.bo.filetype == "markdown"
end

local function open_pdf(output_file)
    vim.fn.jobstart("pdf-v " .. output_file .. " --reuse-window", {
        on_exit = function(_, _) end,
    })
end

vim.api.nvim_create_user_command("PDFTrackingStart", function()
    if is_markdown() then
        live_preview.start_pdf_tracking()
        live_preview.enable_cursor_moved()
    end
end, {})
vim.api.nvim_create_user_command("PDFTrackingStop", function()
    if is_markdown() then
        live_preview.stop_pdf_tracking()
        live_preview.disable_cursor_moved()
    end
end, {})

vim.api.nvim_create_user_command("PDFOpenFile", function()
    if is_markdown() then
        local raw_file = vim.api.nvim_buf_get_name(0)
        local output_file = string.gsub(raw_file, ".md$", ".pdf")
        output_file = escape_spaces(output_file)
        open_pdf(output_file)
    end
end, {})
