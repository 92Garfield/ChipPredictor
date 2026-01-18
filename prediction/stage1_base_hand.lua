-- ChipPredictor Stage 1: Base Hand Calculation

local Stage1 = {}

-- Stage 1: Get base hand chips and mult
function Stage1.calculate_base_hand(hand_name)
    if not G.GAME or not G.GAME.hands or not G.GAME.hands[hand_name] then
        return 0, 0
    end
    
    local hand_chips = G.GAME.hands[hand_name].chips
    local hand_mult = G.GAME.hands[hand_name].mult
    
    return hand_chips, hand_mult
end

return Stage1
