--[[
Description: Trim items to specified length
Version: 1.00
Author: Lokasenna
Donation: https://paypal.me/Lokasenna
Changelog:
    Initial release
Links:
	Lokasenna's Website http://forum.cockos.com/member.php?u=10417
About: 
    Trims all selected items to a given length
--]]

-- Licensed under the GNU GPL v3


------------------------------------
-------- GUI Library ---------------
------------------------------------


local function req(file)
	
    if missing_lib then return function () end end
	
    local ret, err = loadfile(( file:sub(2, 2) == ":" and "" or script_path) .. file)
    
    if not ret then
        reaper.ShowMessageBox("Couldn't load "..file.."\n\nError: "..tostring(err), "Library error", 0)
        missing_lib = true		
        return function () end
    else 
        return ret
    end	

end


---- Libraries added with Lokasenna's Script Compiler ----



---- Beginning of file: F:/Github Repositories/Lokasenna_GUI/Core.lua ----

--[[
	
	Lokasenna_GUI 2.0
	
	Core functionality
	
]]--

local function GUI_table ()

local GUI = {}

GUI.version = "2.0"




------------------------------------
-------- Error handling ------------
------------------------------------


-- A basic crash handler, just to add some helpful detail
-- to the Reaper error message.
GUI.crash = function (errObject)
                             
    local by_line = "([^\r\n]*)\r?\n?"
    local trim_path = "[\\/]([^\\/]-:%d+:.+)$"
    local err = string.match(errObject, trim_path) or "Couldn't get error message."

    local trace = debug.traceback()
    local tmp = {}
    for line in string.gmatch(trace, by_line) do
        
        local str = string.match(line, trim_path) or line
        
        tmp[#tmp + 1] = str

    end
    
    local name = ({reaper.get_action_context()})[2]:match("([^/\\_]+)$")
    
    local ret = reaper.ShowMessageBox(name.." has crashed!\n\n"..
                                      "Would you like to have a crash report printed "..
                                      "to the Reaper console?", 
                                      "Oops", 4)
    
    if ret == 6 then 
        reaper.ShowConsoleMsg("Error: "..err.."\n\n"..
                              "Stack traceback:\n\t"..table.concat(tmp, "\n\t", 2).."\n\n")
    end
    
    gfx.quit()
end



------------------------------------
-------- Main functions ------------
------------------------------------


-- All elements are stored here. Don't put them anywhere else, or
-- Main will never find them.
GUI.elms = {}

-- On each draw loop, only layers that are set to true in this table
-- will be redrawn; if false, it will just copy them from the buffer
-- Set [0] = true to redraw everything.
GUI.redraw_z = {}

-- Maintain a list of all GUI elements, sorted by their z order	
-- Also removes any elements with z = -1, for automatically
-- cleaning things up.
GUI.elms_list = {}
GUI.z_max = 0
GUI.update_elms_list = function (init)
	
	local z_table = {}
	GUI.z_max = 0

	for key, __ in pairs(GUI.elms) do

		local z = GUI.elms[key].z or 5

		-- Delete elements if the script asked to
		if z == -1 then
			
			GUI.elms[key]:ondelete()
			GUI.elms[key] = nil
			
		else

			if z_table[z] then
				table.insert(z_table[z], key)

			else
				z_table[z] = {key}

			end
		
		end
		
		if init then 
			
			GUI.elms[key]:init()

		end

		GUI.z_max = math.max(z, GUI.z_max)

	end

	GUI.elms_list = z_table
	
end

GUI.elms_hide = {}
GUI.elms_freeze = {}




GUI.Init = function ()
    xpcall( function()
        
        
        -- Create the window
        gfx.clear = reaper.ColorToNative(table.unpack(GUI.colors.wnd_bg))
        
        if not GUI.x then GUI.x = 0 end
        if not GUI.y then GUI.y = 0 end
        if not GUI.w then GUI.w = 640 end
        if not GUI.h then GUI.h = 480 end

        if GUI.anchor and GUI.corner then
            GUI.x, GUI.y = GUI.get_window_pos(  GUI.x, GUI.y, GUI.w, GUI.h, 
                                                GUI.anchor, GUI.corner)
        end
            
        gfx.init(GUI.name, GUI.w, GUI.h, GUI.dock or 0, GUI.x, GUI.y)
        
        
        GUI.cur_w, GUI.cur_h = gfx.w, gfx.h

        -- Measure the window's title bar, in case we need it
        local __, __, wnd_y, __, __ = gfx.dock(-1, 0, 0, 0, 0)
        local __, gui_y = gfx.clienttoscreen(0, 0)
        GUI.title_height = gui_y - wnd_y


        -- Initialize a few values
        GUI.last_time = 0
        GUI.mouse = {
        
            x = 0,
            y = 0,
            cap = 0,
            down = false,
            wheel = 0,
            lwheel = 0
            
        }
      
        -- Store which element the mouse was clicked on.
        -- This is essential for allowing drag behaviour where dragging affects 
        -- the element position.
        GUI.mouse_down_elm = nil
        GUI.rmouse_down_elm = nil
        GUI.mmouse_down_elm = nil
            
        -- Convert color presets from 0..255 to 0..1
        for i, col in pairs(GUI.colors) do
            col[1], col[2], col[3], col[4] =    col[1] / 255, col[2] / 255, 
                                                col[3] / 255, col[4] / 255
        end
        
        -- Initialize the tables for our z-order functions
        GUI.update_elms_list(true)	
        
        if GUI.exit then reaper.atexit(GUI.exit) end
        
        GUI.gfx_open = true

    end, GUI.crash)
end

GUI.Main = function ()
    xpcall( function ()    

        GUI.Main_Update_State()

        GUI.Main_Update_Elms()

        -- If the user gave us a function to run, check to see if it needs to be 
        -- run again, and do so. 
        if GUI.func then
            
            local new_time = os.time()
            if new_time - GUI.last_time >= (GUI.freq or 1) then
                GUI.func()
                GUI.last_time = new_time
            
            end
        end
        
        
        -- Maintain a list of elms and zs in case any have been moved or deleted
        GUI.update_elms_list()    
        
        
        GUI.Main_Draw()

    end, GUI.crash)
end


GUI.Main_Update_State = function()
    
	-- Update mouse and keyboard state, window dimensions
    if GUI.mouse.x ~= gfx.mouse_x or GUI.mouse.y ~= gfx.mouse_y then
        
        GUI.mouse.lx, GUI.mouse.ly = GUI.mouse.x, GUI.mouse.y
        GUI.mouse.x, GUI.mouse.y = gfx.mouse_x, gfx.mouse_y
        
        -- Hook for user code
        if GUI.onmousemove then GUI.onmousemove() end
       
    else
    
        GUI.mouse.lx, GUI.mouse.ly = GUI.mouse.x, GUI.mouse.y
       
    end
	GUI.mouse.wheel = gfx.mouse_wheel
	GUI.mouse.cap = gfx.mouse_cap
	GUI.char = gfx.getchar() 
	
	if GUI.cur_w ~= gfx.w or GUI.cur_h ~= gfx.h then
		GUI.cur_w, GUI.cur_h = gfx.w, gfx.h
        
        -- Deprecated
		GUI.resized = true
        
        -- Hook for user code
        if GUI.onresize then GUI.onresize() end
        
	else
		GUI.resized = false
	end
	
	--	(Escape key)	(Window closed)		(User function says to close)
	--if GUI.char == 27 or GUI.char == -1 or GUI.quit == true then
	if (GUI.char == 27 and not (	GUI.mouse.cap & 4 == 4 
								or 	GUI.mouse.cap & 8 == 8 
								or 	GUI.mouse.cap & 16 == 16))
			or GUI.char == -1 
			or GUI.quit == true then
		
		return 0
	else
		reaper.defer(GUI.Main)
	end
    
end


--[[
	Update each element's state, starting from the top down.
	
	This is very important, so that lower elements don't
	"steal" the mouse.
	
	
	This function will also delete any elements that have their z set to -1

	Handy for something like Label:fade if you just want to remove
	the faded element entirely
	
	***Don't try to remove elements in the middle of the Update
	loop; use this instead to have them automatically cleaned up***	
	
]]--
GUI.Main_Update_Elms = function ()
    
    -- Disabled May 2/2018 to see if it was actually necessary
	-- GUI.update_elms_list()
	
	-- We'll use this to shorten each elm's update loop if the user did something
	-- Slightly more efficient, and averts any bugs from false positives
	GUI.elm_updated = false

	-- Check for the dev mode toggle before we get too excited about updating elms
	if  GUI.char == 282         and GUI.mouse.cap & 4 ~= 0 
    and GUI.mouse.cap & 8 ~= 0  and GUI.mouse.cap & 16 ~= 0 then
		
		GUI.dev_mode = not GUI.dev_mode
		GUI.elm_updated = true
		GUI.redraw_z[0] = true
		
	end	


	for i = 0, GUI.z_max do
		if  GUI.elms_list[i] and #GUI.elms_list[i] > 0 
        and not (GUI.elms_hide[i] or GUI.elms_freeze[i]) then
			for __, elm in pairs(GUI.elms_list[i]) do

				if elm and GUI.elms[elm] then GUI.Update(GUI.elms[elm]) end
				
			end
		end
		
	end

	-- Just in case any user functions want to know...
	GUI.mouse.last_down = GUI.mouse.down
	GUI.mouse.last_r_down = GUI.mouse.r_down

end

    
GUI.Main_Draw = function ()    
    
	-- Redraw all of the elements, starting from the bottom up.
	local w, h = GUI.cur_w, GUI.cur_h

	local need_redraw, global_redraw
	if GUI.redraw_z[0] then
		global_redraw = true
        GUI.redraw_z[0] = false
	else
		for z, b in pairs(GUI.redraw_z) do
			if b == true then 
				need_redraw = true 
				break
			end
		end
	end

	if need_redraw or global_redraw then
		
		-- All of the layers will be drawn to their own buffer (dest = z), then
		-- composited in buffer 0. This allows buffer 0 to be blitted as a whole
		-- when none of the layers need to be redrawn.
		
		gfx.dest = 0
		gfx.setimgdim(0, -1, -1)
		gfx.setimgdim(0, w, h)

		GUI.color("wnd_bg")
		gfx.rect(0, 0, w, h, 1)

		for i = GUI.z_max, 0, -1 do
			if  GUI.elms_list[i] and #GUI.elms_list[i] > 0 
            and not GUI.elms_hide[i] then

				if global_redraw or GUI.redraw_z[i] then
					
					-- Set this before we redraw, so that elms can call a redraw 
                    -- from their own :draw method. e.g. Labels fading out
					GUI.redraw_z[i] = false

					gfx.setimgdim(i, -1, -1)
					gfx.setimgdim(i, w, h)
					gfx.dest = i
					
					for __, elm in pairs(GUI.elms_list[i]) do
						if not GUI.elms[elm] then GUI.Msg(elm.." doesn't exist?") end
                        
                        -- Reset these just in case an element or some user code forgot to,
                        -- otherwise we get things like the whole buffer being blitted with a=0.2
                        gfx.mode = 0
                        gfx.set(0, 0, 0, 1)
                        
						GUI.elms[elm]:draw()
					end

					gfx.dest = 0
				end
							
				gfx.blit(i, 1, 0, 0, 0, w, h, 0, 0, w, h, 0, 0)
			end
		end

        -- Draw developer hints if necessary
        if GUI.dev_mode then
            GUI.Draw_Dev()
        else		
            GUI.Draw_Version()		
        end
		
	end
   
		
    -- Reset them again, to be extra sure
	gfx.mode = 0
	gfx.set(0, 0, 0, 1)
	
	gfx.dest = -1
	gfx.blit(0, 1, 0, 0, 0, w, h, 0, 0, w, h, 0, 0)
	
	gfx.update()

end




------------------------------------
-------- Buffer functions ----------
------------------------------------


--[[
	We'll use this to let elements have their own graphics buffers
	to do whatever they want in. 
	
	num	=	How many buffers you want, or 1 if not specified.
	
	Returns a table of buffers, or just a buffer number if num = 1
	
	i.e.
	
	-- Assign this element's buffer
	function GUI.my_element:new(.......)
	
	   ...new stuff...
	   
	   my_element.buffers = GUI.GetBuffer(4)
	   -- or
	   my_element.buffer = GUI.GetBuffer()
		
	end
	
	-- Draw to the buffer
	function GUI.my_element:init()
		
		gfx.dest = self.buffers[1]
		-- or
		gfx.dest = self.buffer
		...draw stuff...
	
	end
	
	-- Copy from the buffer
	function GUI.my_element:draw()
		gfx.blit(self.buffers[1], 1, 0)
		-- or
		gfx.blit(self.buffer, 1, 0)
	end
	
]]--

-- Any used buffers will be marked as True here
GUI.buffers = {}

-- When deleting elements, their buffer numbers
-- will be added here for easy access.
GUI.freed_buffers = {}

GUI.GetBuffer = function (num)
	
	local ret = {}
	local prev
	
	for i = 1, (num or 1) do
		
		if #GUI.freed_buffers > 0 then
			
			ret[i] = table.remove(GUI.freed_buffers)
			
		else
		
			for j = (not prev and 1023 or prev - 1), 0, -1 do
			
				if not GUI.buffers[j] then
					ret[i] = j
					GUI.buffers[j] = true
					break
				end
				
			end
			
		end
		
	end

	return (#ret == 1) and ret[1] or ret

end

-- Elements should pass their buffer (or buffer table) to this
-- when being deleted
GUI.FreeBuffer = function (num)
	
	if type(num) == "number" then
		table.insert(GUI.freed_buffers, num)
	else
		for k, v in pairs(num) do
			table.insert(GUI.freed_buffers, v)
		end
	end	
	
end




------------------------------------
-------- Element functions ---------
------------------------------------


-- Wrapper for creating new elements, allows them to know their own name
-- If called after the script window has opened, will also run their :init
-- method.
-- Can be given a user class directly by passing the class itself as 'elm',
-- or if 'elm' is a string will look for a class in GUI[elm]
GUI.New = function (name, elm, ...)

    local elm = type(elm) == "string"   and GUI[elm]
                                        or  elm

    if not elm or type(elm) ~= "table" then
		reaper.ShowMessageBox(  "Unable to create element '"..tostring(name)..
                                "'.\nClass '"..tostring(elm).."' isn't available.", 
                                "GUI Error", 0)
		GUI.quit = true
		return nil
	end
    
    if GUI.elms[name] then GUI.elms[name]:delete() end
	
	GUI.elms[name] = elm:new(name, ...)
    
	if GUI.gfx_open then GUI.elms[name]:init() end
    
    -- Return this so (I think) a bunch of new elements could be created
    -- within a table that would end up holding their names for easy bulk
    -- processing.

    return name
	
end


--	See if the any of the given element's methods need to be called
GUI.Update = function (elm)
	
	local x, y = GUI.mouse.x, GUI.mouse.y
	local x_delta, y_delta = x-GUI.mouse.lx, y-GUI.mouse.ly
	local wheel = GUI.mouse.wheel
	local inside = GUI.IsInside(elm, x, y)
	
	local skip = elm:onupdate() or false
		
	
	if GUI.elm_updated then
		if elm.focus then
			elm.focus = false
			elm:lostfocus()
		end
		skip = true
	end


	if skip then return end
    
    -- Left button
    if GUI.mouse.cap&1==1 then
        
        -- If it wasn't down already...
        if not GUI.mouse.last_down then


            -- Was a different element clicked?
            if not inside then 
                if GUI.mouse_down_elm == elm then
                    -- Should already have been reset by the mouse-up, but safeguard...
                    GUI.mouse_down_elm = nil
                end
                if elm.focus then
                    elm.focus = false
                    elm:lostfocus()
                end
                return 0
            else
                if GUI.mouse_down_elm == nil then -- Prevent click-through

                    GUI.mouse_down_elm = elm

                    -- Double clicked?
                    if GUI.mouse.downtime 
                    and reaper.time_precise() - GUI.mouse.downtime < 0.10 
                    then

                        GUI.mouse.downtime = nil
                        GUI.mouse.dbl_clicked = true
                        elm:ondoubleclick()

                    elseif not GUI.mouse.dbl_clicked then

                        elm.focus = true
                        elm:onmousedown()

                    end

                    GUI.elm_updated = true
                end
                
                GUI.mouse.down = true
                GUI.mouse.ox, GUI.mouse.oy = x, y
                
                -- Where in the elm the mouse was clicked. For dragging stuff
                -- and keeping it in the place relative to the cursor.
                GUI.mouse.off_x, GUI.mouse.off_y = x - elm.x, y - elm.y
                
            end
                        
        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0) 
        and     GUI.mouse_down_elm == elm then
        
            if elm.focus ~= false then 

                GUI.elm_updated = true
                elm:ondrag(x_delta, y_delta)
                
            end
        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.down and GUI.mouse_down_elm == elm then

            GUI.mouse_down_elm = nil

            if not GUI.mouse.dbl_clicked then elm:onmouseup() end

            GUI.elm_updated = true
            GUI.mouse.down = false
            GUI.mouse.dbl_clicked = false
            GUI.mouse.ox, GUI.mouse.oy = -1, -1
            GUI.mouse.off_x, GUI.mouse.off_y = -1, -1
            GUI.mouse.lx, GUI.mouse.ly = -1, -1
            GUI.mouse.downtime = reaper.time_precise()


    end
    
    
    -- Right button
    if GUI.mouse.cap&2==2 then
        
        -- If it wasn't down already...
        if not GUI.mouse.last_r_down then

            -- Was a different element clicked?
            if not inside then 
                if GUI.rmouse_down_elm == elm then
                    -- Should have been reset by the mouse-up, but in case...
                    GUI.rmouse_down_elm = nil
                end
                --elm.focus = false
            else
            
                -- Prevent click-through
                if GUI.rmouse_down_elm == nil then 

                    GUI.rmouse_down_elm = elm

                        -- Double clicked?
                    if GUI.mouse.r_downtime 
                    and reaper.time_precise() - GUI.mouse.r_downtime < 0.20 
                    then

                        GUI.mouse.r_downtime = nil
                        GUI.mouse.r_dbl_clicked = true
                        elm:onr_doubleclick()

                    elseif not GUI.mouse.r_dbl_clicked then

                        elm:onmouser_down()

                    end

                    GUI.elm_updated = true

                end
                
                GUI.mouse.r_down = true
                GUI.mouse.r_ox, GUI.mouse.r_oy = x, y
                -- Where in the elm the mouse was clicked. For dragging stuff
                -- and keeping it in the place relative to the cursor.
                GUI.mouse.r_off_x, GUI.mouse.r_off_y = x - elm.x, y - elm.y                    

            end
            
    
        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0) 
        and     GUI.rmouse_down_elm == elm then
        
            if elm.focus ~= false then 

                elm:onr_drag(x_delta, y_delta)
                GUI.elm_updated = true

            end

        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.r_down and GUI.rmouse_down_elm == elm then 
    
        GUI.rmouse_down_elm = nil
    
        if not GUI.mouse.r_dbl_clicked then elm:onmouser_up() end

        GUI.elm_updated = true
        GUI.mouse.r_down = false
        GUI.mouse.r_dbl_clicked = false
        GUI.mouse.r_ox, GUI.mouse.r_oy = -1, -1
        GUI.mouse.r_off_x, GUI.mouse.r_off_y = -1, -1
        GUI.mouse.r_lx, GUI.mouse.r_ly = -1, -1
        GUI.mouse.r_downtime = reaper.time_precise()

    end



    -- Middle button
    if GUI.mouse.cap&64==64 then
        
        
        -- If it wasn't down already...
        if not GUI.mouse.last_m_down then


            -- Was a different element clicked?
            if not inside then 
                if GUI.mmouse_down_elm == elm then
                    -- Should have been reset by the mouse-up, but in case...
                    GUI.mmouse_down_elm = nil
                end
            else
                -- Prevent click-through
                if GUI.mmouse_down_elm == nil then 

                    GUI.mmouse_down_elm = elm

                    -- Double clicked?
                    if GUI.mouse.m_downtime 
                    and reaper.time_precise() - GUI.mouse.m_downtime < 0.20 
                    then

                        GUI.mouse.m_downtime = nil
                        GUI.mouse.m_dbl_clicked = true
                        elm:onm_doubleclick()

                    else

                        elm:onmousem_down()

                    end

                    GUI.elm_updated = true

              end

                GUI.mouse.m_down = true
                GUI.mouse.m_ox, GUI.mouse.m_oy = x, y
                GUI.mouse.m_off_x, GUI.mouse.m_off_y = x - elm.x, y - elm.y

            end
            

        
        -- 		Dragging? Did the mouse start out in this element?
        elseif (x_delta ~= 0 or y_delta ~= 0) 
        and     GUI.mmouse_down_elm == elm then
        
            if elm.focus ~= false then 
                
                elm:onm_drag(x_delta, y_delta)
                GUI.elm_updated = true
                
            end

        end

    -- If it was originally clicked in this element and has been released
    elseif GUI.mouse.m_down and GUI.mmouse_down_elm == elm then
    
        GUI.mmouse_down_elm = nil
    
        if not GUI.mouse.m_dbl_clicked then elm:onmousem_up() end
        
        GUI.elm_updated = true
        GUI.mouse.m_down = false
        GUI.mouse.m_dbl_clicked = false
        GUI.mouse.m_ox, GUI.mouse.m_oy = -1, -1
        GUI.mouse.m_off_x, GUI.mouse.m_off_y = -1, -1
        GUI.mouse.m_lx, GUI.mouse.m_ly = -1, -1
        GUI.mouse.m_downtime = reaper.time_precise()

    end

		
	
	-- If the mouse is hovering over the element
	if inside and not GUI.mouse.down and not GUI.mouse.r_down then
		elm:onmouseover()
		elm.mouseover = true
	else
		elm.mouseover = false
		--elm.hovering = false
	end
	
	
	-- If the mousewheel's state has changed
	if inside and GUI.mouse.wheel ~= GUI.mouse.lwheel then
		
		GUI.mouse.inc = (GUI.mouse.wheel - GUI.mouse.lwheel) / 120
		
		elm:onwheel(GUI.mouse.inc)
		GUI.elm_updated = true
		GUI.mouse.lwheel = GUI.mouse.wheel
	
	end
	
	-- If the element is in focus and the user typed something
	if elm.focus and GUI.char ~= 0 then
		elm:ontype() 
		GUI.elm_updated = true
	end
	
