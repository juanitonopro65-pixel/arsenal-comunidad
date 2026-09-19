# ============================================================================
#  LIMPIEZA DIRIGIDA - solo lo que encontramos en ESTE caso
#
#  No usa reglas genericas: no va a tocar Spotify, Discord, Roblox ni Defender.
#  Antes de limpiar averigua si el ejecutable llego a correr, que es lo que
#  decide si con esto alcanza o hay que reinstalar.
#
#  PASO 1 - simulacro, no toca nada:
#      powershell -ExecutionPolicy Bypass -File limpiar_caso.ps1
#  PASO 2 - despues de leer el plan:
#      powershell -ExecutionPolicy Bypass -File limpiar_caso.ps1 -Aplicar
#
#  Nada se borra: todo va a una carpeta de cuarentena en el Escritorio.
# ============================================================================
param([switch]$Aplicar)
$ErrorActionPreference = 'SilentlyContinue'

$Informe    = Join-Path $env:USERPROFILE "Desktop\resultado_limpieza.txt"
$Cuarentena = Join-Path $env:USERPROFILE "Desktop\Cuarentena_$(Get-Date -Format 'yyyyMMdd_HHmm')"
$HUELLA     = '396269DEA266D8B7A3D5AEC6C7D7B586F39CEF0CF45EFE1678368801CD933D0D'

# Dos patrones distintos a proposito:
#
#  EJECUCION - va anclado al principio del nombre de fichero, porque un patron
#  suelto atrapa cosas legitimas. En la prueba, 'Installer-1\.1\.0' coincidio
#  con "fabric-installer-1.1.0.exe" (instalador legitimo de Minecraft) y dio un
#  falso "SI se ejecuto" \u2014 que es el veredicto que manda a reinstalar Windows.
#  Un falso positivo aqui cuesta un formateo para nada.
$EJECUCION = '(^|[\\/])(Installer-1\.1\.0\.exe|[\u0425\u0445][\u0445]-v\.9\.554\.exe|Madium)'
#
#  FICHEROS - puede ser mas ancho: mover algo a cuarentena es reversible,
#  y ademas se comprueba la huella exacta en los .exe.
$PATRON    = 'Madium|Installer-1\.1\.0\.exe|v\.9\.554|v8\.91\.830|[\u0425\u0445][\u0445]'

try { Start-Transcript -Path $Informe -Force | Out-Null } catch { }

function T   ($t) { Write-Host "`n=== $t" -ForegroundColor Cyan }
function Hacer ($q) {
    if ($Aplicar) { Write-Host "  [HECHO] $q" -ForegroundColor Green }
    else          { Write-Host "  [haria] $q" -ForegroundColor Yellow }
}
function Rot13 ($s) {
    $r = ''
    foreach ($ch in $s.ToCharArray()) {
        $c = [int][char]$ch
        if     ($c -ge 97 -and $c -le 122) { $r += [char](97 + ((($c - 97) + 13) % 26)) }
        elseif ($c -ge 65 -and $c -le 90)  { $r += [char](65 + ((($c - 65) + 13) % 26)) }
        else                               { $r += $ch }
    }
    return $r
}
function NombresDe ($clave) {
    if (Test-Path $clave) {
        $k = Get-Item $clave
        if ($k) { return $k.GetValueNames() }
    }
    return @()
}

Write-Host "`n  LIMPIEZA DEL CASO" -ForegroundColor Yellow
if ($Aplicar) { Write-Host "  modo: APLICAR - va a modificar el equipo`n" -ForegroundColor Red }
else          { Write-Host "  modo: SIMULACRO - no toca nada`n"          -ForegroundColor Green }

# ===========================================================================
#  A. LLEGO A EJECUTARSE?
#     El prefetch vino vacio, asi que se miran otros cuatro registros donde
#     Windows deja rastro de lo que se ejecuto. Basta que uno lo confirme.
# ===========================================================================
T "A. SE EJECUTO EL ARCHIVO?"
$pistas = @()

# --- BAM / DAM: cada binario ejecutado, con su fecha
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
foreach ($svc in @('bam', 'dam')) {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc\State\UserSettings\$sid"
    foreach ($n in (NombresDe $k)) {
        if ($n -match $EJECUCION) {
            $cuando = ''
            $b = (Get-ItemProperty -Path $k -Name $n).$n
            if ($b -is [byte[]] -and $b.Length -ge 8) {
                $cuando = [DateTime]::FromFileTime([BitConverter]::ToInt64($b, 0))
            }
            $pistas += "BAM  : $n   $cuando"
        }
    }
}

# --- MUICache: se escribe al lanzar algo desde el Explorador
$mui = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache'
foreach ($n in (NombresDe $mui)) {
    if ($n -match $EJECUCION) { $pistas += "MUICache : $n" }
}

