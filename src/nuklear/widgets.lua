

local sapp      = require("sokol_app")
sg              = require("sokol_gfx")
sg              = require("sokol_nuklear")
local nk        = sg
local slib      = require("sokol_libs") -- Warn - always after gfx!!

local hmm       = require("hmm")
local hutils    = require("hmm_utils")

local ffi = require("ffi")

-- nuklear based widgets
--
--  Widgets use c based objects to store the results for input and other states
--    They are stored in lists here
local widgets = {

}

-- -------------------------------------------------------------------------------------------

local function widgets:label( name, align )
	nk.nk_label(self.ctx, label, align)
end

-- -------------------------------------------------------------------------------------------

local function widgets:menu( name, items, w, h)

	nk.nk_layout_row_push(ctx, 45)
	if (nk.nk_menu_begin_label(ctx, name, nk.NK_TEXT_LEFT, nk.nk_vec2(w, h))) then 
	
		prog = ffi.new("size_t[1]", { 40 } )
		slider = ffi.new("int[1]", { 10 } )
		check =  ffi.new("bool[1]", {nk.nk_true})
		nk.nk_layout_row_dynamic(self.ctx, 25, 1)
		if (nk.nk_menu_item_label(self.ctx, "Hide", nk.NK_TEXT_LEFT)) then 
			show_menu[0] = nk.nk_false
		end
		if (nk.nk_menu_item_label(ctx, "About", nk.NK_TEXT_LEFT)) then 
			show_app_about = nk.nk_true
		end
		nk.nk_progress(self.ctx, prog, 100, nk.NK_MODIFIABLE)
		nk.nk_slider_int(self.ctx, 0, slider, 16, 1)
		nk.nk_checkbox_label(self.ctx, "check", check)
		nk.nk_menu_end(self.ctx)
	end
end

-- -------------------------------------------------------------------------------------------

local function widgets:progress( val, max_val )

	nk.nk_progress(self.ctx, prog, 100, nk.NK_MODIFIABLE)

end

-- -------------------------------------------------------------------------------------------

local function widgets:slider( min_val, val, max_val, step, type )

	local res = false
	if(type == nil or type == "int") then 
		res = nk.nk_slider_int(self.ctx, min_val, val, max_val, step)
	elseif(type == "float") then 
		res = nk.nk_slider_float(self.ctx, min_val, val, max_val, step)
	end
	return res
end

-- -------------------------------------------------------------------------------------------


local function widgets:color_picker( color_val )
	nk_color_pick(self.ctx, color_val, nk.NK_RGBA)
end 

-- -------------------------------------------------------------------------------------------

local function widgets:slider( min_val, val, max_val, step, type )

end

-- -------------------------------------------------------------------------------------------
