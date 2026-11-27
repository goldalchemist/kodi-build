#!/usr/bin/env bash
# kodimenu.sh - menu for kodibuild (G0XRE). Lives in the kodibuild folder, so it
# works from ~/kodibuild or from the USB stick.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KB="python3 $HERE/kodibuild.py"
cd "$HERE" || exit 1

C='\033[36m'; G='\033[32m'; Y='\033[33m'; R='\033[31m'; N='\033[0m'
pause() { echo; read -rsn1 -p "  press any key..."; echo; }
ask()   { read -rp "  $1 " REPLY; }

publish() {
    echo -e "${C}  building repo...${N}"
    $KB repo build && $KB repo publish
}

add_addon() {
    ask "search for (e.g. fen, seren, youtube):"; [ -z "$REPLY" ] && return
    $KB repo search "$REPLY"
    ask "add-on id to add (blank = cancel):"; local id="$REPLY"; [ -z "$id" ] && return
    if grep -qx "$id" addons.conf; then echo -e "${Y}  already in the build${N}"; return; fi
    echo "$id" >> addons.conf
    echo -e "${G}  added $id${N}"
    publish && echo -e "${G}  done - devices install it on their next update check${N}"
}

remove_addon() {
    echo; grep -vE '^\s*(#|$)' addons.conf | nl -w3 -s'  '
    ask "number to remove (blank = cancel):"; [ -z "$REPLY" ] && return
    local id; id=$(grep -vE '^\s*(#|$)' addons.conf | sed -n "${REPLY}p" | awk '{print $1}')
    [ -z "$id" ] && { echo -e "${R}  no such number${N}"; return; }
    ask "remove $id from the build? [y/N]"; [ "$REPLY" != "y" ] && return
    sed -i "/^${id//./\\.}\b/d" addons.conf
    echo -e "${G}  removed $id (devices keep it installed until you uninstall it there)${N}"
    publish
}

android() {
    command -v adb >/dev/null || { echo -e "${R}  adb missing:  sudo apt install adb${N}"; return; }
    ask "device IP for wireless adb (blank = USB cable):"
    if [ -n "$REPLY" ]; then adb connect "$REPLY:5555"; $KB android --serial "$REPLY:5555"
    else $KB android; fi
}

restore() {
    ls -1t backups/*.tar.gz 2>/dev/null | head -10 | nl -w3 -s'  '
    ask "number to restore (blank = newest):"
    local f; f=$(ls -1t backups/*.tar.gz 2>/dev/null | sed -n "${REPLY:-1}p")
    [ -z "$f" ] && { echo -e "${R}  no backups${N}"; return; }
    $KB restore "$f"
}

usb_bundle() {
    ask "copy bundle to which folder? [default: ~/kodi-usb]"
    local dst="${REPLY:-$HOME/kodi-usb}"; dst="${dst/#\~/$HOME}"
    mkdir -p "$dst"
    echo -e "${C}  copying kodibuild (tool, configs, repo site, backups)...${N}"
    rsync -a --delete --exclude cache/ --exclude __pycache__/ "$HERE/" "$dst/kodibuild/"
    [ -d "$HOME/wallpaper" ] && rsync -a --delete "$HOME/wallpaper/" "$dst/wallpaper/" && echo "  + wallpaper"
    cat > "$dst/README-USB.txt" <<EOF
Andy's Kodi kit - $(date '+%Y-%m-%d %H:%M')
Linux / Mac:  cd kodibuild && bash kodimenu.sh
Windows:      install Python 3, then:  python kodibuild\\kodibuild.py install
CONTAINS: Kodi remote password (kodibuild.conf) and Trakt/Real-Debrid tokens
(backups/). Keep this stick safe - or put it in an encrypted volume.
EOF
    du -sh "$dst" | awk '{print "  bundle size: "$1}'
    echo -e "${G}  done -> $dst   (copy that folder onto the stick)${N}"
}

while true; do
    clear
    echo -e "${C}  ╔══════════════════════════════════════╗"
    echo -e "  ║        KODI BUILD  ·  G0XRE          ║"
    echo -e "  ╠══════════════════════════════════════╣${N}"
    echo -e "  ║  ${G}1${N}  Install Kodi + build (this PC)  ${C}║${N}"
    echo -e "  ║  ${G}2${N}  Install on Android / Fire TV    ${C}║${N}"
    echo -e "  ║  ${G}3${N}  Add new add-on                  ${C}║${N}"
    echo -e "  ║  ${G}4${N}  Remove add-on                   ${C}║${N}"
    echo -e "  ║  ${G}5${N}  Update GitHub (build+publish)   ${C}║${N}"
    echo -e "  ║  ${G}6${N}  Status of this PC's Kodi        ${C}║${N}"
    echo -e "  ║  ${G}7${N}  Force update check now          ${C}║${N}"
    echo -e "  ║  ${G}8${N}  Backup (close Kodi first)       ${C}║${N}"
    echo -e "  ║  ${G}9${N}  Restore a backup                ${C}║${N}"
    echo -e "  ║  ${G}u${N}  Make USB bundle                 ${C}║${N}"
    echo -e "  ║  ${G}q${N}  Quit                            ${C}║${N}"
    echo -e "${C}  ╚══════════════════════════════════════╝${N}"
    read -rsn1 k; echo
    case "$k" in
        1) $KB install ;;
        2) android ;;
        3) add_addon ;;
        4) remove_addon ;;
        5) publish ;;
        6) $KB status ;;
        7) $KB update ;;
        8) $KB backup ;;
        9) restore ;;
        u|U) usb_bundle ;;
        q|Q) clear; exit 0 ;;
        *) continue ;;
    esac
    pause
done
