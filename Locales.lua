local _, ns = ...

function ns.Lower(s)
	if not s or s == "" then return "" end
	s = string.lower(s)
	local out, i, n = {}, 1, #s
	while i <= n do
		local b = string.byte(s, i)
		if b == 0xD0 then
			local b2 = string.byte(s, i + 1) or 0
			if b2 >= 0x90 and b2 <= 0x9F then
				out[#out + 1] = string.char(0xD0, b2 + 0x20)
			elseif b2 >= 0xA0 and b2 <= 0xAF then
				out[#out + 1] = string.char(0xD1, b2 - 0x20)
			elseif b2 == 0x81 then
				out[#out + 1] = string.char(0xD0, 0xB5)
			else
				out[#out + 1] = string.char(b, b2)
			end
			i = i + 2
		elseif b == 0xD1 then
			local b2 = string.byte(s, i + 1) or 0
			if b2 == 0x91 then
				out[#out + 1] = string.char(0xD0, 0xB5)
			else
				out[#out + 1] = string.char(b, b2)
			end
			i = i + 2
		elseif b >= 0xC0 then
			local len = 2
			if b >= 0xF0 then len = 4 elseif b >= 0xE0 then len = 3 end
			out[#out + 1] = string.sub(s, i, i + len - 1)
			i = i + len
		else
			out[#out + 1] = string.char(b)
			i = i + 1
		end
	end
	return table.concat(out)
end

function ns.Sep(n)
	if type(n) ~= "number" then return "0" end
	n = math.floor(n + 0.5)
	local sign = ""
	if n < 0 then sign = "-"; n = -n end
	local s, out = tostring(n), ""
	while #s > 3 do
		out = " " .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return sign .. s .. out
end

local L = {}

L.SEARCH_HINT      = "Поиск"
L.SEARCH_ACTIVE    = "Поиск активен"
L.ALL              = "Все"
L.FAVORITES        = "Избранное"
L.WATCHED          = "Отслеживаемая"
L.AT_WAR           = "В состоянии войны"
L.AT_WAR_SHORT     = "война"
L.OTHER            = "Прочее"

L.SORT             = "Сортировка"
L.SORT_GAME        = "Как в WoW"
L.SORT_NAME        = "По названию"
L.SORT_STANDING    = "По отношению"
L.SORT_PROGRESS    = "По прогрессу"
L.SORT_REMAIN      = "Сколько осталось"

L.HIDE_EXALTED     = "Не докачано"
L.GROUPING         = "Группировать"
L.STANDING_FILTER  = "Отношение"
L.STANDING_ALL     = "Все"
L.RESET_FILTERS    = "Сбросить"
L.RESET_FILTERS_TIP = "Сбросить поиск, выбранный раздел, фильтры и сортировку."
L.FAVORITE_TIP_ADD = "Добавить в избранное"
L.FAVORITE_TIP_REMOVE = "Убрать из избранного"

L.FACTIONS         = "Фракций"
L.PROGRESS_TOTAL   = "Общий прогресс"
L.MAXED            = "максимум"
L.LEFT             = "осталось"
L.CHAT_REPUTATION  = "Репутация"
L.SESSION          = "за сессию"
L.NOTHING_FOUND    = "Ничего не найдено. Попробуйте другой запрос."
L.NO_FACTIONS      = "Список репутаций пуст."
L.NO_FAVORITES     = "В избранном пока ничего нет."
L.NO_WATCHED       = "Отслеживаемая репутация не выбрана."
L.NO_AT_WAR        = "Нет фракций в состоянии войны."
L.HIDDEN_BY_FILTERS = "Подходящие фракции есть, но они скрыты текущими фильтрами."
L.INFO_DESC        = "Описание"
L.INFO_WHERE       = "Где качать"
L.INFO_DAILIES     = "Ежедневные задания"
L.INFO_TURNIN      = "Что сдавать"
L.INFO_REWARDS     = "Ради чего качать"
L.INFO_TIP         = "Совет"
L.INFO_NODATA      = "Справки по этой фракции пока нет.\n\nНажмите «Написать справку» внизу - заполните поля прямо в игре, ничего править в файлах не нужно."
L.INFO_FROM_GROUP  = "Справка общая для группы:"
L.INFO_EXACT_NAME  = "Точное название для Data.lua:"

L.BTN_WATCH        = "Отслеживать"
L.BTN_UNWATCH      = "Не отслеживать"
L.BTN_FAV          = "В избранное"
L.BTN_UNFAV        = "Убрать из избранного"
L.BTN_WAR          = "Объявить войну"
L.BTN_PEACE        = "Заключить мир"
L.BTN_EDIT         = "Изменить справку"
L.BTN_EDIT_NEW     = "Написать справку"
L.EDIT_TITLE       = "Справка"
L.EDIT_SAVE        = "Сохранить"
L.EDIT_DELETE      = "Удалить мою запись"
L.EDIT_HINT        = "Заполните нужные поля. Пустые поля не показываются. Запись сохраняется в настройках аддона."
L.EDIT_SAVED       = "справка сохранена:"
L.EDIT_REMOVED     = "своя справка удалена:"

L.REPLACE_TAB      = "Открывать вместо стандартного окна"
L.REPLACE_TAB_TIP  = "Если включить опцию, вкладка «Репутация» в окне персонажа будет открывать SirusRep. По умолчанию используется стандартное окно WoW."
L.FONT_SMALLER     = "Уменьшить шрифт"
L.FONT_BIGGER      = "Увеличить шрифт"
L.MINIMAP_TIP      = "ЛКМ - открыть или закрыть SirusRep.\nПеретаскивание - изменить положение значка."
L.EXPAND_SECTION   = "Развернуть"
L.COLLAPSE_SECTION = "Свернуть"
L.SECTION_CONTROL_TIP = "ЛКМ - развернуть или свернуть список внутри раздела."

L.TIP_ROW          = "ЛКМ - справка по фракции\nShift+ЛКМ - отслеживать на панели опыта\nCtrl+ЛКМ - в избранное\nAlt+ЛКМ - вставить репутацию в чат"
L.LOADED           = "|cff1784d1SirusRep|r загружен. Открыть или закрыть: |cffffd200/sr|r или |cffffd200/srep|r\nСброс положения окна: |cffffd200/sr reset|r или |cffffd200/srep reset|r"
L.POSITION_RESET    = "|cff1784d1SirusRep|r: положение окна сброшено."
L.WRONG_CLIENT     = "|cff1784d1SirusRep|r: аддон рассчитан на клиент 3.3.5a. Возможны ошибки."

ns.L = L
