#!/bin/zsh
# Doppio clic: prepara NettoLR e apre Xcode (fa tutto installa.sh, nella stessa cartella)
cd "${0:A:h}" || exit 1
exec zsh ./installa.sh
