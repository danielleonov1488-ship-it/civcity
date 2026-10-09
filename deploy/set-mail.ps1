$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
# в программу ssh уходит только строка base64 из латиницы — без невидимых меток кодировки
$OutputEncoding = New-Object System.Text.ASCIIEncoding
Write-Host ''
Write-Host 'Почта для игры CivCity' -ForegroundColor Yellow
Write-Host 'С этого ящика игроки получают письма «Забыли пароль?».'
Write-Host 'Пароль вводится здесь и уходит прямо на сервер — на экран и в файлы он не попадает.'
Write-Host ''
$user = Read-Host 'Адрес ящика (например noreply@civcity.ru)'
$sec = Read-Host 'Пароль от ящика' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$pass = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
$key = Join-Path $env:USERPROFILE '.ssh\civcity_ed25519'
$json = @{ host = 'smtp.beget.com'; port = 465; user = $user.Trim(); pass = $pass } | ConvertTo-Json -Compress
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
$pass = $null; $json = $null
Write-Host ''
Write-Host 'Записываю на сервер...'
$b64 | ssh -i $key -o BatchMode=yes root@159.194.249.20 'cd /srv/civcity/server && node setmail.js && systemctl restart civcity && node testmail.js'
$ok = $LASTEXITCODE -eq 0
$b64 = $null
if ($ok) { Write-Host ''; Write-Host 'Готово! Проверьте ящик — туда пришло проверочное письмо.' -ForegroundColor Green }
else { Write-Host ''; Write-Host 'Не получилось. Проверьте адрес и пароль ящика и запустите ещё раз.' -ForegroundColor Red }
