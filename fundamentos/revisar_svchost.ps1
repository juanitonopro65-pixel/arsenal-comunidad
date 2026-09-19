# ============================================================================
#  SEGUNDA FASE — mirar de cerca los tres hallazgos reales
#
#  Solo LEE. No borra, no detiene procesos, no cambia nada.
#  Guarda todo en el Escritorio como resultado_fase2.txt
#
#    powershell -ExecutionPolicy Bypass -File revisar_svchost.ps1
# ============================================================================
$ErrorActionPreference = 'SilentlyContinue'
$Informe = Join-Path $env:USERPROFILE "Desktop\resultado_fase2.txt"
try { Start-Transcript -Path $Informe -Force | Out-Null } catch {}

function T($t) { Write-Host "`n=== $t" -ForegroundColor Cyan }

# --------------------------------------------------------------------------
T "1. QUE ES C:\ProgramData\svchost"
$ruta = "C:\ProgramData\svchost"
if (Test-Path $ruta) {
    $it = Get-Item $ruta -Force
    $esCarpeta = $it.PSIsContainer
    "  tipo        : $(if($esCarpeta){'CARPETA'}else{'FICHERO'})"
    "  creado      : $($it.CreationTime)"
    "  modificado  : $($it.LastWriteTime)"
    "  oculto      : $(($it.Attributes -band [IO.FileAttributes]::Hidden) -ne 0)"
    if ($esCarpeta) {
        "  --- que hay dentro:"
        Get-ChildItem $ruta -Force -Recurse -Depth 2 | ForEach-Object {
            "    $($_.FullName)  ($($_.Length) bytes, $($_.LastWriteTime))"
        }
        # los ejecutables de dentro, con su huella y su firma
        Get-ChildItem $ruta -Force -Recurse -Include *.exe,*.dll,*.bat,*.cmd,*.vbs,*.ps1 -Depth 2 | ForEach-Object {
            "    HUELLA $($_.Name): $((Get-FileHash $_.FullName -Algorithm SHA256).Hash)"
            $s = Get-AuthenticodeSignature $_.FullName
            "    FIRMA  $($_.Name): $($s.Status) $(if($s.SignerCertificate){$s.SignerCertificate.Subject})"
        }
    } else {
        "  tamano      : $($it.Length) bytes"
        "  huella      : $((Get-FileHash $ruta -Algorithm SHA256).Hash)"
        $s = Get-AuthenticodeSignature $ruta
        "  firma       : $($s.Status)"
        "  firmante    : $(if($s.SignerCertificate){$s.SignerCertificate.Subject}else{'NINGUNO'})"
        "  --- primeros bytes (MZ = es un ejecutable de Windows):"
        $b = Get-Content $ruta -Encoding Byte -TotalCount 2
        "      $([char]$b[0])$([char]$b[1])"
    }
} else {
    "  no existe esa ruta"
}

# --------------------------------------------------------------------------
T "2. A QUE APUNTAN LAS TRES PERSISTENCIAS"
"  --- clave de arranque:"
(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run').svchost
(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run').svchost

"  --- acceso directo de la carpeta Inicio:"
$lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\svchost.lnk"
if (Test-Path $lnk) {
    $sh = New-Object -ComObject WScript.Shell
    $a = $sh.CreateShortcut($lnk)
    "    destino   : $($a.TargetPath)"
    "    argumentos: $($a.Arguments)"
    "    carpeta   : $($a.WorkingDirectory)"
}

"  --- tarea programada:"
$t = Get-ScheduledTask -TaskName 'svchost'
if ($t) {
    $t.Actions | ForEach-Object { "    ejecuta: $($_.Execute) $($_.Arguments)" }
    $t.Triggers | ForEach-Object { "    cuando : $($_.CimClass.CimClassName)" }
    "    usuario: $($t.Principal.UserId)  nivel: $($t.Principal.RunLevel)"
    "    estado : $($t.State)"
}

# --------------------------------------------------------------------------
T "3. ANYDESK: QUIEN SE CONECTO Y CUANDO"
$trace = "$env:APPDATA\AnyDesk\connection_trace.txt"
$trace2 = "$env:ProgramData\AnyDesk\connection_trace.txt"
foreach ($f in @($trace, $trace2)) {
    if (Test-Path $f) {
        "  --- $f"
        Get-Content $f -Tail 40 | ForEach-Object { "    $_" }
    }
}
"  --- servicio de AnyDesk:"
Get-Service | Where-Object { $_.Name -like "*AnyDesk*" } |
    Select-Object Name, Status, StartType | Format-Table -Auto | Out-String

"  --- cuando se instalo:"
foreach ($p in @("$env:ProgramFiles(x86)\AnyDesk", "$env:ProgramFiles\AnyDesk", "$env:APPDATA\AnyDesk")) {
    if (Test-Path $p) { "    $p  creado $((Get-Item $p).CreationTime)" }
}

# --------------------------------------------------------------------------
T "4. LO QUE QUEDO DEL ARCHIVO DE HOY"
Get-ChildItem "$env:LOCALAPPDATA\Temp" -Directory -Filter "*zip*" |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-2) } | ForEach-Object {
        "  carpeta: $($_.FullName)   ($($_.LastWriteTime))"
        Get-ChildItem $_.FullName -Recurse -File | ForEach-Object {
            "    $($_.Name)  ($($_.Length) bytes)"
            if ($_.Extension -eq '.exe') {
                "      huella: $((Get-FileHash $_.FullName -Algorithm SHA256).Hash)"
                $s = Get-AuthenticodeSignature $_.FullName
                "      firma : $($s.Status)"
            }
        }
    }

# --------------------------------------------------------------------------
T "5. CUANDO SE EJECUTO ALGO POR ULTIMA VEZ (prefetch)"
Get-ChildItem "C:\Windows\Prefetch" -Filter "*.pf" |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-3) } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 25 |
    ForEach-Object { "  $($_.LastWriteTime)  $($_.Name)" }

try { Stop-Transcript | Out-Null } catch {}
Write-Host "`n  Informe guardado en el Escritorio: resultado_fase2.txt" -ForegroundColor Cyan
Read-Host "  Pulsa ENTER para cerrar"
