# MiniMapimous

A clean and modern minimap enhancement addon for World of Warcraft with customizable data bars and intelligent button collection.

## ✨ Features

### 🗺️ **Square Minimap**
- Clean square minimap design with custom border
- Mousewheel zoom support
- Right-click for tracking menu
- Scalable from 50% to 200%

### 📊 **Data Text Bars**
- **Minimap Data Bar**: Attached below minimap
- **First Data Bar**: Movable, customizable positioning
- **Second Data Bar**: Optional additional bar
- **10 Data Text Types**: FPS, Memory, Coordinates, Clock, Durability, Gold, Guild, Friends, Latency, Mail

### 🔧 **Intelligent Button Collection**
- Automatically collects addon buttons into a clean bar
- Supports LibDBIcon buttons
- Optional Blizzard button inclusion
- Hide bar with minimap hover functionality
- Smart positioning left or right of minimap

### 🎨 **Customization Options**
- Individual font sizes for each data bar (8-20px)
- Opacity controls for movable bars
- Flexible data text positioning (hide, minimap, first bar, second bar)
- Lock/unlock movable bars
- Color-coded data texts (FPS, durability, latency)

## 📥 Installation

1. Download the latest release
2. Extract to `World of Warcraft\_retail_\Interface\AddOns\`
3. Restart WoW or reload UI (`/reload`)
4. Configure via `/minimapimous` or Interface > AddOns > MiniMapimous

## 🎮 Commands

- `/minimapimous` or `/mmap` - Open configuration
- `/reload` - Reload UI if needed

## 🔧 Configuration

Access the configuration panel through:
- Slash command: `/minimapimous`
- Interface Options > AddOns > MiniMapimous
- Main Menu > Interface > AddOns > MiniMapimous

### Data Text Features
- **FPS**: Color-coded performance indicator (Green ≥60, Yellow 30-59, Red <30)
- **Memory**: Real-time addon memory and CPU usage with detailed tooltip
- **Coordinates**: Current player position
- **Clock**: Local time with server time in tooltip, click to open calendar
- **Durability**: Gear condition with color coding (Green ≥75%, Yellow 25-74%, Red <25%)
- **Gold**: Formatted currency display
- **Guild**: Online member count with member list tooltip
- **Friends**: Battle.net and WoW friends online
- **Latency**: Network ping with color coding
- **Mail**: Unread mail count (unclickable, for display only)

## 🎯 Recent Updates

- Simplified interface with clean single-column layout
- Removed complex detach/minimize functionality for better stability
- Enhanced data text color coding and tooltips
- Perfect minimap data bar alignment and scaling
- Unclickable mail data text (display only)
- Font size controls for First and Second data bars
- Streamlined button collection focusing on mouseover functionality

## 🐛 Known Issues

- Some addon buttons may require a `/reload` to be properly collected
- Mail icon visibility depends on Blizzard's UI changes

## 🔄 Compatibility

- **WoW Version**: Retail (The War Within and later)
- **Dependencies**: None
- **Conflicts**: May conflict with other minimap addons

## 🤝 Contributing

Feel free to submit issues, feature requests, or pull requests!

## 📄 License

MIT License - Feel free to modify and redistribute.

---

**Enjoy your clean minimap experience! 🎮** 