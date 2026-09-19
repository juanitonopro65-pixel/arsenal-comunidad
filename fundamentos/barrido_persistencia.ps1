# ============================================================================
#  BARRIDO DE PERSISTENCIA - "quedo algo que vuelva a arrancar solo?"
#
#  Borrar el fichero no alcanza. Lo que hace que una infeccion VUELVA es el
#  mecanismo que la relanza: una tarea con temporizador, una descarga en
#  segundo plano, una suscripcion de WMI que espera a que pase algo.
#
#  Solo LEE. No borra nada. Informe en el Escritorio: persistencia.txt
#
#      powershell -ExecutionPolicy Bypass -File barrido_persistencia.ps1
#      powershell -ExecutionPolicy Bypass -File barrido_persistencia.ps1 -Todo
#
#  Correrlo DESPUES de limpiar, y otra vez a los 3 y 7 dias: si algo tenia
#  temporizador, aparece entonces y no ahora.
#
#  ---------------------------------------------------------------------------
#  POR QUE FILTRA POR FIRMA DIGITAL
#  La primera version marcaba 121 cosas en un equipo sano: OneDrive, Defender,
#  el actualizador de Adobe, extensiones del navegador... Un detector que marca
#  todo no sirve, porque el que lo lee deja de mirarlo.
#  El software legitimo va FIRMADO. El malware casi nunca. Ese es el filtro.
#  Con -Todo se ve tambien lo firmado, por si hay que revisar a fondo.
# ============================================================================
param([switch]$Todo)
$ErrorActionPreference = 'SilentlyContinue'
$Informe = Join-Path $env:USERPROFILE "Desktop\persistencia.txt"
try { Start-Transcript -Path $Informe -Force | Out-Null } catch { }

$SOSPECHOSO = 'AppData|\\Temp\\|ProgramData|\\Public\\'
$hall = 0

function T ($t)  { Write-Host "`n=== $t" -ForegroundColor Cyan }
function Mal ($t){ $script:hall++; Write-Host "  [!] $t" -ForegroundColor Red }
function Det ($t){ Write-Host "        $t" -ForegroundColor DarkYellow }
function Bien($t){ Write-Host "  [ok] $t" -ForegroundColor DarkGray }

# Saca la ruta del ejecutable de una linea de comando con comillas o sin ellas
function RutaDe ($cmd) {
    if (-not $cmd) { return $null }
    $c = $cmd.Trim()
    if ($c.StartsWith('"')) { return ($c -split '"')[1] }
    $m = [regex]::Match($c, '^[A-Za-z]:\\[^\s]+\.(exe|dll|bat|cmd|vbs|js|ps1)')
    if ($m.Success) { return $m.Value }
    return ($c -split ' ')[0]
}

# ¿Esta firmado por alguien? Ese es el filtro que separa senal de ruido.
function Firmado ($ruta) {
    if ($Todo) { return $false }                 # con -Todo no se filtra nada
    $r = [Environment]::ExpandEnvironmentVariables("$ruta")
    if (-not $r -or -not (Test-Path $r)) { return $false }
    $s = Get-AuthenticodeSignature $r
    return ($s.Status -eq 'Valid')
}

Write-Host "`n  BARRIDO DE PERSISTENCIA  -  solo lectura" -ForegroundColor Yellow
if ($Todo) { Write-Host "  modo -Todo: se muestra TAMBIEN lo firmado`n" -ForegroundColor DarkGray }
else       { Write-Host "  se ocultan las entradas con firma digital valida`n" -ForegroundColor DarkGray }

# ---------------------------------------------------------------- 1
T "1. TAREAS PROGRAMADAS  (el 'time sleep' mas comun)"
foreach ($x in (Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })) {
    foreach ($a in $x.Actions) {
        $ruta = RutaDe "$($a.Execute)"
        # Una tarea que lanza wscript/powershell/cmd merece mirada aunque el
        # interprete este firmado: lo que importa es el script que ejecuta.
        $interprete = $ruta -match 'wscript|cscript|powershell|cmd\.exe|mshta|rundll32'
        $arg = "$($a.Arguments)"
        if ($interprete) {
            $real = RutaDe $arg
            if ($real -and (Firmado $real)) { continue }
        } elseif (Firmado $ruta) { continue }
        if (-not $interprete -and "$ruta$arg" -notmatch $SOSPECHOSO) { continue }

        $tipos = ($x.Triggers | ForEach-Object { $_.CimClass.CimClassName }) -join ','
        $rep   = ($x.Triggers | ForEach-Object { $_.Repetition.Interval }) -join ','
        Mal "$($x.TaskPath)$($x.TaskName)"
        Det "ejecuta: $($a.Execute) $arg"
        Det "disparo: $tipos   repite=$rep"
    }
}