end


--[[	Return or change an element's value
	
	For use with external user functions. Returns the given element's current 
	value or, if specified, sets a new one.	Changing values with this is often 
	preferable to setting them directly, as most :val methods will also update 
	some internal parameters and redraw the element when called.
]]--
GUI.Val = function (elm, newval)

	if not GUI.elms[elm] then return nil end
	
	if newval then
		GUI.elms[elm]:val(newval)
	else
		return GUI.elms[elm]:val()
	end

end


-- Are these coordinates inside the given element?
-- If no coords are given, will use the mouse cursor
GUI.IsInside = function (elm, x, y)

	if not elm then return false end

	local x, y = x or GUI.mouse.x, y or GUI.mouse.y

	return	(	x >= (elm.x or 0) and x < ((elm.x or 0) + (elm.w or 0)) and 
				y >= (elm.y or 0) and y < ((elm.y or 0) + (elm.h or 0))	)
	
end




------------------------------------
-------- Prototype element ---------
----- + all default methods --------
------------------------------------


--[[
	All classes will use this as their template, so that
	elements are initialized with every method available.
]]--
GUI.Element = {}
function GUI.Element:new(name)
	
	local elm = {}
	if name then elm.name = name end
    self.z = 1
	
	setmetatable(elm, self)
	self.__index = self
	return elm
	
