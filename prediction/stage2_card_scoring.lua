-- ChipPredictor Stage 2: Playing Card Scoring

local Stage2 = {}

-- Stage 2: Calculate playing card contributions (chips, mult, x_mult, x_chips)
function Stage2.calculate_card_scoring(scoring_hand, context)
    local card_chips = 0
    local card_mult = 0
    local card_x_mult = 1
    local card_x_chips = 1
    
    if not scoring_hand or #scoring_hand == 0 then
        return card_chips, card_mult, card_x_mult, card_x_chips
    end
    
    for _, card in ipairs(scoring_hand) do
        -- Get base card values
        local chips = card:get_chip_bonus()
        local mult = card:get_chip_mult()
        local x_mult = card:get_chip_x_mult(context)
        local x_chips = (card.get_chip_x_bonus and card:get_chip_x_bonus()) or 0
        
        card_chips = card_chips + chips
        card_mult = card_mult + mult
        
        if x_mult and x_mult > 0 then
            card_x_mult = card_x_mult * x_mult
        end
        if x_chips and x_chips > 0 then
            card_x_chips = card_x_chips * x_chips
        end
    end
    
    return card_chips, card_mult, card_x_mult, card_x_chips
end

return Stage2
