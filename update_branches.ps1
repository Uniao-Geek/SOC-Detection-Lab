# Script para atualizar branches remotas
Set-Location "D:\Projetos\MDR-Detection-Lab\SOC-Detection-Lab"

Write-Host "=== Atualizando Branch MAIN ===" -ForegroundColor Green
git push origin main

Write-Host "=== Mudando para Branch MRHENRIKE ===" -ForegroundColor Yellow
git checkout mrhenrike

Write-Host "=== Enviando Branch MRHENRIKE ===" -ForegroundColor Green
git push -u origin mrhenrike

Write-Host "=== Voltando para Branch MAIN ===" -ForegroundColor Yellow
git checkout main

Write-Host "=== Verificando Status Final ===" -ForegroundColor Cyan
git status
git branch -a

Write-Host "=== Atualização Concluída! ===" -ForegroundColor Green
