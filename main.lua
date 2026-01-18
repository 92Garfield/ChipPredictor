--- STEAMODDED HEADER
--- MOD_NAME: Chip Predictor
--- MOD_ID: chippredictor
--- PREFIX: chippredictor
--- MOD_AUTHOR: [92Garfield]
--- MOD_DESCRIPTION: Show chip and mult contributions of cards in the current played hand.
--- VERSION: 0.0.1
--- DEPENDENCIES: []

local mod_id = "chip-predictor"
local mod_name = "Chip Predictor"
local version = "0.0.1"

-- Load modules using SMODS.load_file (Balatro mod standard)
local CP_HUD = assert(SMODS.load_file('hud.lua'))()
local Prediction = assert(SMODS.load_file('prediction.lua'))()

-- Register mod with Steamodded loader
SMODS.Mods[mod_id] = {
    name = mod_name,
    id = mod_id,
    version = version,
    author = "92Garfield",
    main_file = "main.lua",
    description = "Shows chip and mult predictions for selected hands including joker contributions.",
}

-- Guard flag to prevent infinite loop during updates
local _cp_updating = false

-- Joker order tracking variables
local _cp_last_joker_order = {}
local _cp_joker_check_timer = 0
local _cp_joker_check_interval = 0.5  -- Check every 0.5 seconds

-- Update hand prediction display
local function update_hand_prediction()
    -- Prevent recursive updates
    if _cp_updating then
        return
    end
    
    _cp_updating = true
    
    -- Calculate prediction
    local result = Prediction.calculate()
    
    if not result then
        CP_HUD.hide()
        _cp_updating = false
        return
    end
    
    -- Update HUD display with final totals
    CP_HUD.update_prediction(
        result.hand_name,
        result.total_chips,
        result.total_mult,
        result.total_x_mult,
        result.final_score,
        result.joker_chips,
        result.joker_mult,
        result.joker_x_mult
    )

    -- Log detailed breakdown to console for debugging
    print(string.format("[ChipPredictor] === %s ===", result.hand_name))
    print(string.format("  Base Hand: %d chips, %d mult", result.base_chips, result.base_mult))
    print(string.format("  Cards: +%d chips, +%d mult, X%.2f mult, X%.2f chips", 
        result.card_chips, result.card_mult, result.card_x_mult, result.card_x_chips))
    
    if result.edition_chips ~= 0 or result.edition_mult ~= 0 or result.edition_x_mult > 1 then
        print(string.format("  Editions: +%d chips, +%d mult, X%.2f mult", 
            result.edition_chips, result.edition_mult, result.edition_x_mult))
    end
    
    if #result.joker_contributions > 0 then
        print("  Jokers:")
        for _, j in ipairs(result.joker_contributions) do
            local parts = {}
            if j.chips ~= 0 then table.insert(parts, string.format("+%d chips", j.chips)) end
            if j.mult ~= 0 then table.insert(parts, string.format("+%d mult", j.mult)) end
            if j.x_mult > 1 then table.insert(parts, string.format("X%.2f mult", j.x_mult)) end
            print(string.format("    %s: %s", j.name, table.concat(parts, ", ")))
        end
    end

    print("  ---")
    print(string.format("  FINAL: %d chips × %d mult × %.2fx = %d",
        result.total_chips,
        result.total_mult,
        result.total_x_mult,
        result.final_score
    ))
    
    _cp_updating = false
end

-- Hook CardArea:parse_highlighted to trigger on selection changes
local _cp_original_parse_highlighted = CardArea.parse_highlighted
function CardArea:parse_highlighted()
    local ret = _cp_original_parse_highlighted(self)
    
    -- Only update when in hand selection state
    if self == G.hand and G.STATE == G.STATES.SELECTING_HAND then
        update_hand_prediction()
    end
    
    return ret
end

-- Function to get current joker order as a list of names
local function get_joker_order()
    local order = {}
    if G.jokers and G.jokers.cards then
        for i = 1, #G.jokers.cards do
            local joker = G.jokers.cards[i]
            if joker and joker.ability and joker.ability.name then
                table.insert(order, joker.ability.name)
            end
        end
    end
    return order
end

-- Function to compare two joker order lists
local function joker_order_changed(order1, order2)
    if #order1 ~= #order2 then
        return true
    end
    
    for i = 1, #order1 do
        if order1[i] ~= order2[i] then
            return true
        end
    end
    
    return false
end

-- Timer-based joker order check
local function check_joker_order(dt)
    _cp_joker_check_timer = _cp_joker_check_timer + dt
    
    if _cp_joker_check_timer >= _cp_joker_check_interval then
        _cp_joker_check_timer = 0
        
        -- Only check if we're in hand selection state with cards selected
        if G.STATE == G.STATES.SELECTING_HAND and G.hand then
            if G.hand.highlighted and #G.hand.highlighted > 0 then
                local current_order = get_joker_order()
                
                if joker_order_changed(_cp_last_joker_order, current_order) then
                    _cp_last_joker_order = current_order
                    update_hand_prediction()
                end
            end
        end
    end
end

-- Hook into game update loop
local _cp_original_game_update = Game.update
function Game:update(dt)
    local ret = _cp_original_game_update(self, dt)
    check_joker_order(dt)
    return ret
end

-- Optional: announce load
print(string.format("[ChipPredictor] Loaded %s v%s", mod_name, version))

-- Hook Card:add_to_deck to detect when jokers are added
local _cp_original_add_to_deck = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    local ret = _cp_original_add_to_deck(self, from_debuff)
    -- Update prediction when a joker is added
    if self.area == G.jokers and G.STATE == G.STATES.SELECTING_HAND and G.hand then
        if G.hand.highlighted and #G.hand.highlighted > 0 then
            update_hand_prediction()
        end
    end
    return ret
end

-- Hook Card:remove_from_deck to detect when jokers are removed
local _cp_original_remove_from_deck = Card.remove_from_deck
function Card:remove_from_deck(from_debuff)
    local ret = _cp_original_remove_from_deck(self, from_debuff)
    -- Update prediction when a joker is removed
    if self.area == G.jokers and G.STATE == G.STATES.SELECTING_HAND and G.hand then
        if G.hand.highlighted and #G.hand.highlighted > 0 then
            update_hand_prediction()
        end
    end
    return ret
end