# ---------------------------------------------------------------- 2
T "2. SUSCRIPCIONES WMI  (persistencia sin fichero)"
# 'SCM Event Log' viene de serie en Windows: no es hallazgo.
$c = Get-WmiObject -Namespace root\subscription -Class __EventConsumer |
        Where-Object { $_.Name -notmatch '^SCM Event Log' }
if ($c) {
    foreach ($x in $c) {
        Mal "consumidor WMI: $($x.Name)"
        if ($x.CommandLineTemplate) { Det "ejecuta: $($x.CommandLineTemplate)" }
        if ($x.ScriptText) {
            $n = [Math]::Min(150, $x.ScriptText.Length)
            Det "script : $($x.ScriptText.Substring(0, $n))"
        }
    }
} else { Bien "solo las de serie de Windows" }

# ---------------------------------------------------------------- 3
T "3. DESCARGAS EN SEGUNDO PLANO (BITS)  (rebaja el fichero solo)"
$bits = Get-BitsTransfer -AllUsers
if ($bits) {
    foreach ($x in $bits) {
        Mal "trabajo BITS: $($x.DisplayName)   estado=$($x.JobState)"
        $x.FileList | ForEach-Object { Det "$($_.RemoteName)  ->  $($_.LocalName)" }
    }
} else { Bien "ninguna descarga pendiente" }

# ---------------------------------------------------------------- 4
T "4. WINDOWS DEFENDER"
$mp = Get-MpPreference
$ex = @($mp.ExclusionPath) + @($mp.ExclusionProcess) | Where-Object { $_ -and $_ -notmatch 'administrator' }
if ($ex) { foreach ($e in $ex) { Mal "carpeta excluida del antivirus: $e" } }
elseif ("$($mp.ExclusionPath)" -match 'administrator') { Bien "hay que ser administrador para ver las exclusiones" }
else { Bien "sin exclusiones" }
if ($mp.DisableRealtimeMonitoring -eq $true) { Mal "PROTECCION EN TIEMPO REAL DESACTIVADA" }

# ---------------------------------------------------------------- 5
T "5. SERVICIOS"
foreach ($s in (Get-CimInstance Win32_Service | Where-Object { $_.PathName -match $SOSPECHOSO })) {
    $r = RutaDe $s.PathName
    if (Firmado $r) { continue }
    Mal "servicio $($s.Name)  [$($s.StartMode)]  ->  $($s.PathName)"
}

# ---------------------------------------------------------------- 6
T "6. CLAVES DE ARRANQUE (todas las variantes)"
$claves = @(
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run',
 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')
foreach ($k in $claves) {
    if (-not (Test-Path $k)) { continue }
    (Get-ItemProperty $k).PSObject.Properties |
        Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
            $v = "$($_.Value)"
            $r = RutaDe $v
            if ($v -match $SOSPECHOSO -and -not (Firmado $r)) {
                Mal "$($_.Name) = $v"
                Det "en $k"
            }
        }
}

# ---------------------------------------------------------------- 7
T "7. CARPETAS DE INICIO"
foreach ($d in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
                 "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
    foreach ($f in (Get-ChildItem $d | Where-Object { $_.Name -ne 'desktop.ini' })) {
        $destino = ''
        if ($f.Extension -eq '.lnk') {
            $sh = New-Object -ComObject WScript.Shell
            $destino = $sh.CreateShortcut($f.FullName).TargetPath
        } else { $destino = $f.FullName }
        if (Firmado $destino) { continue }
        Mal "en Inicio: $($f.Name)   ($($f.LastWriteTime))"
        if ($destino) { Det "apunta a: $destino" }
    }
}

# ---------------------------------------------------------------- 8
T "8. WINLOGON  (corre antes que el escritorio)"
$w = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'
$ok = $true
if ($w.Userinit -notmatch '(?i)^C:\\Windows\\system32\\userinit\.exe,?$') { Mal "Userinit alterado: $($w.Userinit)"; $ok = $false }
if ($w.Shell    -notmatch '(?i)^explorer\.exe$')                          { Mal "Shell alterado: $($w.Shell)";       $ok = $false }
if ($ok) { Bien "Userinit y Shell normales" }

# ---------------------------------------------------------------- 9
T "9. SECUESTRO POR DEPURADOR (IFEO)"
$n = 0
Get-ChildItem 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' |
    ForEach-Object {
        $d = (Get-ItemProperty $_.PSPath).Debugger
        if ($d) { Mal "IFEO: $($_.PSChildName)  ->  depurador = $d"; $n++ }
    }
if ($n -eq 0) { Bien "ninguno" }

