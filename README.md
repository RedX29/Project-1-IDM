```markdown
<p align="center">
  <img src="https://img.shields.io/badge/version-1.0-blue" alt="Version">
  <img src="https://img.shields.io/badge/IDM-6.43.10.2-green" alt="IDM Compatible">
  <img src="https://img.shields.io/badge/license-MIT-orange" alt="License">
</p>

> **A lightweight, self-updating tool to activate Internet Download Manager (IDM), freeze the trial, or reset activation.**  
> **Safe, fast, and fully open-source.**

---

## 📋 Table of Contents

- [Features](#-features)
- [Repository Structure](#-repository-structure)
- [Download & Installation](#-download--installation)
- [How to Use](#-how-to-use)
- [How It Works](#-how-it-works)
- [Auto-Update System](#-auto-update-system)
- [Safety & Security](#-safety--security)
- [Troubleshooting](#-troubleshooting)
- [Tested Versions](#-tested-versions)
- [Contributing](#-contributing)
- [License](#-license)
- [Disclaimer](#-disclaimer)
- [Contact](#-contact)
- [Star the Repository!](#-star-the-repository)

---

## 📋 Features

| Feature | Description |
|---------|-------------|
| ✅ **Activate IDM** | Generates a **fake registration** and **locks the registry** to keep IDM activated. |
| ⏸️ **Freeze Trial** | **Prevents the 30-day trial from expiring** (no fake serial, just trial freeze). |
| 🔄 **Reset Trial** | **Unlocks and removes all registry keys** – IDM reverts to fresh trial mode. |
| 🔍 **Update Checker** | Compares your IDM version with the **latest tested version** and **auto-updates the script**. |
| 🛡️ **Safety First** | **Always asks for `YES` confirmation** before making any registry changes. |
| 💾 **Auto Backup** | **Automatically backs up your registry** before any modification. |
| 🌐 **Offline Friendly** | The **core activator works offline** – only the update checker needs internet. |

---

## 📁 Repository Structure

```
Project-1-IDM/
├── IDM-Activator.bat         # Main batch file (activator)
├── Update-Check.ps1          # PowerShell update checker
├── version.txt               # Latest tested IDM version
├── script_version.txt        # Latest script version (for auto-update)
└── README.md                 # This file
```

---

## 🚀 Download & Installation

### Option 1 – Download from GitHub (Recommended)

1. Go to the [**Releases**](https://github.com/RedX29/Project-1-IDM/releases) page.
2. Download the latest `IDM-Activator.zip`.
3. Extract the files to a folder (e.g., `C:\IDM-Activator` or your Desktop).
4. **Right-click `IDM-Activator.bat`** → **Run as administrator**.

### Option 2 – Clone the Repository

```bash
git clone https://github.com/RedX29/Project-1-IDM.git
cd Project-1-IDM
```

Then run `IDM-Activator.bat` as administrator.

---

## 🖥️ How to Use

### Main Menu

```
==================================================
        IDM Activator v1.0
==================================================
   Installed IDM : 6.43.10.2
   Status        : Working
==================================================
   [1] Activate IDM
   [2] Freeze Trial (30-day freeze)
   [3] Reset Activation / Trial
   [4] Download IDM (Official)
   [5] Check for Updates
   [0] Exit
