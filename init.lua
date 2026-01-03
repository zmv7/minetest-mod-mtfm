--compat
local ro_legacy = core.settings:get("mtfm.read_only")
if ro_legacy then
	core.settings:set_bool("lc.read_only", true)
end

local ro = core.settings:get("lc.read_only")

local lc = {}
lc.dirlist = {}
lc.last_path = {}
lc.last_editor_path = {}
lc.saved = {}
lc.selected = {}
lc.selected_mod = {}
local modlist = core.get_modnames() or {"Failed to load modlist"}
local worldpath = core.get_worldpath()
local F = core.formspec_escape

local function btoh(val)
	if type(val) ~= "number" then
		return
	end
	local lvls = {"", "K", "M", "G", "T"}
	local lvl = 1
	while val > 1000 and lvl < #lvls do
		val = val/1000
		lvl = lvl + 1
	end
	local str = tostring(val):match("%d+%.%d%d")
	return (str or val).." "..lvls[lvl].."B"
end

local function isdir(file)
	local _, msg = file:read()
	if msg == "Is a directory" then
		return true
	end
end

local function fm_fs(name, path)
	local _, dirlist = pcall(core.get_dir_list, path)
	if type(dirlist) ~= "table" then
		core.chat_send_player(name, "Invalid / illegal path")
		return
	end
	table.sort(dirlist)
	lc.dirlist[name] = table.copy(dirlist)
	for i,elem in ipairs(dirlist) do
		local file = io.open(path.."/"..elem, "r")
		if file then
			dirlist[i] = dirlist[i]..(isdir(file) and ",<dir>" or ","..btoh(file:seek("end")))
			file:close()
		else
			dirlist[i] = dirlist[i]..",<error>"
		end
	end
	lc.last_path[name] = path
	core.show_formspec(name, "lc:fm", "size[16,12]" ..
		"set_focus[list]" ..
		"button[0.1,0;1,1;up;^]" ..
		"field[1.2,0.3;14.3,1;path;;"..F(path).."]" ..
		"field_close_on_enter[path;false]" ..
		"button[15,0;1,1;go;>]" ..
	--	"style[list;font=mono]" ..
		"tablecolumns[text;text,align=right,padding=1]" ..
		"table[0.1,0.9;15.8,10;list;"..table.concat(dirlist,",").."]" ..
		"button[0.1,11;1.5,1;modlist;Modlist]" ..
		"button[1.4,11;1.5,1;toworldpath;Worldpath]" ..
		"button[13.2,11;1.5,1;edit;Edit]" ..
		"button[14.5,11;1.5,1;open;Open]" ..
		(not ro and
		"button[8,11;1.5,1;newfile;New file]" ..
		"button[9.3,11;1.5,1;newdir;New dir]" ..
		"button[10.6,11;1.5,1;del;Delete]" ..
		"button[11.9,11;1.5,1;copy;Copy]" or ""))
end

local function modlist_fs(name)
	core.show_formspec(name, "lc:modlist", "size[16,12]" ..
		"button[0.1,0;1,1;up;^]" ..
		"textlist[0.1,0.9;15.8,10;list;"..table.concat(modlist,",").."]" ..
		"button[14.5,11;1.5,1;open;Open]")
end

local function editor_fs(name, path, new)
	local text = ""
	if not new then
		local _, file = pcall(io.open, path)
		if not file then
			core.chat_send_player(name, "Invalid/illegal path")
			return
		end
		text = file:read(524288) or "Error loading content" --512kb limit
		file:close()
	end
	lc.last_editor_path[name] = path
	core.show_formspec(name, "lc:editor", "size[16,12]" ..
		"button[0.1,0;1,1;close;X]" ..
		"field[1.2,0.3;13.5,1;path;;"..F(path).."]" ..
		"field_close_on_enter[path;false]" ..
		"button[14.2,0;1,1;open;Open]" ..
		"style[content;font=mono]" ..
		"textarea[0.3,1;16,13;content;;"..F(text).."]" ..
		(not ro and "button[15,0;1,1;save;Save]" or ""))
end

local function image_viewer_fs(name, path, image)
	core.show_formspec(name, "lc:image_viewer", "size[16,12]" ..
		"button[0.1,0;1,1;close;X]" ..
		"field[1.2,0.3;14.9,1;path;;"..path.."]" ..
		"field_close_on_enter[path;false]" ..
		"image[3,1;12,12;"..image.."]")
end

core.register_chatcommand("lc",{
  description = "Open file manager",
  privs = {server=true},
  params = "[path]",
  func = function(name, param)
	if not core.get_player_by_name(name) then
		return false, "No player"
	end
	fm_fs(name, param and param ~= "" and param or lc.last_path[name] or worldpath)
	return true, "File manager opened"
end})

