-- ChipPredictor Stage 4: Joker Effects Evaluation

local Stage4 = {}

-- Stage 4: Evaluate joker effects
function Stage4.calculate_joker_effects(cards, scoring_hand, hand_name, poker_hands)
    local joker_chips = 0
    local joker_mult = 0
    local joker_x_mult = 1
    local joker_contributions = {}
    
    print("[ChipPredictor] === Evaluating Jokers ===")
    
    if not G.jokers or not G.jokers.cards then
        print("[ChipPredictor] No jokers found")
        return joker_chips, joker_mult, joker_x_mult, joker_contributions
    end
    
    print(string.format("[ChipPredictor] Found %d joker(s)", #G.jokers.cards))
    
    for i, joker in ipairs(G.jokers.cards) do
        local j_chips = 0
        local j_mult = 0
        local j_x_mult = 1
        
        local joker_name = joker.ability.name or "Unknown Joker"
        local joker_key = joker.config and joker.config.center and joker.config.center.key or "unknown"
        print(string.format("[ChipPredictor] Joker #%d: %s (key: %s)", i, joker_name, joker_key))
        
        -- Print joker edition
        if joker.edition then
            if joker.edition.holo then print("  - Has Holographic edition") end
            if joker.edition.foil then print("  - Has Foil edition") end
            if joker.edition.polychrome then print("  - Has Polychrome edition") end
        end
        
        -- Debug: Print joker ability details
        if joker.ability then
            print(string.format("  - Joker ability type: %s", tostring(joker.ability.type)))
            if joker.ability.x_mult then
                print(string.format("  - Joker has x_mult: %.2f", joker.ability.x_mult))
            end
            if joker.ability.t_mult then
                print(string.format("  - Joker has t_mult: %d (type: %s)", joker.ability.t_mult, tostring(joker.ability.type)))
            end
            if joker.ability.mult then
                print(string.format("  - Joker has mult: %d", joker.ability.mult))
            end
            if joker.ability.extra then
                print(string.format("  - Joker has extra table"))
                if type(joker.ability.extra) == "table" then
                    for k, v in pairs(joker.ability.extra) do
                        print(string.format("    - extra.%s = %s", k, tostring(v)))
                    end
                end
            end
        end
        
        -- Don't call calculate_joker as it triggers actual game effects!
        -- Instead, manually check joker properties and simulate common patterns
        
        -- Check joker ability properties directly (safe, no game effects)
        
        -- Check for x_mult (from ability.x_mult)
        if joker.ability.x_mult and joker.ability.x_mult > 1 then
            local trigger = false
            -- Check if joker type matches hand type (ability.type == "" means always trigger)
            if joker.ability.type == '' or (poker_hands and poker_hands[joker.ability.type] and next(poker_hands[joker.ability.type])) then
                trigger = true
            end

            if trigger and joker_name ~= 'Seeing Double' then
                print(string.format("  - Using ability.x_mult: %.2f", joker.ability.x_mult))
                j_x_mult = j_x_mult * joker.ability.x_mult
            end
        end

        -- Check for t_mult (typed mult - requires specific hand type)
        if joker.ability.t_mult and joker.ability.t_mult > 0 then
            if poker_hands and poker_hands[joker.ability.type] and next(poker_hands[joker.ability.type]) then
                print(string.format("  - Using ability.t_mult: %d", joker.ability.t_mult))
                j_mult = j_mult + joker.ability.t_mult
            end
        end

        -- Check for t_chips (typed chips - requires specific hand type)
        if joker.ability.t_chips and joker.ability.t_chips > 0 then
            if poker_hands and poker_hands[joker.ability.type] and next(poker_hands[joker.ability.type]) then
                print(string.format("  - Using ability.t_chips: %d", joker.ability.t_chips))
                j_chips = j_chips + joker.ability.t_chips
            end
        end

        -- Check for mult (general mult bonus)
        if joker.ability.mult and joker.ability.mult > 0 then
            print(string.format("  - Using ability.mult: %d", joker.ability.mult))
            j_mult = j_mult + joker.ability.mult
        end

        -- Special handling for specific jokers that use extra tables
        if joker.ability.extra and type(joker.ability.extra) == "table" then
            -- Wrathful Joker: +mult for each card of discarded suit
            if joker_key == "j_wrathful_joker" and joker.ability.extra.s_mult and scoring_hand then
                local suit = joker.ability.extra.suit
                local count = 0
                for _, card in ipairs(scoring_hand) do
                    if card and card.base and card.base.suit == suit then
                        count = count + 1
                    end
                end
                if count > 0 then
                    local bonus = count * joker.ability.extra.s_mult
                    print(string.format("  - Wrathful Joker: %d %s cards × %d = +%d mult", count, suit, joker.ability.extra.s_mult, bonus))
                    j_mult = j_mult + bonus
                end
            end

            -- Mystic Summit: +mult if discards remaining match requirement
            if joker_key == "j_mystic_summit" and joker.ability.extra.mult and joker.ability.extra.d_remaining then
                if G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left == joker.ability.extra.d_remaining then
                    print(string.format("  - Mystic Summit: +%d mult (discards=%d)", joker.ability.extra.mult, G.GAME.current_round.discards_left))
                    j_mult = j_mult + joker.ability.extra.mult
                end
            end

            -- Fortune Teller: mult per Tarot used (we'll approximate as 0 for prediction)
            if joker_key == "j_fortune_teller" then
                print("  - Fortune Teller: requires tarot tracking (skipped)")
            end
        end
        
        -- Check for other_card effects (like Raised Fist) that affect held cards
        -- These jokers check cards remaining in hand (NOT the selected cards)
        -- Manually simulate without calling calculate_joker to avoid triggering game effects
        if G.hand and G.hand.cards then
            -- Raised Fist: gives h_mult for lowest rank card remaining in hand
            if joker_key == "j_raised_fist" then
                -- Build set of selected cards for quick lookup
                local selected_set = {}
                if cards then
                    for _, card in ipairs(cards) do
                        selected_set[card] = true
                    end
                end
                
                -- Find lowest rank card remaining in hand (not selected)
                local lowest_rank = 15
                local lowest_card
                for _, card in ipairs(G.hand.cards) do
                    if not selected_set[card] and card.base and card.base.id then
                        if not SMODS.has_no_rank or not SMODS.has_no_rank(card) then
                            if card.base.id < lowest_rank then
                                lowest_rank = card.base.id
                                lowest_card = card
                            end
                        end
                    end
                end
                
                if lowest_card and lowest_card.base.nominal then
                    local h_mult_bonus = 2 * lowest_card.base.nominal
                    print(string.format("  - %s adds h_mult: %d for %s (remaining in hand)", joker_name, h_mult_bonus, lowest_card.base.value))
                    j_mult = j_mult + h_mult_bonus
                end
            end
        end
        
        -- Check joker edition bonuses
        if joker.edition then
            -- Manually calculate edition bonuses
            if joker.edition.holo then
                print("  - Adding Holographic edition: +10 mult")
                j_mult = j_mult + 10
            end
            if joker.edition.foil then
                print("  - Adding Foil edition: +50 chips")
                j_chips = j_chips + 50
            end
            if joker.edition.polychrome then
                print("  - Adding Polychrome edition: X1.5 mult")
                j_x_mult = j_x_mult * 1.5
            end
        end
        
        print(string.format("  - Final contribution: chips=%d, mult=%d, x_mult=%.2f", j_chips, j_mult, j_x_mult))
        
        -- Accumulate totals
        joker_chips = joker_chips + j_chips
        joker_mult = joker_mult + j_mult
        joker_x_mult = joker_x_mult * j_x_mult
        
        -- Store individual contributions
        if j_chips ~= 0 or j_mult ~= 0 or j_x_mult > 1 then
            table.insert(joker_contributions, {
                name = joker_name,
                chips = j_chips,
                mult = j_mult,
                x_mult = j_x_mult
            })
        end
    end
    
    print(string.format("[ChipPredictor] Total joker contribution: chips=%d, mult=%d, x_mult=%.2f", 
        joker_chips, joker_mult, joker_x_mult))
    print("[ChipPredictor] === End Joker Evaluation ===")
    
    return joker_chips, joker_mult, joker_x_mult, joker_contributions
end

return Stage4