end

-- Called a) when the script window is first opened
-- 		  b) when any element is created via GUI.New after that
-- i.e. Elements can draw themselves to a buffer once on :init()
-- and then just blit/rotate/etc as needed afterward
function GUI.Element:init() end

-- Called whenever the element's z layer is told to redraw
function GUI.Element:draw() end

-- Ask for a redraw on the next update
function GUI.Element:redraw()
    GUI.redraw_z[self.z] = true
end

-- Called on every update loop, unless the element is hidden or frozen
function GUI.Element:onupdate() end

function GUI.Element:delete()
    
    self.ondelete(self)
    GUI.elms[self.name] = nil
    
end

-- Called when the element is deleted by GUI.update_elms_list() or :delete.
-- Use it for freeing up buffers and anything else memorywise that this
-- element was doing
function GUI.Element:ondelete() end


-- Set or return the element's value
-- Can be useful for something like a Slider that doesn't have the same
-- value internally as what it's displaying
function GUI.Element:val() end

-- Called on every update loop if the mouse is over this element.
function GUI.Element:onmouseover() end

-- Only called once; won't repeat if the button is held
function GUI.Element:onmousedown() end

function GUI.Element:onmouseup() end
function GUI.Element:ondoubleclick() end

-- Will continue being called even if you drag outside the element
function GUI.Element:ondrag() end

-- Right-click
function GUI.Element:onmouser_down() end
function GUI.Element:onmouser_up() end
function GUI.Element:onr_doubleclick() end
function GUI.Element:onr_drag() end

-- Middle-click
function GUI.Element:onmousem_down() end
function GUI.Element:onmousem_up() end
function GUI.Element:onm_doubleclick() end
function GUI.Element:onm_drag() end

function GUI.Element:onwheel() end
function GUI.Element:ontype() end


-- Elements like a Textbox that need to keep track of their focus
-- state will use this to e.g. update the text somewhere else 
-- when the user clicks out of the box.
function GUI.Element:lostfocus() end




------------------------------------
-------- Developer stuff -----------
------------------------------------


-- Print a string to the Reaper console.
GUI.Msg = function (str)
	reaper.ShowConsoleMsg(tostring(str).."\n")
end

