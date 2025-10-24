@echo off
cd /d "D:\Projetos\MDR-Detection-Lab\SOC-Detection-Lab"

echo === Atualizando Branch MAIN ===
git push origin main

echo === Mudando para Branch MRHENRIKE ===
git checkout mrhenrike

echo === Enviando Branch MRHENRIKE ===
git push -u origin mrhenrike

echo === Voltando para Branch MAIN ===
git checkout main

echo === Verificando Status Final ===
git status
git branch -a

echo === Atualizacao Concluida! ===
pause
