local module = require("modules.module")
local config = { opt = "Hello!" }
local M = {}
M.config = config

local cursor_moved_group = vim.api.nvim_create_augroup("PDFCursorMoved", { clear = true })

local debounce_timer = nil
local debounce_interval = 500

local function escape_spaces(str)
    return str:gsub(" ", "\\ ")
end

M.setup = function(args)
    M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.hello = function()
    print(module.my_first_function(M.config.opt))
end

local function generate_pdf()
    local bufcontents =
        table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    local current_file = vim.api.nvim_buf_get_name(0)
    local temp_file = os.tmpname() .. ".md"
    local file = io.open(temp_file, "w")
    file:write(bufcontents)
    file:close()

    local output_file = string.gsub(current_file, ".md$", ".pdf")
    local check = io.open("/tmp/pdf-viewer/req.file", "r")
    temp_file = escape_spaces(temp_file)
    output_file = escape_spaces(output_file)

    local pandoc_cmd = table.concat({
        "pandoc",
        temp_file,
        "-o",
        output_file,
        "--pdf-engine=xelatex",
        "-V mainfont='DejaVuSansM Nerd Font'",
        "-V geometry:margin=1in",
        "-V documentclass=article",
        "-V papersize=A4",
        "-V urlcolor=blue",
        "-V linkcolor=blue",
    }, " ")

    vim.fn.jobstart(pandoc_cmd, {
        on_exit = function(_, _)
            os.remove(temp_file)
            if check then
                local content = check:read("*a")
                if string.find(content, "failback.pdf") then
                    vim.fn.jobstart(
                        "pdf-v " .. output_file .. " --reuse-window",
                        {
                            on_exit = function(_, _) end,
                        }
                    )
                else
                    vim.fn.jobstart("pdf-v --reload", {
                        on_exit = function(_, _) end,
                    })
                end
            end
        end,
    })
end

M.reset_debounce_timer = function()
    if debounce_timer then
        debounce_timer:stop()
    else
        debounce_timer = vim.loop.new_timer()
    end
    debounce_timer:start(debounce_interval, 0, vim.schedule_wrap(generate_pdf))
end

M.start_pdf_tracking = function()
    if debounce_timer then
        vim.api.nvim_out_write("PDF tracking is already running.\n")
        return
    end
    M.reset_debounce_timer()
    vim.cmd(
        'autocmd TextChanged,TextChangedI <buffer> lua require("md-pdf").reset_debounce_timer()'
    )
end

M.stop_pdf_tracking = function()
    if debounce_timer then
        debounce_timer:stop()
        debounce_timer:close()
        debounce_timer = nil
        vim.cmd("autocmd! TextChanged,TextChangedI <buffer>")
    end
    vim.api.nvim_out_write("PDF tracking stopped.\n")
end

M.jump_to_line = function()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local current_col = vim.api.nvim_win_get_cursor(0)[2]
    local line_text =
        vim.api.nvim_buf_get_lines(0, current_line - 1, current_line, false)[1]

    local words = {}
    for word in line_text:gmatch("%S+") do
        if not word:find("#") then
            word = word:gsub("%*", "")
            table.insert(words, word)
        end
    end

    local cursor_word_index = nil
    local char_count = 0
    for i, word in ipairs(words) do
        char_count = char_count + #word
        if current_col <= char_count then
            cursor_word_index = i
            break
        end
        if i < #words then
            char_count = char_count + 1
        end
    end

    if cursor_word_index == nil and current_col >= char_count then
        cursor_word_index = #words
    end

    local start_index, end_index
    if cursor_word_index == 1 then
        start_index = 1
        end_index = math.min(#words, 3)
    elseif cursor_word_index == #words then
        start_index = math.max(1, cursor_word_index - 2)
        end_index = cursor_word_index
    else
        start_index = math.max(1, cursor_word_index - 1)
        end_index = math.min(#words, cursor_word_index + 1)
    end

    local selected_text = table.concat(words, " ", start_index, end_index)

    print(selected_text)

    vim.fn.jobstart("pdf-v /placeholder --jump-to '" .. selected_text .. "'", {
        on_exit = function(_, _) end,
    })
end

M.enable_cursor_moved = function()
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = cursor_moved_group,
        pattern = "*.md",
        callback = function()
            M.jump_to_line()
        end,
    })
    vim.api.nvim_out_write("CursorMoved event tracking enabled.\n")
end

M.disable_cursor_moved = function()
    vim.api.nvim_del_augroup_by_name("PDFCursorMoved")
    vim.api.nvim_out_write("CursorMoved event tracking disabled.\n")
end

return M
