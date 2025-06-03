# MiniMapimous

A clean and modern minimap enhancement addon for World of Warcraft with customizable data bars and intelligent button collection.

## ✨ Features

### 🗺️ **Square Minimap**
- Clean square minimap design with custom border
- Mousewheel zoom support
- Right-click for tracking menu
- Scalable from 50% to 200%

### 📊 **Data Text Bars**
- **Minimap Data Bar**: Attached below minimap (up to 3 data texts)
- **First Data Bar**: Movable, customizable positioning
- **Second Data Bar**: Optional additional bar
- **15 Data Text Types**: Memory, Coordinates, Clock, Durability, Gold, Guild, Friends, Mail, Experience, Bags, Talents, Reputation, Currency, Session, Performance

### 📈 **Enhanced Data Tracking**
- **Session Statistics**: Track XP/gold gains, playtime, and performance over time
- **Performance History**: FPS and latency monitoring with min/max/average tracking
- **Enhanced Tooltips**: Detailed breakdowns for guild members by zone, addon performance, etc.

### 🔧 **Intelligent Button Collection**
- Automatically collects addon buttons into a clean bar
- Supports LibDBIcon buttons
- Optional Blizzard button inclusion
- Hide bar with minimap hover functionality
- Smart positioning left or right of minimap

### 🎨 **Customization Options**
- Individual font sizes for each data bar (8-20px)
- **Full Opacity Range**: Complete transparency support (0-100%)
- Flexible data text positioning (hide, minimap, first bar, second bar)
- Lock/unlock movable bars
- **Smart Color Coding**: Guild (green), Friends (cyan), performance indicators
- **Faction-Aware Tooltips**: Guild members color-coded by Alliance/Horde

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
- **Memory**: Real-time addon memory/CPU usage with detailed performance breakdown
- **FPS/Performance**: Color-coded performance indicator (Green ≥60, Yellow 30-59, Red <30)
- **Coordinates**: Current player position with zone information
- **Clock**: Local time with server time in tooltip, click to open calendar
- **Durability**: Gear condition with color coding (Green ≥75%, Yellow 25-74%, Red <25%)
- **Gold**: Formatted currency display with session tracking
- **Guild**: Online member count only (green), with enhanced tooltip showing members by zone
- **Friends**: WoW online friends count (cyan), with Battle.net details in tooltip
- **Session**: Playtime, XP/gold gains, and rates per hour
- **Performance**: Current FPS/latency with session statistics and performance tips
- **Mail**: Unread mail indicator (display only, unclickable)
- **Experience**: XP progress with rested bonus tracking
- **Bags**: Bag space usage with per-bag breakdown
- **Talents**: Unspent talent point notifications
- **Reputation**: Watched faction progress
- **Currency**: Various game currencies (Honor, Flightstones, etc.)

## 🏆 **Code Quality**
- Professional, publication-ready codebase
- Optimized performance with smart caching
- Clean, maintainable architecture
- Comprehensive error handling

## 🎯 **Recent Updates**

- **Enhanced data texts**: Guild shows online only, Friends shows WoW only
- **Session tracking**: XP/gold gains, performance history, playtime stats
- **Full opacity range**: Transparency from 0-100% (was 10-100%)
- **Smart tooltips**: Zone grouping for guild, game grouping for friends
- **Performance monitoring**: FPS/latency history with assessments
- **Publication-ready**: Professional code cleanup and optimization
- **Simplified interface**: Clean single-column layout for better usability
- **Perfect minimap alignment**: Data bar scaling matches minimap perfectly

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
