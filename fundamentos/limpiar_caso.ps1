# ============================================================================
#  LIMPIEZA DIRIGIDA — solo lo que encontramos en ESTE caso
#
#  No usa reglas genericas: no va a tocar Spotify, Discord, Roblox ni Defender.
#  Quita exactamente cuatro cosas, y antes averigua si el ejecutable llego a
#  correr, que es lo que decide si con esto alcanza.
#
#  PASO 1 — simulacro, no toca nada, solo informa:
#      powershell -ExecutionPolicy Bypass -File limpiar_caso.ps1
#  PASO 2 — despues de leer el plan:
#      powershell -ExecutionPolicy Bypass -File limpiar_caso.ps1 -Aplicar
#
#  Nada se borra: todo va a una carpeta de cuarentena en el Escritorio.
# ============================================================================
param([switch]$Aplicar)
$ErrorActionPreference = 'SilentlyContinue'

$Informe = Join-Path $env:USERPROFILE "Desktop\resultado_limpieza.txt"
try { Start-Transcript -Path $Informe -Force | Out-Null } catch {}
$Cuarentena = Join-Path $env:USERPROFILE "Desktop\Cuarentena_$(Get-Date -Format 'yyyyMMdd_HHmm')"
$HUELLA = '396269DEA266D8B7A3D5AEC6C7D7B586F39CEF0CF45EFE1678368801CD933D0D'

function T($t){ Write-Host "`n=== $t" -ForegroundColor Cyan }
function Hacer($q){ if($Aplicar){ Write-Host "  [HECHO] $q" -ForegroundColor Green }
                    else        { Write-Host "  [haria] $q" -ForegroundColor Yellow } }

Write-Host @"

  LIMPIEZA DEL CASO
  modo: $(if($Aplicar){'APLICAR — va a modificar el equipo'}else{'SIMULACRO — no toca nada'})
"@ -ForegroundColor Yellow

# ===========================================================================
#  A. ¿LLEGO A EJECUTARSE?  Windows lo apunta en cuatro sitios ademas del
#     prefetch. Basta que uno lo confirme.
# ===========================================================================
T "A. ¿SE EJECUTO EL ARCHIVO?"
$corrio = $false
$pistas = @()

# --- BAM: el moderador de actividad guarda cada binario ejecutado, con fecha
$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
foreach ($svc in @('bam','dam')) {
    $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc\State\UserSettings\$sid"
    (Get-Item $k).GetValueNames() | Where-Object { $_ -match 'zip|хх|Хх|\.exe$' } | ForEach-Object {
        if ($_ -match 'хх|Хх|zip\.\d+') {
            $b = (Get-ItemProperty $k).$_
            $t = [DateTime]::FromFileTime([BitConverter]::ToInt64($b,0))
            $pistas += "BAM: $_  ->  ejecutado $t"; $corrio = $true
        }
    }
}

# --- MUICache: se escribe cuando un programa se lanza desde el Explorador
$mui = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache'
(Get-Item $mui).GetValueNames() | Where-Object { $_ -match 'хх|Хх|Madium|Installer-1\.1\.0' } |
    ForEach-Object { $pistas += "MUICache: $_"; $corrio = $true }

# --- UserAssist: cuenta los lanzamientos desde el escritorio
$ua = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist'
Get-ChildItem $ua | ForEach-Object {
    $c = Join-Path $_.PSPath 'Count'
    (Get-Item $c).GetValueNames() | ForEach-Object {
        # los nombres van con ROT13
        $d = -join ($_.ToCharArray() | ForEach-Object {
            if ($_ -match '[a-m]'){[char](([int]$_)+13)} elseif($_ -match '[n-z]'){[char](([int]$_)-13)}
            elseif($_ -match '[A-M]'){[char](([int]$_)+13)} elseif($_ -match '[N-Z]'){[char](([int]$_)-13)}
            else {$_} })
        if ($d -match 'хх|Хх|Madium|Installer-1\.1\.0') { $pistas += "UserAssist: $d"; $corrio = $true }
    }
}

# --- ficheros .lnk recientes: Windows crea uno al abrir algo
Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -Filter *.lnk |
    Where-Object { $_.Name -match 'хх|Хх|Madium|Installer' } |
    ForEach-Object { $pistas += "Reciente: $($_.Name)  ($($_.LastWriteTime))"; $corrio = $true }

if ($pistas) { $pistas | ForEach-Object { Write-Host "  [!] $_" -ForegroundColor Red } }
else { Write-Host "  sin rastro de ejecucion en BAM, MUICache, UserAssist ni Recientes" -ForegroundColor Green }

Write-Host ""
if ($corrio) {
    Write-Host "  VEREDICTO: SI se ejecuto. Limpiar no alcanza —" -ForegroundColor Red
    Write-Host "  hay que rotar credenciales y reinstalar." -ForegroundColor Red
} else {
    Write-Host "  VEREDICTO: no encontramos rastro de que se ejecutara." -ForegroundColor Green
    Write-Host "  Eso no lo prueba al 100%, pero son cuatro registros distintos" -ForegroundColor DarkGray
    Write-Host "  y los cuatro estan vacios." -ForegroundColor DarkGray
}

# ===========================================================================
#  B. LO QUE SE VA A QUITAR
# ===========================================================================
T "B. LAS TRES PERSISTENCIAS HUERFANAS DE 'svchost'"
Write-Host "  (apuntan a C:\ProgramData\svchost, que ya no existe)" -ForegroundColor DarkGray

