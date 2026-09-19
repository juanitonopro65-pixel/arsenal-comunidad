# ============================================================================
#  REVISAR SI ESTE PC EJECUTO EL INSTALADOR FALSO
#  Solo LEE. No borra, no cambia, no toca nada.
#
#  Como usarlo:
#    1. Boton derecho en Inicio -> Terminal (o PowerShell)
#    2. Pegar:  powershell -ExecutionPolicy Bypass -File revisar_pc.ps1
# ============================================================================
$ErrorActionPreference = 'SilentlyContinue'
$hallazgos = @()
function Aviso($t) { $script:hallazgos += $t; Write-Host "  [!] $t" -ForegroundColor Red }
function Ok($t)    { Write-Host "  [ok] $t" -ForegroundColor DarkGray }

Write-Host "`n=== 1. EL ARCHIVO, POR SU HUELLA ===" -ForegroundColor Cyan
# Esta es la huella exacta de la muestra analizada.
$HUELLA = '7D369EF21A49E0BCFD7875D2E000A5C6BB592E00F305E139A188F40B3DC32249'
$sitios = @("$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop","$env:TEMP",
            "$env:APPDATA","$env:LOCALAPPDATA")
$encontrado = $false
foreach ($s in $sitios) {
    Get-ChildItem $s -Recurse -Include *.exe -Depth 3 | ForEach-Object {
        if ((Get-FileHash $_.FullName -Algorithm SHA256).Hash -eq $HUELLA) {
            Aviso "Muestra encontrada: $($_.FullName)"; $encontrado = $true
        }
    }
}
if (-not $encontrado) { Ok "el archivo exacto no esta en las carpetas habituales" }

Write-Host "`n=== 2. ARRANCA SOLO CON WINDOWS? ===" -ForegroundColor Cyan
$claves = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
foreach ($k in $claves) {
    $p = Get-ItemProperty $k
    if ($p) {
        $p.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
            $v = "$($_.Value)"
            # lo que arranca desde carpetas de usuario es lo sospechoso
            if ($v -match 'AppData|Temp|Roaming|Public|ProgramData') {
                Aviso "Arranque sospechoso: $($_.Name) = $v"
            } else { Ok "$($_.Name)" }
        }
    }
}

Write-Host "`n=== 3. CARPETA DE INICIO ===" -ForegroundColor Cyan
$ini = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$items = Get-ChildItem $ini | Where-Object { $_.Name -ne 'desktop.ini' }
if ($items) { $items | ForEach-Object { Aviso "En Inicio: $($_.Name)  ($($_.LastWriteTime))" } }
else { Ok "vacia" }

Write-Host "`n=== 4. TAREAS PROGRAMADAS RECIENTES ===" -ForegroundColor Cyan
$t = Get-ScheduledTask | Where-Object {
    $_.Date -gt (Get-Date).AddDays(-7) -and $_.TaskPath -notlike '*Microsoft*'
}
if ($t) { $t | ForEach-Object { Aviso "Tarea: $($_.TaskName)  creada $($_.Date)" } }
else { Ok "ninguna tarea nueva fuera de las de Windows" }

Write-Host "`n=== 5. EJECUTABLES NUEVOS DONDE NO DEBERIA HABERLOS ===" -ForegroundColor Cyan
$n = 0
@("$env:APPDATA","$env:LOCALAPPDATA\Temp","$env:TEMP","$env:ProgramData") | ForEach-Object {
    Get-ChildItem $_ -Recurse -Include *.exe,*.scr,*.bat,*.vbs,*.ps1 -Depth 2 |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } |
        Select-Object -First 15 | ForEach-Object {
            Aviso "Nuevo: $($_.FullName)  ($([math]::Round($_.Length/1KB))KB, $($_.LastWriteTime))"
            $n++
        }
}
if ($n -eq 0) { Ok "nada nuevo en los ultimos 7 dias" }

Write-Host "`n=== 6. PROCESOS CORRIENDO DESDE CARPETAS DE USUARIO ===" -ForegroundColor Cyan
$p = Get-Process | Where-Object { $_.Path -match 'AppData|Temp|ProgramData|Public' }
if ($p) { $p | Select-Object -Unique Name,Path | ForEach-Object { Aviso "Proceso: $($_.Name) -> $($_.Path)" } }
else { Ok "ninguno" }

Write-Host "`n=== 7. CONEXIONES ACTIVAS HACIA FUERA ===" -ForegroundColor Cyan
Get-NetTCPConnection -State Established | Where-Object { $_.RemoteAddress -notmatch '^(127\.|::1|192\.168\.|10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[01]\.)' } |
    ForEach-Object {
        $pr = (Get-Process -Id $_.OwningProcess).Name
        Write-Host "     $pr -> $($_.RemoteAddress):$($_.RemotePort)" -ForegroundColor DarkGray
    }

# ---------------------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Yellow
if ($hallazgos.Count -eq 0) {
    Write-Host " SIN INDICIOS. Si nunca hiciste doble clic en el archivo," -ForegroundColor Green
    Write-Host " lo mas probable es que solo lo hayas descargado." -ForegroundColor Green
    Write-Host " Borra el archivo y listo." -ForegroundColor Green
} else {
    Write-Host " $($hallazgos.Count) INDICIO(S). Esto pide accion:" -ForegroundColor Red
    Write-Host " 1. Desconecta este equipo de internet." -ForegroundColor Red
    Write-Host " 2. Desde OTRO dispositivo: cambia contrasenas (correo primero)," -ForegroundColor Red
    Write-Host "    cierra todas las sesiones y activa 2FA." -ForegroundColor Red
    Write-Host " 3. Copia tus archivos personales y REINSTALA Windows." -ForegroundColor Red
    Write-Host "    Limpiar a mano un ladron de datos no es fiable." -ForegroundColor Red
}
Write-Host "============================================================`n" -ForegroundColor Yellow
