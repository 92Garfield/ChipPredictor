-- ChipPredictor: Custom evaluate_play Implementation
-- This is a prediction-safe version of G.FUNCS.evaluate_play
-- It simulates the scoring process without triggering actual game effects

local JokerEffects = assert(SMODS.load_file('prediction/joker_effects.lua'))()

local EvaluatePlay = {}

-- Custom implementation of evaluate_play for prediction purposes
-- Uses our safe Stage4.calculate_joker_effects instead of calculate_joker
function EvaluatePlay.predict_evaluate_play(cards)
    if not cards or #cards == 0 then
        return 0, 0, 1, {}
    end
    
    print("[ChipPredictor] === Starting evaluate_play Prediction ===")
    
    -- Get poker hand info
    local text, disp_text, poker_hands, scoring_hand, non_loc_disp_text = G.FUNCS.get_poker_hand_info(cards)
    
    print(string.format("[ChipPredictor] Hand: %s", disp_text))
    print(string.format("[ChipPredictor] Scoring cards: %d", #scoring_hand))
    
    -- Initialize score values
    local hand_chips = 0
    local mult = 0
    
    -- Check if hand is valid and not debuffed
    if not G.GAME or not G.GAME.hands or not G.GAME.hands[text] then
        print("[ChipPredictor] Invalid hand or game state")
        return 0, 0, 1, {}
    end
    
    -- Check for blind debuff
    if G.GAME.blind and G.GAME.blind.debuff_hand then
        -- Pass check=true to prevent boss blind side effects (The Arm, The Ox, etc.)
        local debuffed = G.GAME.blind:debuff_hand(cards, poker_hands, text, true)
        if debuffed then
            print("[ChipPredictor] Hand is debuffed by blind")
            return 0, 0, 1, {}
        end
    end
    
    -- Get base hand values
    hand_chips = G.GAME.hands[text].chips or 0
    mult = G.GAME.hands[text].mult or 0
    
    print(string.format("[ChipPredictor] Base hand: chips=%d, mult=%d", hand_chips, mult))
    
    -- === STAGE 0: "Before" Joker Effects (before scoring begins) ===
    print("[ChipPredictor] === Stage 0: Before Jokers ===")
    
    -- These jokers trigger with context.before = true
    -- Examples: Midas Mask (turns faces to gold), Vampire (removes enhancements), 
    --           Spare Trousers (upgrades on Two Pair), Square Joker (upgrades on 4 cards)
    -- Note: These modify game state, so we skip them for prediction safety
    -- They would need special handling to predict their effects
    
    print("[ChipPredictor] (Before jokers skipped for prediction safety)")
    
    -- === BLIND MODIFICATIONS (must be before card scoring) ===
    print("[ChipPredictor] === Blind Modifications ===")
    
    if G.GAME.blind and G.GAME.blind.modify_hand then
        local modded = false
        mult, hand_chips, modded = G.GAME.blind:modify_hand(cards, poker_hands, text, mult, hand_chips)
        if modded then
            print(string.format("  Blind modified: chips=%d, mult=%d", hand_chips, mult))
        end
    end
    
    -- Apply mod_mult and mod_chips to base values
    mult = mod_mult and mod_mult(mult) or mult
    hand_chips = mod_chips and mod_chips(hand_chips) or hand_chips
    
    print(string.format("[ChipPredictor] After blind mods: chips=%d, mult=%d", hand_chips, mult))
    
    -- Add pure bonus cards (Stone Cards) to scoring_hand if not already included
    local pures = {}
    if cards then
        for i = 1, #cards do
            if cards[i].ability and cards[i].ability.effect == 'Stone Card' then
                local inside = false
                for j = 1, #scoring_hand do
                    if scoring_hand[j] == cards[i] then
                        inside = true
                        break
                    end
                end
                if not inside then
                    table.insert(pures, cards[i])
                end
            end
        end
    end
    
    for i = 1, #pures do
        table.insert(scoring_hand, pures[i])
    end
    
    -- Sort scoring hand by position
    table.sort(scoring_hand, function(a, b)
        if a.T and b.T then
            return a.T.x < b.T.x
        end
        return false
    end)
    
    print(string.format("[ChipPredictor] Total scoring cards (with stone): %d", #scoring_hand))
    
    -- === STAGE 1: Process Scoring Cards ===
    print("[ChipPredictor] === Stage 1: Scoring Cards ===")
    
    for i = 1, #scoring_hand do
        local card = scoring_hand[i]
        
        -- Skip debuffed cards
        if card.debuff then
            print(string.format("  Card #%d: DEBUFFED", i))
        else
            -- Calculate total repetitions for this card (red seal + joker effects)
            -- This includes red seal, Sock and Buskin, Hanging Chad, Dusk, etc.
            local total_reps = JokerEffects.calculate_repetitions(card, cards, scoring_hand, text, poker_hands, true)
            
            print(string.format("  Card #%d: %s - will score %d time(s)", 
                i, card.base and card.base.value or "?", total_reps))
            
            -- Score the card (possibly multiple times)
            for rep = 1, total_reps do
                if rep > 1 then
                    print(string.format("  Card #%d: Retrigger #%d", i, rep - 1))
                end
                
                local card_chips = 0
                
                -- Get card base values
                if card.ability and card.ability.effect ~= 'Stone Card' then
                    if card.base and card.base.nominal then
                        card_chips = card.base.nominal or 0
                        if rep == 1 then
                            print(string.format("  Card #%d: %s - base chips=%d", i, card.base.value or "?", card_chips))
                        end
                    end
                else
                    if rep == 1 then
                        print(string.format("  Card #%d: Stone Card (bonus chips)", i))
                    end
                    card_chips = 50 -- Stone cards give bonus chips
                end
                
                -- Add chips to hand total
                hand_chips = hand_chips + card_chips
                hand_chips = mod_chips and mod_chips(hand_chips) or hand_chips
                
                -- Add card bonus (Bonus cards)
                if card.ability and card.ability.bonus then
                    hand_chips = hand_chips + card.ability.bonus
                    hand_chips = mod_chips and mod_chips(hand_chips) or hand_chips
                    if rep == 1 then
                        print(string.format("    + Bonus card: +%d chips", card.ability.bonus))
                    end
                end
                
                -- Add card mult (Mult cards)
                -- Skip lucky cards - they only have a 1 in 5 chance to trigger
                if card.ability and card.ability.mult and card.ability.effect ~= 'Lucky Card' then
                    mult = mult + card.ability.mult
                    mult = mod_mult and mod_mult(mult) or mult
                    if rep == 1 then
                        print(string.format("    + Mult card: +%d mult", card.ability.mult))
                    end
                elseif card.ability and card.ability.mult and card.ability.effect == 'Lucky Card' then
                    if rep == 1 then
                        print(string.format("    + Lucky card (1/5 chance for +%d mult - not predicted)", card.ability.mult))
                    end
                end
                
                -- Add card edition effects (applied BEFORE joker individual effects)
                if card.edition then
                    if card.edition.foil then
                        hand_chips = hand_chips + 50
                        hand_chips = mod_chips and mod_chips(hand_chips) or hand_chips
                        if rep == 1 then
                            print(string.format("    + Foil edition: +50 chips"))
                        end
                    end
                    if card.edition.holo then
                        mult = mult + 10
                        mult = mod_mult and mod_mult(mult) or mult
                        if rep == 1 then
                            print(string.format("    + Holo edition: +10 mult"))
                        end
                    end
                    if card.edition.polychrome then
                        -- Polychrome multiplies the current mult
                        mult = mult * 1.5
                        mult = mod_mult and mod_mult(mult) or mult
                        if rep == 1 then
                            print(string.format("    + Polychrome edition: x1.5 mult (mult: %.1f)", mult))
                        end
                    end
                end
                
                -- Add glass card x_mult (applies after editions, before joker effects)
                if card.ability and card.ability.x_mult and card.ability.x_mult > 1 then
                    mult = mult * card.ability.x_mult
                    mult = mod_mult and mod_mult(mult) or mult
                    if rep == 1 then
                        print(string.format("    + Glass Card: x%.1f mult (mult: %.1f)", card.ability.x_mult, mult))
                    end
                end
                
                -- Add joker effects for this individual scoring card
                local joker_card_chips, joker_card_mult, joker_card_x_mult, joker_card_contribs = 
                    JokerEffects.single_card(card, cards, scoring_hand, text, poker_hands, true)
                
                if joker_card_chips > 0 then
                    hand_chips = hand_chips + joker_card_chips
                    hand_chips = mod_chips and mod_chips(hand_chips) or hand_chips
                end
                
                if joker_card_mult > 0 then
                    mult = mult + joker_card_mult
                    mult = mod_mult and mod_mult(mult) or mult
                end
                
                if joker_card_x_mult > 1 then
                    -- X-mult multiplies the current mult
                    mult = mult * joker_card_x_mult
                    mult = mod_mult and mod_mult(mult) or mult
                    if rep == 1 then
                        print(string.format("    + Joker x%.2f mult (mult: %.1f)", joker_card_x_mult, mult))
                    end
                end
            end
        end
    end
    
    print(string.format("[ChipPredictor] After scoring cards: chips=%d, mult=%d, score=%.0f", 
        hand_chips, mult, hand_chips * mult))
    
    -- === STAGE 2: Process Held Cards (cards in hand but not played) ===
    print("[ChipPredictor] === Stage 2: Held Cards ===")
    
    if G.hand and G.hand.cards then
        -- Build set of played cards for quick lookup
        local played_set = {}
        if cards then
            for _, card in ipairs(cards) do
                played_set[card] = true
            end
        end
        
        -- Check held cards for effects
        for i = 1, #G.hand.cards do
            local card = G.hand.cards[i]
            
            -- Only process cards that were NOT played
            if not played_set[card] and not card.debuff then
                -- First, apply steel card effect (h_x_mult from the card itself)
                if card.ability and card.ability.effect == 'Steel Card' and card.ability.h_x_mult then
                    local steel_x_mult = card.ability.h_x_mult or 1.5
                    mult = mult * steel_x_mult
                    mult = mod_mult and mod_mult(mult) or mult
                    print(string.format("  %s (Steel): x%.1f mult (mult: %.1f)", 
                        card.base and card.base.value or "Card", steel_x_mult, mult))
                end
                
                -- Then get joker effects for held cards (Baron, Shoot the Moon, etc.)
                local held_chips, held_mult, held_x_mult, held_contribs = 
                    JokerEffects.single_card(card, cards, scoring_hand, text, poker_hands, false)
                
                if held_chips > 0 then
                    hand_chips = hand_chips + held_chips
                    hand_chips = mod_chips and mod_chips(hand_chips) or hand_chips
                end
                
                if held_mult > 0 then
                    mult = mult + held_mult
                    mult = mod_mult and mod_mult(mult) or mult
                end
                
                if held_x_mult > 1 then
                    -- X-mult multiplies the current mult
                    mult = mult * held_x_mult
                    mult = mod_mult and mod_mult(mult) or mult
                    print(string.format("  Held card joker x%.2f mult (mult: %.1f)", held_x_mult, mult))
                end
            end
        end
    end
    
    print(string.format("[ChipPredictor] After held cards: chips=%d, mult=%d, score=%.0f", 
        hand_chips, mult, hand_chips * mult))
    
    -- === STAGE 3: Joker Hand-Level Effects + Joker Editions ===
    print("[ChipPredictor] === Stage 3: Joker Effects ===")
    
    -- Process each joker: edition first, then its effect
    if G.jokers and G.jokers.cards then
        for i = 1, #G.jokers.cards do
            local joker = G.jokers.cards[i]
            
            if not joker.debuff then
                local joker_name = joker.ability and joker.ability.name or "Unknown"
                
                -- 1. Apply this joker's edition effects FIRST (ALWAYS apply, even if joker doesn't trigger)
                if joker.edition then
                    if joker.edition.foil then
                        hand_chips = hand_chips + 50
                        hand_chips = mod_chips and mod_chips(hand_chips) or hand_chips
                        print(string.format("  %s (Foil): +50 chips", joker_name))
                    end
                    
                    if joker.edition.holo then
                        mult = mult + 10
                        mult = mod_mult and mod_mult(mult) or mult
                        print(string.format("  %s (Holo): +10 mult", joker_name))
                    end
                    
                    if joker.edition.polychrome then
                        -- Polychrome multiplies the current mult
                        mult = mult * 1.5
                        mult = mod_mult and mod_mult(mult) or mult
                        print(string.format("  %s (Polychrome): x1.5 mult (mult: %.1f)", joker_name, mult))
                    end
                end
                
                -- 2. Then apply this joker's hand-level effect
                local j_chips, j_mult, j_x_mult, j_contribs = 
                    JokerEffects.scoring_hand_single_joker(joker, cards, scoring_hand, text, poker_hands)
                
                if j_chips > 0 then
                    hand_chips = hand_chips + j_chips
                    hand_chips = mod_chips and mod_chips(hand_chips) or hand_chips
                end
                
                if j_mult > 0 then
                    mult = mult + j_mult
                    mult = mod_mult and mod_mult(mult) or mult
                end
                
                if j_x_mult > 1 then
                    -- X-mult multiplies the current mult
                    mult = mult * j_x_mult
                    mult = mod_mult and mod_mult(mult) or mult
                    print(string.format("  %s: x%.2f mult (mult: %.1f)", joker_name, j_x_mult, mult))
                end
            end
        end
    end
    
    print(string.format("[ChipPredictor] After joker effects: chips=%d, mult=%d, score=%.0f", 
        hand_chips, mult, hand_chips * mult))
    
    -- === DECK EFFECTS (Plasma Deck balancing) ===
    if G.GAME and G.GAME.selected_back and G.GAME.selected_back.name == 'Plasma Deck' then
        -- Plasma Deck balances chips and mult
        local total = hand_chips + mult
        hand_chips = math.floor(total / 2)
        mult = math.floor(total / 2)
        print(string.format("[ChipPredictor] Plasma Deck: balanced to chips=%d, mult=%d", hand_chips, mult))
    end
    
    -- === FINAL CALCULATION ===
    print("[ChipPredictor] === Final Calculation ===")
    
    -- Calculate final score
    local final_score = hand_chips * mult
    
    print(string.format("[ChipPredictor] Final: chips=%d × mult=%d = %.0f", 
        hand_chips, mult, final_score))
    print("[ChipPredictor] === End evaluate_play Prediction ===")
    
    -- Return components for detailed breakdown
    return hand_chips, mult, 1, {
        hand_name = text,
        display_name = disp_text,
        scoring_hand = scoring_hand,
        poker_hands = poker_hands,
        final_score = final_score
    }
end

-- Simpler version that just returns the final score
function EvaluatePlay.predict_score(cards)
    local chips, mult, x_mult, details = EvaluatePlay.predict_evaluate_play(cards)
    return chips * mult * x_mult, details
end

return EvaluatePlay
