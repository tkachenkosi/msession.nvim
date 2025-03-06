local M = {}

vim.g.mm_windows = nil

-- Основной буфер и окно
local main_buf, main_win
-- Буфер и окно для ввода фильтра
local filter_buf, filter_win
-- Исходные строки (для фильтрации)
local original_lines = {}
-- для вычисления ширины окна
local max_len_buffer = 0
-- окно откуда был запуск и в котором нужно поменять содержимое
local session_name = "/.session"
-- домашняя директория
M.home_dir = ""

M.curr_session = "*"

M.config = {
	width_win = 0,												-- ширина окна, если = 0 вычисляется
	color_cursor_line = "#2b2b2b",				-- цвет подсветки строки с курсором
	color_cursor_mane_line = "#2b2b2b",		-- цвет подсветки строки в основном редакторе
	color_light_filter = "#194d19",				-- цвет строки ввода фильтра
	color_light_date = "#ada085",					-- цвет выделения даты из имени файла
	color_light_curr = "#f1b841",					-- цвет цвет номера для текущей сессии
}

-- проверяем что сессия существует
local function session_exists(file_path)
    return vim.fn.filereadable(file_path) == 1
end

-- Получение даты и времени модификации файла
local function get_file_modification_time(file_path)
		local session = vim.fn.expand(file_path .. session_name)

    if session_exists(session) then
        local stat = vim.loop.fs_stat(session)
        if stat then
            -- return os.date("%Y-%m-%d %H:%M:%S", stat.mtime.sec)
            return os.date("%Y-%m-%d", stat.mtime.sec)
        end
    end
    return nil
end

-- Функция для запроса подтверждения у пользователя
local function confirm_input(comfirm)
  return vim.fn.input(comfirm .. " (y)es: ") == "y"
end

-- укорачиватель путей заменой home на ~
local function short_path(comfirm)
	return string.gsub(comfirm, M.home_dir, "~", 1)
end

-- Функция для добавления строки в файл
function M.add_session_to_list()
	-- текущий коталог который нужно сохранить в list
	local root_dir = short_path(vim.fn.getcwd())
	local count = 0

	M.close()
	if not confirm_input("Save? "..root_dir) then
		return
	end

	vim.cmd("mks! .session")
	-- Путь к файлу
	local file_path = vim.fn.expand("~/.config/nvim" .. session_name)

	-- Открываем файл для чтения
	local file = io.open(file_path, "r")
	local lines = {}
	if file then
			-- Читаем все строки из файла
			for line in file:lines() do
					table.insert(lines, line)
					-- ограничение на количество записей
					count = count + 1
					if count > 50 then
						break
					end
			end
			file:close()
	end

	-- Проверяем, существует ли запись в списке
	local index = nil
	for i, line in ipairs(lines) do
			if line == root_dir then
					index = i
					break
			end
	end

	-- Если запись найдена, удаляем её из текущей позиции
	if index then
			table.remove(lines, index)
	end

	-- Добавляем новую запись в начало списка
	table.insert(lines, 1, root_dir)

	-- Открываем файл для записи
	file = io.open(file_path, "w")
	if file then
			-- Записываем обновлённый список в файл
			for _, line in ipairs(lines) do
					file:write(line.."\n")
			end
			file:close()
	else
			print("\nОшибка: не удалось открыть файл для записи.")
	end
	print("\nSave Ok. "..root_dir)
end

-- Функция для подсветки даты в имени сессии
local function highlight_in_filename(line, line_number)
    -- local last_slash_pos = line:find("/[^/]*$")
    local last_pos=line:match(".* ()") - 1
    if not last_pos then
        return
    end

    -- Добавляем подсветку с помощью vim.highlight
    vim.api.nvim_buf_add_highlight(main_buf, -1, "HighlightPath", line_number - 1, last_pos, -1)
		if line:find(M.curr_session, 1, true) then
			vim.api.nvim_buf_add_highlight(main_buf, -1, "HighlightPathCurr", line_number - 1, 1, last_pos - 1)
		end
end

