#!/bin/bash
# ============================================================
# FFit Thermal Printer Driver — Ubuntu Installer
# ============================================================
# Usage:
#   chmod +x install.sh
#   sudo ./install.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="FFit Printer"
APP_BIN="ffit-printer"
BACKEND_NAME="ffit"
CUPS_BACKEND_DIR="/usr/lib/cups/backend"
INSTALL_DIR="/usr/local/bin"
DESKTOP_DIR="/usr/share/applications"
CONFIG_DIR="/etc/ffit"

# Standalone bundle detection
if [ -d "$SCRIPT_DIR/bundle" ]; then
    APP_BUNDLE="$SCRIPT_DIR/bundle"
    BACKEND_SRC="$SCRIPT_DIR/ffit"
    PPD_SRC="$SCRIPT_DIR/pos58.ppd"
    ICON_SRC="$SCRIPT_DIR/icon.png"
else
    APP_BUNDLE="$SCRIPT_DIR/../ffit_printer_ubuntu/build/linux/x64/release/bundle"
    BACKEND_SRC="$SCRIPT_DIR/../cups_backend/ffit"
    PPD_SRC="$SCRIPT_DIR/pos58.ppd"
    ICON_SRC="$SCRIPT_DIR/icon.png"
fi

echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║     FFit Thermal Printer Driver — Installer      ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Root check ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Please run with sudo: sudo ./install.sh${NC}"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
echo -e "${GREEN}Installing for user: ${BOLD}$REAL_USER${NC}"
echo ""

# ── Step 1: Check dependencies ───────────────────────────────────────────────
echo -e "${YELLOW}[1/6] Checking dependencies...${NC}"

MISSING_DEPS=()
for dep in cups python3 pip3; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if ! python3 -c "import PIL" &>/dev/null; then
    MISSING_DEPS+=("python3-pil")
fi

if ! command -v pdftoppm &>/dev/null; then
    MISSING_DEPS+=("poppler-utils")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "  Installing missing packages: ${MISSING_DEPS[*]}"
    apt-get update -qq
    apt-get install -y -qq cups python3 python3-pip poppler-utils python3-pil \
        bluez rfcomm 2>/dev/null || true
    pip3 install -q Pillow 2>/dev/null || true
fi

echo -e "  ${GREEN}✓ Dependencies OK${NC}"

# ── Step 2: Install CUPS backend ─────────────────────────────────────────────
echo -e "${YELLOW}[2/6] Installing CUPS backend...${NC}"

cp "$BACKEND_SRC" "$CUPS_BACKEND_DIR/$BACKEND_NAME"
chmod 755 "$CUPS_BACKEND_DIR/$BACKEND_NAME"
chown root:root "$CUPS_BACKEND_DIR/$BACKEND_NAME"

# Copy 58mm PPD file for paper size formatting
mkdir -p /usr/share/ppd/custom
cp "$PPD_SRC" "/usr/share/ppd/custom/pos58.ppd"
chmod 644 "/usr/share/ppd/custom/pos58.ppd"

# Create system configuration folder for system-wide/CUPS access
mkdir -p "$CONFIG_DIR"
chmod 777 "$CONFIG_DIR"

echo -e "  ${GREEN}✓ CUPS backend and PPD installed${NC}"

# ── Step 3: Install Flutter app ───────────────────────────────────────────────
echo -e "${YELLOW}[3/6] Installing Flutter desktop app...${NC}"

if [ -d "$APP_BUNDLE" ]; then
    # Release build available
    mkdir -p "/opt/ffit-printer"
    cp -r "$APP_BUNDLE/." "/opt/ffit-printer/"
    cp "$ICON_SRC" "/opt/ffit-printer/icon.png"
    chmod 644 "/opt/ffit-printer/icon.png"
    ln -sf "/opt/ffit-printer/ffit_printer_ubuntu" "$INSTALL_DIR/$APP_BIN"
    echo -e "  ${GREEN}✓ Flutter app installed: /opt/ffit-printer${NC}"
else
    echo -e "  ${YELLOW}⚠ Release build not found. Run 'flutter build linux --release' first.${NC}"
    echo -e "  ${YELLOW}  App can still be launched with: flutter run -d linux${NC}"
fi

# ── Step 4: Desktop shortcut ──────────────────────────────────────────────────
echo -e "${YELLOW}[4/6] Creating desktop shortcut...${NC}"

cat > "$DESKTOP_DIR/ffit-printer.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=FFit Printer
GenericName=Thermal Printer Manager
Comment=Configure and manage FFit thermal printers (USB, Network, Bluetooth)
Exec=$INSTALL_DIR/$APP_BIN
Icon=/opt/ffit-printer/icon.png
Terminal=false
Categories=Office;Utility;
Keywords=printer;thermal;receipt;POS;bluetooth;network;USB;
StartupNotify=true
EOF

chmod 644 "$DESKTOP_DIR/ffit-printer.desktop"
echo -e "  ${GREEN}✓ Desktop shortcut created${NC}"

# ── Step 5: User permissions ──────────────────────────────────────────────────
echo -e "${YELLOW}[5/6] Setting up user permissions...${NC}"

# Add user to lp group (USB printer access)
if ! groups "$REAL_USER" | grep -q "\blp\b"; then
    usermod -aG lp "$REAL_USER"
    echo -e "  ${GREEN}✓ Added $REAL_USER to 'lp' group (USB printer access)${NC}"
else
    echo -e "  ${GREEN}✓ $REAL_USER already in 'lp' group${NC}"
fi

# Add user to bluetooth group
if ! groups "$REAL_USER" | grep -q "\bbluetooth\b"; then
    usermod -aG bluetooth "$REAL_USER" 2>/dev/null || true
    echo -e "  ${GREEN}✓ Added $REAL_USER to 'bluetooth' group${NC}"
fi

# Enable bluetooth service
systemctl enable bluetooth 2>/dev/null || true
systemctl start bluetooth 2>/dev/null || true

# ── Step 6: Register CUPS printer ────────────────────────────────────────────
echo -e "${YELLOW}[6/6] Registering with CUPS print system...${NC}"

# Restart CUPS to pick up new backend
systemctl restart cups 2>/dev/null || service cups restart 2>/dev/null || true

# Check if CUPS picked up our backend
if [ -x "$CUPS_BACKEND_DIR/$BACKEND_NAME" ]; then
    echo -e "  ${GREEN}✓ CUPS backend registered${NC}"
    echo -e "  ${BLUE}  Chrome mein print karo → 'FFit Thermal' dikhega${NC}"
else
    echo -e "  ${YELLOW}⚠ CUPS backend may need manual registration${NC}"
fi

# ── Done! ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║           ✅ Installation Complete!              ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo -e "  ${BLUE}1.${NC} ${YELLOW}Logout aur wapas login karo${NC} (groups update ke liye)"
echo -e "  ${BLUE}2.${NC} Applications menu mein ${BOLD}'FFit Printer'${NC} kholo"
echo -e "  ${BLUE}3.${NC} Apna printer select karo (USB / Network / Bluetooth)"
echo -e "  ${BLUE}4.${NC} ${BOLD}'Register with CUPS'${NC} button click karo"
echo -e "  ${BLUE}5.${NC} Chrome → Print → ${BOLD}'FFit Thermal'${NC} select karo → Done! ✅"
echo ""
echo -e "${YELLOW}⚠  Important: Logout aur login karna ZAROORI hai (lp group apply ke liye)${NC}"
echo ""
