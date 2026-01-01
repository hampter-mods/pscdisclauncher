<img width="512" height="512" alt="drive2" src="https://github.com/user-attachments/assets/fe4bb482-2e03-4151-b699-00210749877c" /> PS Classic Real Discs

## ⚠️ Important Notes / Disclaimers

- This mod **modifies system files and databases** used by Project Eris.
- Use at your own risk — although a full uninstall is provided.
- You must have **Project Eris already installed and working**.
- This does **not** replace Project Eris — it extends it.
- If you are **not using internal USB mods**:
  - You will need a **powered USB hub**
  - It will work via the **front USB ports**
  - The disc drive does **not fully work over OTG**
    (you can still tap power via OTG using a **Y-splitter** if needed)

### Required Settings

Before using this:

1. In Project Eris settings, enable:  
   **“Launch RetroArch games from stock UI”**

2. USB order **matters**:
   - The **Project Eris USB must be connected first**
   - The **external disc drive must be connected after it**

This ensures Eris mounts correctly before the drive.

---

## Requirements

- PlayStation Classic with Project Eris installed
- USB drive labelled **`SONY`**
- External USB CD/DVD drive
- PC or Mac with SSH
- PCSX-ReARMed DiscProject core (included)

---

## Installation

### 1️⃣ Download & extract

1. Download this repository.
2. Extract the folder **to the root of your Project Eris USB** (labelled `SONY`).

Your USB should look like:

```
SONY/
  pscdisclauncher-main/
    install.sh
    uninstall.sh
    payload/
    README.md
```

---

### 2️⃣ Boot & connect

1. Plug the USB into the **second controller port** on the PlayStation Classic.
2. Plug the supplied **micro-USB power cable into your computer**.
3. Power on the PlayStation Classic.

---

### 3️⃣ SSH into the console

From your computer terminal:

```bash
ssh root@169.254.215.100
```

(Default password is usually blank.)

---

### 4️⃣ Run the installer

```bash
cd /media/pscdisclauncher-main
bash install.sh
```

The script will:
- Back up modified system files
- Install required modules and cores
- Add the launcher entry
- Modify Eris databases safely

When finished, you’re ready to go 🎉

---

## Uninstall

To completely remove everything and restore backups:

```bash
cd /media/pscdisclauncher-main
bash uninstall.sh
```

This will:
- Restore original files
- Remove launcher entries
- Remove database entries
- Remove save files, overrides, modules, and folders created by the mod

---

## Roadmap / Future Plans

This project is actively evolving. Planned improvements include:

- **Simple `.mod` installer support**  
  A future version will ship as a native Project Eris `.mod` file so installation can be done entirely through the Eris UI, without SSH or manual scripts.

- **PS3-style disc UI integration**  
  Including:
  - Live-updating 3D game case art
  - Automatic cover detection using the game serial from `SYSTEM.CNF`
  - Real-time disc recognition and metadata updates

- **Per-game memory card and save-state slots**  
  Each disc will get:
  - Its own virtual memory card
  - Its own save-state namespace  
  This prevents saves from different games overwriting each other and makes disc swapping seamless.

- **Integrated disc ripping & library builder**  
  A fully integrated UI option to:
  - Rip inserted discs directly from the PlayStation Classic
  - Convert them into Project Eris USB-format PS1 entries
  - Automatically create cover art, metadata, and launcher entries

All of this is aimed at making physical discs feel like first-class citizens inside the Project Eris ecosystem — just as smooth and polished as digital titles.

---

## References

- **Project Eris GitHub:** https://github.com/ProjectEris/ProjectEris
- **PCSX-ReARMed DiscProject core:** https://github.com/libretro/pcsx_rearmed
- **GNU General Public License:** https://www.gnu.org/licenses/gpl-3.0.html

---

## License

This project is released under the **GNU General Public License (GPL)**.  
You are free to use, modify, and redistribute it under the terms of the license.

---

## Final Notes

- If something goes wrong, you can always rerun `uninstall.sh` to restore the system.
- Backups of modified files are stored automatically during install.
- Make sure no disc is inserted during installation.

---

Enjoy 🚀
