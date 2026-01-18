-- ChipPredictor HUD
-- On-screen UI display for chip predictions

local CP_HUD = {}

-- Store prediction data
CP_HUD.prediction_data = {
    visible = false,
    hand_name = "",
    total_chips = 0,
    total_mult = 0,
    x_mult = 1,
    final_score = 0,
    joker_chips = 0,
    joker_mult = 0,
    joker_x_mult = 1
}

-- UI element reference
CP_HUD.ui_box = nil

-- Create the prediction UI box
function CP_HUD.create_ui()
    if not G or not G.HUD then return end
    
    -- Remove existing UI if present
    if CP_HUD.ui_box then
        CP_HUD.ui_box:remove()
        CP_HUD.ui_box = nil
    end
    
    -- Create UI box positioned to the right of hand display
    CP_HUD.ui_box = UIBox{
        definition = {
            n = G.UIT.ROOT,
            config = {
                align = "cm",
                padding = 0.1,
                colour = {0, 0, 0, 0.8},
                r = 0.1,
                emboss = 0.05,
                id = "chip_predictor_box"
            },
            nodes = {
                -- Title
                {n = G.UIT.R, config = {align = "cm", padding = 0.05}, nodes = {
                    {n = G.UIT.T, config = {
                        text = "PREDICTION",
                        scale = 0.35,
                        colour = G.C.UI.TEXT_LIGHT,
                        shadow = true
                    }}
                }},
                -- Hand name
                {n = G.UIT.R, config = {align = "cm", padding = 0.02}, nodes = {
                    {n = G.UIT.T, config = {
                        ref_table = CP_HUD.prediction_data,
                        ref_value = "hand_name",
                        scale = 0.4,
                        colour = G.C.ORANGE,
                        shadow = true,
                        id = "cp_hand_name"
                    }}
                }},
                -- Chips display
                {n = G.UIT.R, config = {align = "cm", padding = 0.05}, nodes = {
                    {n = G.UIT.C, config = {align = "cr", minw = 1.5, minh = 0.5, r = 0.1, colour = G.C.BLUE, emboss = 0.05, padding = 0.05}, nodes = {
                        {n = G.UIT.T, config = {
                            ref_table = CP_HUD.prediction_data,
                            ref_value = "total_chips",
                            scale = 0.5,
                            colour = G.C.UI.TEXT_LIGHT,
                            shadow = true,
                            id = "cp_chips"
                        }}
                    }},
                    {n = G.UIT.C, config = {align = "cm", padding = 0.05}, nodes = {
                        {n = G.UIT.T, config = {
                            text = "X",
                            scale = 0.5,
                            colour = G.C.WHITE,
                            shadow = true
                        }}
                    }},
                    {n = G.UIT.C, config = {align = "cl", minw = 1.5, minh = 0.5, r = 0.1, colour = G.C.RED, emboss = 0.05, padding = 0.05}, nodes = {
                        {n = G.UIT.T, config = {
                            ref_table = CP_HUD.prediction_data,
                            ref_value = "total_mult",
                            scale = 0.5,
                            colour = G.C.UI.TEXT_LIGHT,
                            shadow = true,
                            id = "cp_mult"
                        }}
                    }}
                }},
                -- X-mult from jokers (if > 1)
                {n = G.UIT.R, config = {align = "cm", padding = 0.02, id = "cp_xmult_row"}, nodes = {
                    {n = G.UIT.T, config = {
                        ref_table = CP_HUD.prediction_data,
                        ref_value = "joker_x_mult_text",
                        scale = 0.35,
                        colour = G.C.ORANGE,
                        shadow = true,
                        id = "cp_xmult"
                    }}
                }},
                -- Final score
                {n = G.UIT.R, config = {align = "cm", padding = 0.05}, nodes = {
                    {n = G.UIT.C, config = {align = "cm", minw = 3.2, minh = 0.6, r = 0.1, colour = G.C.GOLD, emboss = 0.05, padding = 0.05}, nodes = {
                        {n = G.UIT.T, config = {
                            ref_table = CP_HUD.prediction_data,
                            ref_value = "final_score",
                            scale = 0.6,
                            colour = G.C.UI.TEXT_LIGHT,
                            shadow = true,
                            id = "cp_score"
                        }}
                    }}
                }},
                -- Joker contributions summary
                {n = G.UIT.R, config = {align = "cm", padding = 0.02}, nodes = {
                    {n = G.UIT.T, config = {
                        ref_table = CP_HUD.prediction_data,
                        ref_value = "joker_summary",
                        scale = 0.28,
                        colour = G.C.UI.TEXT_INACTIVE,
                        shadow = true,
                        id = "cp_joker_summary"
                    }}
                }}
            }
        },
        config = {
            align = "br",
            offset = {x = -2.2, y = 0.3},
            major = G.consumeables,
            bond = "Weak"
        }
    }
