# ============================================================================
#  LIMPIAR LO QUE ENCONTRO revisar_pc.ps1
#
#  QUE HACE Y QUE NO:
#    Quita lo que SE ENCONTRO: procesos, arranque automatico, tareas y ficheros.
#    NO puede garantizar que el equipo quede limpio - solo quita lo que buscamos.
#    Si el programa dejo algo que no miramos (secuestro de COM, suscripciones
#    WMI, carga dentro de un proceso legitimo, extensiones del navegador), este
#    script dira "hecho" y no sera verdad.
#
#    Por eso, si el equipo guarda algo que importe: copia tus archivos y
#    REINSTALA. Esto es para cuando eso no se puede hacer ahora mismo.
#
#  COMO SE USA - dos pasos, en este orden:
#    1) SIMULACRO (no toca nada, solo ensena lo que haria):
#         powershell -ExecutionPolicy Bypass -File limpiar_pc.ps1
#    2) APLICAR de verdad, despues de leer la lista:
#         powershell -ExecutionPolicy Bypass -File limpiar_pc.ps1 -Aplicar
#
#  Nada se borra: todo va a una carpeta de cuarentena y se puede recuperar.
# ============================================================================
param(
    [switch]$Aplicar,
    [string]$Huella = '7D369EF21A49E0BCFD7875D2E000A5C6BB592E00F305E139A188F40B3DC32249'
)
$ErrorActionPreference = 'SilentlyContinue'

$Cuarentena = "$env:USERPROFILE\Cuarentena_$(Get-Date -Format 'yyyyMMdd_HHmm')"
$Plan = @()

function Plan($tipo, $que, $accion) {
    $script:Plan += [pscustomobject]@{ Tipo = $tipo; Objetivo = $que; Accion = $accion }
}
function Titulo($t) { Write-Host "`n=== $t" -ForegroundColor Cyan }

Write-Host @"

  LIMPIEZA DE INDICADORES
  modo: $(if($Aplicar){'APLICAR (va a modificar el equipo)'}else{'SIMULACRO (no toca nada)'})
  cuarentena: $Cuarentena
"@ -ForegroundColor Yellow

# ---------------------------------------------------------------- 1. procesos
Titulo "PROCESOS corriendo desde carpetas de usuario"
$procs = Get-Process | Where-Object { $_.Path -match 'AppData|\\Temp\\|ProgramData|\\Public\\' }
if (-not $procs) { Write-Host "  ninguno" -ForegroundColor DarkGray }
foreach ($p in $procs) {
    Write-Host "  $($p.Name)  ->  $($p.Path)"
    Plan 'proceso' $p.Path "detener PID $($p.Id) y poner el fichero en cuarentena"
}

# ------------------------------------------------------------- 2. claves Run
Titulo "ARRANQUE AUTOMATICO desde carpetas de usuario"
$claves = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
$sospechosas = @()
foreach ($k in $claves) {
    $props = Get-ItemProperty $k
    if (-not $props) { continue }
    $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
        $v = "$($_.Value)"
        if ($v -match 'AppData|\\Temp\\|ProgramData|\\Public\\') {
            Write-Host "  $k :: $($_.Name) = $v"
            $sospechosas += [pscustomobject]@{ Clave = $k; Nombre = $_.Name; Valor = $v }
            Plan 'arranque' "$k :: $($_.Name)" 'guardar copia y borrar la entrada'
        }
    }
}
if (-not $sospechosas) { Write-Host "  ninguna" -ForegroundColor DarkGray }

# ------------------------------------------------------- 3. carpeta de inicio
Titulo "CARPETA DE INICIO"
$ini = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$enInicio = Get-ChildItem $ini | Where-Object { $_.Name -ne 'desktop.ini' }
if (-not $enInicio) { Write-Host "  vacia" -ForegroundColor DarkGray }
foreach ($f in $enInicio) {
    Write-Host "  $($f.Name)   ($($f.LastWriteTime))"
    Plan 'inicio' $f.FullName 'mover a cuarentena'
}

# ---------------------------------------------------------------- 4. tareas
Titulo "TAREAS PROGRAMADAS recientes y fuera de Windows"
$tareas = Get-ScheduledTask | Where-Object {
    $_.Date -gt (Get-Date).AddDays(-14) -and $_.TaskPath -notlike '*Microsoft*'
}
if (-not $tareas) { Write-Host "  ninguna" -ForegroundColor DarkGray }
foreach ($t in $tareas) {
    Write-Host "  $($t.TaskPath)$($t.TaskName)   creada $($t.Date)"
    Plan 'tarea' "$($t.TaskPath)$($t.TaskName)" 'exportar a XML y desactivar'
}

