local ro = core.settings:get("mtfm.read_only")

mtfm = {}
mtfm.last_path = {}
mtfm.last_editor_path = {}
mtfm.dirlist = {}
mtfm.file = {}
mtfm.saved = {}
mtfm.selected = {}
mtfm.selected_mod = {}
local modlist = core.get_modnames() or {"Failed to load modlist"}
local worldpath = core.get_worldpath()
local F = core.formspec_escape

function safe_run(code)
	local func, err = loadstring(code)
	if not func then  -- Syntax error
		return err
	end
	local good, err = pcall(func)
	if not good then  -- Runtime error
		return err
	end
	return nil
end

local function fm_fs(name, path)
	local err = safe_run("mtfm.dirlist['"..name.."'] = core.get_dir_list('"..path.."')")
	if err then
		core.chat_send_player(name, "Invalid / illegal path")
		return
	end
	table.sort(mtfm.dirlist[name])
	local fs = "size[16,12]" ..
		"button[0.1,0;1,1;up;^]" ..
		"field[1.2,0.3;14.3,1;path;;"..F(path).."]" ..
		"field_close_on_enter[path;false]" ..
		"button[15,0;1,1;go;>]" ..
		"textlist[0.1,0.9;15.8,10;list;"..table.concat(mtfm.dirlist[name],",").."]" ..
		"button[0.1,11;1.5,1;modlist;Modlist]" ..
		"button[1.4,11;1.5,1;toworldpath;Worldpath]" ..
		"button[2.7,11;1.5,1;edit;Edit]" ..
		"button[14.5,11;1.5,1;open;Open]"
	if not ro then
		fs = fs .. "button[10.6,11;1.5,1;newfile;New file]" ..
		"button[9.3,11;1.5,1;newdir;New dir]" ..
		"button[11.9,11;1.5,1;del;Delete]" ..
		"button[13.2,11;1.5,1;copy;Copy]"
	end
		mtfm.last_path[name] = path
		core.show_formspec(name, "mtfm:fm", fs)
end

local function modlist_fs(name)
	local fs = "size[16,12]" ..
		"button[0.1,0;1,1;up;^]" ..
		"textlist[0.1,0.9;15.8,10;list;"..table.concat(modlist,",").."]" ..
		"button[14.5,11;1.5,1;open;Open]"
		core.show_formspec(name, "mtfm:modlist", fs)
end

local function editor_fs(name, path, new)
	local text = ""
	if not new then
		local err = safe_run("mtfm.file['"..name.."'] = io.open('"..path.."')")
		if err or not mtfm.file[name] then
			core.chat_send_player(name, "Invalid/illegal path")
			return
		end
		text = mtfm.file[name]:read(524288) or "Error loading content" --512kb limit
	end
	local fs = "size[16,12]" ..
		"button[0.1,0;1,1;close;X]" ..
		"field[1.2,0.3;13.5,1;path;;"..F(path).."]" ..
		"field_close_on_enter[path;false]" ..
		"button[14.2,0;1,1;open;Open]" ..
		"textarea[0.3,1;16,13;content;;"..F(text).."]"
	if not ro then
		fs = fs .. "button[15,0;1,1;save;Save]"
	end
	mtfm.last_editor_path[name] = path
	core.show_formspec(name, "mtfm:editor", fs)
end

local function image_viewer_fs(name, path, image)
	local fs = "size[16,12]" ..
		"button[0.1,0;1,1;close;X]" ..
		"field[1.2,0.3;14.9,1;path;;"..path.."]" ..
		"field_close_on_enter[path;false]" ..
		"image[3,1;12,12;"..image.."]"
	core.show_formspec(name, "mtfm:image_viewer", fs)
end

core.register_chatcommand("mtfm",{
  description = "Open file manager",
  privs = {server=true},
  params = "[path]",
  func = function(name, param)
	if not param or param == "" then
		param = mtfm.last_path[name] or worldpath
	end
	fm_fs(name, param)
	return true, "File manager opened"
end})

