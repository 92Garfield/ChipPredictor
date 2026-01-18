-- ChipPredictor Prediction Module
-- Handles all chip and mult calculation logic following Balatro's exact scoring stages
-- Now uses the comprehensive evaluate_play implementation

local Prediction = {}

-- Load modules
local Utils = assert(SMODS.load_file('prediction/utils.lua'))()
local EvaluatePlay = assert(SMODS.load_file('prediction/evaluate_play.lua'))()

-- Main calculation function following exact scoring order
function Prediction.calculate()
    local start_time = os.clock()

    -- Wrap everything in pcall to catch any errors
    local success, result = pcall(function()
        local cards = Utils.get_highlighted_cards()
        if #cards == 0 then
            return nil
        end

        -- Use the comprehensive evaluate_play implementation
        local hand_chips, mult, x_mult, details = EvaluatePlay.predict_evaluate_play(cards)

        if not details or not details.hand_name then
            return nil
        end

        -- Extract joker contributions from details
        local joker_contributions = details.joker_contributions or {}

        -- Calculate final score
        local final_score = hand_chips * mult * x_mult

        -- Return results in the expected format
        return {
            hand_name = details.display_name or details.hand_name,
            base_chips = 0,  -- Not separately tracked in new implementation
            base_mult = 0,   -- Not separately tracked in new implementation
            card_chips = 0,  -- Not separately tracked in new implementation
            card_mult = 0,   -- Not separately tracked in new implementation
            card_x_mult = 1, -- Not separately tracked in new implementation
            card_x_chips = 1, -- Not separately tracked in new implementation
            edition_chips = 0, -- Not separately tracked in new implementation
            edition_mult = 0,  -- Not separately tracked in new implementation
            edition_x_mult = 1, -- Not separately tracked in new implementation
            joker_chips = 0,   -- Included in total_chips
            joker_mult = 0,    -- Included in total_mult
            joker_x_mult = x_mult, -- X-mult component
            total_chips = math.floor(hand_chips),
            total_mult = math.floor(mult),
            total_x_mult = x_mult,
            final_score = math.floor(final_score),
            joker_contributions = joker_contributions
        }
    end)

    if not success then
        print("[ChipPredictor] ERROR in calculate(): " .. tostring(result))
        return nil
    end

    local end_time = os.clock()
    local elapsed_ms = (end_time - start_time) * 1000
    print(string.format("[ChipPredictor] Calculation completed in %.2f ms", elapsed_ms))

    return result
end

return Prediction