end

-- Update prediction data and UI
function CP_HUD.update_prediction(hand_name, total_chips, total_mult, x_mult, final_score, joker_chips, joker_mult, joker_x_mult)
    -- Hide HUD in shop or blind selection
    if G.STATE == G.STATES.SHOP or G.STATE == G.STATES.BLIND_SELECT then
        CP_HUD.hide()
        return
    end
    
    CP_HUD.prediction_data.visible = true
    CP_HUD.prediction_data.hand_name = hand_name or ""
    CP_HUD.prediction_data.total_chips = total_chips or 0
    CP_HUD.prediction_data.total_mult = total_mult or 0
    CP_HUD.prediction_data.x_mult = x_mult or 1
    CP_HUD.prediction_data.final_score = final_score or 0
    CP_HUD.prediction_data.joker_chips = joker_chips or 0
    CP_HUD.prediction_data.joker_mult = joker_mult or 0
    CP_HUD.prediction_data.joker_x_mult = joker_x_mult or 1
    
    -- Format x-mult text
    if joker_x_mult > 1 then
        CP_HUD.prediction_data.joker_x_mult_text = string.format("(X%.2f)", joker_x_mult)
    else
        CP_HUD.prediction_data.joker_x_mult_text = ""
    end
    
    -- Format joker summary
    local summary_parts = {}
    if joker_chips > 0 then
        table.insert(summary_parts, string.format("+%d chips", joker_chips))
    end
    if joker_mult > 0 then
        table.insert(summary_parts, string.format("+%d mult", joker_mult))
    end
    if joker_x_mult > 1 then
        table.insert(summary_parts, string.format("X%.2f mult", joker_x_mult))
    end
    
    if #summary_parts > 0 then
        CP_HUD.prediction_data.joker_summary = "Jokers: " .. table.concat(summary_parts, ", ")
    else
        CP_HUD.prediction_data.joker_summary = ""
    end
    
    -- Ensure UI is created
    if not CP_HUD.ui_box and G and G.HUD then
        CP_HUD.create_ui()
    end
    
    -- Update UI elements if they exist
    if CP_HUD.ui_box then
        local chips_elem = CP_HUD.ui_box:get_UIE_by_ID('cp_chips')
        local mult_elem = CP_HUD.ui_box:get_UIE_by_ID('cp_mult')
        local score_elem = CP_HUD.ui_box:get_UIE_by_ID('cp_score')
        
        if chips_elem then chips_elem:update(0) end
        if mult_elem then mult_elem:update(0) end
        if score_elem then score_elem:update(0) end
    end
end

-- Hide prediction UI
function CP_HUD.hide()
    CP_HUD.prediction_data.visible = false
    CP_HUD.prediction_data.hand_name = ""
    CP_HUD.prediction_data.final_score = 0
    
    if CP_HUD.ui_box then
        CP_HUD.ui_box:remove()
        CP_HUD.ui_box = nil
    end
end

-- Initialize HUD when game starts
function CP_HUD.init()
    -- Hook into game start to create UI
    if G and G.HUD then
        CP_HUD.create_ui()
    end
end

return CP_HUD