core.register_on_player_receive_fields(function(player, formname, fields)
	if not formname:match("^lc:") then return end
	local name = player:get_player_name()
	if not name then return end
	if formname == "lc:fm" then
		local dirlist = lc.dirlist[name]
		if fields.list then
			local evnt = core.explode_table_event(fields.list)
			lc.selected[name] = evnt.row
		end
		if (fields.go or fields.key_enter_field) and fields.path and fields.path ~= "" then
			fm_fs(name, fields.path)
		end
		if fields.modlist then
			modlist_fs(name)
		end
		if fields.toworldpath then
			fm_fs(name, worldpath)
		end
		if fields.edit then
			local elem = dirlist[lc.selected[name]]
			if not elem or elem == "" then
				core.chat_send_player(name, "Please select file/dir")
				return
			end
			editor_fs(name,lc.last_path[name].."/"..elem)
		end
		if fields.open or (fields.list and fields.list:match("DCL")) then
			local elem = dirlist[lc.selected[name]]
			if not elem or elem == "" then
				core.chat_send_player(name, "Please select file/dir")
				return
			end
			if elem:match("%S+%.png$") then
				image_viewer_fs(name, lc.last_path[name].."/"..elem, elem)
				return
			end
			if elem:match("%S+%.ogg$") then
				core.sound_play(elem:gsub(".ogg",""), {to_player=name})
				return
			end
			local _, file = pcall(io.open, lc.last_path[name].."/"..elem)
			if file then
				if isdir(file) then
					fm_fs(name, lc.last_path[name].."/"..elem)
				else
					editor_fs(name, lc.last_path[name].."/"..elem)
				end
				file:close()
			else
				core.chat_send_player(name, "Error opening")
			end
		end
		if fields.up and fields.path and fields.path ~= "" then
			local splitted = fields.path:split("/")
			local newpath = fields.path:gsub("/"..splitted[#splitted]:gsub('([^%w])','%%%1'),"") or worldpath
			fm_fs(name, newpath)
		end
		if fields.newdir and not ro then
			core.show_formspec(name, "lc:newdir_dialog", "size[8,2]"..
				"field[0.3,0.1;8,1;dirname;;NewDir]"..
				"field_close_on_enter[path;false]"..
				"button[3,1;2,1;accept;Accept]")
		end
		if fields.newfile and not ro then
			editor_fs(name,lc.last_path[name].."/new.txt", true)
		end
		if fields.del and not ro then
			local elem = dirlist[lc.selected[name]]
			if not elem or elem == "" then
				core.chat_send_player(name, "Please select file/dir")
				return
			end
			local _, ok = pcall(core.rmdir, lc.last_path[name].."/"..elem, true)
			core.chat_send_player(name, ok and "Deleted successfully" or "Error deleting")
			fm_fs(name, lc.last_path[name])
		end
		if fields.copy and not ro then
			local elem = dirlist[lc.selected[name]]
			if not elem or elem == "" then
				core.chat_send_player(name, "Please select file/dir")
				return
			end
			local _, file = pcall(io.open, lc.last_path[name].."/"..elem, "r")
			if file then
				local _, ok = isdir(file) and pcall(core.cpdir, lc.last_path[name].."/"..elem, lc.last_path[name].."/"..elem.."-copy")
					or pcall(core.safe_file_write, lc.last_path[name].."/"..elem.."-copy", file:read("*a"))
				core.chat_send_player(name, ok and "Copied successfully" or "Error copying")
				file:close()
			else
				core.chat_send_player(name, "Error copying")
			end
			fm_fs(name, lc.last_path[name])
		end
	end
	if formname == "lc:modlist" then
		if fields.list then
			local evnt = core.explode_textlist_event(fields.list)
			lc.selected_mod[name] = evnt.index
		end
		if fields.up then
			fm_fs(name,worldpath)
		end
		if fields.open or (fields.list and fields.list:match("DCL")) then
			local modname = modlist[lc.selected_mod[name]]
			if not modname or modname == "" then
				core.chat_send_player(name, "Please select a mod")
				return
			end
			fm_fs(name, core.get_modpath(modlist[lc.selected_mod[name]]))
		end
	end
	if formname == "lc:newdir_dialog" then
		if (fields.accept or fields.key_enter_field) and fields.dirname and fields.dirname ~= "" and not ro then
			local _, ok = pcall(core.mkdir, lc.last_path[name].."/"..fields.dirname)
			core.chat_send_player(name, ok and "Successfully created new directory" or "Error creating new directory")
			fm_fs(name, lc.last_path[name])
		end
	end
	if formname == "lc:editor" then
		if fields.close then
			fm_fs(name, lc.last_path[name])
		end
		if (fields.open or fields.key_enter_field) and fields.path and fields.path ~= "" then
			editor_fs(name, fields.path)
		end
		if fields.save and fields.path and fields.path ~= "" and not ro then
			local content = fields.content
			if content then
				local _, ok = pcall(core.safe_file_write, fields.path, content)
				core.chat_send_player(name, ok and "Saved successfully" or "Erorr saving file")
			end
		end
	end
	if formname == "lc:image_viewer" then
		if fields.close then
			fm_fs(name, lc.last_path[name])
		end
	end
end)
