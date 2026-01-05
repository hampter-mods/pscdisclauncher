<table>
  <tr>
    <td width="280" valign="middle">
      <img
        width="256"
        height="256"
        alt="SLUS-99998"
        src="https://github.com/user-attachments/assets/99286216-0a3c-4864-8e3b-36dec3bfc058"
      />
    </td>
    <td valign="middle">
      <h1>PlayStation Classic — Real Discs</h1>
      <p><i>Use your original PlayStation discs on the PSC, integrated into Project Eris.</i></p>
    </td>
  </tr>
</table>

---

## Download

Ready-to-use **Project Eris `.mod` files** (recommended):

- https://github.com/hampter-mods/pscdisclauncher/releases/tag/mod-files

Files:
- `pscdisclauncher-install.mod`
- `pscdisclauncher-uninstall.mod`

---

## ⚠️ Important Notes / Disclaimers

- This mod **modifies system files and databases** used by Project Eris.
- Use at your own risk — although a full uninstall is provided.
- You must have **Project Eris already installed and working**.
- This does **not** replace Project Eris — it extends it.
- Memory cards are shared.
- Save states work, but are manual (**save to slot `-1`** in RetroArch).

If you are **not using internal USB mods**:
- You will need a **powered USB hub**
- It will work via the **front USB ports**
- The disc drive does **not fully work over OTG**  
  (you can still tap power via OTG using a **Y-splitter** if needed)

---

## Required Settings

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
- PCSX-ReARMed DiscProject core (included)

> Note: **SSH is no longer required** for install/uninstall when using the `.mod` files.

---

## Installation (recommended)

1. Copy:

```
pscdisclauncher-install.mod
```

into:

```
SONY/project_eris/mods/
```

on your Project Eris USB.

2. Boot the PSC with your Project Eris USB connected.  
Project Eris will automatically install the mod on boot.

---

## Uninstall (clean removal)

Before uninstalling, you should back up the `.pcsx` folder associated with the Disc Launcher entry if you want to keep saves/states.

1. In the **Project Eris desktop app**, delete the Disc Launcher entry and **regenerate the USB games database**.
2. Immediately after that, copy:

```
pscdisclauncher-uninstall.mod
```

into:

```
SONY/project_eris/mods/
```

3. Boot the PSC — everything will be reverted automatically, and added files removed.

---

## Repository Structure

This repo includes **package source folders** you can edit and rebuild into `.mod` files:

```
pscdisclauncher-install-pkg/
  DEBIAN/
  media/

pscdisclauncher-uninstall-pkg/
  DEBIAN/
  media/
```

- `DEBIAN/control` = package metadata
- `DEBIAN/postinst` = install/uninstall actions (runs on PSC during install)
- `media/...` = files that are extracted onto the PSC (written to `/media/...`)

---

## Build `.mod` files yourself

You can modify the `*-pkg` folders and rebuild the `.mod` files locally.

### What you’ll need

The build process creates:
- `data.tar.xz` (LZMA2 + CRC64)
- `control.tar.gz`
- `debian-binary`
…then wraps them into a `.mod` file using `ar`.

---

### Windows (WSL / Ubuntu)

#### Install prerequisites

1. Enable WSL + install Ubuntu (Windows 10/11):
   - In an Administrator PowerShell:
     - `wsl --install -d Ubuntu`
2. In Ubuntu (WSL), install tools:
   ```bash
   sudo apt update
   sudo apt install -y xz-utils binutils tar
   ```

#### Put the pkg folders somewhere on Windows

For example:

```
C:\Users\<your user>\Documents\pscdisclauncher\pscdisclauncher-install
C:\Users\<your user>\Documents\pscdisclauncher\pscdisclauncher-uninstall

```
- Edit the `/mnt/...` paths in the command blocks below to match your location.

#### Build: Install mod (single paste)

Paste into WSL:

