#!/bin/zsh
# ════════════════════════════════════════════════════════════════════
#  Installa NettoLR sul tuo iPhone, dal Mac.
#  Nel Terminale incolla questa riga e premi Invio:
#
#    curl -fsSL https://raw.githubusercontent.com/LR-apps609/NettoLR/main/installa.sh | zsh
#
#  Scarica (o aggiorna) NettoLR nella cartella «NettoLR» della tua Inizio,
#  prepara il progetto e apre Xcode. Si può rilanciare quando vuoi: aggiorna e basta.
# ════════════════════════════════════════════════════════════════════
# Tutto dentro una funzione: con «curl … | zsh» lo script viene letto per intero prima di partire
principale() {
REPO="https://github.com/LR-apps609/NettoLR.git"
clear
print ""
print "  NettoLR — preparo tutto per il tuo iPhone"
print "  ═════════════════════════════════════════"
print ""

fail() { print ""; print "  ❌ $1"; print ""; print "  Mandami uno screenshot di questa finestra."; exit 1 }

# 1. Xcode
print "  1/4  Controllo Xcode…"
XCODE=$(ls -d /Applications/Xcode*.app 2>/dev/null | sort -V | tail -n 1)
[[ -n "$XCODE" ]] || fail "Non trovo Xcode in Applicazioni. Installalo dal Mac App Store (è gratis), aprilo una volta e rilancia."
if [[ $(xcode-select -p 2>/dev/null) != $XCODE/* ]]; then
  print "       Imposto Xcode come strumento predefinito (ti chiede la password del Mac: mentre scrivi non si vede nulla, è normale)…"
  sudo xcode-select -s "$XCODE/Contents/Developer" || fail "Non riesco a impostare Xcode."
fi
xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 || sudo xcodebuild -runFirstLaunch >/dev/null 2>&1
print "       ✅ $(basename "$XCODE")"

# 2. Il codice di NettoLR: la cartella di questo file se c'è già, altrimenti ~/NettoLR
print "  2/4  Scarico NettoLR…"
QUI="${0:A:h}"
if [[ -f "$QUI/project.yml" ]]; then
  CARTELLA="$QUI"
else
  CARTELLA="$HOME/NettoLR"
fi
if [[ -d "$CARTELLA/.git" ]]; then
  git -C "$CARTELLA" pull --ff-only --quiet || fail "Non riesco ad aggiornare NettoLR da GitHub."
elif [[ -f "$CARTELLA/project.yml" ]]; then
  print "       (cartella scaricata come ZIP: uso quella così com'è)"
else
  git clone --quiet "$REPO" "$CARTELLA" || fail "Non riesco a scaricare NettoLR da GitHub. Sei collegato a internet?"
fi
cd "$CARTELLA" || fail "Non trovo la cartella $CARTELLA."
print "       ✅ $CARTELLA · versione $(grep -m1 MARKETING_VERSION project.yml | grep -oE '[0-9.]+' | head -1)"

# 3. XcodeGen (crea il progetto Xcode dal file project.yml): se manca lo scarico, senza Homebrew
print "  3/4  Preparo il progetto…"
if command -v xcodegen >/dev/null 2>&1; then
  XG=xcodegen
else
  XG="$CARTELLA/.strumenti/xcodegen/bin/xcodegen"
  if [[ ! -x "$XG" ]]; then
    mkdir -p .strumenti
    curl -fsSL -o .strumenti/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip \
      || fail "Non riesco a scaricare XcodeGen."
    (cd .strumenti && unzip -oq xcodegen.zip && rm xcodegen.zip) || fail "Non riesco ad aprire XcodeGen."
  fi
fi
if pgrep -x Xcode >/dev/null; then
  print "       Chiudo Xcode per ricaricare il progetto…"
  osascript -e 'quit app "Xcode"' >/dev/null 2>&1; sleep 3
fi
"$XG" generate --quiet || fail "Non riesco a creare il progetto."
print "       ✅"

# 4. Apri Xcode
print "  4/4  Apro Xcode…"
open NettoLR.xcodeproj
print ""
print "  Ora in Xcode (la prima volta):"
print "   1. In alto a sinistra clicca «NettoLR» (l'icona blu), poi sotto TARGETS clicca «NettoLR»"
print "   2. Scheda «Signing & Capabilities» → Team: scegli il tuo Apple ID"
print "      (se non c'è: menu Xcode → Settings → Accounts → + → Apple ID)"
print "   3. Collega l'iPhone con il cavo, sbloccalo e tocca «Autorizza»"
print "   4. In alto al centro scegli il tuo iPhone, poi premi ▶︎"
print ""
print "  Sull'iPhone, solo la prima volta:"
print "   • Impostazioni → Privacy e sicurezza → Modalità sviluppatore → attiva (l'iPhone si riavvia)"
print "   • Impostazioni → Generali → VPN e gestione dispositivi → tocca il tuo Apple ID → Autorizza"
print ""
print "  Per aggiornare in futuro: rilancia la stessa riga nel Terminale."
print ""
}

principale "$@"