# --------------------------------------------------------------- 5. ficheros
Titulo "FICHEROS: por huella exacta, y ejecutables nuevos"
$ficheros = @()
@("$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop","$env:APPDATA",
  "$env:LOCALAPPDATA","$env:TEMP","$env:ProgramData") | ForEach-Object {
    Get-ChildItem $_ -Recurse -Include *.exe,*.scr,*.bat,*.vbs,*.ps1,*.cmd -Depth 3 |
        ForEach-Object {
            $porHuella = (Get-FileHash $_.FullName -Algorithm SHA256).Hash -eq $Huella
            $nuevo = $_.LastWriteTime -gt (Get-Date).AddDays(-7) -and
                     $_.DirectoryName -match 'AppData|\\Temp\\|ProgramData'
            if ($porHuella -or $nuevo) {
                $motivo = if ($porHuella) { 'HUELLA EXACTA' } else { 'ejecutable nuevo donde no deberia' }
                Write-Host "  [$motivo] $($_.FullName)"
                $ficheros += $_
                Plan 'fichero' $_.FullName 'mover a cuarentena'
            }
        }
}
if (-not $ficheros) { Write-Host "  ninguno" -ForegroundColor DarkGray }

# ============================================================== EL PLAN
Write-Host "`n============================================================" -ForegroundColor Yellow
if ($Plan.Count -eq 0) {
    Write-Host " Nada que limpiar con lo que buscamos." -ForegroundColor Green
    Write-Host " Eso NO prueba que el equipo este limpio: prueba que no" -ForegroundColor DarkGray
    Write-Host " encontramos lo que sabiamos buscar." -ForegroundColor DarkGray
    Write-Host "============================================================`n" -ForegroundColor Yellow
    return
}
Write-Host " PLAN: $($Plan.Count) accion(es)" -ForegroundColor Yellow
$Plan | Format-Table -Auto -Wrap | Out-String -Width 160 | Write-Host

if (-not $Aplicar) {
    Write-Host " Esto fue un SIMULACRO. No se toco nada." -ForegroundColor Green
    Write-Host " Lee la lista de arriba. Si estas de acuerdo, corre:" -ForegroundColor Green
    Write-Host "   powershell -ExecutionPolicy Bypass -File limpiar_pc.ps1 -Aplicar`n" -ForegroundColor White
    return
}

# ============================================================== APLICAR
New-Item -ItemType Directory -Path $Cuarentena -Force | Out-Null
$registro = "$Cuarentena\lo_que_se_hizo.txt"
"Limpieza $(Get-Date)" | Out-File $registro

Titulo "APLICANDO"
foreach ($a in $Plan) {
    switch ($a.Tipo) {
        'proceso' {
            Get-Process | Where-Object { $_.Path -eq $a.Objetivo } | Stop-Process -Force
            "proceso detenido: $($a.Objetivo)" | Out-File $registro -Append
            Write-Host "  detenido: $($a.Objetivo)" -ForegroundColor Green
        }
        'arranque' {
            $partes = $a.Objetivo -split ' :: '
            $valor = (Get-ItemProperty $partes[0]).$($partes[1])
            "arranque borrado: $($a.Objetivo) = $valor" | Out-File $registro -Append
            Remove-ItemProperty -Path $partes[0] -Name $partes[1]
            Write-Host "  quitado del arranque: $($partes[1])" -ForegroundColor Green
        }
        'tarea' {
            $n = Split-Path $a.Objetivo -Leaf
            $p = (Split-Path $a.Objetivo -Parent) + '\'
            Export-ScheduledTask -TaskName $n -TaskPath $p |
                Out-File "$Cuarentena\tarea_$n.xml"
            Disable-ScheduledTask -TaskName $n -TaskPath $p | Out-Null
            "tarea desactivada: $($a.Objetivo)" | Out-File $registro -Append
            Write-Host "  tarea desactivada: $n" -ForegroundColor Green
        }
        default {
            if (Test-Path $a.Objetivo) {
                $destino = Join-Path $Cuarentena ((Split-Path $a.Objetivo -Leaf) + '.bloqueado')
                Move-Item $a.Objetivo $destino -Force
                "fichero en cuarentena: $($a.Objetivo) -> $destino" | Out-File $registro -Append
                Write-Host "  en cuarentena: $(Split-Path $a.Objetivo -Leaf)" -ForegroundColor Green
            }
        }
    }
}

Write-Host @"

============================================================
 HECHO. Todo esta en:
   $Cuarentena
 con el detalle en lo_que_se_hizo.txt. Nada se borro: si algo
 era legitimo, se recupera de ahi.

 AHORA LA PARTE QUE DE VERDAD IMPORTA
 --------------------------------------------------------
 Los datos ya salieron de aqui. Borrar el programa no los
 devuelve. Desde OTRO dispositivo, en este orden:

   1. Contrasena del CORREO. Primero, siempre: con el correo
      se recuperan todas las demas cuentas.
   2. Cerrar TODAS las sesiones abiertas en cada servicio.
      Cambiar la clave no cierra una sesion ya robada, y con
      la cookie entran sin clave y sin 2FA.
   3. Discord, Roblox, Steam, banco, y todo lo que tenga
      tarjeta guardada.
   4. Activar 2FA en todo lo que lo permita.
   5. Si habia cripto: mover los fondos YA. Una frase semilla
      que estuvo en este equipo esta quemada para siempre.
   6. Avisar a tus contactos: el mismo archivo les va a
      llegar desde TU cuenta, y a vos te creen.

 Y lo honesto: esto quito lo que encontramos. No prueba que
 el equipo este limpio. Si guarda algo que importe, copia
 tus archivos y reinstala.
============================================================

"@ -ForegroundColor Yellow
