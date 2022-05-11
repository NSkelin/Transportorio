Search_history = require("data.Search_history")

local Trades_menu = {
	active = false,
	search_history = Search_history:new()
}

function Trades_menu:new()
	local trades_menu = {}
	setmetatable(trades_menu, self)
	self.__index = self

	return trades_menu
end

-- opens players trade menu if closed; closes players trade menu if open
function Trades_menu:toggle(player)
	if self.active == false then
		self:open(player)
	else
		self:close(player)
	end
end

function Trades_menu:open(player)
	local player_global = global.players[player.index]
	local screen_element = player.gui.screen

	local root_frame = screen_element.add{type="frame", name="tro_trade_root_frame", direction="vertical"}

	self:create_title_bar(root_frame)

	root_frame.add{type="textfield", name="tro_trade_menu_search", tooltip = {"tro.trade_menu_textfield"}}
	root_frame.add{
		type="button",
		caption="back",
		name="tro_move_back_in_search_history_button",
		tooltip = {"tro.trade_menu_back_but"}
	}
	local trades_list = root_frame.add{type="scroll-pane", name="tro_trades_list", direction="vertical"}

	if #self.search_history >= 1 then
		local search_term = self.search_history[1].searched_item
		local filter = self.search_history[1].filter
		self:create_list_rows(trades_list, global.cities, search_term, filter, player)
	else
		-- search for all
		self:create_list_rows(trades_list, global.cities, "", "any", player)
	end
	
	root_frame.style.size = {800, 700}
	root_frame.auto_center = true
	self.active = not self.active
end

-- closes gui and resets search history
function Trades_menu:close(player)
	self:destroy(player)
	self.search_history:reset()
end

-- closes gui without reseting search history
function Trades_menu:minimize(player)
	self:destroy(player)
end

-- destroys the root gui element and all its child elements
function Trades_menu:destroy(player)
	local player_global = global.players[player.index]
	local screen_element = player.gui.screen
	local main_frame = screen_element["tro_trade_root_frame"]

	main_frame.destroy()

	-- update players state
	self.active = not self.active
end

-- updates the trade menu window search bar and search list based on search text
function Trades_menu:update_search(player, search, add_to_search_history, update_search_field)
	update_search_field = update_search_field or false

	-- if the trade menu isnt open you cant update it
	if self.active == false then
		return
	end

	if add_to_search_history then
		self.search_history:add_search(search)
	end

	-- update search field
	if update_search_field then
		local textfield = player.gui.screen["tro_trade_root_frame"]["tro_trade_menu_search"]
		textfield.text = search.filter .. ":" .. search.searched_item
	end
		
	-- update trades list
	local trades_list = player.gui.screen["tro_trade_root_frame"]["tro_trades_list"]
	trades_list.clear()
	self:create_list_rows(trades_list, global.cities, search.searched_item, search.filter, player)
end

function Trades_menu:create_title_bar(root_element)
	local header = root_element.add{type="flow", name="tro_trade_menu_header", direction="horizontal"}
	header.add{type="label", caption={"tro.trade_menu_title"}, style="frame_title"}
	local filler = header.add{type="empty-widget", style="draggable_space"}
	filler.style.height = 24
		filler.style.horizontally_stretchable = true
		filler.drag_target = root_element
	header.add{
		type = "sprite-button",
		name = "tro_trade_menu_header_exit_button",
		style = "frame_action_button",
		sprite = "utility/close_white",
		hovered_sprite = "utility/close_black",
		clicked_sprite = "utility/close_black"
	}
end

