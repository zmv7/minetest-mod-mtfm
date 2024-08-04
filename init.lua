local ro = minetest.settings:get("mtfm.read_only")

local mtfm = {}
mtfm.dirlist = {}
mtfm.last_path = {}
mtfm.last_editor_path = {}
mtfm.saved = {}
mtfm.selected = {}
mtfm.selected_mod = {}
local modlist = minetest.get_modnames() or {"Failed to load modlist"}
local worldpath = minetest.get_worldpath()
local F = minetest.formspec_escape

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
	local _, dirlist = pcall(minetest.get_dir_list, path)
	if type(dirlist) ~= "table" then
		minetest.chat_send_player(name, "Invalid / illegal path")
		return
	end
	table.sort(dirlist)
	mtfm.dirlist[name] = table.copy(dirlist)
	for i,elem in ipairs(dirlist) do
		local file = io.open(path.."/"..elem, "r")
		if file then
			if isdir(file) then
				dirlist[i] = dirlist[i]..",<dir>"
				file:close()
			else
				dirlist[i] = dirlist[i]..","..btoh(file:seek("end"))
				file:close()
			end
		else
			dirlist[i] = dirlist[i]..",<error>"
		end
	end
	mtfm.last_path[name] = path
	minetest.show_formspec(name, "mtfm:fm", "size[16,12]" ..
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
	minetest.show_formspec(name, "mtfm:modlist", "size[16,12]" ..
		"button[0.1,0;1,1;up;^]" ..
		"textlist[0.1,0.9;15.8,10;list;"..table.concat(modlist,",").."]" ..
		"button[14.5,11;1.5,1;open;Open]")
end

local function editor_fs(name, path, new)
	local text = ""
	if not new then
		local _, file = pcall(io.open, path)
		if not file then
			minetest.chat_send_player(name, "Invalid/illegal path")
			return
		end
		text = file:read(524288) or "Error loading content" --512kb limit
		file:close()
	end
	mtfm.last_editor_path[name] = path
	minetest.show_formspec(name, "mtfm:editor", "size[16,12]" ..
		"button[0.1,0;1,1;close;X]" ..
		"field[1.2,0.3;13.5,1;path;;"..F(path).."]" ..
		"field_close_on_enter[path;false]" ..
		"button[14.2,0;1,1;open;Open]" ..
		"style[content;font=mono]" ..
		"textarea[0.3,1;16,13;content;;"..F(text).."]" ..
		(not ro and "button[15,0;1,1;save;Save]" or ""))
end

local function image_viewer_fs(name, path, image)
	minetest.show_formspec(name, "mtfm:image_viewer", "size[16,12]" ..
		"button[0.1,0;1,1;close;X]" ..
		"field[1.2,0.3;14.9,1;path;;"..path.."]" ..
		"field_close_on_enter[path;false]" ..
		"image[3,1;12,12;"..image.."]")
end

minetest.register_chatcommand("mtfm",{
  description = "Open file manager",
  privs = {server=true},
  params = "[path]",
  func = function(name, param)
	if not minetest.get_player_by_name(name) then
		return false, "No player"
	end
	fm_fs(name, param and param ~= "" and param or mtfm.last_path[name] or worldpath)
	return true, "File manager opened"
end})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not formname:match("^mtfm:") then return end
	local name = player:get_player_name()
	if not name then return end
	if formname == "mtfm:fm" then
		local dirlist = mtfm.dirlist[name]
		if fields.list then
			local evnt = minetest.explode_table_event(fields.list)
			mtfm.selected[name] = evnt.row
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
			local elem = dirlist[mtfm.selected[name]]
			if not elem or elem == "" then
				minetest.chat_send_player(name, "Please select file/dir")
				return
			end
			editor_fs(name,mtfm.last_path[name].."/"..elem)
		end
		if fields.open or (fields.list and fields.list:match("DCL")) then
			local elem = dirlist[mtfm.selected[name]]
			if not elem or elem == "" then
				minetest.chat_send_player(name, "Please select file/dir")
				return
			end
			if elem:match("%S+%.png$") then
				image_viewer_fs(name, mtfm.last_path[name].."/"..elem, elem)
				return
			end
			if elem:match("%S+%.ogg$") then
				minetest.sound_play(elem:gsub(".ogg",""), {to_player=name})
				return
			end
			local _, file = pcall(io.open, mtfm.last_path[name].."/"..elem)
			if file then
				if isdir(file) then
					fm_fs(name, mtfm.last_path[name].."/"..elem)
				else
					editor_fs(name, mtfm.last_path[name].."/"..elem)
				end
				file:close()
			else
				minetest.chat_send_player(name, "Error opening")
			end
		end
		if fields.up and fields.path and fields.path ~= "" then
			local splitted = fields.path:split("/")
			local newpath = fields.path:gsub("/"..splitted[#splitted]:gsub('([^%w])','%%%1'),"") or worldpath
			fm_fs(name, newpath)
		end
		if fields.newdir and not ro then
			minetest.show_formspec(name, "mtfm:newdir_dialog", "size[8,2]"..
				"field[0.3,0.1;8,1;dirname;;NewDir]"..
				"field_close_on_enter[path;false]"..
				"button[3,1;2,1;accept;Accept]")
		end
		if fields.newfile and not ro then
			editor_fs(name,mtfm.last_path[name].."/new.txt", true)
		end
		if fields.del and not ro then
			local elem = dirlist[mtfm.selected[name]]
			if not elem or elem == "" then
				minetest.chat_send_player(name, "Please select file/dir")
				return
			end
			local _, ok = pcall(minetest.rmdir, mtfm.last_path[name].."/"..elem, true)
			minetest.chat_send_player(name, ok and "Deleted successfully" or "Error deleting")
			fm_fs(name, mtfm.last_path[name])
		end
		if fields.copy and not ro then
			local elem = dirlist[mtfm.selected[name]]
			if not elem or elem == "" then
				minetest.chat_send_player(name, "Please select file/dir")
				return
			end
			local _, file = pcall(io.open, mtfm.last_path[name].."/"..elem, "r")
			if file then
				local _, ok = isdir(file) and pcall(minetest.cpdir, mtfm.last_path[name].."/"..elem, mtfm.last_path[name].."/"..elem.."-copy")
					or pcall(minetest.safe_file_write, mtfm.last_path[name].."/"..elem.."-copy", file:read("*a"))
				minetest.chat_send_player(name, ok and "Copied successfully" or "Error copying")
				file:close()
			else
				minetest.chat_send_player(name, "Error copying")
			end
			fm_fs(name, mtfm.last_path[name])
		end
	end
	if formname == "mtfm:modlist" then
		if fields.list then
			local evnt = minetest.explode_textlist_event(fields.list)
			mtfm.selected_mod[name] = evnt.index
		end
		if fields.up then
			fm_fs(name,worldpath)
		end
		if fields.open or (fields.list and fields.list:match("DCL")) then
			local modname = modlist[mtfm.selected_mod[name]]
			if not modname or modname == "" then
				minetest.chat_send_player(name, "Please select a mod")
				return
			end
			fm_fs(name, minetest.get_modpath(modlist[mtfm.selected_mod[name]]))
		end
	end
	if formname == "mtfm:newdir_dialog" then
		if (fields.accept or fields.key_enter_field) and fields.dirname and fields.dirname ~= "" and not ro then
			local _, ok = pcall(minetest.mkdir, mtfm.last_path[name].."/"..fields.dirname)
			minetest.chat_send_player(name, ok and "Successfully created new directory" or "Error creating new directory")
			fm_fs(name, mtfm.last_path[name])
		end
	end
	if formname == "mtfm:editor" then
		if fields.close then
			fm_fs(name, mtfm.last_path[name])
		end
		if (fields.open or fields.key_enter_field) and fields.path and fields.path ~= "" then
			editor_fs(name, fields.path)
		end
		if fields.save and fields.path and fields.path ~= "" and not ro then
			local content = fields.content
			if content then
				local _, ok = pcall(minetest.safe_file_write, fields.path, content)
				minetest.chat_send_player(name, ok and "Saved successfully" or "Erorr saving file")
			end
		end
	end
	if formname == "mtfm:image_viewer" then
		if fields.close then
			fm_fs(name, mtfm.last_path[name])
		end
	end
end)