# --- UserAssist: cuenta los lanzamientos. Guarda los nombres en ROT13.
$ua = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist'
if (Test-Path $ua) {
    foreach ($sub in (Get-ChildItem $ua)) {
        $cnt = Join-Path $sub.PSPath 'Count'
        foreach ($n in (NombresDe $cnt)) {
            $claro = Rot13 $n
            if ($claro -match $EJECUCION) { $pistas += "UserAssist : $claro" }
        }
    }
}

# --- accesos recientes: Windows crea un .lnk al abrir algo
foreach ($f in (Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -Filter *.lnk)) {
    if ($f.Name -match $EJECUCION) { $pistas += "Reciente : $($f.Name)   $($f.LastWriteTime)" }
}

$corrio = ($pistas.Count -gt 0)
if ($corrio) {
    foreach ($p in $pistas) { Write-Host "  [!] $p" -ForegroundColor Red }
    Write-Host "`n  VEREDICTO: SI se ejecuto." -ForegroundColor Red
    Write-Host "  Limpiar no alcanza: hay que rotar credenciales y reinstalar." -ForegroundColor Red
} else {
    Write-Host "  sin rastro en BAM, MUICache, UserAssist ni Recientes" -ForegroundColor Green
    Write-Host "`n  VEREDICTO: no encontramos rastro de que se ejecutara." -ForegroundColor Green
    Write-Host "  No lo prueba al 100%, pero son cuatro registros y los cuatro" -ForegroundColor DarkGray
    Write-Host "  estan vacios." -ForegroundColor DarkGray
}

# ===========================================================================
#  B. LAS TRES PERSISTENCIAS HUERFANAS
# ===========================================================================
T "B. LAS TRES PERSISTENCIAS DE 'svchost'"
Write-Host "  (apuntan a C:\ProgramData\svchost, que ya no existe)" -ForegroundColor DarkGray

if ($Aplicar) { New-Item -ItemType Directory -Path $Cuarentena -Force | Out-Null }
$algo = $false

foreach ($k in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
    $v = (Get-ItemProperty -Path $k -Name 'svchost').svchost
    if ($v) {
        $algo = $true
        Hacer "borrar del arranque: $k :: svchost = $v"
        if ($Aplicar) {
            "$k :: svchost = $v" | Out-File "$Cuarentena\registro_borrado.txt" -Append
            Remove-ItemProperty -Path $k -Name 'svchost'
        }
    }
}

$lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\svchost.lnk"
if (Test-Path $lnk) {
    $algo = $true
    Hacer "mover a cuarentena el acceso directo de Inicio: svchost.lnk"
    if ($Aplicar) { Move-Item $lnk "$Cuarentena\svchost.lnk" -Force }
}

if (Get-ScheduledTask -TaskName 'svchost' -ErrorAction SilentlyContinue) {
    $algo = $true
    Hacer "exportar y borrar la tarea programada 'svchost'"
    if ($Aplicar) {
        Export-ScheduledTask -TaskName 'svchost' -ErrorAction SilentlyContinue | Out-File "$Cuarentena\tarea_svchost.xml"
        Unregister-ScheduledTask -TaskName 'svchost' -Confirm:$false
    }
}
if (-not $algo) { Write-Host "  ninguna encontrada" -ForegroundColor DarkGray }

# ===========================================================================
#  C. EL ARCHIVO DE HOY Y SUS RESTOS
# ===========================================================================
T "C. EL ARCHIVO Y SUS RESTOS"
$algo = $false
$n = 0

# Se busca EN PROFUNDIDAD y en todos los sitios donde puede haber quedado,
# incluido el Escritorio redirigido a OneDrive: la primera version solo miraba
# el nivel superior de Descargas y Escritorio, y se dejaba fuera la copia que
# de hecho se ejecuto, en OneDrive\Escritorio\...\хх\хх\
$raices = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\OneDrive\Escritorio",
    "$env:USERPROFILE\OneDrive\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:LOCALAPPDATA\Temp"
) | Where-Object { Test-Path $_ } | Sort-Object -Unique

# --- carpetas enteras cuyo nombre delata el origen
foreach ($r in $raices) {
    foreach ($dir in (Get-ChildItem $r -Directory -Recurse -Depth 3)) {
        if ($dir.Name -match '9\.554|[Хх][х]|Madium') {
            $algo = $true; $n++
            Hacer "cuarentena carpeta: $($dir.FullName)"
            if ($Aplicar) { Move-Item $dir.FullName (Join-Path $Cuarentena "carpeta_$n") -Force }
        }
    }
}

