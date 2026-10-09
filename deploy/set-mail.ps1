$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Write-Host ''
Write-Host 'Почта для игры CivCity' -ForegroundColor Yellow
Write-Host 'С этого ящика игроки получают письма «Забыли пароль?».'
Write-Host 'Пароль вводится здесь и уходит прямо на сервер — нигде больше он не сохраняется.'
Write-Host ''
$user = Read-Host 'Адрес ящика (например noreply@civcity.ru)'
$sec = Read-Host 'Пароль от ящика' -AsSecureString
$pass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$key = Join-Path $env:USERPROFILE '.ssh\civcity_ed25519'
$json = @{ host = 'smtp.beget.com'; port = 465; user = $user; pass = $pass } | ConvertTo-Json -Compress
$pass = $null
Write-Host ''
Write-Host 'Записываю на сервер...'
$json | ssh -i $key -o BatchMode=yes root@159.194.249.20 'cd /srv/civcity/server && node setmail.js && systemctl restart civcity && node testmail.js'
if ($LASTEXITCODE -eq 0) { Write-Host ''; Write-Host 'Готово! Проверьте ящик — туда пришло проверочное письмо.' -ForegroundColor Green }
else { Write-Host ''; Write-Host 'Не получилось. Проверьте адрес и пароль ящика и запустите ещё раз.' -ForegroundColor Red }