core.register_on_player_receive_fields(function(player, formname, fields)
	--core.chat_send_all(dump(fields,''))  --for debug
	local name = player:get_player_name()
	if not name then return end
	local dirlist = mtfm.dirlist[name]
	if formname == "mtfm:fm" then
		if fields.list then
			local evnt = core.explode_textlist_event(fields.list)
			mtfm.selected[name] = evnt.index
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
				core.chat_send_player(name, "Please select file/dir")
				return
			end
			editor_fs(name,mtfm.last_path[name].."/"..elem)
		end
		if fields.open or (fields.list and fields.list:match("DCL")) then
			local elem = dirlist[mtfm.selected[name]]
			if not elem or elem == "" then
				core.chat_send_player(name, "Please select file/dir")
				return
			end
			if elem:match("%S+%.png") then
				image_viewer_fs(name, mtfm.last_path[name].."/"..elem, elem)
				return
			end
			if elem:match("%S+%.ogg") then
				core.sound_play(elem:gsub(".ogg",""), {to_player=name})
				return
			end
			local err = safe_run("mtfm.file['"..name.."'] = io.open('"..mtfm.last_path[name].."'..'/'..'"..elem.."')")
			if not err and mtfm.file[name] and mtfm.file[name]:read() then
				editor_fs(name,mtfm.last_path[name].."/"..elem)
			else
				fm_fs(name, mtfm.last_path[name].."/"..elem)
			end
		end
		if fields.up and fields.path and fields.path ~= "" then
			local splitted = fields.path:split("/")
			local newpath = fields.path:gsub("/"..splitted[#splitted]:gsub('([^%w])','%%%1'),"") or worldpath
			fm_fs(name, newpath)
		end
		if fields.newdir and not ro  then
			core.show_formspec(name, "mtfm:newdir_dialog", 	"size[8,2]"..
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
				core.chat_send_player(name, "Please select file/dir")
				return
			end
			local err = safe_run("core.rmdir(mtfm.last_path['"..name.."']..'/'..'"..elem.."', true)")
			core.chat_send_player(name, err and "Error deleting" or "Deleted successfully")
			fm_fs(name, mtfm.last_path[name])
		end
		if fields.copy and not ro then
			local elem = dirlist[mtfm.selected[name]]
			if not elem or elem == "" then
				core.chat_send_player(name, "Please select file/dir")
				return
			end
			local err = safe_run("core.cpdir(mtfm.last_path['"..name.."']..'/'..'"..elem.."', mtfm.last_path['"..name.."']..'/'..'"..elem.."-copy')")
			core.chat_send_player(name, err and "Error copying" or "Copied successfully")
			fm_fs(name, mtfm.last_path[name])
		end
	end
	
	if formname == "mtfm:modlist" then
		if fields.list then
			local evnt = core.explode_textlist_event(fields.list)
			mtfm.selected_mod[name] = evnt.index
		end
		if fields.up then
			fm_fs(name,worldpath)
		end
		if fields.open or (fields.list and fields.list:match("DCL")) then
			local modname = modlist[mtfm.selected_mod[name]]
			if not modname or modname == "" then
				core.chat_send_player(name, "Please select a mod")
				return
			end
			fm_fs(name, core.get_modpath(modlist[mtfm.selected_mod[name]]))
		end
	end
	if formname == "mtfm:newdir_dialog" then
		if (fields.accept or fields.key_enter_field) and fields.dirname and fields.dirname ~= "" and not ro then
			local err = safe_run("core.mkdir(mtfm.last_path['"..name.."']..'/'..'"..fields.dirname.."')")
			core.chat_send_player(name, err and "Error creating new directory" or "Successfully created new directory")
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
				local err = safe_run("core.safe_file_write('"..fields.path.."', '"..content.."')")
				core.chat_send_player(name, err and "Error saving file" or "Saved successfully")
			end
		end
	end
	if formname == "mtfm:image_viewer" then
		if fields.close then
			fm_fs(name, mtfm.last_path[name])
		end
	end
end)