-- creates each trade row from the list of machines and a filter. then adds the rows onto the list
function Trades_menu:create_list_rows(list, cities, search_term, filter, player)

	local assemblers = {}
	local cities_len = 0
	local trades = 0
	local malls = 0
	for i, city in ipairs(cities) do
		cities_len = cities_len + 1
		for x, building in ipairs(city.buildings.traders) do
			table.insert(assemblers, building)
			trades = trades + 1
		end
		for x, building in ipairs(city.buildings.malls) do
			table.insert(assemblers, building)
			malls = malls + 1
		end 
	end

	game.print("cities " .. cities_len)
	game.print("trades ".. trades)
	game.print("malls ".. malls)

	-- filter assemblers according to filter
	local filtered_assemblers = {}
	for x, assembler in ipairs(assemblers) do
		local recipe = assembler.get_recipe()

		-- add any assemblers that have the searched term in their recipe
		if filter == "any" then 
			for i, product in ipairs(recipe.products) do
				if string.find(product.name, search_term, 0, true) then
					table.insert(filtered_assemblers, assembler)
					goto next_loop
				end
			end
			for i, ingredient in ipairs(recipe.ingredients) do
				if string.find(ingredient.name, search_term, 0, true) then
					table.insert(filtered_assemblers, assembler)
					goto next_loop
				end
			end

		-- add assemblers where they produce the searched term
		elseif filter == "product" then
			for i, product in ipairs(recipe.products) do
				if string.find(product.name, search_term, 0, true) then
					table.insert(filtered_assemblers, assembler)
				end
			end

		-- add assemblers where they require the searched term to produce something
		elseif filter == "ingredient" then
			for i, ingredient in ipairs(recipe.ingredients) do
				if string.find(ingredient.name, search_term, 0, true) then
					table.insert(filtered_assemblers, assembler)
				end
			end
		end
		::next_loop::
	end

	if #filtered_assemblers > 0 then
		-- create a row for each recipe for each assembler
		for i, assembler in ipairs(filtered_assemblers) do
			local position = assembler.position
			local recipe = assembler.get_recipe()
			local ingredients = recipe.ingredients
			local products = recipe.products
			self:create_row(list, ingredients, products, position)
		end
	else 
		-- if list is empty, create a message saying as much
		local message_element = self:create_failed_search_message(list, player, filter, search_term)
	end
end

-- creates a ui explaining the search for an item failed as well as next steps
function Trades_menu:create_failed_search_message(list, player, filter, search_term)
	local search_history = self.search_history
	local message_element = list.add{type="flow"}
	local horizontal_flow = message_element.add{type="flow", direction="horizontal"}

	-- main text
	if filter == "any" then
		horizontal_flow.add{type="label", caption="No recipes found."}
	elseif filter == "product" then
		horizontal_flow.add{type="label", caption="No recipes create"}
		horizontal_flow.add{type="sprite", sprite=search_history[1].item_type .. "/" .. search_history[1].searched_item}
		horizontal_flow.add{type="label", caption=search_term}
	elseif filter == "ingredient" then
		horizontal_flow.add{type="label", caption="No recipes require"}
		horizontal_flow.add{type="sprite", sprite=search_history[1].item_type .. "/" .. search_history[1].searched_item}
		horizontal_flow.add{type="label", caption=search_term}
	else
		horizontal_flow.add{type="label", caption="Unknown filter!"}
	end

	-- ending text
	if #search_history > 0 then
		message_element.add{type="label", caption='Try searching for something else. Or press "backspace" to see your last search!'}
	else
		message_element.add{type="label", caption="Try searching for something else!"}
	end
end

function Trades_menu:create_row(list, ingredients, products, position)
	local trade_row = list.add{type="frame", style="tro_trade_row"}
	local trade_row_flow = trade_row.add{type="flow", style="tro_trade_row_flow"}
	trade_row_flow.add{
		type="button",
		caption="ping",
		name="tro_ping_button",
		tags={location=position}, 
		tooltip={"tro.trade_menu_ping"}
	}
	trade_row_flow.add{type="button",
		caption="goto",
		name="tro_goto_button",
		tags={location=position},
		tooltip={"tro.trade_menu_goto"}
	}
	
	if #ingredients >= 1 then
		for i, ingredient in ipairs(ingredients) do
			trade_row_flow.add{
				type="sprite-button",
				sprite = ingredient.type .. "/" .. ingredient.name, 
				tags={
					action="tro_filter_list",
					item_name=ingredient.name,
					filter="ingredient",
					type=ingredient.type
				},
				tooltip={"", {"tro.item_name"}, ": ", ingredient.name, " | ", {"tro.trade_menu_item_sprite_button_instructions"}}
			}
			trade_row_flow.add{type="label", caption = ingredient.amount}
		end
	end

	trade_row_flow.add{type="label", caption = " --->"}

	for i, product in ipairs(products) do
		trade_row_flow.add{
			type="sprite-button",
			sprite = product.type .. "/" .. product.name, 
			tags={
				action="tro_filter_list",
				item_name=product.name,
				filter="product", 
				type=product.type
			},
			tooltip={"", {"tro.item_name"}, ": ", product.name, " | ", {"tro.trade_menu_item_sprite_button_instructions"}}
		}
		trade_row_flow.add{type="label", caption = product.amount}
	end
end

function Trades_menu:move_backward_in_search_history(player)
	self.search_history:remove_last_added_term()

	local new_search = Search:new("any", "")


	if #self.search_history >= 1 then
		new_search = self.search_history[1]
	end

	self:update_search(player, new_search, false, true)
end

return Trades_menu