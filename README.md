# Token Price Display

**Token Price Display** is a lightweight World of Warcraft addon that displays the current WoW Token market price in a small, movable window on your screen. The addon automatically updates the token price every 5 minutes, ensuring you always have the most up-to-date information.

## Features

- **Live WoW Token Price Display**: Shows the current market price of the WoW Token in a compact window.
- **Automatic Updates**: Refreshes the token price every 5 minutes to keep it current.
- **Dynamic Frame Resizing**: The frame size adjusts automatically based on the length of the displayed price, ensuring a clean and polished look.
- **Movable Window**: Easily drag the window to any position on your screen.

## Installation

1. **Download** the latest release from the [Releases](https://github.com/I-AM-T3X/TokenPriceDisplay/releases) page.
2. **Extract** the `TokenPriceDisplay` folder to your World of Warcraft `Interface/AddOns` directory:
   - **Windows**: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\`
   - **macOS**: `/Applications/World of Warcraft/_retail_/Interface/AddOns/`
3. **Restart** World of Warcraft or type `/reload` in the game console to load the addon.

## Usage

- After installation, the addon will automatically display the WoW Token price in a small window on your screen.
- **Move the Window**: Click and drag the window to reposition it anywhere on your screen.
- The price is **updated every 5 minutes**. Ensure you are connected to the internet to get the latest price.

## Planned Features

- Customization options for text size, color, and font.
## Changelog

### v1.55 - Compatibility Update

### Improvements
- **Updated Interface Version**: Updated the interface ID to 110005 to ensure compatibility with the upcoming patch 11.0.5.
- **General Maintenance**: No major code changes; this update is to mark the addon as compatible and prevent it from being flagged as "Out of Date".

Thanks for your continued use of Token Price Display

### v1.54 - Visual Enhancements

- **New Price Indicators**: Added icons to show token price changes:
  - **Up Arrow**: `Interface\\Icons\\Misc_Arrowlup` for price increases.
  - **Down Arrow**: `Interface\\Icons\\Misc_Arrowdown` for price decreases.
  - **No Change**: `Interface\\Buttons\\UI-GroupLoot-Pass-Up` when the price remains the same.
- **Cleaned Up Debug Messages**: Removed unnecessary debug print statements for a smoother experience.

This update improves clarity with new visual indicators and a cleaner console.

### v1.53 - New Settings Integration and UI Enhancements

### New Features
- **New Settings Integration**: The settings panel is now implemented using the new `Settings` API, providing a more intuitive and seamless experience within the WoW Interface Options.
- **Slash Command to Open Settings**: You can now use the `/tpd settings` command to open the settings panel directly, making customization quick and easy.

### Improvements
- **Refined Layout with `Settings.RegisterCanvasLayoutCategory`**: The settings panel layout has been updated to utilize `Settings.RegisterCanvasLayoutCategory` for proper registration and compatibility with the WoW settings interface.
- **Dynamic Category Opening**: The settings panel now correctly opens to the specified category using `category:GetID()` for smooth navigation without errors.
- **Enhanced UI Elements**: Improved button and label configurations for changing frame and text colors, as well as resetting to defaults, now fully integrated with the settings system.

### Bug Fixes
- **General Stability Enhancements**: Various code refinements have been made for stability and compatibility with the latest WoW version.

Thank you for using Token Price Display! Enjoy the new and improved settings experience.

### v1.52 - UI Refinements and Minor Fixes

**Updated:**
- **Reset Button Label**: Shortened the "Reset to Default Colors" button text to "Reset to Default" to prevent text from touching the button frame and improve visual clarity.
- **UI Improvements**: Minor graphical adjustments to ensure all UI elements are properly aligned and spaced within the settings window.

These changes provide a cleaner, more polished user interface for better usability.

### v1.51 - Improved Color Picker Handling

**Improved:**
- **Color Picker Position Management**: The Color Picker now saves its original position when opened and resets it after use, ensuring compatibility with other addons.
  - The Color Picker remains draggable for users, maintaining flexibility and ease of use.
  - This prevents the Color Picker from appearing in unexpected locations if moved by another addon.

**Other Minor Tweaks**:
- Refined the `ShowColorPicker` function to handle positioning more gracefully and avoid conflicts with the UI.

### v1.5 - Enhanced Customization and Improved Color Picker

**Added:**
- **Color Picker Integration**: Replaced RGB sliders with the built-in WoW `ColorPickerFrame`, allowing users to choose colors more intuitively.
  - Users can select custom colors for the frame and text using the color picker.
  - The selected colors update immediately and are saved to ensure consistency across sessions and characters.
- **Improved Settings Window**: Streamlined the settings interface to make customization easier:
  - Removed redundant RGB slider controls and replaced them with buttons to open the color picker.
  - Adjusted the layout to ensure better spacing and alignment.
- **Refactored Code**:
  - Enhanced frame position and color loading functions to reduce redundancy and improve stability.
  - Simplified event handling and initialization for better performance and maintainability.

### v1.4 - User Customization and Persistance Across Characters

**Added:**
- **Settings Window:** A new settings window has been introduced, allowing users to customize the color of the frame to better match their UI.
  - **Access:** Type `/tpd settings` into chat to open the settings window.
- **Color Customization:** Users can now adjust the frame color using RGB values in the settings window.
- **Persistent Color Settings:** The RGB color values are now saved into the global saved variables, ensuring consistent frame color across all characters.

### v1.3 - Persistent Frame Position Across Characters

- **Global Saved Variables**: Changed saved variables to global to share frame positions across all characters.
- **Improved Frame Position Handling**: Now uses the `PLAYER_LOGIN` event to ensure the frame is positioned correctly after the UI is fully loaded.
- **Dynamic Position Loading**: Clears and sets frame points dynamically to prevent conflicts when loading saved positions.
- **General Code Optimization**: Enhanced overall stability and performance.

### v1.2 - Event-Driven Price Updates

- Added event-driven updates using `TOKEN_MARKET_PRICE_UPDATED` to ensure accurate and timely WoW Token price updates.
- Automatically refreshes token prices upon login or UI reload.
- Optimized the code to improve reliability and prevent outdated price information.

### v1.1 - Initial Release

- Live WoW Token price display with automatic updates every 5 minutes.
- Movable and resizable window for easy customization.

## Contributing

We welcome contributions from the community! If you have suggestions, encounter bugs, or want to contribute to the development of **Token Price Display**, please follow these steps:

1. **Fork** the repository.
2. **Create a new branch**: `git checkout -b feature/YourFeatureName`.
3. **Commit your changes**: `git commit -m 'Add some feature'`.
4. **Push to the branch**: `git push origin feature/YourFeatureName`.
5. **Open a Pull Request**.

For major changes, please open an issue first to discuss what you would like to change.

## Issues and Feedback

If you find a bug or have a feature request, please report it on the [Issues](https://github.com/I-AM-T3X/TokenPriceDisplay/issues) page. Your feedback is highly appreciated!

## License

This addon is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Acknowledgments

- Thanks to the World of Warcraft community for the inspiration and support.
- Special thanks to **LightSky.GG** for the suggestion to use `C_WowTokenPublic.UpdateMarketPrice()` to keep the addon up-to-date.
