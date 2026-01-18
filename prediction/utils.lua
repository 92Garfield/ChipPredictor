-- ChipPredictor Utility Functions

local Utils = {}

-- Utility: safe get highlighted cards (selected in hand)
function Utils.get_highlighted_cards()
    if not G or not G.hand or not G.hand.highlighted then return {} end
    return G.hand.highlighted
end

return Utils
