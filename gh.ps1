### 6.4 Kompletny skrypt jednokomendowy
# UWAGA: Uruchom jako Administrator
# To nadpisze CALE zdalne repozytorium!

cd C:\Users\mszew\neuroatypowy; `
git init; `
git branch -M main; `
git remote remove origin 2>$null; `
git remote add origin https://github.com/Neuroatypowi/neuroatypowy.git; `
git rm --cached .env 2>$null; `
git add --all; `
git commit -m "POLONISTA v2.1 $(Get-Date -Format 'yyyy-MM-dd HH:mm')"; `
git push --force origin main