# --- ficheros sueltos: por nombre, o por huella exacta si es ejecutable
foreach ($r in $raices) {
    foreach ($f in (Get-ChildItem $r -File -Recurse -Depth 4)) {
        $coincide = $f.Name -match $PATRON
        if (-not $coincide -and $f.Extension -in @('.exe', '.zip')) {
            $coincide = (Get-FileHash $f.FullName -Algorithm SHA256).Hash -eq $HUELLA
        }
        if ($coincide) {
            $algo = $true; $n++
            Hacer "cuarentena: $($f.FullName)"
            if ($Aplicar) { Move-Item $f.FullName (Join-Path $Cuarentena "$n`_$($f.Name).bloqueado") -Force }
        }
    }
}

# --- el programa "Madium" que se instalo, y su acceso directo del menu Inicio
foreach ($p in @("$env:LOCALAPPDATA\Programs", "$env:APPDATA", "$env:LOCALAPPDATA")) {
    foreach ($dir in (Get-ChildItem $p -Directory -ErrorAction SilentlyContinue)) {
        if ($dir.Name -match 'madium') {
            $algo = $true; $n++
            Hacer "cuarentena el programa instalado: $($dir.FullName)"
            if ($Aplicar) { Move-Item $dir.FullName (Join-Path $Cuarentena "programa_$n") -Force }
        }
    }
}
foreach ($m in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
                 "$env:ProgramData\Microsoft\Windows\Start Menu\Programs")) {
    foreach ($f in (Get-ChildItem $m -Filter *.lnk -Recurse -ErrorAction SilentlyContinue)) {
        if ($f.Name -match 'madium|9\.554|[Хх][х]') {
            $algo = $true; $n++
            Hacer "cuarentena acceso directo: $($f.FullName)"
            if ($Aplicar) { Move-Item $f.FullName (Join-Path $Cuarentena "lnk_$n`_$($f.Name)") -Force }
        }
    }
}

if (-not $algo) { Write-Host "  nada encontrado" -ForegroundColor DarkGray }

# ===========================================================================
#  D. LO QUE NO TOCO YO
# ===========================================================================
T "D. ESTO NO LO QUITO SOLO - decidilo vos"
Write-Host "  AnyDesk   control remoto instalado en 2021, servicio en arranque." -ForegroundColor White
Write-Host "            Sin conexiones entrantes desde agosto de 2021: NO es del" -ForegroundColor White
Write-Host "            atacante. Pero si no lo usas, sobra." -ForegroundColor White
Write-Host "            Configuracion > Aplicaciones > AnyDesk > Desinstalar" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Celestial herramienta de Roblox no oficial que arranca con Windows," -ForegroundColor White
Write-Host "            en AppData\Roaming\Celestial. Del mismo mundo que el" -ForegroundColor White
Write-Host "            archivo de hoy. Si no la usas, fuera." -ForegroundColor White

# ===========================================================================
Write-Host "`n============================================================" -ForegroundColor Yellow
if (-not $Aplicar) {
    Write-Host " Esto fue un SIMULACRO. No se toco nada." -ForegroundColor Green
    Write-Host " Si estas de acuerdo con el plan:" -ForegroundColor Green
    Write-Host "   powershell -ExecutionPolicy Bypass -File limpiar_caso.ps1 -Aplicar" -ForegroundColor White
} else {
    Write-Host " Listo. Todo esta en:" -ForegroundColor Green
    Write-Host "   $Cuarentena" -ForegroundColor White
    Write-Host " Nada se borro: si algo era legitimo, se recupera de ahi." -ForegroundColor Green
    Write-Host ""
    if ($corrio) {
        Write-Host " PERO EL ARCHIVO SE EJECUTO. Borrarlo no devuelve lo que ya" -ForegroundColor Red
        Write-Host " salio. Desde OTRO dispositivo, en este orden:" -ForegroundColor Red
        Write-Host "   1. Contrasena del CORREO" -ForegroundColor Red
        Write-Host "   2. CERRAR TODAS LAS SESIONES en cada servicio" -ForegroundColor Red
        Write-Host "   3. Discord, Roblox, Steam, banco" -ForegroundColor Red
        Write-Host "   4. Activar 2FA" -ForegroundColor Red
        Write-Host "   5. Avisar a tus contactos" -ForegroundColor Red
        Write-Host "   6. Copiar tus archivos y REINSTALAR Windows" -ForegroundColor Red
    } else {
        Write-Host " No hubo rastro de ejecucion, asi que con esto deberia" -ForegroundColor Green
        Write-Host " alcanzar. Cambia igual la clave de Discord y Roblox y" -ForegroundColor Green
        Write-Host " activa 2FA: cuesta cinco minutos." -ForegroundColor Green
    }
}
Write-Host "============================================================" -ForegroundColor Yellow

try { Stop-Transcript | Out-Null } catch { }
Write-Host "`n  Informe en el Escritorio: resultado_limpieza.txt" -ForegroundColor Cyan
Read-Host "  Pulsa ENTER para cerrar"
