local joker_effects = {}

-- Calculate joker effects for a single joker on the scoring hand (not individual cards)
-- This is called with context.joker_main = true for one joker at a time
-- blueprint_depth: prevents infinite loops when Blueprint/Brainstorm copy each other
function joker_effects.scoring_hand_single_joker(joker, cards, scoring_hand, hand_name, poker_hands, blueprint_depth)
    local joker_chips = 0
    local joker_mult = 0
    local joker_x_mult = 1
    local contributions = {}
    
    -- Prevent infinite Blueprint/Brainstorm loops
    blueprint_depth = blueprint_depth or 0
    if blueprint_depth > #G.jokers.cards then
        return joker_chips, joker_mult, joker_x_mult, contributions
    end
    
    if not joker or joker.debuff then
        return joker_chips, joker_mult, joker_x_mult, contributions
    end
    
    if not joker.ability or joker.ability.set ~= "Joker" then
        return joker_chips, joker_mult, joker_x_mult, contributions
    end
    
    local joker_name = joker.ability.name or "Unknown"
    
    -- === BLUEPRINT AND BRAINSTORM ===
    -- These jokers copy the ability of another joker
    if joker_name == 'Blueprint' or joker_name == 'Brainstorm' then
        local other_joker = nil
        
        if joker_name == 'Brainstorm' then
            -- Brainstorm copies the leftmost joker
            other_joker = G.jokers.cards[1]
        elseif joker_name == 'Blueprint' then
            -- Blueprint copies the joker to its right
            for i = 1, #G.jokers.cards do
                if G.jokers.cards[i] == joker then
                    if i + 1 <= #G.jokers.cards then
                        other_joker = G.jokers.cards[i + 1]
                    end
                    break
                end
            end
        end
        
        -- Check if we can copy this joker
        if other_joker and other_joker ~= joker and not other_joker.debuff then
            -- Check blueprint compatibility
            local is_compatible = true
            if other_joker.config and other_joker.config.center and other_joker.config.center.blueprint_compat == false then
                is_compatible = false
            end
            
            if is_compatible then
                -- Recursively calculate the copied joker's effect
                print(string.format("  %s: copying %s", joker_name, other_joker.ability and other_joker.ability.name or "Unknown"))
                return joker_effects.scoring_hand_single_joker(other_joker, cards, scoring_hand, hand_name, poker_hands, blueprint_depth + 1)
            else
                print(string.format("  %s: target joker not compatible", joker_name))
            end
        else
            print(string.format("  %s: no valid target to copy", joker_name))
        end
        
        return joker_chips, joker_mult, joker_x_mult, contributions
    end
    
    -- === HAND TYPE JOKERS (t_chips, t_mult, x_mult with type) ===
    -- These jokers trigger when a specific poker hand is played
    
    -- Check if joker has a hand type requirement
    if joker.ability.type and joker.ability.type ~= '' then
        -- Check if the current hand matches the joker's required hand
        if poker_hands and poker_hands[joker.ability.type] and next(poker_hands[joker.ability.type]) then
            -- Add chips from hand-specific jokers
            if joker.ability.t_chips and joker.ability.t_chips > 0 then
                joker_chips = joker_chips + joker.ability.t_chips
                print(string.format("  %s: +%d chips (hand type: %s)", joker_name, joker.ability.t_chips, joker.ability.type))
            end
            
            -- Add mult from hand-specific jokers
            if joker.ability.t_mult and joker.ability.t_mult > 0 then
                joker_mult = joker_mult + joker.ability.t_mult
                print(string.format("  %s: +%d mult (hand type: %s)", joker_name, joker.ability.t_mult, joker.ability.type))
            end
            
            -- Add x_mult from hand-specific jokers (but NOT Seeing Double)
            if joker_name ~= 'Seeing Double' and joker.ability.x_mult and joker.ability.x_mult > 1 then
                joker_x_mult = joker_x_mult * joker.ability.x_mult
                print(string.format("  %s: x%.2f mult (hand type: %s)", joker_name, joker.ability.x_mult, joker.ability.type))
            end
        end
    else
        -- No hand type requirement - check for generic x_mult jokers
        if joker_name ~= 'Seeing Double' and joker.ability.x_mult and joker.ability.x_mult > 1 then
            joker_x_mult = joker_x_mult * joker.ability.x_mult
            print(string.format("  %s: x%.2f mult (always active)", joker_name, joker.ability.x_mult))
        end
    end
    
    -- === SPECIAL JOKERS (specific implementations) ===
    
    -- Half Joker: +mult if hand size <= 3
    if joker_name == 'Half Joker' then
        if cards and #cards <= (joker.ability.extra and joker.ability.extra.size or 3) then
            local half_mult = (joker.ability.extra and joker.ability.extra.mult) or 20
            joker_mult = joker_mult + half_mult
            print(string.format("  %s: +%d mult (hand size %d)", joker_name, half_mult, #cards))
        end
    end
    
    -- Abstract Joker: +mult per joker
    if joker_name == 'Abstract Joker' then
        local joker_count = 0
        for j = 1, #G.jokers.cards do
            if G.jokers.cards[j].ability.set == 'Joker' then
                joker_count = joker_count + 1
            end
        end
        local abstract_mult = joker_count * (joker.ability.extra or 3)
        joker_mult = joker_mult + abstract_mult
        print(string.format("  %s: +%d mult (%d jokers)", joker_name, abstract_mult, joker_count))
    end
    
    -- Acrobat: x_mult if 0 hands left
    if joker_name == 'Acrobat' then
        if G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left == 0 then
            local acrobat_x = joker.ability.extra or 3
            joker_x_mult = joker_x_mult * acrobat_x
            print(string.format("  %s: x%.1f mult (final hand)", joker_name, acrobat_x))
        end
    end
    
    -- Mystic Summit: +mult if specific discards remaining
    if joker_name == 'Mystic Summit' then
        if G.GAME and G.GAME.current_round and joker.ability.extra then
            if G.GAME.current_round.discards_left == (joker.ability.extra.d_remaining or 0) then
                local summit_mult = joker.ability.extra.mult or 15
                joker_mult = joker_mult + summit_mult
                print(string.format("  %s: +%d mult (%d discards left)", joker_name, summit_mult, G.GAME.current_round.discards_left))
            end
        end
    end
    
    -- Misprint: random mult
    if joker_name == 'Misprint' then
        local min_mult = (joker.ability.extra and joker.ability.extra.min) or 0
        local max_mult = (joker.ability.extra and joker.ability.extra.max) or 23
        -- Use a simple average for prediction (we can't call pseudorandom safely)
        local avg_mult = math.floor((min_mult + max_mult) / 2)
        joker_mult = joker_mult + avg_mult
        print(string.format("  %s: +%d mult (avg, range %d-%d)", joker_name, avg_mult, min_mult, max_mult))
    end
    
    -- Banner: chips per discard remaining
    if joker_name == 'Banner' then
        if G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left > 0 then
            local banner_chips = G.GAME.current_round.discards_left * (joker.ability.extra or 30)
            joker_chips = joker_chips + banner_chips
            print(string.format("  %s: +%d chips (%d discards)", joker_name, banner_chips, G.GAME.current_round.discards_left))
        end
    end
    
    -- Stuntman: flat chips
    if joker_name == 'Stuntman' then
        local stunt_chips = (joker.ability.extra and joker.ability.extra.chip_mod) or 250
        joker_chips = joker_chips + stunt_chips
        print(string.format("  %s: +%d chips", joker_name, stunt_chips))
    end
    
    -- Matador: dollars if blind triggered
    if joker_name == 'Matador' then
        if G.GAME and G.GAME.blind and G.GAME.blind.triggered then
            -- This gives dollars, not chips/mult, so we track it but don't add to score
            print(string.format("  %s: $%d (blind triggered)", joker_name, joker.ability.extra or 8))
        end
    end
    
    -- Supernova: mult per times this hand played
    if joker_name == 'Supernova' then
        if G.GAME and G.GAME.hands and G.GAME.hands[hand_name] then
            local times_played = G.GAME.hands[hand_name].played or 0
            joker_mult = joker_mult + times_played
            print(string.format("  %s: +%d mult (hand played %d times)", joker_name, times_played, times_played))
        end
    end
    
    -- Ceremonial Dagger: static mult (builds up over time)
    if joker_name == 'Ceremonial Dagger' then
        if joker.ability.mult and joker.ability.mult > 0 then
            joker_mult = joker_mult + joker.ability.mult
            print(string.format("  %s: +%d mult", joker_name, joker.ability.mult))
        end
    end
    
    -- Loyalty Card: x_mult every N hands
    if joker_name == 'Loyalty Card' then
        if joker.ability.extra and joker.ability.loyalty_remaining then
            if joker.ability.loyalty_remaining == (joker.ability.extra.every or 5) then
                local loyalty_x = joker.ability.extra.Xmult or 4
                joker_x_mult = joker_x_mult * loyalty_x
                print(string.format("  %s: x%.1f mult (triggered)", joker_name, loyalty_x))
            end
        end
    end
    
    -- Gros Michel: flat +15 mult (unconditional)
    if joker_name == 'Gros Michel' then
        if joker.ability.extra and joker.ability.extra.mult then
            joker_mult = joker_mult + joker.ability.extra.mult
            print(string.format("  %s: +%d mult", joker_name, joker.ability.extra.mult))
        end
    end
    
    -- Cavendish: flat x3 mult (unconditional)
    if joker_name == 'Cavendish' then
        if joker.ability.extra and joker.ability.extra.Xmult then
            joker_x_mult = joker_x_mult * joker.ability.extra.Xmult
            print(string.format("  %s: x%.1f mult", joker_name, joker.ability.extra.Xmult))
        end
    end
    
    -- Ice Cream: flat chips (unconditional, decreases each round)
    if joker_name == 'Ice Cream' then
        if joker.ability.extra and joker.ability.extra.chips then
            joker_chips = joker_chips + joker.ability.extra.chips
            print(string.format("  %s: +%d chips", joker_name, joker.ability.extra.chips))
        end
    end
    
    -- Fortune Teller: mult per Tarot card used
    if joker_name == 'Fortune Teller' then
        if G.GAME and G.GAME.consumeable_usage_total and G.GAME.consumeable_usage_total.tarot then
            local tarot_count = G.GAME.consumeable_usage_total.tarot
            if tarot_count > 0 then
                joker_mult = joker_mult + tarot_count
                print(string.format("  %s: +%d mult (%d tarots used)", joker_name, tarot_count, tarot_count))
            end
        end
    end
    
    -- Record contribution if meaningful
    if joker_chips > 0 or joker_mult > 0 or joker_x_mult > 1 then
        table.insert(contributions, {
            joker = joker,
            name = joker_name,
            chips = joker_chips,
            mult = joker_mult,
            x_mult = joker_x_mult
        })
    else
        -- DEBUG: Log jokers that didn't trigger with their ability data
        print(string.format("  %s: NOT TRIGGERED - ability data:", joker_name))
        if joker.ability.mult and joker.ability.mult > 0 then
            print(string.format("    - ability.mult = %d", joker.ability.mult))
        end
        if joker.ability.extra then
            -- Check if extra is a table or a simple value
            if type(joker.ability.extra) == "table" then
                if joker.ability.extra.mult then
                    print(string.format("    - ability.extra.mult = %d", joker.ability.extra.mult))
                end
                if joker.ability.extra.chips then
                    print(string.format("    - ability.extra.chips = %d", joker.ability.extra.chips))
                end
                if joker.ability.extra.Xmult then
                    print(string.format("    - ability.extra.Xmult = %.2f", joker.ability.extra.Xmult))
                end
            else
                -- extra is a simple value (number, string, etc.)
                print(string.format("    - ability.extra = %s", tostring(joker.ability.extra)))
            end
        end
        if joker.ability.type then
            print(string.format("    - ability.type = '%s'", joker.ability.type))
        end
        if joker.ability.t_mult and joker.ability.t_mult > 0 then
            print(string.format("    - ability.t_mult = %d", joker.ability.t_mult))
        end
        if joker.ability.t_chips and joker.ability.t_chips > 0 then
            print(string.format("    - ability.t_chips = %d", joker.ability.t_chips))
        end
        if joker.ability.x_mult and joker.ability.x_mult > 1 then
            print(string.format("    - ability.x_mult = %.2f", joker.ability.x_mult))
        end
        if joker.ability.effect then
            print(string.format("    - ability.effect = '%s'", joker.ability.effect))
        end
    end
    
    return joker_chips, joker_mult, joker_x_mult, contributions
end

-- Calculate joker effects that trigger on the scoring hand (not individual cards)
-- This is called with context.joker_main = true
function joker_effects.scoring_hand(cards, scoring_hand, hand_name, poker_hands)
    local total_chips = 0
    local total_mult = 0
    local total_x_mult = 1
    local contributions = {}
    
    if not G.jokers or not G.jokers.cards then
        return total_chips, total_mult, total_x_mult, contributions
    end
    
    print(string.format("[JokerEffects] Calculating scoring_hand effects for %d jokers", #G.jokers.cards))
    
    -- Process each joker
    for i = 1, #G.jokers.cards do
        local joker = G.jokers.cards[i]
        
        -- Skip debuffed jokers
        if not joker.debuff and joker.ability and joker.ability.set == "Joker" then
            local joker_chips = 0
            local joker_mult = 0
            local joker_x_mult = 1
            local joker_name = joker.ability.name or "Unknown"
            
            -- === HAND TYPE JOKERS (t_chips, t_mult, x_mult with type) ===
            -- These jokers trigger when a specific poker hand is played
            
            -- Check if joker has a hand type requirement
            if joker.ability.type and joker.ability.type ~= '' then
                -- Check if the current hand matches the joker's required hand
                if poker_hands and poker_hands[joker.ability.type] and next(poker_hands[joker.ability.type]) then
                    -- Add chips from hand-specific jokers
                    if joker.ability.t_chips and joker.ability.t_chips > 0 then
                        joker_chips = joker_chips + joker.ability.t_chips
                        print(string.format("  %s: +%d chips (hand type: %s)", joker_name, joker.ability.t_chips, joker.ability.type))
                    end
                    
                    -- Add mult from hand-specific jokers
                    if joker.ability.t_mult and joker.ability.t_mult > 0 then
                        joker_mult = joker_mult + joker.ability.t_mult
                        print(string.format("  %s: +%d mult (hand type: %s)", joker_name, joker.ability.t_mult, joker.ability.type))
                    end
                    
                    -- Add x_mult from hand-specific jokers (but NOT Seeing Double)
                    if joker_name ~= 'Seeing Double' and joker.ability.x_mult and joker.ability.x_mult > 1 then
                        joker_x_mult = joker_x_mult * joker.ability.x_mult
                        print(string.format("  %s: x%.2f mult (hand type: %s)", joker_name, joker.ability.x_mult, joker.ability.type))
                    end
                end
            else
                -- No hand type requirement - check for generic x_mult jokers
                if joker_name ~= 'Seeing Double' and joker.ability.x_mult and joker.ability.x_mult > 1 then
                    joker_x_mult = joker_x_mult * joker.ability.x_mult
                    print(string.format("  %s: x%.2f mult (always active)", joker_name, joker.ability.x_mult))
                end
            end
            
            -- === SPECIAL JOKERS (specific implementations) ===
            
            -- Half Joker: +mult if hand size <= 3
            if joker_name == 'Half Joker' then
                if cards and #cards <= (joker.ability.extra and joker.ability.extra.size or 3) then
                    local half_mult = (joker.ability.extra and joker.ability.extra.mult) or 20
                    joker_mult = joker_mult + half_mult
                    print(string.format("  %s: +%d mult (hand size %d)", joker_name, half_mult, #cards))
                end
            end
            
            -- Abstract Joker: +mult per joker
            if joker_name == 'Abstract Joker' then
                local joker_count = 0
                for j = 1, #G.jokers.cards do
                    if G.jokers.cards[j].ability.set == 'Joker' then
                        joker_count = joker_count + 1
                    end
                end
                local abstract_mult = joker_count * (joker.ability.extra or 3)
                joker_mult = joker_mult + abstract_mult
                print(string.format("  %s: +%d mult (%d jokers)", joker_name, abstract_mult, joker_count))
            end
            
            -- Acrobat: x_mult if 0 hands left
            if joker_name == 'Acrobat' then
                if G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left == 0 then
                    local acrobat_x = joker.ability.extra or 3
                    joker_x_mult = joker_x_mult * acrobat_x
                    print(string.format("  %s: x%.1f mult (final hand)", joker_name, acrobat_x))
                end
            end
            
            -- Mystic Summit: +mult if specific discards remaining
            if joker_name == 'Mystic Summit' then
                if G.GAME and G.GAME.current_round and joker.ability.extra then
                    if G.GAME.current_round.discards_left == (joker.ability.extra.d_remaining or 0) then
                        local summit_mult = joker.ability.extra.mult or 15
                        joker_mult = joker_mult + summit_mult
                        print(string.format("  %s: +%d mult (%d discards left)", joker_name, summit_mult, G.GAME.current_round.discards_left))
                    end
                end
            end
            
            -- Misprint: random mult
            if joker_name == 'Misprint' then
                local min_mult = (joker.ability.extra and joker.ability.extra.min) or 0
                local max_mult = (joker.ability.extra and joker.ability.extra.max) or 23
                -- Use a simple average for prediction (we can't call pseudorandom safely)
                local avg_mult = math.floor((min_mult + max_mult) / 2)
                joker_mult = joker_mult + avg_mult
                print(string.format("  %s: +%d mult (avg, range %d-%d)", joker_name, avg_mult, min_mult, max_mult))
            end
            
            -- Banner: chips per discard remaining
            if joker_name == 'Banner' then
                if G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left > 0 then
                    local banner_chips = G.GAME.current_round.discards_left * (joker.ability.extra or 30)
                    joker_chips = joker_chips + banner_chips
                    print(string.format("  %s: +%d chips (%d discards)", joker_name, banner_chips, G.GAME.current_round.discards_left))
                end
            end
            
            -- Stuntman: flat chips
            if joker_name == 'Stuntman' then
                local stunt_chips = (joker.ability.extra and joker.ability.extra.chip_mod) or 250
                joker_chips = joker_chips + stunt_chips
                print(string.format("  %s: +%d chips", joker_name, stunt_chips))
            end
            
            -- Matador: dollars if blind triggered
            if joker_name == 'Matador' then
                if G.GAME and G.GAME.blind and G.GAME.blind.triggered then
                    -- This gives dollars, not chips/mult, so we track it but don't add to score
                    print(string.format("  %s: $%d (blind triggered)", joker_name, joker.ability.extra or 8))
                end
            end
            
            -- Supernova: mult per times this hand played
            if joker_name == 'Supernova' then
                if G.GAME and G.GAME.hands and G.GAME.hands[hand_name] then
                    local times_played = G.GAME.hands[hand_name].played or 0
                    joker_mult = joker_mult + times_played
                    print(string.format("  %s: +%d mult (hand played %d times)", joker_name, times_played, times_played))
                end
            end
            
            -- Ceremonial Dagger: static mult (builds up over time)
            if joker_name == 'Ceremonial Dagger' then
                if joker.ability.mult and joker.ability.mult > 0 then
                    joker_mult = joker_mult + joker.ability.mult
                    print(string.format("  %s: +%d mult", joker_name, joker.ability.mult))
                end
            end
            
            -- Loyalty Card: x_mult every N hands
            if joker_name == 'Loyalty Card' then
                if joker.ability.extra and joker.ability.loyalty_remaining then
                    if joker.ability.loyalty_remaining == (joker.ability.extra.every or 5) then
                        local loyalty_x = joker.ability.extra.Xmult or 4
                        joker_x_mult = joker_x_mult * loyalty_x
                        print(string.format("  %s: x%.1f mult (triggered)", joker_name, loyalty_x))
                    end
                end
            end
            
            -- Add joker's contribution to totals
            total_chips = total_chips + joker_chips
            total_mult = total_mult + joker_mult
            total_x_mult = total_x_mult * joker_x_mult
            
            -- Record contribution if meaningful
            if joker_chips > 0 or joker_mult > 0 or joker_x_mult > 1 then
                table.insert(contributions, {
                    joker = joker,
                    name = joker_name,
                    chips = joker_chips,
                    mult = joker_mult,
                    x_mult = joker_x_mult
                })
            end
        end
    end
    
    print(string.format("[JokerEffects] Totals: +%d chips, +%d mult, x%.2f mult", total_chips, total_mult, total_x_mult))
    
    return total_chips, total_mult, total_x_mult, contributions
end

-- Calculate joker effects for a single card
-- is_scoring: true if card is in scoring hand, false if card is held in hand
-- blueprint_depth: prevents infinite loops when Blueprint/Brainstorm copy each other
function joker_effects.single_card(card, cards, scoring_hand, hand_name, poker_hands, is_scoring, blueprint_depth)
    local total_chips = 0
    local total_mult = 0
    local total_x_mult = 1
    local contributions = {}
    
    -- Prevent infinite Blueprint/Brainstorm loops
    blueprint_depth = blueprint_depth or 0
    if blueprint_depth > 10 then
        return total_chips, total_mult, total_x_mult, contributions
    end
    
    if not card or card.debuff then
        return total_chips, total_mult, total_x_mult, contributions
    end
    
    if not G.jokers or not G.jokers.cards then
        return total_chips, total_mult, total_x_mult, contributions
    end
    
    local card_type = is_scoring and "scoring" or "held"
    local card_name = (card.base and card.base.value) or "Unknown"
    local card_id = card.base and card.base.id or (card.get_id and card:get_id()) or 0
    local card_suit = card.base and card.base.suit or "Unknown"
    
    print(string.format("[JokerEffects] Calculating %s card effects: %s of %s (ID:%d)", 
        card_type, card_name, card_suit, card_id))
    
    -- Process each joker
    for i = 1, #G.jokers.cards do
        local joker = G.jokers.cards[i]
        
        -- Skip debuffed jokers
        if not joker.debuff and joker.ability and joker.ability.set == "Joker" then
            local joker_chips = 0
            local joker_mult = 0
            local joker_x_mult = 1
            local joker_h_mult = 0  -- Hold mult (for held cards)
            local joker_name = joker.ability.name or "Unknown"
            
            -- === BLUEPRINT AND BRAINSTORM ===
            -- These jokers copy the ability of another joker for individual card effects
            if joker_name == 'Blueprint' or joker_name == 'Brainstorm' then
                local other_joker = nil
                
                if joker_name == 'Brainstorm' then
                    -- Brainstorm copies the leftmost joker
                    other_joker = G.jokers.cards[1]
                elseif joker_name == 'Blueprint' then
                    -- Blueprint copies the joker to its right
                    for j = 1, #G.jokers.cards do
                        if G.jokers.cards[j] == joker then
                            if j + 1 <= #G.jokers.cards then
                                other_joker = G.jokers.cards[j + 1]
                            end
                            break
                        end
                    end
                end
                
                -- Check if we can copy this joker
                if other_joker and other_joker ~= joker and not other_joker.debuff then
                    -- Check blueprint compatibility
                    local is_compatible = true
                    if other_joker.config and other_joker.config.center and other_joker.config.center.blueprint_compat == false then
                        is_compatible = false
                    end
                    
                    if is_compatible then
                        -- We need to process the copied joker's individual card effect
                        -- This is tricky because we're in a loop - we need to extract the logic
                        -- For now, we'll call this function recursively with a modified jokers list
                        -- containing only the copied joker
                        print(string.format("  %s: copying %s for individual card effect", 
                            joker_name, other_joker.ability and other_joker.ability.name or "Unknown"))
                        
                        -- Create a temporary context where only the copied joker exists
                        local saved_jokers = G.jokers.cards
                        G.jokers.cards = {other_joker}
                        
                        local copy_chips, copy_mult, copy_x_mult, copy_contribs = 
                            joker_effects.single_card(card, cards, scoring_hand, hand_name, poker_hands, is_scoring, blueprint_depth + 1)
                        
                        G.jokers.cards = saved_jokers
                        
                        -- Add the copied effect
                        joker_chips = joker_chips + copy_chips
                        joker_mult = joker_mult + copy_mult
                        joker_x_mult = joker_x_mult * copy_x_mult
                    else
                        print(string.format("  %s: target joker not compatible", joker_name))
                    end
                end
                
                -- Skip the rest of the loop since Blueprint/Brainstorm don't have their own effects
                goto continue_joker_loop
            end
            
            -- === SCORING CARD EFFECTS ===
            if is_scoring then
                -- Hiker: Permanent +5 chips to every played card
                if joker_name == 'Hiker' then
                    joker_chips = joker_chips + (joker.ability.extra or 5)
                    print(string.format("  %s: +%d chips (permanent bonus)", joker_name, joker.ability.extra or 5))
                end
                
                -- Lucky Cat: x_mult builds up when Lucky cards trigger
                -- Note: We can't track lucky_trigger safely, so we skip the upgrade logic
                
                -- Wee Joker: Upgrades when 2s are played
                -- Note: We skip the upgrade logic but can still use current value
                
                -- Photograph: x_mult on first face card
                if joker_name == 'Photograph' then
                    local is_first_face = false
                    if card.is_face and card:is_face() then
                        -- Check if this is the first face card in scoring hand
                        for j = 1, #scoring_hand do
                            if scoring_hand[j].is_face and scoring_hand[j]:is_face() then
                                is_first_face = (scoring_hand[j] == card)
                                break
                            end
                        end
                    end
                    if is_first_face then
                        joker_x_mult = joker_x_mult * (joker.ability.extra or 2)
                        print(string.format("  %s: x%.1f mult (first face)", joker_name, joker.ability.extra or 2))
                    end
                end
                
                -- 8 Ball: Create Tarot when 8 is played (chance-based)
                -- Note: We skip the card creation logic
                
                -- The Idol: x_mult for specific card rank and suit
                if joker_name == 'The Idol' then
                    if G.GAME and G.GAME.current_round and G.GAME.current_round.idol_card then
                        local idol = G.GAME.current_round.idol_card
                        local matches = (card_id == idol.id)
                        if matches and card.is_suit and card:is_suit(idol.suit) then
                            joker_x_mult = joker_x_mult * (joker.ability.extra or 2)
                            print(string.format("  %s: x%.1f mult (matches idol)", joker_name, joker.ability.extra or 2))
                        end
                    end
                end
                
                -- Scary Face: +30 chips per face card
                if joker_name == 'Scary Face' then
                    if card.is_face and card:is_face() then
                        joker_chips = joker_chips + (joker.ability.extra or 30)
                        print(string.format("  %s: +%d chips (face card)", joker_name, joker.ability.extra or 30))
                    end
                end
                
                -- Smiley Face: +4 mult per face card
                if joker_name == 'Smiley Face' then
                    if card.is_face and card:is_face() then
                        joker_mult = joker_mult + (joker.ability.extra or 4)
                        print(string.format("  %s: +%d mult (face card)", joker_name, joker.ability.extra or 4))
                    end
                end
                
                -- Golden Ticket: $3 per Gold card
                -- Note: We skip dollar rewards
                
                -- Scholar: +20 chips, +4 mult for Aces
                if joker_name == 'Scholar' then
                    if card_id == 14 then
                        if joker.ability.extra then
                            joker_chips = joker_chips + (joker.ability.extra.chips or 20)
                            joker_mult = joker_mult + (joker.ability.extra.mult or 4)
                            print(string.format("  %s: +%d chips, +%d mult (Ace)", 
                                joker_name, joker.ability.extra.chips or 20, joker.ability.extra.mult or 4))
                        end
                    end
                end
                
                -- Walkie Talkie: +10 chips, +4 mult for 10s and 4s
                if joker_name == 'Walkie Talkie' then
                    if card_id == 10 or card_id == 4 then
                        if joker.ability.extra then
                            joker_chips = joker_chips + (joker.ability.extra.chips or 10)
                            joker_mult = joker_mult + (joker.ability.extra.mult or 4)
                            print(string.format("  %s: +%d chips, +%d mult (10 or 4)", 
                                joker_name, joker.ability.extra.chips or 10, joker.ability.extra.mult or 4))
                        end
                    end
                end
                
                -- Business Card: 1 in 2 chance for $2 per face card
                -- Note: We skip dollar rewards
                
                -- Fibonacci: +8 mult for Fibonacci numbers (A,2,3,5,8)
                if joker_name == 'Fibonacci' then
                    if card_id == 2 or card_id == 3 or card_id == 5 or card_id == 8 or card_id == 14 then
                        joker_mult = joker_mult + (joker.ability.extra or 8)
                        print(string.format("  %s: +%d mult (Fibonacci)", joker_name, joker.ability.extra or 8))
                    end
                end
                
                -- Even Steven: +4 mult for even ranks
                if joker_name == 'Even Steven' then
                    if card_id <= 10 and card_id >= 0 and card_id % 2 == 0 then
                        joker_mult = joker_mult + (joker.ability.extra or 4)
                        print(string.format("  %s: +%d mult (even rank)", joker_name, joker.ability.extra or 4))
                    end
                end
                
                -- Odd Todd: +31 chips for odd ranks
                if joker_name == 'Odd Todd' then
                    local is_odd = ((card_id <= 10 and card_id >= 0 and card_id % 2 == 1) or (card_id == 14))
                    if is_odd then
                        joker_chips = joker_chips + (joker.ability.extra or 31)
                        print(string.format("  %s: +%d chips (odd rank)", joker_name, joker.ability.extra or 31))
                    end
                end
                
                -- Suit Mult Jokers (Smeared Joker, etc): +mult for specific suit
                -- Wild cards count as all suits (handled by is_suit method)
                if joker.ability.effect == 'Suit Mult' then
                    if card.is_suit and card:is_suit(joker.ability.extra.suit) then
                        local suit_mult = joker.ability.extra.s_mult or 4
                        joker_mult = joker_mult + suit_mult
                        local is_wild = card.ability and card.ability.name == 'Wild Card'
                        print(string.format("  %s: +%d mult (suit: %s%s)", 
                            joker_name, suit_mult, joker.ability.extra.suit, is_wild and " [wild]" or ""))
                    end
                end
                
                -- Rough Gem: $1 per Diamond
                -- Note: We skip dollar rewards
                
                -- Onyx Agate: +7 mult per Club (wild cards count as Clubs via is_suit)
                if joker_name == 'Onyx Agate' then
                    if card.is_suit and card:is_suit("Clubs") then
                        joker_mult = joker_mult + (joker.ability.extra or 7)
                        local is_wild = card.ability and card.ability.name == 'Wild Card'
                        print(string.format("  %s: +%d mult (Club%s)", joker_name, joker.ability.extra or 7, is_wild and " [wild]" or ""))
                    end
                end
                
                -- Arrowhead: +50 chips per Spade (wild cards count as Spades via is_suit)
                if joker_name == 'Arrowhead' then
                    if card.is_suit and card:is_suit("Spades") then
                        joker_chips = joker_chips + (joker.ability.extra or 50)
                        local is_wild = card.ability and card.ability.name == 'Wild Card'
                        print(string.format("  %s: +%d chips (Spade%s)", joker_name, joker.ability.extra or 50, is_wild and " [wild]" or ""))
                    end
                end
                
                -- Bloodstone: 1 in 2 chance for x1.5 per Heart (wild cards count as Hearts via is_suit)
                if joker_name == 'Bloodstone' then
                    if card.is_suit and card:is_suit("Hearts") then
                        -- Use average for prediction: 50% chance
                        -- We'll apply it conservatively (not applying for prediction safety)
                        local is_wild = card.ability and card.ability.name == 'Wild Card'
                        print(string.format("  %s: (50%% chance x%.1f for Heart%s - not predicted)", 
                            joker_name, joker.ability.extra and joker.ability.extra.Xmult or 1.5, is_wild and " [wild]" or ""))
                    end
                end
                
                -- Ancient Joker: x_mult for cards matching ancient suit (wild cards always match via is_suit)
                if joker_name == 'Ancient Joker' then
                    if G.GAME and G.GAME.current_round and G.GAME.current_round.ancient_card then
                        if card.is_suit and card:is_suit(G.GAME.current_round.ancient_card.suit) then
                            joker_x_mult = joker_x_mult * (joker.ability.extra or 1.5)
                            local is_wild = card.ability and card.ability.name == 'Wild Card'
                            print(string.format("  %s: x%.1f mult (ancient suit: %s%s)", 
                                joker_name, joker.ability.extra or 1.5, G.GAME.current_round.ancient_card.suit, is_wild and " [wild]" or ""))
                        end
                    end
                end
                
                -- Triboulet: x2 mult for Kings and Queens
                if joker_name == 'Triboulet' then
                    if card_id == 12 or card_id == 13 then
                        joker_x_mult = joker_x_mult * (joker.ability.extra or 2)
                        print(string.format("  %s: x%.1f mult (King/Queen)", joker_name, joker.ability.extra or 2))
                    end
                end
                
            -- === HELD CARD EFFECTS ===
            else
                -- Shoot the Moon: +13 mult per Queen in hand
                if joker_name == 'Shoot the Moon' then
                    if card_id == 12 then
                        joker_h_mult = joker_h_mult + 13
                        print(string.format("  %s: +13 h_mult (Queen in hand)", joker_name))
                    end
                end
                
                -- Baron: x1.5 mult per King in hand
                if joker_name == 'Baron' then
                    if card_id == 13 then
                        joker_x_mult = joker_x_mult * (joker.ability.extra or 1.5)
                        print(string.format("  %s: x%.1f mult (King in hand)", joker_name, joker.ability.extra or 1.5))
                    end
                end
            end
            
            -- Add joker's contribution to totals
            total_chips = total_chips + joker_chips
            total_mult = total_mult + joker_mult + joker_h_mult  -- h_mult is just added to mult
            total_x_mult = total_x_mult * joker_x_mult
            
            -- Record contribution if meaningful
            if joker_chips > 0 or joker_mult > 0 or joker_h_mult > 0 or joker_x_mult > 1 then
                table.insert(contributions, {
                    joker = joker,
                    name = joker_name,
                    chips = joker_chips,
                    mult = joker_mult + joker_h_mult,
                    x_mult = joker_x_mult,
                    is_scoring = is_scoring
                })
            end
            
            ::continue_joker_loop::
        end
    end
    
    if total_chips > 0 or total_mult > 0 or total_x_mult > 1 then
        print(string.format("  Card totals: +%d chips, +%d mult, x%.2f mult", total_chips, total_mult, total_x_mult))
    end
    
    return total_chips, total_mult, total_x_mult, contributions
end

-- Calculate total repetitions for a card (from seal + jokers)
-- Returns total number of repetitions (1 = no repeat, 2 = one repeat, etc.)
function joker_effects.calculate_repetitions(card, cards, scoring_hand, hand_name, poker_hands, is_scoring)
    local total_reps = 1 -- Start with base scoring (no repetition)
    
    if not card then
        return total_reps
    end
    
    -- Check for Red Seal (adds 1 repetition)
    if card.seal == 'Red' then
        total_reps = total_reps + 1
        print(string.format("    Red Seal: +1 repetition"))
    end
    
    -- Check jokers for repetitions (only for scoring cards)
    if is_scoring and G.jokers and G.jokers.cards then
        for j = 1, #G.jokers.cards do
            local joker = G.jokers.cards[j]
            
            if not joker.debuff and joker.ability and joker.ability.set == 'Joker' then
                local joker_name = joker.ability.name or "Unknown"
                local joker_reps = 0
                
                -- Sock and Buskin: retrigger face cards
                if joker_name == 'Sock and Buskin' then
                    if card.ability and card.ability.effect ~= 'Stone Card' then
                        if card.base and card.base.face then
                            joker_reps = joker.ability.extra or 2
                        end
                    end
                end
                
                -- Hanging Chad: retrigger first card
                if joker_name == 'Hanging Chad' then
                    if scoring_hand and #scoring_hand > 0 and card == scoring_hand[1] then
                        joker_reps = joker.ability.extra or 2
                    end
                end
                
                -- Dusk: retrigger all cards on final hand
                if joker_name == 'Dusk' then
                    if G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left == 0 then
                        joker_reps = joker.ability.extra or 2
                    end
                end
                
                if joker_reps > 0 then
                    total_reps = total_reps + joker_reps
                    print(string.format("    %s: +%d repetition(s)", joker_name, joker_reps))
                end
            end
        end
    end
    
    return total_reps
end

return joker_effects