```bash
# 0) clean previous build artifacts for THIS mod
rm -f ~/data.tar ~/data.tar.xz ~/control.tar.gz ~/debian-binary ~/pscdisclauncher-install.mod
rm -rf ~/pscdisclauncher-install

# 1) stage package in Linux FS (permissions behave)
cp -r /mnt/<path to downloaded source>/pscdisclauncher/pscdisclauncher-install-pkg ~/pscdisclauncher-install
cd ~/pscdisclauncher-install

# 2) permissions (DEBIAN + scripts)
chmod 755 DEBIAN
chmod 644 DEBIAN/control
[ -f DEBIAN/postinst ] && chmod 755 DEBIAN/postinst || true
[ -f DEBIAN/prerm ] && chmod 755 DEBIAN/prerm || true
[ -f DEBIAN/postrm ] && chmod 755 DEBIAN/postrm || true

# 3) build data.tar.xz (LZMA2 + CRC64), exclude DEBIAN
tar --numeric-owner --owner=0 --group=0 --exclude=./DEBIAN -cf ~/data.tar .
xz -f -z -9e --check=crc64 ~/data.tar

# 4) build control.tar.gz
tar --numeric-owner --owner=0 --group=0 -C "$PWD/DEBIAN" -czf ~/control.tar.gz .

# 5) debian-binary
printf "2.0\n" > ~/debian-binary

# 6) wrap into .mod (OUTPUT MUST BE A FILE)
ar rc ~/pscdisclauncher-install.mod ~/debian-binary ~/control.tar.gz ~/data.tar.xz

# 7) copy back to Windows (copy the FILE)
mkdir -p /mnt/c/mod
cp ~/pscdisclauncher-install.mod /mnt/c/mod/pscdisclauncher-install.mod
```

Output:
- `C:\mod\pscdisclauncher-install.mod`

#### Build: Uninstall mod (single paste)

Paste into WSL:

```bash
# 0) clean previous build artifacts for THIS mod
rm -f ~/data.tar ~/data.tar.xz ~/control.tar.gz ~/debian-binary ~/pscdisclauncher-uninstall.mod

# 1) stage package in Linux FS (clean staging dir first)
rm -rf ~/pscdisclauncher-uninstall
cp -r /mnt/<path to downloaded source>/pscdisclauncher/pscdisclauncher-uninstall-pkg ~/pscdisclauncher-uninstall
cd ~/pscdisclauncher-uninstall

# 2) permissions
chmod 755 DEBIAN
chmod 644 DEBIAN/control
chmod 755 DEBIAN/postinst

# 3) build data.tar.xz (LZMA2 + CRC64)
tar --numeric-owner --owner=0 --group=0 --exclude=./DEBIAN -cf ~/data.tar .
xz -f -z -9e --check=crc64 ~/data.tar

# 4) build control.tar.gz
tar --numeric-owner --owner=0 --group=0 -C "$PWD/DEBIAN" -czf ~/control.tar.gz .

# 5) debian-binary
printf "2.0\n" > ~/debian-binary

# 6) wrap into .mod (OUTPUT MUST BE A FILE)
ar rc ~/pscdisclauncher-uninstall.mod ~/debian-binary ~/control.tar.gz ~/data.tar.xz

# 7) copy back to Windows (copy the FILE)
mkdir -p /mnt/c/mod
cp ~/pscdisclauncher-uninstall.mod /mnt/c/mod/pscdisclauncher-uninstall.mod
```

Output:
- `C:\mod\pscdisclauncher-uninstall.mod`

---

### Linux (native)

#### Install prerequisites (Debian/Ubuntu)

```bash
sudo apt update
sudo apt install -y xz-utils binutils tar
```

#### Build (install / uninstall)

1. Clone the repo and go to it:
   ```bash
   git clone https://github.com/hampter-mods/pscdisclauncher.git
   cd pscdisclauncher
   ```

2. Build install mod:
   ```bash
   rm -f ~/data.tar ~/data.tar.xz ~/control.tar.gz ~/debian-binary ~/pscdisclauncher-install.mod
   rm -rf ~/pscdisclauncher-install
   cp -r ./pscdisclauncher-install-pkg ~/pscdisclauncher-install
   cd ~/pscdisclauncher-install

   chmod 755 DEBIAN
   chmod 644 DEBIAN/control
   [ -f DEBIAN/postinst ] && chmod 755 DEBIAN/postinst || true

   tar --numeric-owner --owner=0 --group=0 --exclude=./DEBIAN -cf ~/data.tar .
   xz -f -z -9e --check=crc64 ~/data.tar
   tar --numeric-owner --owner=0 --group=0 -C "$PWD/DEBIAN" -czf ~/control.tar.gz .
   printf "2.0\n" > ~/debian-binary
   ar rc ~/pscdisclauncher-install.mod ~/debian-binary ~/control.tar.gz ~/data.tar.xz
   ```