==================================================
Enter option:
```

| Option | Action |
|--------|--------|
| **`1`** | **Activate IDM** – Generates a fake serial and locks the registry. |
| **`2`** | **Freeze Trial** – Stops the 30-day trial from counting down (no fake serial). |
| **`3`** | **Reset Trial** – Removes all registry keys – IDM becomes unactivated again. |
| **`4`** | Opens the official IDM download page in your browser. |
| **`5`** | Runs the **update checker** (see below). |
| **`0`** | Exits the program. |

---

### Update Checker (Option `5`)

The update checker does three things:

1. **Compares your IDM version** against the latest tested version (stored in `version.txt` on GitHub).
2. **Checks for a newer script version** (compares your `SCRIPT_VERSION` with `script_version.txt`).
3. **Offers to download and update** the batch file if a newer version exists.

If `Update-Check.ps1` is missing, the batch will **offer to download it automatically** from GitHub.

---

## 🔧 How It Works

### Activation Logic

1. **Registry Backup** – Exports `HKCU\Software\Classes\CLSID` to `%TEMP%`.
2. **Cleanup** – Removes old registration data.
3. **Add Flag** – Creates `AdvIntDriverEnabled2 = 1` in `HKLM\SOFTWARE\Internet Download Manager`.
4. **Fake Serial** – Generates random **FName**, **LName**, **Email**, and a 25-character serial.
5. **Trigger IDM** – Downloads small images from IDM's website to create the CLSID keys.
6. **Lock Keys** – Uses `icacls` to **deny Everyone** access to those keys.

### Freeze Logic

Same as activation, but **without** the fake serial – this keeps the trial active but never expires.

### Reset Logic

1. **Backup** – Exports CLSID keys.
2. **Unlock Keys** – Uses `takeown` + `icacls /grant` to regain ownership.
3. **Delete Keys** – Removes all CLSID keys and clears the registration entries.

---

## 🔄 Auto-Update System

The tool is **self-updating** – when you run `[5] Check for Updates`:

1. It downloads `version.txt` and `script_version.txt` from GitHub.
2. If `script_version.txt` is newer than your local `SCRIPT_VERSION`, it asks if you want to download the new batch file.
3. If you say **Yes**, it downloads the new `.bat`, overwrites itself, and restarts.

> **You're always in control** – no silent updates.

---

## 🛡️ Safety & Security

- ✅ **Always asks for confirmation** – you must type `YES` before any registry changes.
- ✅ **Auto-backup** – your registry keys are backed up before any modification.
- ✅ **No data collection** – the script does not send any personal data anywhere.
- ✅ **Open source** – you can review the entire code before running it.

---

## ❓ Troubleshooting

### "Update-Check.ps1 is missing"

- The batch will **offer to download it automatically** from GitHub.
- If the download fails, you can manually download it from:
  `https://raw.githubusercontent.com/RedX29/Project-1-IDM/main/Update-Check.ps1`
  Place it in the **same folder** as `IDM-Activator.bat`.

### "IDM is not installed"

- Download IDM from the official website: [https://www.internetdownloadmanager.com/download.html](https://www.internetdownloadmanager.com/download.html)
- Install it, then run the activator again.

### "Access denied" errors

- Make sure you're running the script as **Administrator**.
- Right-click `IDM-Activator.bat` → **Run as administrator**.

### "Windows protected your PC" (SmartScreen warning)

- Click **More info** → **Run anyway**.
- This happens because the script is not digitally signed – it's safe to run.

### The batch file closes immediately

- The script auto-elevates to admin, but if it flashes and closes:
  1. Open **Command Prompt as Administrator**.
  2. Navigate to the folder with the batch file:
     ```cmd
     cd C:\path\to\folder
     ```
  3. Run it manually:
     ```cmd
     IDM-Activator.bat
     ```
  This will keep the window open so you can see any error messages.

---

## 🧪 Tested Versions

| IDM Version | Status |
|-------------|--------|
| `6.42.33`   | ✅ Working |
| `6.43.10.2` | ✅ Working |

---

## 🤝 Contributing

1. **Fork** the repository.
2. Create a **feature branch** (`git checkout -b feature/amazing-feature`).
3. **Commit** your changes (`git commit -m 'Add amazing feature'`).
4. **Push** to the branch (`git push origin feature/amazing-feature`).
5. Open a **Pull Request**.

---

## 📜 License

This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.

---

## ⚠️ Disclaimer

This tool is provided **for educational purposes only**.  
The authors are not responsible for any misuse, damages, or issues that arise from using this software.  
You are responsible for complying with IDM's terms of service.

---

## 📬 Contact

- **Discord**: `onlyvyrex`
- **Issues**: [https://github.com/RedX29/Project-1-IDM/issues](https://github.com/RedX29/Project-1-IDM/issues)
- **Discussions**: [https://github.com/RedX29/Project-1-IDM/discussions](https://github.com/RedX29/Project-1-IDM/discussions)

---

## ⭐ Star the Repository!

If you find this tool useful, please consider starring the repository on GitHub – it helps others discover it too!

[![Star on GitHub](https://img.shields.io/github/stars/RedX29/Project-1-IDM?style=social)](https://github.com/RedX29/Project-1-IDM/stargazers)

---

**Enjoy your fully activated IDM!** 🚀
```