# ---------------------------------------------------------------- 10
T "10. DLLs QUE SE INYECTAN EN TODO PROGRAMA"
$a  = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Windows'
$ap = Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Session Manager'
$n = 0
if ($a.AppInit_DLLs)  { Mal "AppInit_DLLs = $($a.AppInit_DLLs)"; $n++ }
if ($ap.AppCertDlls)  { Mal "AppCertDlls = $($ap.AppCertDlls)";  $n++ }
if ($n -eq 0) { Bien "ninguna" }

# ---------------------------------------------------------------- 11
T "11. SECUESTRO DE COM"
$n = 0
if (Test-Path 'HKCU:\Software\Classes\CLSID') {
    Get-ChildItem 'HKCU:\Software\Classes\CLSID' | ForEach-Object {
        $s = (Get-ItemProperty "$($_.PSPath)\InprocServer32").'(default)'
        if ($s -match $SOSPECHOSO -and -not (Firmado (RutaDe $s))) {
            Mal "COM $($_.PSChildName)  ->  $s"; $n++
        }
    }
}
if ($n -eq 0) { Bien "nada sin firmar" }

# ---------------------------------------------------------------- 12
T "12. ACTIVE SETUP  (corre al iniciar sesion)"
$n = 0
foreach ($r in @('HKLM:\Software\Microsoft\Active Setup\Installed Components',
                 'HKLM:\Software\Wow6432Node\Microsoft\Active Setup\Installed Components')) {
    Get-ChildItem $r | ForEach-Object {
        $s = (Get-ItemProperty $_.PSPath).StubPath
        if ($s -match $SOSPECHOSO -and -not (Firmado (RutaDe $s))) {
            Mal "Active Setup $($_.PSChildName)  ->  $s"; $n++
        }
    }
}
if ($n -eq 0) { Bien "nada sospechoso" }

# ---------------------------------------------------------------- 13
T "13. EJECUTABLES SIN FIRMAR EN SITIOS RAROS (ultimos 14 dias)"
$n = 0
$IGNORAR = 'Extensions\\|\.minecraft|node_modules|\\cache|\\Cache|Crashpad|\\Code Cache'
foreach ($d in @("$env:APPDATA","$env:LOCALAPPDATA","$env:TEMP","$env:ProgramData","$env:PUBLIC")) {
    Get-ChildItem $d -Recurse -Include *.exe,*.dll,*.scr,*.bat,*.cmd,*.vbs -Depth 2 |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-14) -and $_.FullName -notmatch $IGNORAR } |
        ForEach-Object {
            if (Firmado $_.FullName) { return }
            $kb = [math]::Round($_.Length / 1024)
            $cuando = $_.LastWriteTime
            Mal "sin firmar: $($_.FullName)"
            Det "$kb KB, $cuando"
            $n++
        }
}
if ($n -eq 0) { Bien "nada sin firmar en 14 dias" }

# ---------------------------------------------------------------- 14
T "14. PROCESOS SIN FIRMAR CON CONEXION HACIA FUERA"
$n = 0
$vistos = @{}
foreach ($c in (Get-NetTCPConnection -State Established)) {
    $p = Get-Process -Id $c.OwningProcess
    if (-not $p.Path) { continue }
    if ($p.Path -notmatch $SOSPECHOSO) { continue }
    if (Firmado $p.Path) { continue }
    $clave = "$($p.Path)|$($c.RemoteAddress)"
    if ($vistos[$clave]) { continue }
    $vistos[$clave] = $true
    Mal "$($p.Name)  ->  $($c.RemoteAddress):$($c.RemotePort)"
    Det $p.Path
    $n++
}
if ($n -eq 0) { Bien "ninguno" }

# ===========================================================================
Write-Host "`n============================================================" -ForegroundColor Yellow
if ($hall -eq 0) {
    Write-Host " Nada sin firmar en ningun mecanismo de persistencia." -ForegroundColor Green
    Write-Host "" -ForegroundColor Green
    Write-Host " Volve a correrlo a los 3 y a los 7 dias: si algo tenia" -ForegroundColor Green
    Write-Host " temporizador, aparece entonces y no ahora." -ForegroundColor Green
} else {
    Write-Host " $hall hallazgo(s). Todos SIN FIRMA DIGITAL valida." -ForegroundColor Red
    Write-Host " Eso no los vuelve malos por si solo - hay programas" -ForegroundColor DarkGray
    Write-Host " legitimos sin firmar - pero es donde hay que mirar." -ForegroundColor DarkGray
    Write-Host " Lo que no reconozcas, se investiga antes de borrarlo." -ForegroundColor DarkGray
}
Write-Host "============================================================" -ForegroundColor Yellow
try { Stop-Transcript | Out-Null } catch { }
Write-Host "`n  Informe en el Escritorio: persistencia.txt" -ForegroundColor Cyan
Read-Host "  Pulsa ENTER para cerrar"