if ($Aplicar) { New-Item -ItemType Directory -Path $Cuarentena -Force | Out-Null }

foreach ($k in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')) {
    $v = (Get-ItemProperty $k).svchost
    if ($v) {
        Hacer "borrar clave de arranque $k :: svchost = $v"
        if ($Aplicar) {
            "$k :: svchost = $v" | Out-File "$Cuarentena\registro_borrado.txt" -Append
            Remove-ItemProperty -Path $k -Name 'svchost'
        }
    }
}

$lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\svchost.lnk"
if (Test-Path $lnk) {
    Hacer "mover a cuarentena el acceso directo de Inicio: svchost.lnk"
    if ($Aplicar) { Move-Item $lnk "$Cuarentena\svchost.lnk" -Force }
}

if (Get-ScheduledTask -TaskName 'svchost') {
    Hacer "exportar y borrar la tarea programada 'svchost'"
    if ($Aplicar) {
        Export-ScheduledTask -TaskName 'svchost' | Out-File "$Cuarentena\tarea_svchost.xml"
        Unregister-ScheduledTask -TaskName 'svchost' -Confirm:$false
    }
}

T "C. EL ARCHIVO DE HOY Y SUS RESTOS"
Get-ChildItem "$env:LOCALAPPDATA\Temp" -Directory | Where-Object { $_.Name -match 'zip' } |
    ForEach-Object {
        $tieneMuestra = Get-ChildItem $_.FullName -Recurse -File |
            Where-Object { (Get-FileHash $_.FullName -Algorithm SHA256).Hash -eq $HUELLA }
        if ($tieneMuestra) {
            Hacer "mover a cuarentena la carpeta temporal: $($_.Name)"
            if ($Aplicar) { Move-Item $_.FullName "$Cuarentena\temp_$($_.Name)" -Force }
        }
    }

foreach ($d in @("$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop")) {
    Get-ChildItem $d -File | Where-Object {
        $_.Name -match 'Installer-1\.1\.0|v\.9\.554|v8\.91\.830' -or
        ($_.Extension -eq '.exe' -and (Get-FileHash $_.FullName -Algorithm SHA256).Hash -eq $HUELLA)
    } | ForEach-Object {
        Hacer "mover a cuarentena: $($_.Name)"
        if ($Aplicar) { Move-Item $_.FullName "$Cuarentena\$($_.Name).bloqueado" -Force }
    }
}

# ===========================================================================
#  D. LO QUE NO TOCO YO — decision suya
# ===========================================================================
T "D. ESTO NO LO QUITO SOLO, DECIDILO VOS"
Write-Host @"
  AnyDesk  — control remoto, instalado en 2021, servicio en arranque
             automatico. Sin conexiones entrantes desde agosto de 2021, o
             sea que NO es del atacante. Pero si no lo usas, sobra:
               Configuracion > Aplicaciones > AnyDesk > Desinstalar

  Celestial ($CRXCelestial.exe en AppData\Roaming\Celestial)
           — herramienta de Roblox de origen no oficial, arranca con Windows.
             Viene del mismo mundo que el archivo de hoy. Si no la usas, fuera.
"@ -ForegroundColor White

# ===========================================================================
if (-not $Aplicar) {
    Write-Host "`n============================================================" -ForegroundColor Yellow
    Write-Host " Esto fue un SIMULACRO. No se toco nada." -ForegroundColor Green
    Write-Host " Lee el plan. Si estas de acuerdo:" -ForegroundColor Green
    Write-Host "   powershell -ExecutionPolicy Bypass -File limpiar_caso.ps1 -Aplicar" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor Yellow
} else {
    Write-Host "`n============================================================" -ForegroundColor Yellow
    Write-Host " Listo. Todo esta en:" -ForegroundColor Green
    Write-Host "   $Cuarentena" -ForegroundColor White
    Write-Host " Nada se borro. Si algo era legitimo, se recupera de ahi." -ForegroundColor Green
    Write-Host ""
    if ($corrio) {
        Write-Host " PERO EL ARCHIVO SE EJECUTO. Borrarlo no devuelve lo que" -ForegroundColor Red
        Write-Host " ya salio. Desde OTRO dispositivo, en este orden:" -ForegroundColor Red
        Write-Host "   1. Contrasena del CORREO (con el se recupera lo demas)" -ForegroundColor Red
        Write-Host "   2. CERRAR TODAS LAS SESIONES en cada servicio" -ForegroundColor Red
        Write-Host "      (una cookie robada entra sin contrasena y sin 2FA)" -ForegroundColor Red
        Write-Host "   3. Discord, Roblox, Steam, banco" -ForegroundColor Red
        Write-Host "   4. Activar 2FA en todo" -ForegroundColor Red
        Write-Host "   5. Avisar a tus contactos" -ForegroundColor Red
        Write-Host "   6. Copiar tus archivos y REINSTALAR Windows" -ForegroundColor Red
    } else {
        Write-Host " No hubo rastro de ejecucion, asi que con esto deberia" -ForegroundColor Green
        Write-Host " alcanzar. Aun asi, cambia la contrasena de Discord y de" -ForegroundColor Green
        Write-Host " Roblox y activa 2FA: cuesta cinco minutos." -ForegroundColor Green
    }
    Write-Host "============================================================" -ForegroundColor Yellow
}

try { Stop-Transcript | Out-Null } catch {}
Write-Host "`n  Informe en el Escritorio: resultado_limpieza.txt" -ForegroundColor Cyan
Read-Host "  Pulsa ENTER para cerrar"
