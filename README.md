# ChipPredictor

A Balatro mod that provides real-time chip and mult predictions for your selected hands, including detailed joker effect breakdowns.

## Features

- **Real-time Predictions**: See the exact score for your selected hand before playing it
- **Joker Effect Tracking**: Detailed breakdown of how each joker contributes to your score
- **Blueprint & Brainstorm Support**: Accurately predicts effects when jokers copy other jokers
- **Card Repetition Tracking**: Handles Red Seal, Sock and Buskin, Hanging Chad, and Dusk repetitions
- **Smart Updates**: Only recalculates when hand selection or joker order changes

## Installation

1. Install [Steamodded](https://github.com/Steamopollys/Steamodded) mod loader for Balatro
2. Download this mod and extract to `%appdata%/Balatro/Mods/ChipPredictor`
3. Launch Balatro with mods enabled

## How It Works

The mod hooks into the game's card selection system and calculates the exact score you'll get by:

1. Evaluating the base poker hand (pair, flush, etc.)
2. Adding card chip values and mult values
3. Applying card editions (foil, holo, polychrome)
4. Processing joker effects in correct order
5. Handling card repetitions (seals and joker effects)

## Supported Features

### Card Effects
- Base card chips and mult
- Stone cards, Bonus cards, Mult cards, Glass cards, Steel cards, Lucky cards (prediction skips probabilistic effects)
- Wild cards (count as all suits)
- Card editions (Foil, Holo, Polychrome)
- Red Seal repetitions

### Joker Effects
- Hand-type specific jokers (Flower Pot, Scary Face, etc.)
- Individual card effects (Hiker, Scholar, Even Steven, Odd Todd, etc.)
- Position-dependent jokers (Blueprint, Brainstorm)
- Card repetition jokers (Sock and Buskin, Hanging Chad, Dusk)
- X-mult jokers (Baron, Ancient Joker, Triboulet, etc.)
- Dynamic jokers (Swashbuckler, Fortune Teller, etc.)

## Known Limitations

- Lucky card mult bonuses are not predicted (1/5 chance, too unreliable)
- Probabilistic effects are skipped for prediction accuracy
- Some jokers with complex state changes may not be fully tracked

## Version

0.0.1 - Initial release

## Author

92Garfield

## License

MIT License
