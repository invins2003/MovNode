# MovNode 🎬

A lightweight, powerful, and fast CLI scraper for movies and TV series. Search TMDB and stream instantly in your browser or VLC. Optimized for both **PC (Windows/Linux/Mac)** and **Mobile (Android/Termux)**.

![MovNode Screenshot](https://raw.githubusercontent.com/invins2003/MovNode/main/logo_preview.png)

## 🚀 Features

- **Global Search**: Search through millions of movies and TV shows using the official TMDB JSON API.
- **Season & Episode Support**: Browse seasons and select specific episodes for TV series.
- **Multiple Sources**: Choose from various high-quality streaming providers (VidSrc, VsEmbed, MultiEmbed).
- **Mobile Optimized**: Native support for **Termux** on Android with forced **Brave Browser** integration for an ad-free experience.
- **VLC Integration**: Extract direct stream links and play them in VLC (PC only).
- **Beautiful UI**: Colorful CLI interface with interactive menus and progress indicators.

---

## 📦 Installation

### On PC (Windows / Mac / Linux)
1. **Clone the repo**:
   ```bash
   git clone https://github.com/invins2003/MovNode.git
   cd MovNode
   ```
2. **Install dependencies**:
   ```bash
   npm install
   ```
3. **Run**:
   ```bash
   node index.js
   ```

### On Mobile (Android via Termux)
1. **Install Termux** and the **Termux:API** app.
2. **Setup environment**:
   ```bash
   pkg install nodejs termux-api git
   ```
3. **Clone and install**:
   ```bash
   git clone https://github.com/invins2003/MovNode.git
   cd MovNode
   npm install
   ```
4. **Make it a command**:
   ```bash
   npm install -g .
   ```
5. **Run**:
   ```bash
   movnode
   ```

---

## 🛠 Usage

Simply run the command and follow the interactive prompts:
```bash
# Start interactive search
movnode

# Search directly
movnode "Inception"
```

### Pro Tip for Mobile Users
To get the best experience without ads, **install Brave Browser** on your Android device. MovNode is configured to automatically force links into Brave, which handles video player pop-ups perfectly.

---

## 📜 License
This project is for educational purposes only. All content is fetched from public APIs and embeds.