3. Build uninstall mod:
   ```bash
   rm -f ~/data.tar ~/data.tar.xz ~/control.tar.gz ~/debian-binary ~/pscdisclauncher-uninstall.mod
   rm -rf ~/pscdisclauncher-uninstall
   cp -r ./pscdisclauncher-uninstall-pkg ~/pscdisclauncher-uninstall
   cd ~/pscdisclauncher-uninstall

   chmod 755 DEBIAN
   chmod 644 DEBIAN/control
   chmod 755 DEBIAN/postinst

   tar --numeric-owner --owner=0 --group=0 --exclude=./DEBIAN -cf ~/data.tar .
   xz -f -z -9e --check=crc64 ~/data.tar
   tar --numeric-owner --owner=0 --group=0 -C "$PWD/DEBIAN" -czf ~/control.tar.gz .
   printf "2.0\n" > ~/debian-binary
   ar rc ~/pscdisclauncher-uninstall.mod ~/debian-binary ~/control.tar.gz ~/data.tar.xz
   ```

Outputs:
- `~/pscdisclauncher-install.mod`
- `~/pscdisclauncher-uninstall.mod`

---

### macOS (native)

macOS ships with `tar` and `ar`, but for best compatibility install GNU tools.

#### Install prerequisites (Homebrew)

```bash
brew install xz binutils gnu-tar
```

Use GNU tar as `gtar` (recommended). If `ar` has issues, use `gar` from `binutils`.

#### Build (install / uninstall)

```bash
git clone https://github.com/hampter-mods/pscdisclauncher.git
cd pscdisclauncher
```

Install mod:

```bash
rm -f ~/data.tar ~/data.tar.xz ~/control.tar.gz ~/debian-binary ~/pscdisclauncher-install.mod
rm -rf ~/pscdisclauncher-install
cp -r ./pscdisclauncher-install-pkg ~/pscdisclauncher-install
cd ~/pscdisclauncher-install

chmod 755 DEBIAN
chmod 644 DEBIAN/control
[ -f DEBIAN/postinst ] && chmod 755 DEBIAN/postinst || true

gtar --numeric-owner --owner=0 --group=0 --exclude=./DEBIAN -cf ~/data.tar .
xz -f -z -9e --check=crc64 ~/data.tar
gtar --numeric-owner --owner=0 --group=0 -C "$PWD/DEBIAN" -czf ~/control.tar.gz .
printf "2.0\n" > ~/debian-binary
ar rc ~/pscdisclauncher-install.mod ~/debian-binary ~/control.tar.gz ~/data.tar.xz
```

Uninstall mod:

```bash
rm -f ~/data.tar ~/data.tar.xz ~/control.tar.gz ~/debian-binary ~/pscdisclauncher-uninstall.mod
rm -rf ~/pscdisclauncher-uninstall
cp -r ./pscdisclauncher-uninstall-pkg ~/pscdisclauncher-uninstall
cd ~/pscdisclauncher-uninstall

chmod 755 DEBIAN
chmod 644 DEBIAN/control
chmod 755 DEBIAN/postinst

gtar --numeric-owner --owner=0 --group=0 --exclude=./DEBIAN -cf ~/data.tar .
xz -f -z -9e --check=crc64 ~/data.tar
gtar --numeric-owner --owner=0 --group=0 -C "$PWD/DEBIAN" -czf ~/control.tar.gz .
printf "2.0\n" > ~/debian-binary
ar rc ~/pscdisclauncher-uninstall.mod ~/debian-binary ~/control.tar.gz ~/data.tar.xz
```

---

## Roadmap / Future Plans

This project is actively evolving. Planned improvements include:

- **PS3-style disc UI integration**
  - Live-updating 3D game case art
  - Automatic cover detection using the disc serial from `SYSTEM.CNF`
  - Real-time disc recognition and metadata updates

- **Per-game memory card and save-state slots**
  - Per-game virtual memory cards
  - Per-game save-state namespaces

- **Integrated disc ripping & library builder**
  - Rip inserted discs directly on the PSC
  - Convert to Project Eris USB-format entries
  - Auto-generate cover art, metadata, launcher entries

---

## References

- **Project Eris GitHub:** https://github.com/ProjectEris/ProjectEris
- **PCSX-ReARMed DiscProject core:** https://github.com/libretro/pcsx_rearmed
- **GNU General Public License:** https://www.gnu.org/licenses/gpl-3.0.html

---

## Legal / Ethical Notice

- This project does **not condone piracy**. It is intended only for use with **legally owned physical discs or personal backup copies**.
- I do **not provide PlayStation BIOS files**, game images, or copyrighted content of any kind.
- Users are responsible for complying with their local laws regarding game backups and emulation.
- All trademarks, game content, and BIOS remain the property of their respective owners — including Sony Interactive Entertainment.

---

## License

This project is released under the **GNU General Public License (GPL)**.  
You are free to use, modify, and redistribute it under the terms of the license.

---

## Final Notes

- Make sure no disc is inserted during installation.
- If something goes wrong, install the uninstall `.mod` to restore everything.