-- Функция для получения списка session
local function get_sessions_list()
	local count = 0

	-- Путь к файлу
	local file_path = vim.fn.expand("~/.config/nvim" .. session_name)

	-- Открываем файл для чтения
	local file = io.open(file_path, "r")
	original_lines = {}

	if file then
			-- Читаем все строки из файла
			for line in file:lines() do
					count = count + 1
					table.insert(original_lines, string.format(" %2d %s %s", count, line, get_file_modification_time(line)))
					max_len_buffer = math.max(max_len_buffer, string.len(line) + 15)
			end
			file:close()
	else
			print("Ошибка: не удалось открыть файл для чтения.")
	end
end

-- Функция для создания основного окна
local function create_main_window()
	-- Создаём основной буфер
	main_buf = vim.api.nvim_create_buf(false, true)

	-- Устанавливаем текст в буфере
	vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, original_lines)

	vim.cmd("highlight HighlightPath guifg="..M.config.color_light_date)
	vim.cmd("highlight HighlightPathCurr guifg="..M.config.color_light_curr)
	for i, line in ipairs(original_lines) do
		highlight_in_filename(line, i)
	end

	-- Создаём основное окно
	local width = 0
	if M.config.width_win > 0 then
		width = math.min(vim.o.columns - 10, M.config.width_win )
	else
		width = math.min(vim.o.columns - 10,  max_len_buffer + 2)
	end

	local height = math.min(vim.o.lines - 4, vim.api.nvim_buf_line_count(main_buf) + 1)
	local col = math.floor((vim.o.columns - width))

	local opts = {
			relative = "editor",
			width = width,
			height = height,
			row = 1,
			col = col,
			style = "minimal",
	}

	-- Открываем основное окно
	main_win = vim.api.nvim_open_win(main_buf, true, opts)
	vim.cmd("stopi")
	vim.api.nvim_set_hl(0, "CursorLine", { bg = M.config.color_cursor_line })
	vim.api.nvim_win_set_option(0, "cursorline", true)

	-- Устанавливаем режим "только для чтения"
	vim.api.nvim_buf_set_option(main_buf, "readonly", true)
	vim.api.nvim_buf_set_option(main_buf, "modifiable", false)

	vim.api.nvim_buf_set_keymap(main_buf, "n", "<Esc>", "<cmd>lua require('msession').close()<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(main_buf, "n", "q", "<cmd>lua require('msession').close()<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(main_buf, "n", "f", "<cmd>lua require('msession').select_filter_window()<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(main_buf, "n", "s", "<cmd>lua require('msession').add_session_to_list()<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(main_buf, "n", "<c-Up>", "<cmd>lua require('msession').select_filter_window()<CR>", { noremap = true, silent = true })
	vim.api.nvim_buf_set_keymap(main_buf, "n", "<CR>", "<cmd>lua require('msession').load_session()<CR>", { noremap = true, silent = true })
	print("f-filter, s-save. "..short_path(vim.fn.getcwd()))
end

-- Функция для создания окна ввода фильтра
local function create_filter_window()
    -- Создаём буфер для ввода фильтра
    filter_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(filter_buf, 0, -1, false, {"  sessions:* "})

    -- Создаём окно для ввода фильтра
    local width = 0
		if M.config.width_win > 0 then
			width = math.min(vim.o.columns - 10, M.config.width_win )
		else
			width = math.min(vim.o.columns - 10,  max_len_buffer + 2)
		end
    local height = 1
    local col = math.floor((vim.o.columns - width) )

    local opts = {
        relative = "editor",
        width = width,
        height = height,
        row = 0,
        col = col,
        style = "minimal",
    }

    -- Открываем окно для ввода фильтра
    filter_win = vim.api.nvim_open_win(filter_buf, true, opts)

    vim.cmd("highlight RedText guibg=" .. M.config.color_light_filter)
    vim.api.nvim_buf_add_highlight(filter_buf, -1, "RedText", 0, 0, -1)

    -- Переключаемся в режим редактирования
    -- vim.api.nvim_command("startinsert")
		vim.cmd("star")

    -- Устанавливаем клавишу Esc для закрытия окна
    vim.api.nvim_buf_set_keymap(filter_buf, "i", "<Esc>", "<cmd>lua require('msession').close()<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(filter_buf, "i", "<CR>", "<cmd>lua require('msession').select_main_window()<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(filter_buf, "i", "<Down>", "<cmd>lua require('msession').select_main_window()<CR>", { noremap = true, silent = true })

    -- Устанавливаем обработчик ввода текста
    vim.api.nvim_buf_attach(filter_buf, false, {
        on_lines = function()
					vim.schedule(function()
            -- Получаем текст фильтра
            local filter_text = table.concat(vim.api.nvim_buf_get_lines(filter_buf, 0, -1, false), "")

            -- Фильтруем строки в основном буфере
            local filtered_lines = {}
            for _, line in ipairs(original_lines) do
                if line:find(filter_text, 1, true) then
                    table.insert(filtered_lines, line)
                end
            end

            -- Обновляем основной буфер
            vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, filtered_lines)
						for i, line in ipairs(filtered_lines) do
							highlight_in_filename(line, i)
						end
					end)
        end,
    })
end

-- загрузка cсессии
function M.load_session()
	local session_path = vim.fn.expand(string.sub(vim.api.nvim_get_current_line(), 5, -1))
	local last_pos=session_path:match(".* ()") - 2
	session_path = string.sub(session_path, 1, last_pos)
	local session = session_path .. session_name
	M.close()
	-- проверяем есть ли сессия
	if session_exists(session) then
		-- загружаем выбранную сессию
		vim.cmd("cd "..session_path)
		-- если один буфер запрос пользователя не делаем
		if confirm_input("Load? "..short_path(session_path)) then
			-- сохраним текущию сессию в глобальную переменную для подсветки в списке
			M.curr_session = short_path(session_path)
			-- Закрыть все окна, кроме текущего
			vim.cmd("only")
			-- Закрыть все буферы, кроме текущего
			vim.cmd("bufdo bdelete")
			vim.cmd("silent! source .session")
			print("Load Ok. "..short_path(vim.fn.getcwd()))
			return
		end
		print("Goto: "..session_path)
	else
		print("Нет файла! " .. session)
	end
end

-- для переключение на окно с 
function M.select_main_window()
    -- Возвращаемся в основной буфер
		vim.api.nvim_win_set_option(0, "cursorline", false)
    vim.api.nvim_set_current_win(main_win)
		vim.api.nvim_win_set_option(0, "cursorline", true)
    -- Устанавливаем режим "только для чтения"
    vim.api.nvim_buf_set_option(main_buf, "readonly", true)
    vim.api.nvim_buf_set_option(main_buf, "modifiable", false)
		vim.cmd("stopi")
end

function M.select_filter_window()
    -- Убираем режим "только для чтения"
    vim.api.nvim_buf_set_option(main_buf, "readonly", false)
    vim.api.nvim_buf_set_option(main_buf, "modifiable", true)

		-- очищаем поле ввода фильта если там находится путь к папке проекта (* не допустима в имени файла)
		if table.concat(vim.api.nvim_buf_get_lines(filter_buf, 0, -1, false), ""):find("*", 1, true) then
			vim.api.nvim_buf_set_lines(filter_buf, 0, -1, false, {})
		end

    -- Возвращаемся в основной буфер
		vim.api.nvim_win_set_option(0, "cursorline", false)
    vim.api.nvim_set_current_win(filter_win)
		vim.api.nvim_win_set_option(0, "cursorline", true)
		vim.cmd("star")
end

function M.mks_session()
	vim.cmd("mks! .session")
	print("Save Ok. "..short_path(vim.fn.getcwd()))
end

function M.close()
	vim.g.mm_windows = nil
	original_lines = {}
	-- Закрываем окна для фильтра и буфероф
	vim.api.nvim_win_close(filter_win, true)
	vim.api.nvim_buf_delete(filter_buf, { force = true })
	vim.api.nvim_win_close(main_win, true)
	vim.api.nvim_buf_delete(main_buf, { force = true })
	vim.api.nvim_set_hl(0, "CursorLine", { bg = M.config.color_cursor_mane_line })
	vim.cmd("stopi")
end

function M.setup(options)
	M.config = vim.tbl_deep_extend("force", M.config, options or {})

	M.home_dir = tostring(os.getenv("HOME"))
	-- vim.api.nvim_create_user_command("StartMsession", M.start, {})
end

-- Функция для запуска менеджера буферов
function M.start()
	if vim.g.mm_windows ~= nil then
		return
	end
	vim.g.mm_windows = 2
	-- M.home_dir = tostring(os.getenv("HOME"))
	get_sessions_list()

  -- Создаём окно ввода фильтра
  create_filter_window()

  -- Создаём основное окно
  create_main_window()
end

return M