-- Print the specified parameters for a given element to the Reaper console.
-- If nothing is specified, prints all of the element's properties.
function GUI.Element:Msg(...)
    
    local arg = {...}
    
    if #arg == 0 then
        arg = {}
        for k in GUI.kpairs(self, "full") do
            arg[#arg+1] = k
        end
    end    
    
    if not self or not self.type then return end
    local pre = tostring(self.name) .. "."
    local strs = {}
    
    for i = 1, #arg do
        
        strs[#strs + 1] = pre .. tostring(arg[i]) .. " = "
        
        if type(self[arg[i]]) == "table" then 
            strs[#strs] = strs[#strs] .. "table:"
            strs[#strs + 1] = GUI.table_list(self[arg[i]], nil, 1)
        else
            strs[#strs] = strs[#strs] .. tostring(self[arg[i]])
        end
        
    end
    
    reaper.ShowConsoleMsg( "\n" .. table.concat(strs, "\n") .. "\n")
    
end


-- Developer mode settings
GUI.dev = {
	
	-- grid_a must be a multiple of grid_b, or it will
	-- probably never be drawn
	grid_a = 128,
	grid_b = 16
	
}


-- Draws a grid overlay and some developer hints
-- Toggled via Ctrl+Shift+Alt+Z, or by setting GUI.dev_mode = true
GUI.Draw_Dev = function ()
	    
	-- Draw a grid for placing elements
	GUI.color("magenta")
	gfx.setfont("Courier New", 10)
	
	for i = 0, GUI.w, GUI.dev.grid_b do
		
		local a = (i == 0) or (i % GUI.dev.grid_a == 0)
		gfx.a = a and 1 or 0.3
		gfx.line(i, 0, i, GUI.h)
		gfx.line(0, i, GUI.w, i)
		if a then
			gfx.x, gfx.y = i + 4, 4
			gfx.drawstr(i)
			gfx.x, gfx.y = 4, i + 4
			gfx.drawstr(i)
		end	
	
	end
    
    local str = "Mouse: "..math.modf(GUI.mouse.x)..", "..math.modf(GUI.mouse.y).." "
    local str_w, str_h = gfx.measurestr(str)
    gfx.x, gfx.y = GUI.w - str_w - 2, GUI.h - 2*str_h - 2
    
    GUI.color("black")
    gfx.rect(gfx.x - 2, gfx.y - 2, str_w + 4, 2*str_h + 4, true)
    
    GUI.color("white")
    gfx.drawstr(str)
   
    local snap_x, snap_y = GUI.nearestmultiple(GUI.mouse.x, GUI.dev.grid_b),
                           GUI.nearestmultiple(GUI.mouse.y, GUI.dev.grid_b)
    
    gfx.x, gfx.y = GUI.w - str_w - 2, GUI.h - str_h - 2
	gfx.drawstr(" Snap: "..snap_x..", "..snap_y)
    
	gfx.a = 1
    
    GUI.redraw_z[0] = true
	
end




------------------------------------
-------- Constants/presets ---------
------------------------------------
	
    
GUI.chars = {
	
	ESCAPE		= 27,
	SPACE		= 32,
	BACKSPACE	= 8,
	TAB			= 9,
	HOME		= 1752132965,
	END			= 6647396,
	INSERT		= 6909555,
	DELETE		= 6579564,
	PGUP		= 1885828464,
	PGDN		= 1885824110,
	RETURN		= 13,
	UP			= 30064,
	DOWN		= 1685026670,
	LEFT		= 1818584692,
	RIGHT		= 1919379572,
	
	F1			= 26161,
	F2			= 26162,
	F3			= 26163,
	F4			= 26164,
	F5			= 26165,
	F6			= 26166,
	F7			= 26167,
	F8			= 26168,
	F9			= 26169,
	F10			= 6697264,
	F11			= 6697265,
	F12			= 6697266

}


--[[	Font and color presets
	
	Can be set using the accompanying functions GUI.font
	and GUI.color. i.e.
	
	GUI.font(2)				applies the Header preset
	GUI.color("elm_fill")	applies the Element Fill color preset
	
	Colors are converted from 0-255 to 0-1 when GUI.Init() runs,
	so if you need to access the values directly at any point be
	aware of which format you're getting in return.
		
]]--
GUI.fonts = {
	
				-- Font, size, bold/italics/underline
				-- 				^ One string: "b", "iu", etc.
				{"Calibri", 32},	-- 1. Title
				{"Calibri", 20},	-- 2. Header
				{"Calibri", 16},	-- 3. Label
				{"Calibri", 16},	-- 4. Value
	version = 	{"Calibri", 12, "i"},
	
}


GUI.colors = {
	
	-- Element colors
	wnd_bg = {64, 64, 64, 255},			-- Window BG
	tab_bg = {56, 56, 56, 255},			-- Tabs BG
	elm_bg = {48, 48, 48, 255},			-- Element BG
	elm_frame = {96, 96, 96, 255},		-- Element Frame
	elm_fill = {64, 192, 64, 255},		-- Element Fill
	elm_outline = {32, 32, 32, 255},	-- Element Outline
	txt = {192, 192, 192, 255},			-- Text
	
	shadow = {0, 0, 0, 48},				-- Element Shadows
	faded = {0, 0, 0, 64},
	
	-- Standard 16 colors
	black = {0, 0, 0, 255},
	white = {255, 255, 255, 255},
	red = {255, 0, 0, 255},
	lime = {0, 255, 0, 255},
	blue =  {0, 0, 255, 255},
	yellow = {255, 255, 0, 255},
	cyan = {0, 255, 255, 255},
	magenta = {255, 0, 255, 255},
	silver = {192, 192, 192, 255},
	gray = {128, 128, 128, 255},
	maroon = {128, 0, 0, 255},
	olive = {128, 128, 0, 255},
	green = {0, 128, 0, 255},
	purple = {128, 0, 128, 255},
	teal = {0, 128, 128, 255},
	navy = {0, 0, 128, 255},
	
	none = {0, 0, 0, 0},
	

}


-- Global shadow size, in pixels
GUI.shadow_dist = 2


--[[
	How fast the caret in textboxes should blink, measured in GUI update loops.
	
	'16' looks like a fairly typical textbox caret.
	
	Because each On and Off redraws the textbox's Z layer, this can cause CPU 
    issues in scripts with lots of drawing to do. In that case, raising it to 
    24 or 32 will still look alright but require less redrawing.
]]--
GUI.txt_blink_rate = 16


-- Odds are you don't need too much precision here
-- If you do, just specify GUI.pi = math.pi() in your code
GUI.pi = 3.14159




------------------------------------
-------- Table functions -----------
------------------------------------


--[[	Copy the contents of one table to another, since Lua can't do it natively
	
	Provide a second table as 'base' to use it as the basis for copying, only
	bringing over keys from the source table that don't exist in the base
	
	'depth' only exists to provide indenting for my debug messages, it can
	be left out when calling the function.
]]--
GUI.table_copy = function (source, base, depth)
	
	-- 'Depth' is only for indenting debug messages
	depth = ((not not depth) and (depth + 1)) or 0
	
	
	
	if type(source) ~= "table" then return source end
	
	local meta = getmetatable(source)
	local new = base or {}
	for k, v in pairs(source) do
		

		
		if type(v) == "table" then
			
			if base then
				new[k] = GUI.table_copy(v, base[k], depth)
			else
				new[k] = GUI.table_copy(v, nil, depth)
			end
			
		else
			if not base or (base and new[k] == nil) then 

				new[k] = v
			end
		end
		
	end
	setmetatable(new, meta)
	
	return new
	
end


-- (For debugging)
-- Returns a string of the table's contents, indented to show nested tables
-- If 't' contains classes, or a lot of nested tables, etc, be wary of using larger
-- values for max_depth - this function will happily freeze Reaper for ten minutes.
GUI.table_list = function (t, max_depth, cur_depth)
    
    local ret = {}
    local n,v
    cur_depth = cur_depth or 0
    
    for n,v in pairs(t) do
                        
                ret[#ret+1] = string.rep("\t", cur_depth) .. n .. " = "
                
                if type(v) == "table" then
                    
                    ret[#ret] = ret[#ret] .. "table:"
                    if not max_depth or cur_depth <= max_depth then
                        ret[#ret+1] = GUI.table_list(v, max_depth, cur_depth + 1)
                    end
                
                else
                
                    ret[#ret] = ret[#ret] .. tostring(v)
                end

    end
    
    return table.concat(ret, "\n")
    
end


-- Compare the contents of one table to another, since Lua can't do it natively
-- Returns true if all of t_a's keys + and values match all of t_b's.
GUI.table_compare = function (t_a, t_b)
	
	if type(t_a) ~= "table" or type(t_b) ~= "table" then return false end
	
	local key_exists = {}
	for k1, v1 in pairs(t_a) do
		local v2 = t_b[k1]
		if v2 == nil or not GUI.table_compare(v1, v2) then return false end
		key_exists[k1] = true
	end
	for k2, v2 in pairs(t_b) do
		if not key_exists[k2] then return false end
	end
	
    return true
    
end


-- 	Sorting function adapted from: http://lua-users.org/wiki/SortedIteration
GUI.full_sort = function (op1, op2)

	-- Sort strings that begin with a number as if they were numbers,
	-- i.e. so that 12 > "6 apples"
	if type(op1) == "string" and string.match(op1, "^(%-?%d+)") then
		op1 = tonumber( string.match(op1, "^(%-?%d+)") )
	end
	if type(op2) == "string" and string.match(op2, "^(%-?%d+)") then
		op2 = tonumber( string.match(op2, "^(%-?%d+)") )
	end

	--if op1 == "0" then op1 = 0 end
	--if op2 == "0" then op2 = 0 end
	local type1, type2 = type(op1), type(op2)
	if type1 ~= type2 then --cmp by type
		return type1 < type2
	elseif type1 == "number" and type2 == "number"
		or type1 == "string" and type2 == "string" then
		return op1 < op2 --comp by default
	elseif type1 == "boolean" and type2 == "boolean" then
		return op1 == true
	else
		return tostring(op1) < tostring(op2) --cmp by address
	end
	
end


--[[	Allows "for x, y in pairs(z) do" in alphabetical/numerical order
    
	Copied from Programming In Lua, 19.3
	
	Call with f = "full" to use the full sorting function above, or
	use f to provide your own sorting function as per pairs() and ipairs()
	
]]--
GUI.kpairs = function (t, f)


	if f == "full" then
		f = GUI.full_sort
	end

	local a = {}
	for n in pairs(t) do table.insert(a, n) end

	table.sort(a, f)
	
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
	
		i = i + 1
		
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
		
	end
	
	
	return iter
end


-- Accepts a table, and returns a table with the keys and values swapped, i.e.
-- {a = 1, b = 2, c = 3} --> {1 = "a", 2 = "b", 3 = "c"}
GUI.table_invert = function(t)
    
    local tmp = {}
    
    for k, v in pairs(t) do
        tmp[v] = k
    end
    
    return tmp

end


-- Looks through a table using ipairs (specify a different function with 'f') and returns
-- the first key whose value matches 'find'. 'find' is checked using string.match, so patterns
-- should be allowable. No (captures) though.

-- If you need to find multiple values in the same table, and each of them only occurs once, 
-- it will be more efficient to just copy the table with GUI.table_invert and check by key.
GUI.table_find = function(t, find, f)      
    local iter = f or ipairs
    
    for k, v in iter(t) do
        if string.match(tostring(v), find) then return k end
    end
    
end

------------------------------------
-------- Text functions ------------
------------------------------------


--[[	Apply a font preset
	
	fnt			Font preset number
				or
				A preset table -> GUI.font({"Arial", 10, "i"})
	
]]--
GUI.font = function (fnt)
	
	local font, size, str = table.unpack( type(fnt) == "table" 
                                            and fnt 
                                            or  GUI.fonts[fnt])
	
	-- Different OSes use different font sizes, for some reason
	-- This should give a roughly equal size on Mac
	if string.find(reaper.GetOS(), "OSX") then
		size = math.floor(size * 0.7)
	end
	
	-- Cheers to Justin and Schwa for this
	local flags = 0
	if str then
		for i = 1, str:len() do 
			flags = flags * 256 + string.byte(str, i) 
		end 	
	end
	
	gfx.setfont(1, font, size, flags)

end


--[[	Prepares a table of character widths
	
	Iterates through all of the GUI.fonts[] presets, storing the widths
	of every printable ASCII character in a table. 
	
	Accessable via:		GUI.txt_width[font_num][char_num]
	
	- Requires a window to have been opened in Reaper
	
	- 'get_txt_width' and 'word_wrap' will automatically run this
	  if it hasn't been run already; it may be rather clunky to use
	  on demand depending on what your script is doing, so it's
	  probably better to run this immediately after initiliazing
	  the window and then have the width table ready to use.
]]--

GUI.init_txt_width = function ()

	GUI.txt_width = {}
	local arr
	for k in pairs(GUI.fonts) do
			
		GUI.font(k)
		GUI.txt_width[k] = {}
		arr = {}
		
		for i = 1, 255 do
			
			arr[i] = gfx.measurechar(i)
			
		end	
		
		GUI.txt_width[k] = arr
		
	end
	
end


-- Returns the total width (in pixels) for a given string and font
-- (as a GUI.fonts[] preset number or name)
-- Most of the time it's simpler to use gfx.measurestr(), but scripts 
-- with a lot of text should use this instead - it's 10-12x faster.
GUI.get_txt_width = function (str, font)
	
	if not GUI.txt_width then GUI.init_txt_width() end 

	local widths = GUI.txt_width[font]
	local w = 0
	for i = 1, string.len(str) do

		w = w + widths[		string.byte(	string.sub(str, i, i)	) ]

	end

	return w

end


-- Measures a string to see how much of it will it in the given width,
-- then returns both the trimmed string and the excess
GUI.fit_txt_width = function (str, font, w)
    
    local len = string.len(str)
    
    -- Assuming 'i' is the narrowest character, get an upper limit
    local max_end = math.floor( w / GUI.txt_width[font][string.byte("i")] )

    for i = max_end, 1, -1 do
       
        if GUI.get_txt_width( string.sub(str, 1, i), font ) < w then
           
           return string.sub(str, 1, i), string.sub(str, i + 1)
           
        end
        
    end
    
    -- Worst case: not even one character will fit
    -- If this actually happens you should probably rethink your choices in life.
    return "", str

end


--[[	Returns 'str' wrapped to fit a given pixel width
	
	str		String. Can include line breaks/paragraphs; they should be preserved.
	font	Font preset number
	w		Pixel width
	indent	Number of spaces to indent the first line of each paragraph
			(The algorithm skips tab characters and leading spaces, so
			use this parameter instead)
	
	i.e.	Blah blah blah blah		-> indent = 2 ->	  Blah blah blah blah
			blah blah blah blah							blah blah blah blah

	
	pad		Indent wrapped lines by the first __ characters of the paragraph
			(For use with bullet points, etc)
			
	i.e.	- Blah blah blah blah	-> pad = 2 ->	- Blah blah blah blah
			blah blah blah blah				  	 	  blah blah blah blah
	
				
	This function expands on the "greedy" algorithm found here:
	https://en.wikipedia.org/wiki/Line_wrap_and_word_wrap#Algorithm
				
]]--
GUI.word_wrap = function (str, font, w, indent, pad)
	
	if not GUI.txt_width then GUI.init_txt_width() end
	
	local ret_str = {}

	local w_left, w_word
	local space = GUI.txt_width[font][string.byte(" ")]
	
	local new_para = indent and string.rep(" ", indent) or 0
	
	local w_pad = pad   and GUI.get_txt_width( string.sub(str, 1, pad), font ) 
                        or 0
	local new_line = "\n"..string.rep(" ", math.floor(w_pad / space)	)
	
	
	for line in string.gmatch(str, "([^\n\r]*)[\n\r]*") do
		
		table.insert(ret_str, new_para)
		
		-- Check for leading spaces and tabs
		local leading, line = string.match(line, "^([%s\t]*)(.*)$")	
		if leading then table.insert(ret_str, leading) end
		
		w_left = w
		for word in string.gmatch(line,  "([^%s]+)") do
	
			w_word = GUI.get_txt_width(word, font)
			if (w_word + space) > w_left then
				
				table.insert(ret_str, new_line)
				w_left = w - w_word
				
			else
			
				w_left = w_left - (w_word + space)
				
			end
			
			table.insert(ret_str, word)
			table.insert(ret_str, " ")
			
		end
		
		table.insert(ret_str, "\n")
		
	end
	
	table.remove(ret_str, #ret_str)
	ret_str = table.concat(ret_str)
	
	return ret_str
			
end


-- Draw the given string of the first color with a shadow 
-- of the second color (at 45' to the bottom-right)
GUI.shadow = function (str, col1, col2)
	
	local x, y = gfx.x, gfx.y
	
	GUI.color(col2)
	for i = 1, GUI.shadow_dist do
		gfx.x, gfx.y = x + i, y + i
		gfx.drawstr(str)
	end
	
	GUI.color(col1)
	gfx.x, gfx.y = x, y
	gfx.drawstr(str)
	
end


-- Draws a string using the given text and outline color presets
GUI.outline = function (str, col1, col2)

	local x, y = gfx.x, gfx.y
	
	GUI.color(col2)
	
	gfx.x, gfx.y = x + 1, y + 1
	gfx.drawstr(str)
	gfx.x, gfx.y = x - 1, y + 1
	gfx.drawstr(str)
	gfx.x, gfx.y = x - 1, y - 1
	gfx.drawstr(str)
	gfx.x, gfx.y = x + 1, y - 1
	gfx.drawstr(str)
	
	GUI.color(col1)
	gfx.x, gfx.y = x, y
	gfx.drawstr(str)
	
end


--[[	Draw a background rectangle for the given string
	
	A solid background is necessary for blitting z layers
	on their own; antialiased text with a transparent background
	looks like complete shit. This function draws a rectangle 2px
	larger than your text on all sides.
	
	Call with your position, font, and color already set:
	
	gfx.x, gfx.y = self.x, self.y
	GUI.font(self.font)
	GUI.color(self.col)
	
	GUI.text_bg(self.text)
	
	gfx.drawstr(self.text)
	
	Also accepts an optional background color:
	GUI.text_bg(self.text, "elm_bg")
	
]]--
GUI.text_bg = function (str, col)
	
	local x, y = gfx.x, gfx.y
	local r, g, b, a = gfx.r, gfx.g, gfx.b, gfx.a
	
	col = col or "wnd_bg"
	
	GUI.color(col)
	
	local w, h = gfx.measurestr(str)
	w, h = w + 4, h + 4
		
	gfx.rect(gfx.x - 2, gfx.y - 2, w, h, true)
	
	gfx.x, gfx.y = x, y
	
	gfx.set(r, g, b, a)	
	
end




------------------------------------
-------- Color functions -----------
------------------------------------


--[[	Apply a color preset
	
	col			Color preset string -> "elm_fill"
				or
				Color table -> {1, 0.5, 0.5[, 1]}
								R  G    B  [  A]
]]--			
GUI.color = function (col)

	-- If we're given a table of color values, just pass it right along
	if type(col) == "table" then

		gfx.set(col[1], col[2], col[3], col[4] or 1)
	else
		gfx.set(table.unpack(GUI.colors[col]))
	end	

end


-- Convert a hex color RRGGBB to 8-bit values R, G, B
GUI.hex2rgb = function (num)
	
	if string.sub(num, 1, 2) == "0x" then
		num = string.sub(num, 3)
	end

	local red = string.sub(num, 1, 2)
	local green = string.sub(num, 3, 4)
	local blue = string.sub(num, 5, 6)

	
	red = tonumber(red, 16) or 0
	green = tonumber(green, 16) or 0
	blue = tonumber(blue, 16) or 0

	return red, green, blue
	
end


-- Convert rgb[a] to hsv[a]; useful for gradients
-- Arguments/returns are given as 0-1
GUI.rgb2hsv = function (r, g, b, a)
	
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local chroma = max - min
	
	-- Dividing by zero is never a good idea
	if chroma == 0 then
		return 0, 0, max, (a or 1)
	end
	
	local hue
	if max == r then
		hue = ((g - b) / chroma) % 6
	elseif max == g then
		hue = ((b - r) / chroma) + 2
	elseif max == b then
		hue = ((r - g) / chroma) + 4
	else
		hue = -1
	end
	
	if hue ~= -1 then hue = hue / 6 end
	
	local sat = (max ~= 0) 	and	((max - min) / max)
							or	0
							
	return hue, sat, max, (a or 1)
	
	
end


-- ...and back the other way
GUI.hsv2rgb = function (h, s, v, a)
	
	local chroma = v * s
	
	local hp = h * 6
	local x = chroma * (1 - math.abs(hp % 2 - 1))
	
	local r, g, b
	if hp <= 1 then
		r, g, b = chroma, x, 0
	elseif hp <= 2 then
		r, g, b = x, chroma, 0
	elseif hp <= 3 then
		r, g, b = 0, chroma, x
	elseif hp <= 4 then
		r, g, b = 0, x, chroma
	elseif hp <= 5 then
		r, g, b = x, 0, chroma
	elseif hp <= 6 then
		r, g, b = chroma, 0, x
	else
		r, g, b = 0, 0, 0
	end
	
	local min = v - chroma	
	
	return r + min, g + min, b + min, (a or 1)
	
end


--[[
	Returns the color for a given position on an HSV gradient 
	between two color presets

	col_a		Tables of {R, G, B[, A]}, values from 0-1
	col_b
	
	pos			Position along the gradient, 0 = col_a, 1 = col_b
	
	returns		r, g, b, a

]]--
GUI.gradient = function (col_a, col_b, pos)
	
	local col_a = {GUI.rgb2hsv( table.unpack( type(col_a) == "table" 
                                                and col_a 
                                                or  GUI.colors(col_a) )) }
	local col_b = {GUI.rgb2hsv( table.unpack( type(col_b) == "table" 
                                                and col_b 
                                                or  GUI.colors(col_b) )) }
	
	local h = math.abs(col_a[1] + (pos * (col_b[1] - col_a[1])))
	local s = math.abs(col_a[2] + (pos * (col_b[2] - col_a[2])))
	local v = math.abs(col_a[3] + (pos * (col_b[3] - col_a[3])))
    
	local a = (#col_a == 4) 
        and  (math.abs(col_a[4] + (pos * (col_b[4] - col_a[4])))) 
        or  1
	
	return GUI.hsv2rgb(h, s, v, a)
	
end




------------------------------------
-------- Math/trig functions -------
------------------------------------


-- Round a number to the nearest integer (or optional decimal places)
GUI.round = function (num, places)

	if not places then
		return num > 0 and math.floor(num + 0.5) or math.ceil(num - 0.5)
	else
		places = 10^places
		return num > 0 and math.floor(num * places + 0.5) 
                        or math.ceil(num * places - 0.5) / places
	end
	
end


-- Returns 'val', rounded to the nearest multiple of 'snap'
GUI.nearestmultiple = function (val, snap)
    
    local int, frac = math.modf(val / snap)
    return (math.floor( frac + 0.5 ) == 1 and int + 1 or int) * snap
    
end



-- Make sure num is between min and max
-- I think it will return the correct value regardless of what
-- order you provide the values in.
GUI.clamp = function (num, min, max)
        
	if min > max then min, max = max, min end
	return math.min(math.max(num, min), max)
    
end


-- Returns an ordinal string (i.e. 30 --> 30th)
GUI.ordinal = function (num)
	
	rem = num % 10
	num = GUI.round(num)
	if num == 1 then
		str = num.."st"
	elseif rem == 2 then
		str = num.."nd"
	elseif num == 13 then
		str = num.."th"
	elseif rem == 3 then
		str = num.."rd"
	else
		str = num.."th"
	end
	
	return str
	
end


--[[ 
	Takes an angle in radians (omit Pi) and a radius, returns x, y
	Will return coordinates relative to an origin of (0,0), or absolute
	coordinates if an origin point is specified
]]--
GUI.polar2cart = function (angle, radius, ox, oy)
	
	local angle = angle * GUI.pi
	local x = radius * math.cos(angle)
	local y = radius * math.sin(angle)

	
	if ox and oy then x, y = x + ox, y + oy end

	return x, y
	
end


--[[
	Takes cartesian coords, with optional origin coords, and returns
	an angle (in radians) and radius. The angle is given without reference
	to Pi; that is, pi/4 rads would return as simply 0.25
]]--
GUI.cart2polar = function (x, y, ox, oy)
	
	local dx, dy = x - (ox or 0), y - (oy or 0)
	
	local angle = math.atan(dy, dx) / GUI.pi
	local r = math.sqrt(dx * dx + dy * dy)

	return angle, r
	
end




------------------------------------
-------- Drawing functions ---------
------------------------------------


-- Improved roundrect() function with fill, adapted from mwe's EEL example.
GUI.roundrect = function (x, y, w, h, r, antialias, fill)
	
	local aa = antialias or 1
	fill = fill or 0
	
	if fill == 0 or false then
		gfx.roundrect(x, y, w, h, r, aa)
	else
	
		if h >= 2 * r then
			
			-- Corners
			gfx.circle(x + r, y + r, r, 1, aa)			-- top-left
			gfx.circle(x + w - r, y + r, r, 1, aa)		-- top-right
			gfx.circle(x + w - r, y + h - r, r , 1, aa)	-- bottom-right
			gfx.circle(x + r, y + h - r, r, 1, aa)		-- bottom-left
			
			-- Ends
			gfx.rect(x, y + r, r, h - r * 2)
			gfx.rect(x + w - r, y + r, r + 1, h - r * 2)
				
			-- Body + sides
			gfx.rect(x + r, y, w - r * 2, h + 1)
			
		else
		
			r = (h / 2 - 1)
		
			-- Ends
			gfx.circle(x + r, y + r, r, 1, aa)
			gfx.circle(x + w - r, y + r, r, 1, aa)
			
			-- Body
			gfx.rect(x + r, y, w - (r * 2), h)
			
		end	
		
	end
	
end


-- Improved triangle() function with optional non-fill
GUI.triangle = function (fill, ...)
	
	-- Pass any calls for a filled triangle on to the original function
	if fill then
		
		gfx.triangle(...)
		
	else
	
		-- Store all of the provided coordinates into an array
		local coords = {...}
		
		-- Duplicate the first pair at the end, so the last line will
		-- be drawn back to the starting point.
		table.insert(coords, coords[1])
		table.insert(coords, coords[2])
	
		-- Draw a line from each pair of coords to the next pair.
		for i = 1, #coords - 2, 2 do			
				
			gfx.line(coords[i], coords[i+1], coords[i+2], coords[i+3])
		
		end		
	
	end
	
end




------------------------------------
-------- Misc. functions -----------
------------------------------------


--[[	Use when working with file paths if you need to add your own /s
		(Borrowed from X-Raym)
        
        Apr. 22/18 - Further reading leads me to believe that simply using
        '/' as a separator should work just fine on Windows, Mac, and Linux.
]]--
GUI.file_sep = string.match(reaper.GetOS(), "Win") and "\\" or "/"


-- To open files in their default app, or URLs in a browser
-- Copied from Heda; cheers!
GUI.open_file = function (path)

	local OS = reaper.GetOS()
    
    if OS == "OSX32" or OS == "OSX64" then
		os.execute('open "" "' .. path .. '"')
	else
		os.execute('start "" "' .. path .. '"')
	end
  
end


-- Also might need to know this
GUI.SWS_exists = reaper.APIExists("CF_GetClipboardBig")


-- Why does Lua not have an operator for this?
GUI.xor = function(a, b)
   
   return (a or b) and not (a and b)
    
end


--[[
Returns x,y coordinates for a window with the specified anchor position

If no anchor is specified, it will default to the top-left corner of the screen.
	x,y		offset coordinates from the anchor position
	w,h		window dimensions
	anchor	"screen" or "mouse"
	corner	"TL"
			"T"
			"TR"
			"R"
			"BR"
			"B"
			"BL"
			"L"
			"C"
]]--
GUI.get_window_pos = function (x, y, w, h, anchor, corner)

	local ax, ay, aw, ah = 0, 0, 0 ,0
		
	local __, __, scr_w, scr_h = reaper.my_getViewport(x, y, x + w, y + h, 
                                                       x, y, x + w, y + h, 1)
	
	if anchor == "screen" then
		aw, ah = scr_w, scr_h
	elseif anchor =="mouse" then
		ax, ay = reaper.GetMousePosition()
	end
	
	local cx, cy = 0, 0
	if corner then
		local corners = {
			TL = 	{0, 				0},
			T =		{(aw - w) / 2, 		0},
			TR = 	{(aw - w) - 16,		0},
			R =		{(aw - w) - 16,		(ah - h) / 2},
			BR = 	{(aw - w) - 16,		(ah - h) - 40},
			B =		{(aw - w) / 2, 		(ah - h) - 40},
			BL = 	{0, 				(ah - h) - 40},
			L =	 	{0, 				(ah - h) / 2},
			C =	 	{(aw - w) / 2,		(ah - h) / 2},
		}
		
		cx, cy = table.unpack(corners[corner])
	end	
	
	x = x + ax + cx
	y = y + ay + cy
	
--[[
	
	Disabled until I can figure out the multi-monitor issue
	
	-- Make sure the window is entirely on-screen
	local l, t, r, b = x, y, x + w, y + h
	
	if l < 0 then x = 0 end
	if r > scr_w then x = (scr_w - w - 16) end
	if t < 0 then y = 0 end
	if b > scr_h then y = (scr_h - h - 40) end
]]--	
	
	return x, y	
	
end


-- Display the GUI version number
-- Set GUI.version = 0 to hide this
GUI.Draw_Version = function ()
	
	if not GUI.version then return 0 end

	local str = "Lokasenna_GUI "..GUI.version
	
	GUI.font("version")
	GUI.color("txt")
	
	local str_w, str_h = gfx.measurestr(str)
	
	--gfx.x = GUI.w - str_w - 4
	--gfx.y = GUI.h - str_h - 4
	gfx.x = gfx.w - str_w - 6
	gfx.y = gfx.h - str_h - 4
	
	gfx.drawstr(str)	
	
end




------------------------------------
-------- The End -------------------
------------------------------------


-- Make our table full of functions available to the parent script
return GUI

end
GUI = GUI_table()

----------------------------------------------------------------
----------------------------To here-----------------------------
----------------------------------------------------------------

---- End of file: F:/Github Repositories/Lokasenna_GUI/Core.lua ----



---- Beginning of file: F:/Github Repositories/Lokasenna_GUI/Classes/Class - Button.lua ----

--[[	Lokasenna_GUI - Button class 
	
	(Adapted from eugen2777's simple GUI template.)
	
	---- User parameters ----

	(name, z, x, y, w, h, caption, func[, ...])

Required:
z				Element depth, used for hiding and disabling layers. 1 is the highest.
x, y			Coordinates of top-left corner
w, h			Button size
caption			Label
func			Function to perform when clicked

                Note that you only need give a reference to the function:

                GUI.New("my_button", "Button", 1, 32, 32, 64, 32, "Button", my_func)

                Unless the function is returning a function (hey, Lua is weird), you don't 
                want to actually run it:

                GUI.New("my_button", "Button", 1, 32, 32, 64, 32, "Button", my_func())

Optional:
...				Any parameters to pass to that function, separated by commas as they
				would be if calling the function directly.


Additional:
r_func			Function to perform when right-clicked
r_params		If provided, any parameters to pass to that function
font			Button label's font
col_txt			Button label's color

col_fill		Button color. 
				*** If you change this, call :init() afterward ***


Extra methods:
exec			Force a button-click, i.e. for allowing buttons to have a hotkey:
					[Y]es	[N]o	[C]ancel
					
				Params:
				r			Boolean, optional. r = true will run the button's
							right-click action instead

]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


-- Button - New
GUI.Button = GUI.Element:new()
function GUI.Button:new(name, z, x, y, w, h, caption, func, ...)

	local Button = {}
	
	Button.name = name
	Button.type = "Button"
	
	Button.z = z
	GUI.redraw_z[z] = true	
	
	Button.x, Button.y, Button.w, Button.h = x, y, w, h

	Button.caption = caption
	
	Button.font = 3
	Button.col_txt = "txt"
	Button.col_fill = "elm_frame"
	
	Button.func = func or function () end
	Button.params = {...}
	
	Button.state = 0

	setmetatable(Button, self)
	self.__index = self
	return Button

end


function GUI.Button:init()
	
	self.buff = self.buff or GUI.GetBuffer()
	
	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*self.w + 4, self.h + 2)
	
	GUI.color(self.col_fill)
	GUI.roundrect(1, 1, self.w, self.h, 4, 1, 1)
	GUI.color("elm_outline")
	GUI.roundrect(1, 1, self.w, self.h, 4, 1, 0)
	
	
	local r, g, b, a = table.unpack(GUI.colors["shadow"])
	gfx.set(r, g, b, 1)
	GUI.roundrect(self.w + 2, 1, self.w, self.h, 4, 1, 1)
	gfx.muladdrect(self.w + 2, 1, self.w + 2, self.h + 2, 1, 1, 1, a, 0, 0, 0, 0 )
	
	
end


function GUI.Button:ondelete()
	
	GUI.FreeBuffer(self.buff)
	
end



-- Button - Draw.
function GUI.Button:draw()
	
	local x, y, w, h = self.x, self.y, self.w, self.h
	local state = self.state

	-- Draw the shadow if not pressed
	if state == 0 then
		
		for i = 1, GUI.shadow_dist do
			
			gfx.blit(self.buff, 1, 0, w + 2, 0, w + 2, h + 2, x + i - 1, y + i - 1)
			
		end

	end
	
	gfx.blit(self.buff, 1, 0, 0, 0, w + 2, h + 2, x + 2 * state - 1, y + 2 * state - 1) 	
	
	-- Draw the caption
	GUI.color(self.col_txt)
	GUI.font(self.font)
    
    local str = self.caption
    str = str:gsub([[\n]],"\n")
	
	local str_w, str_h = gfx.measurestr(str)
	gfx.x = x + 2 * state + ((w - str_w) / 2)
	gfx.y = y + 2 * state + ((h - str_h) / 2)
	gfx.drawstr(str)
	
end


-- Button - Mouse down.
function GUI.Button:onmousedown()
	
	self.state = 1
	self:redraw()

end


-- Button - Mouse up.
function GUI.Button:onmouseup() 
	
	self.state = 0
	
	-- If the mouse was released on the button, run func
	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) then
		
		self.func(table.unpack(self.params))
		
	end
	self:redraw()

end

function GUI.Button:ondoubleclick()
	
	self.state = 0
	
	end


-- Button - Right mouse up
function GUI.Button:onmouser_up()

	if GUI.IsInside(self, GUI.mouse.x, GUI.mouse.y) and self.r_func then
	
		self.r_func(table.unpack(self.r_params))

	end
end


-- Button - Execute (extra method)
-- Used for allowing hotkeys to press a button
function GUI.Button:exec(r)
	
	if r then
		self.r_func(table.unpack(self.r_params))
	else
		self.func(table.unpack(self.params))
	end
	
end


---- End of file: F:/Github Repositories/Lokasenna_GUI/Classes/Class - Button.lua ----



---- Beginning of file: F:/Github Repositories/Lokasenna_GUI/Classes/Class - Menubox.lua ----

--[[	Lokasenna_GUI - MenuBox class
	
	---- User parameters ----
	
	(name, z, x, y, w, h, caption, opts[, pad, noarrow])
	
Required:
z				Element depth, used for hiding and disabling layers. 1 is the highest.
x, y			Coordinates of top-left corner
w, h
caption			Label displayed to the left of the menu box
opts			Comma-separated string of options. As with gfx.showmenu, there are
				a few special symbols that can be added at the beginning of an option:
				
                    ! : Checked
					# : grayed out
					> : this menu item shows a submenu
					< : last item in the current submenu
					An empty field will appear as a separator in the menu.
					
				
				
Optional:
pad				Padding between the label and the box
noarrow         Boolean. Removes the arrow from the menubox.


Additional:
col_txt         Value color
col_cap         Caption color
bg				Color to be drawn underneath the label. Defaults to "wnd_bg"
font_a			Font for the menu's label
font_b			Font for the menu's current value
align           Flags for gfx.drawstr:

                    flags&1: center horizontally
                    flags&2: right justify
                    flags&4: center vertically
                    flags&8: bottom justify
                    flags&256: ignore right/bottom, 
                    otherwise text is clipped to (gfx.x, gfx.y, right, bottom)
                    

Extra methods:



GUI.Val()		Returns the current menu option, numbered from 1. Numbering does include
				separators and submenus:
				
					New					1
					--					
					Open				3
					Save				4
					--					
					Recent	>	a.txt	7
								b.txt	8
								c.txt	9
					--
					Options				11
					Quit				12
										
GUI.Val(new)	Sets the current menu option, numbered as above.


]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


GUI.Menubox = GUI.Element:new()
function GUI.Menubox:new(name, z, x, y, w, h, caption, opts, pad, noarrow)
	
	local menu = {}
	
	menu.name = name
	menu.type = "Menubox"
	
	menu.z = z
	GUI.redraw_z[z] = true	
	
	menu.x, menu.y, menu.w, menu.h = x, y, w, h

	menu.caption = caption
	menu.bg = "wnd_bg"
	
	menu.font_a = 3
	menu.font_b = 4
	
	menu.col_cap = "txt"
	menu.col_txt = "txt"
	
	menu.pad = pad or 4
    menu.noarrow = noarrow or false
    menu.align = 0
	
    if type(opts) == "string" then
        -- Parse the string of options into a table
        menu.optarray = {}

        for word in string.gmatch(opts, '([^,]+)') do
            menu.optarray[#menu.optarray+1] = word
        end
    elseif type(opts) == "table" then
        menu.optarray = opts
    end
	
	menu.retval = 1
	
	setmetatable(menu, self)
    self.__index = self 
    return menu
	
end


function GUI.Menubox:init()
	
	local w, h = self.w, self.h
	
	self.buff = GUI.GetBuffer()
	
	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*w + 4, 2*h + 4)
	
    self:drawframe()
    
    if not self.noarrow then self:drawarrow() end

end


function GUI.Menubox:draw()	
	
	local x, y, w, h = self.x, self.y, self.w, self.h
	
	local caption = self.caption
	local focus = self.focus
	

	-- Draw the caption
	if caption and caption ~= "" then self:drawcaption() end
	
    
    -- Blit the shadow + frame
	for i = 1, GUI.shadow_dist do
		gfx.blit(self.buff, 1, 0, w + 2, 0, w + 2, h + 2, x + i - 1, y + i - 1)	
	end
	
	gfx.blit(self.buff, 1, 0, 0, (focus and (h + 2) or 0) , w + 2, h + 2, x - 1, y - 1) 	
	

    -- Draw the text
    self:drawtext()
	
end


function GUI.Menubox:val(newval)
	
	if newval then
		self.retval = newval
		self:redraw()		
	else
		return math.floor(self.retval), self.optarray[self.retval]
	end
	
end


------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.Menubox:onmouseup()

    -- Bypass option for GUI Builder
    if not self.focus then
        self:redraw()
        return
    end
    
	-- The menu doesn't count separators in the returned number,
	-- so we'll do it here
	local menu_str, sep_arr = self:prepmenu()
	
	gfx.x, gfx.y = GUI.mouse.x, GUI.mouse.y	
	local curopt = gfx.showmenu(menu_str)
	
	if #sep_arr > 0 then curopt = self:stripseps(curopt, sep_arr) end	
	if curopt ~= 0 then self.retval = curopt end

	self.focus = false
	self:redraw()	
    
end


-- This is only so that the box will light up
function GUI.Menubox:onmousedown()
	self:redraw()
end


function GUI.Menubox:onwheel()
	
	-- Avert a crash if there aren't at least two items in the menu
	--if not self.optarray[2] then return end	
	
	-- Check for illegal values, separators, and submenus
    self.retval = self:validateoption(  GUI.round(self.retval - GUI.mouse.inc),
                                        GUI.round((GUI.mouse.inc > 0) and 1 or -1) )

	self:redraw()	
    
end


------------------------------------
-------- Drawing methods -----------
------------------------------------


function GUI.Menubox:drawframe()

    local x, y, w, h = self.x, self.y, self.w, self.h
	local r, g, b, a = table.unpack(GUI.colors["shadow"])
	gfx.set(r, g, b, 1)
	gfx.rect(w + 3, 1, w, h, 1)
	gfx.muladdrect(w + 3, 1, w + 2, h + 2, 1, 1, 1, a, 0, 0, 0, 0 )
	
	GUI.color("elm_bg")
	gfx.rect(1, 1, w, h)
	gfx.rect(1, w + 3, w, h)
	
	GUI.color("elm_frame")
	gfx.rect(1, 1, w, h, 0)
	if not self.noarrow then gfx.rect(1 + w - h, 1, h, h, 1) end
	
	GUI.color("elm_fill")
	gfx.rect(1, h + 3, w, h, 0)
	gfx.rect(2, h + 4, w - 2, h - 2, 0)

end


function GUI.Menubox:drawarrow()

    local x, y, w, h = self.x, self.y, self.w, self.h
    gfx.rect(1 + w - h, h + 3, h, h, 1)

    GUI.color("elm_bg")
    
    -- Triangle size
    local r = 5
    local rh = 2 * r / 5
    
    local ox = (1 + w - h) + h / 2
    local oy = 1 + h / 2 - (r / 2)

    local Ax, Ay = GUI.polar2cart(1/2, r, ox, oy)
    local Bx, By = GUI.polar2cart(0, r, ox, oy)
    local Cx, Cy = GUI.polar2cart(1, r, ox, oy)
    
    GUI.triangle(true, Ax, Ay, Bx, By, Cx, Cy)
    
    oy = oy + h + 2
    
    Ax, Ay = GUI.polar2cart(1/2, r, ox, oy)
    Bx, By = GUI.polar2cart(0, r, ox, oy)
    Cx, Cy = GUI.polar2cart(1, r, ox, oy)	
    
    GUI.triangle(true, Ax, Ay, Bx, By, Cx, Cy)	    
    
end


function GUI.Menubox:drawcaption()
 
    GUI.font(self.font_a)
    local str_w, str_h = gfx.measurestr(self.caption)    
    
    gfx.x = self.x - str_w - self.pad
    gfx.y = self.y + (self.h - str_h) / 2
    
    GUI.text_bg(self.caption, self.bg)
    GUI.shadow(self.caption, self.col_cap, "shadow")

end


function GUI.Menubox:drawtext()

    -- Make sure retval hasn't been accidentally set to something illegal
    self.retval = self:validateoption(tonumber(self.retval) or 1)

    -- Strip gfx.showmenu's special characters from the displayed value
	local text = string.match(self.optarray[self.retval], "^[<!#]?(.+)")

	-- Draw the text
	GUI.font(self.font_b)
	GUI.color(self.col_txt)
	
	--if self.output then text = self.output(text) end
    
    if self.output then
        local t = type(self.output)

        if t == "string" or t == "number" then
            text = self.output
        elseif t == "table" then
            text = self.output[text]
        elseif t == "function" then
            text = self.output(text)
        end
    end
    
    -- Avoid any crashes from weird user data
    text = tostring(text)


    str_w, str_h = gfx.measurestr(text)
	gfx.x = self.x + 4
	gfx.y = self.y + (self.h - str_h) / 2
    
    local r = gfx.x + self.w - 8 - (self.noarrow and 0 or self.h)
    local b = gfx.y + str_h
	gfx.drawstr(text, self.align, r, b)       
    
end


------------------------------------
-------- Input helpers -------------
------------------------------------


-- Put together a string for gfx.showmenu from the values in optarray
function GUI.Menubox:prepmenu()

	local str_arr = {}
    local sep_arr = {}    
    local menu_str = ""
    
	for i = 1, #self.optarray do
		
		-- Check off the currently-selected option
		if i == self.retval then menu_str = menu_str .. "!" end

        table.insert(str_arr, tostring( type(self.optarray[i]) == "table"
                                            and self.optarray[i][1]
                                            or  self.optarray[i]
                                      )
                    )

		if str_arr[#str_arr] == ""
		or string.sub(str_arr[#str_arr], 1, 1) == ">" then 
			table.insert(sep_arr, i) 
		end

		table.insert( str_arr, "|" )

	end
	
	menu_str = table.concat( str_arr )
	
	return string.sub(menu_str, 1, string.len(menu_str) - 1), sep_arr

end


-- Adjust the menu's returned value to ignore any separators ( --------- )
function GUI.Menubox:stripseps(curopt, sep_arr)

    for i = 1, #sep_arr do
        if curopt >= sep_arr[i] then
            curopt = curopt + 1
        else
            break
        end
    end
    
    return curopt
    
end    


function GUI.Menubox:validateoption(val, dir)
    
    dir = dir or 1
    
    while true do

        -- Past the first option, look upward instead
        if val < 1 then
            val = 1
            dir = 1        

        -- Past the last option, look downward instead
        elseif val > #self.optarray then
            val = #self.optarray
            dir = -1

        end
        
        -- Don't stop on separators, folders, or grayed-out options        
        local opt = string.sub(self.optarray[val], 1, 1)
        if opt == "" or opt == ">" or opt == "#" then
            val = val - dir
            
        -- This option is good
        else
            break
        end
    
    end
    
    return val    
    
end

---- End of file: F:/Github Repositories/Lokasenna_GUI/Classes/Class - Menubox.lua ----



---- Beginning of file: F:/Github Repositories/Lokasenna_GUI/Classes/Class - Textbox.lua ----

--[[	Lokasenna_GUI - Textbox class
	
	---- User parameters ----

	(name, z, x, y, w, h[, caption, pad])

Required:
z				Element depth, used for hiding and disabling layers. 1 is the highest.
x, y			Coordinates of top-left corner
w, h			Width and height of the textbox

Optional:
caption			Label shown to the left of the textbox
pad				Padding between the label and the textbox


Additional:
bg				Color to be drawn underneath the label. Defaults to "wnd_bg"
shadow			Boolean. Draw a shadow beneath the label?
color			Text color
font_a			Label font
font_b			Text font
cap_pos         Position of the text box's label.
                "left", "right", "top", "bottom"

focus			Whether the textbox is "in focus" or not, allowing users to type.
				This setting is automatically updated, so you shouldn't need to
				change it yourself in most cases.
				

Extra methods:


GUI.Val()		Returns the contents of the textbox.
GUI.Val(new)	Sets the contents of the textbox.


]]--

if not GUI then
	reaper.ShowMessageBox("Couldn't access GUI functions.\n\nLokasenna_GUI - Core.lua must be loaded prior to any classes.", "Library Error", 0)
	missing_lib = true
	return 0
end


-- Managing text is MUCH easier with a monospace font.
GUI.fonts.textbox = {"Courier", 8}


GUI.Textbox = GUI.Element:new()
function GUI.Textbox:new(name, z, x, y, w, h, caption, pad)
	
	local txt = {}
	
	txt.name = name
	txt.type = "Textbox"
	
	txt.z = z
	GUI.redraw_z[z] = true	
	
	txt.x, txt.y, txt.w, txt.h = x, y, w, h

    txt.retval = ""
    txt.undo_states = {}
    txt.redo_states = {}
	txt.caption = caption or ""
	txt.pad = pad or 4
	
	txt.shadow = true
	txt.bg = "wnd_bg"
	txt.color = "txt"
	txt.blink = 0    
	
	txt.font_a = 3
    
	txt.font_b = "textbox"
    
    txt.cap_pos = "left"
	
    txt.wnd_pos = 0
	txt.caret = 0
	txt.sel_s, txt.sel_e = nil, nil

    txt.char_h, txt.wnd_h, txt.wnd_w, txt.char_w = nil, nil, nil, nil

	txt.focus = false
    
    txt.undo_limit = 20
	
	setmetatable(txt, self)
	self.__index = self
	return txt

end


function GUI.Textbox:init()
	
	local x, y, w, h = self.x, self.y, self.w, self.h
	
	self.buff = GUI.GetBuffer()
	
	gfx.dest = self.buff
	gfx.setimgdim(self.buff, -1, -1)
	gfx.setimgdim(self.buff, 2*w, h)
	
	GUI.color("elm_bg")
	gfx.rect(0, 0, 2*w, h, 1)
	
	GUI.color("elm_frame")
	gfx.rect(0, 0, w, h, 0)
	
	GUI.color("elm_fill")
	gfx.rect(w, 0, w, h, 0)
	gfx.rect(w + 1, 1, w - 2, h - 2, 0)
	
	
end


function GUI.Textbox:draw()
	
	-- Some values can't be set in :init() because the window isn't
	-- open yet - measurements won't work.
	if not self.wnd_w then self:wnd_recalc() end
    
	if self.caption and self.caption ~= "" then self:drawcaption() end
	
	-- Blit the textbox frame, and make it brighter if focused.
	gfx.blit(self.buff, 1, 0, (self.focus and self.w or 0), 0, 
            self.w, self.h, self.x, self.y)

    if self.retval ~= "" then self:drawtext() end

	if self.focus then

		if self.sel_s then self:drawselection() end
		if self.show_caret then self:drawcaret() end
		
	end
    
    self:drawgradient()    
	
end


function GUI.Textbox:val(newval)
	
	if newval then
		self.retval = newval
		self:redraw()		
	else
		return self.retval
	end
    
end


-- Just for making the caret blink
function GUI.Textbox:onupdate()
	
	if self.focus then
	
		if self.blink == 0 then
			self.show_caret = true
			self:redraw()
		elseif self.blink == math.floor(GUI.txt_blink_rate / 2) then
			self.show_caret = false
			self:redraw()
		end
		self.blink = (self.blink + 1) % GUI.txt_blink_rate

	end
	
end

-- Make sure the box highlight goes away
function GUI.Textbox:lostfocus()
    
    self:redraw()
    
end



------------------------------------
-------- Input methods -------------
------------------------------------


function GUI.Textbox:onmousedown()

    self.caret = self:getcaret(GUI.mouse.x)
    
    -- Reset the caret so the visual change isn't laggy
    self.blink = 0
    
    -- Shift+click to select text
    if GUI.mouse.cap & 8 == 8 and self.caret then
        
        self.sel_s, self.sel_e = self.caret, self.caret
        
    else
    
        self.sel_s, self.sel_e = nil, nil
        
    end
    
    self:redraw()
	
end


function GUI.Textbox:ondoubleclick()
	
	self:selectword()
    
end


function GUI.Textbox:ondrag()
	
	self.sel_s = self:getcaret(GUI.mouse.ox, GUI.mouse.oy)
    self.sel_e = self:getcaret(GUI.mouse.x, GUI.mouse.y)
    
	self:redraw()	
    
end


function GUI.Textbox:ontype()
	
	local char = GUI.char

    -- Navigation keys, Return, clipboard stuff, etc
    if self.keys[char] then
        
        local shift = GUI.mouse.cap & 8 == 8
        
        if shift and not self.sel then
            self.sel_s = self.caret
        end
        
        -- Flag for some keys (clipboard shortcuts) to skip
        -- the next section
        local bypass = self.keys[char](self)
        
        if shift and char ~= GUI.chars.BACKSPACE then
            
            self.sel_e = self.caret
            
        elseif not bypass then
        
            self.sel_s, self.sel_e = nil, nil
        
        end
        
    -- Typeable chars
    elseif GUI.clamp(32, char, 254) == char then
    
        if self.sel_s then self:deleteselection() end
        
        self:insertchar(char)

    end
    self:windowtocaret()
    
    -- Reset the caret so the visual change isn't laggy
    self.blink = 0
    
end


function GUI.Textbox:onwheel(inc)
   
   local len = string.len(self.retval)
   
   if len <= self.wnd_w then return end
   
   -- Scroll right/left
   local dir = inc > 0 and 3 or -3
   self.wnd_pos = GUI.clamp(0, self.wnd_pos + dir, len + 2 - self.wnd_w)
   
   self:redraw()    
    
end




------------------------------------
-------- Drawing methods -----------
------------------------------------

	
function GUI.Textbox:drawcaption()
    
    local caption = self.caption
    
    GUI.font(self.font_a)
    
    local str_w, str_h = gfx.measurestr(caption)

    if self.cap_pos == "left" then
        gfx.x = self.x - str_w - self.pad
        gfx.y = self.y + (self.h - str_h) / 2    
    
    elseif self.cap_pos == "top" then
        gfx.x = self.x + (self.w - str_w) / 2
        gfx.y = self.y - str_h - self.pad
    
    elseif self.cap_pos == "right" then
        gfx.x = self.x + self.w + self.pad
        gfx.y = self.y + (self.h - str_h) / 2
    
    elseif self.cap_pos == "bottom" then
        gfx.x = self.x + (self.w - str_w) / 2
        gfx.y = self.y + self.h + self.pad
    
    end
    
    GUI.text_bg(caption, self.bg)
    
    if self.shadow then 
        GUI.shadow(caption, self.color, "shadow") 
    else
        GUI.color(self.color)
        gfx.drawstr(caption)
    end

end


function GUI.Textbox:drawtext()

	GUI.color(self.color)
	GUI.font(self.font_b)

    local str = string.sub(self.retval, self.wnd_pos + 1)

    -- I don't think self.pad should affect the text at all. Looks weird,
    -- messes with the amount of visible text too much.
	gfx.x = self.x + 4 -- + self.pad
	gfx.y = self.y + (self.h - gfx.texth) / 2
    local r = gfx.x + self.w - 8 -- - 2*self.pad
    local b = gfx.y + gfx.texth
    
	gfx.drawstr(str, 0, r, b)
    
end


function GUI.Textbox:drawcaret()
    
    local caret_wnd = self:adjusttowindow(self.caret)

    if caret_wnd then

        GUI.color("txt")
        
        gfx.rect(   self.x + self.pad + (caret_wnd * self.char_w),
                    self.y + self.pad,
                    self.insert_caret and self.char_w or 2,
                    self.char_h - 2)
                    
    end
    
end


function GUI.Textbox:drawselection()

    local x, w
    
    GUI.color("elm_fill")
    gfx.a = 0.5
    gfx.mode = 1    
    
    local s, e = self.sel_s, self.sel_e
    
    if e < s then s, e = e, s end


    local x = GUI.clamp(self.wnd_pos, s, self:wnd_right())
    local w = GUI.clamp(x, e, self:wnd_right()) - x

    if self:selectionvisible(x, w) then
        
        -- Convert from char-based coords to actual pixels
        x = self.x + self.pad + (x - self.wnd_pos) * self.char_w
        
        y = self.y + self.pad

        w = w * self.char_w
        w = math.min(w, self.x + self.w - x - self.pad)

        h = self.char_h
        
        gfx.rect(x, y, w, h, true)
        
    end    
        
    gfx.mode = 0
    
	-- Later calls to GUI.color should handle this, but for
	-- some reason they aren't always.    
    gfx.a = 1
    
end


function GUI.Textbox:drawgradient()
    
    local left, right = self.wnd_pos > 0, self.wnd_pos < (string.len(self.retval) - self.wnd_w + 2)
    if not (left or right) then return end
    
    local x, y, w, h = self.x, self.y, self.w, self.h
    local fade_w = 12

    GUI.color("elm_bg")
    for i = 0, fade_w do
    
        gfx.a = i/fade_w
        
        -- Left
        if left then
            local x = x + 2 + fade_w - i
            gfx.line(x, y + 2, x, y + h - 4)
        end
        
        -- Right
        if right then
            local x = x + w - 3 - fade_w + i
            gfx.line(x, y + 2, x, y + h - 4)
        end
        
    end
    
end




------------------------------------
-------- Selection methods ---------
------------------------------------


-- Make sure at least part of the selection is visible
function GUI.Textbox:selectionvisible(x, w)
    
	return 		w > 0                   -- Selection has width,
			and x + w > self.wnd_pos    -- doesn't end to the left
            and x < self:wnd_right()    -- and doesn't start to the right
    
end


function GUI.Textbox:selectall()
    
    self.sel_s = 0
    self.caret = 0
    self.sel_e = string.len(self.retval)
    
end


function GUI.Textbox:selectword()
    
    local str = self.retval
    
    if not str or str == "" then return 0 end
    
    self.sel_s = string.find( str:sub(1, self.caret), "%s[%S]+$") or 0
    self.sel_e = (      string.find( str, "%s", self.sel_s + 1)
                    or  string.len(str) + 1)
                - (self.wnd_pos > 0 and 2 or 1) -- Kludge, fixes length issues

end


function GUI.Textbox:deleteselection()   

    if not (self.sel_s and self.sel_e) then return 0 end

    self:storeundostate()

    local s, e = self.sel_s, self.sel_e
        
    if s > e then
        s, e = e, s
    end
    
    self.retval =   string.sub(self.retval or "", 1, s)..
                    string.sub(self.retval or "", e + 1)
    
    self.caret = s
    
    self.sel_s, self.sel_e = nil, nil
    self:windowtocaret()
    
    
end


function GUI.Textbox:getselectedtext()
    
    local s, e= self.sel_s, self.sel_e
    
    if s > e then s, e = e, s end
    
    return string.sub(self.retval, s + 1, e)    
    
end


function GUI.Textbox:toclipboard(cut)
    
    if self.sel_s and self:SWS_clipboard() then
        
        local str = self:getselectedtext()
        reaper.CF_SetClipboard(str)
        if cut then self:deleteselection() end
        
    end   
    
end


function GUI.Textbox:fromclipboard()
    
    if self:SWS_clipboard() then
        
        -- reaper.SNM_CreateFastString( str )
        -- reaper.CF_GetClipboardBig( output )
        local fast_str = reaper.SNM_CreateFastString("")
        local str = reaper.CF_GetClipboardBig(fast_str)
        reaper.SNM_DeleteFastString(fast_str)
        
        self:insertstring(str, true)

    end   
    
end



------------------------------------
-------- Window/pos helpers --------
------------------------------------


function GUI.Textbox:wnd_recalc()
    
    GUI.font(self.font_b)
    
    self.char_h = gfx.texth
    self.char_w = gfx.measurestr("_")
    self.wnd_w = math.floor(self.w / self.char_w)
    
end


function GUI.Textbox:wnd_right()
    
   return self.wnd_pos + self.wnd_w 
    
end


-- See if a given position is in the visible window
-- If so, adjust it from absolute to window-relative
-- If not, returns nil
function GUI.Textbox:adjusttowindow(x)
    
    return ( GUI.clamp(self.wnd_pos, x, self:wnd_right() - 1) == x )
        and x - self.wnd_pos
        or nil

end


function GUI.Textbox:windowtocaret()
    
    if self.caret < self.wnd_pos + 1 then
        self.wnd_pos = math.max(0, self.caret - 1)
    elseif self.caret > (self:wnd_right() - 2) then
        self.wnd_pos = self.caret + 2 - self.wnd_w
    end
    
end


function GUI.Textbox:getcaret(x)

    x = math.floor(  ((x - self.x) / self.w) * self.wnd_w) + self.wnd_pos
    return GUI.clamp(0, x, string.len(self.retval or ""))

end




------------------------------------
-------- Char/string helpers -------
------------------------------------


function GUI.Textbox:insertstring(str, move_caret)

    self:storeundostate()
    
    str = self:sanitizetext(str)
    
    if self.sel_s then self:deleteselection() end
    
    local s = self.caret
    
    local pre, post =   string.sub(self.retval or "", 1, s),
                        string.sub(self.retval or "", s + 1)
                        
    self.retval = pre .. tostring(str) .. post
    
    if move_caret then self.caret = self.caret + string.len(str) end
    
end


function GUI.Textbox:insertchar(char)
    
    self:storeundostate()
    
    local a, b = string.sub(self.retval, 1, self.caret), 
                 string.sub(self.retval, self.caret + (self.insert_caret and 2 or 1))
                
    self.retval = a..string.char(char)..b
    self.caret = self.caret + 1
    
end


function GUI.Textbox:carettoend()
    
   return string.len(self.retval or "")
    
end


-- Replace any characters that we're unable to reproduce properly
function GUI.Textbox:sanitizetext(str)

    str = tostring(str)
    str = str:gsub("\t", "    ")
    str = str:gsub("[\n\r]", " ")
    return str

end


function GUI.Textbox:ctrlchar(func, ...)
    
    if GUI.mouse.cap & 4 == 4 then
        func(self, ... and table.unpack({...}))
        
        -- Flag to bypass the "clear selection" logic in :ontype()        
        return true
        
    else
        self:insertchar(GUI.char)        
    end    

end

-- Non-typing key commands
-- A table of functions is more efficient to access than using really
-- long if/then/else structures.
GUI.Textbox.keys = {
    
    [GUI.chars.LEFT] = function(self)
       
        self.caret = math.max( 0, self.caret - 1)
        
    end,
    
    [GUI.chars.RIGHT] = function(self)
        
        self.caret = math.min( string.len(self.retval), self.caret + 1 )
        
    end,
    
    [GUI.chars.UP] = function(self)
    
        self.caret = 0
        
    end,
    
    [GUI.chars.DOWN] = function(self)
        
        self.caret = string.len(self.retval)
        
    end,    
    
    [GUI.chars.BACKSPACE] = function(self)
        
        self:storeundostate()
        
        if self.sel_s then
            
            self:deleteselection()
            
        else
        
        if self.caret <= 0 then return end
            
            local str = self.retval
            self.retval =   string.sub(str, 1, self.caret - 1)..
                            string.sub(str, self.caret + 1, -1)
            self.caret = math.max(0, self.caret - 1)
            
        end
        
    end,
    
    [GUI.chars.INSERT] = function(self)
        
        self.insert_caret = not self.insert_caret        
        
    end,

    [GUI.chars.DELETE] = function(self)
        
        self:storeundostate()
        
        if self.sel_s then
            
            self:deleteselection()
            
        else
        
            local str = self.retval
            self.retval =   string.sub(str, 1, self.caret) ..
                            string.sub(str, self.caret + 2)
                            
        end
        
    end,
    
    [GUI.chars.RETURN] = function(self)
        
        self.focus = false
        self:lostfocus()
        self:redraw()

    end,
    
    [GUI.chars.HOME] = function(self)
        
        self.caret = 0
        
    end,
    
    [GUI.chars.END] = function(self)
        
        self.caret = string.len(self.retval)
        
    end,

	-- A -- Select All
	[1] = function(self)
		
		return self:ctrlchar(self.selectall)
		
	end,
	
	-- C -- Copy
	[3] = function(self)
		
		return self:ctrlchar(self.toclipboard)
		
	end,
	
	-- V -- Paste
	[22] = function(self)
		
        return self:ctrlchar(self.fromclipboard)	
		
	end,
	
	-- X -- Cut
	[24] = function(self)
	
		return self:ctrlchar(self.toclipboard, true)
		
	end,	
	
	-- Y -- Redo
	[25] = function (self)
		
		return self:ctrlchar(self.redo)
		
	end,
	
	-- Z -- Undo
	[26] = function (self)
		
		return self:ctrlchar(self.undo)		
		
	end


}




------------------------------------
-------- Misc. helpers -------------
------------------------------------


function GUI.Textbox:undo()
	
	if #self.undo_states == 0 then return end
	table.insert(self.redo_states, self:geteditorstate() )
	local state = table.remove(self.undo_states)

    self.retval = state.retval
	self.caret = state.caret
	
	self:windowtocaret()
	
end


function GUI.Textbox:redo()
	
	if #self.redo_states == 0 then return end
	table.insert(self.undo_states, self:geteditorstate() )
	local state = table.remove(self.redo_states)
    
	self.retval = state.retval
	self.caret = state.caret
	
	self:windowtocaret()
	
end


function GUI.Textbox:storeundostate()

table.insert(self.undo_states, self:geteditorstate() )
	if #self.undo_states > self.undo_limit then table.remove(self.undo_states, 1) end
	self.redo_states = {}

end


function GUI.Textbox:geteditorstate()
	
	return { retval = self.retval, caret = self.caret }
	
end


-- See if we have a new-enough version of SWS for the clipboard functions
-- (v2.9.7 or greater)
function GUI.Textbox:SWS_clipboard()
	
	if GUI.SWS_exists then
		return true
	else
	
		reaper.ShowMessageBox(	"Clipboard functions require the SWS extension, v2.9.7 or newer."..
									"\n\nDownload the latest version at http://www.sws-extension.org/index.php",
									"Sorry!", 0)
		return false
	
	end
	
end




-- Script UI generated by Lokasenna's GUI Builder


local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please run 'Set Lokasenna_GUI v2 library path.lua' in the Lokasenna_GUI folder.", "Whoops!", 0)
    return
end
loadfile(lib_path .. "Core.lua")()

GUI.req("Classes/Class - Menubox.lua")()
GUI.req("Classes/Class - Button.lua")()
GUI.req("Classes/Class - Textbox.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end


local function parse_settings()
    
    -- Valid the textbox
    local length = tonumber( GUI.Val("Textbox1") )
    if not length then return end
    
    -- Get a time multiplier for the specified unit
    local _, units = GUI.Val("Menubox1")

    -- Get settings
    if     units    == "milliseconds" then
        length = length / 1000
    elseif units    == "minutes" then
        length = length * 60
    elseif units    == "beats" then
        length = length * (60 / reaper.Master_GetTempo() )
    elseif units    == "measures" then
        length = length * 4 * (60 / reaper.Master_GetTempo() )    
    elseif units    == "frames" then
        length = get_frames(length)
    elseif units    == "gridlines" then
        local _, divisionIn, _, _ = reaper.GetSetProjectGrid(0, false)
        length =    length * divisionIn * 4 * (60 / reaper.Master_GetTempo() )
    elseif units    == "visible gridlines" then

        local pos = reaper.GetCursorPosition()
        local cur = 0.001

        while true do
            
            local cur_pos = reaper.SnapToGrid(0, pos + cur)
            
            if cur_pos ~= pos then
                length = length * (cur_pos - pos)
                break
            else
                cur = cur * 2
            end
            
        end
    
    end    
    
    return length
    
end



local function go()
    
    local num_items = reaper.CountSelectedMediaItems()
    if num_items == 0 then 
        reaper.MB("No items selected.", "Whoops!", 0)
        return 
    end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    
    -- Parse the user settings to get a length
    local l = parse_settings()    
    if not l then return end
    
    -- For each selected item
    for i = 0, num_items - 1 do
        
        local item = reaper.GetSelectedMediaItem(0, i)
        
        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", l)
    
    end
    
    reaper.Undo_EndBlock("Trim items to specified length", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    
end









GUI.name = "Trim items to..."
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 272, 96
GUI.anchor, GUI.corner = "mouse", "C"



GUI.New("Button1", "Button", {
    z = 11,
    x = 112.0,
    y = 48,
    w = 48,
    h = 24,
    caption = "Go!",
    font = 3,
    col_txt = "txt",
    col_fill = "elm_frame",
    func = go,
})

GUI.New("Menubox1", "Menubox", {
    z = 11,
    x = 124,
    y = 16.0,
    w = 112,
    h = 20,
    caption = "",
    optarray = {"beats", "measures", "milliseconds", "seconds", "minutes", "gridlines", "visible gridlines", "frames"},
    retval = 5.0,
    font_a = 3,
    font_b = 4,
    col_txt = "txt",
    col_cap = "txt",
    bg = "wnd_bg",
    pad = 4,
    noarrow = false,
    align = 0
})

GUI.New("Textbox1", "Textbox", {
    z = 11,
    x = 64.0,
    y = 16.0,
    w = 56,
    h = 20,
    caption = "Length:",
    cap_pos = "left",
    font_a = 3,
    font_b = "textbox",
    color = "txt",
    bg = "wnd_bg",
    shadow = true,
    pad = 4,
    undo_limit = 20
})


GUI.Init()
GUI.Main()