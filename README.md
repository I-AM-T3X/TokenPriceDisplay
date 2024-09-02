# TokenPriceChecker

**TokenPriceChecker** is a lightweight World of Warcraft addon that displays the current WoW Token market price in a small, movable window on your screen. The addon automatically updates the token price every 5 minutes, ensuring you always have the most up-to-date information.

## Features

- **Live WoW Token Price Display**: Shows the current market price of the WoW Token in a compact window.
- **Automatic Updates**: Refreshes the token price every 5 minutes to keep it current.
- **Dynamic Frame Resizing**: The frame size adjusts automatically based on the length of the displayed price, ensuring a clean and polished look.
- **Movable Window**: Easily drag the window to any position on your screen.

## Installation

1. **Download** the latest release from the [Releases](https://github.com/I-AM-T3X/TokenPriceChecker/releases) page.
2. **Extract** the `TokenPriceChecker` folder to your World of Warcraft `Interface/AddOns` directory.
   - On Windows, this is typically:  
     `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\`
   - On macOS, this is typically:  
     `/Applications/World of Warcraft/_retail_/Interface/AddOns/`
3. **Restart** World of Warcraft or use the `/reload` command in the game to load the addon.

## Usage

- After installation, the addon will automatically display the WoW Token price in a small window on your screen.
- **Move the Window**: Click and drag the window to reposition it anywhere on your screen.
- The price is **updated every 5 minutes**. Ensure you are connected to the internet to get the latest price.

## Planned Features

- Customization options for text size, color, and font.

## Contributing

We welcome contributions from the community! If you have suggestions, encounter bugs, or want to contribute to the development of **TokenPriceChecker**, please follow these steps:

1. **Fork** the repository.
2. **Create a new branch**: `git checkout -b feature/YourFeatureName`.
3. **Commit your changes**: `git commit -m 'Add some feature'`.
4. **Push to the branch**: `git push origin feature/YourFeatureName`.
5. **Open a Pull Request**.

For major changes, please open an issue first to discuss what you would like to change.

## Issues and Feedback

If you find a bug or have a feature request, please report it on the [Issues](https://github.com/I-AM-T3X/TokenPriceChecker/issues) page. Your feedback is highly appreciated!

## License

This addon is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Acknowledgments

- Thanks to the World of Warcraft community for the inspiration and support.
- Special thanks to lightsky.gg for the suggestion to use `C_WowTokenPublic.UpdateMarketPrice()` to keep the addon up-to-date.
