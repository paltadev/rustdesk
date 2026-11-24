# Palta PC Remoto - instalador
# Uso (PowerShell):  irm https://paltapc.com/remoto | iex
# Sirve para instalar y para actualizar: siempre baja la ultima version publicada.
# Codigo fuente: https://github.com/paltadev/rustdesk (rama palta-branding, carpeta palta/)
#
# Este archivo es solo ASCII a proposito: GitHub lo sirve como binario y Windows PowerShell 5.1
# lo leeria con otra codificacion. Las letras con tilde salen de [char].

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'   # sin la barra de progreso, Invoke-WebRequest baja mucho mas rapido

    $COMANDO = 'irm https://paltapc.com/remoto | iex'
    $BASE    = 'https://github.com/paltadev/rustdesk/releases/latest/download'
    $NOMBRE  = 'Palta PC Remoto'
    $EXE     = Join-Path $env:ProgramFiles "$NOMBRE\$NOMBRE.exe"
    $PAGINA  = 'https://paltapc.com/remoto'

    $a = [char]0xE1; $e = [char]0xE9; $i = [char]0xED; $o = [char]0xF3; $u = [char]0xFA
    $n = [char]0xF1; $preg = [char]0xBF

    function Paso($texto)  { Write-Host "  > $texto" -ForegroundColor Cyan }
    function Falla($texto) {
        Write-Host ''
        Write-Host "  No se pudo terminar: $texto" -ForegroundColor Red
        Write-Host "  Pod${e}s bajar el programa a mano desde $PAGINA" -ForegroundColor Yellow
        Write-Host '  o avisarnos por WhatsApp y te ayudamos.' -ForegroundColor Yellow
        Write-Host ''
        throw 'PALTA-FALLA'
    }

    Write-Host ''
    Write-Host '  ==========================================' -ForegroundColor Green
    Write-Host "         $NOMBRE - instalaci${o}n" -ForegroundColor Green
    Write-Host '  ==========================================' -ForegroundColor Green
    Write-Host ''

    # 1. Permisos de administrador: si no los tiene, se vuelve a abrir solo, ya elevado (como winutil).
    $yo = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $yo.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Paso "Windows va a pedir permiso para instalar. Toc${a} ""S${i}""."
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-Command', $COMANDO)
        } catch {
            Write-Host "  No se dieron los permisos. Volv${e} a pegar el comando y toc${a} ""S${i}""." -ForegroundColor Red
        }
        return
    }

    # GitHub exige TLS 1.2; Windows 10 viejos usan TLS 1.0 por defecto.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072

    # 2. Descarga a una carpeta nueva, solo nuestra.
    $tmp = Join-Path $env:TEMP ('paltapc-remoto-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $instalador = Join-Path $tmp 'PaltaPC-Remoto.exe'
    try {
        Paso 'Descargando el programa...'
        try {
            Invoke-WebRequest "$BASE/PaltaPC-Remoto.exe" -OutFile $instalador -UseBasicParsing
            $esperado = (Invoke-WebRequest "$BASE/PaltaPC-Remoto.exe.sha256" -UseBasicParsing).Content
        } catch { Falla "no se pudo descargar ($($_.Exception.Message))." }
        if ($esperado -is [byte[]]) { $esperado = [Text.Encoding]::ASCII.GetString($esperado) }
        $esperado = ($esperado.Trim() -split '\s+')[0].ToLower()

        Paso 'Verificando la descarga...'
        $real = (Get-FileHash $instalador -Algorithm SHA256).Hash.ToLower()
        if ($real -ne $esperado) { Falla "la descarga lleg${o} da${n}ada o fue modificada. No se instal${o} nada." }

        # 3. Instalar (o actualizar, si ya estaba).
        Paso 'Instalando (puede tardar un minuto)...'
        Start-Process $instalador -ArgumentList '--silent-install' -Wait

        $hasta = (Get-Date).AddSeconds(120)
        while (-not ((Test-Path $EXE) -and (Get-Service $NOMBRE -ErrorAction SilentlyContinue | Where-Object Status -eq 'Running'))) {
            if ((Get-Date) -gt $hasta) { Falla "el programa no termin${o} de instalarse." }
            Start-Sleep -Seconds 2
        }

        # 4. El ID del equipo (lo da el servicio; tarda unos segundos en arrancar).
        Paso 'Obteniendo el ID del equipo...'
        $id = ''
        $hasta = (Get-Date).AddSeconds(60)
        while (-not $id) {
            $id = ((& $EXE --get-id | Out-String) -replace '\s', '')
            if (-not $id) {
                if ((Get-Date) -gt $hasta) { Falla "no se pudo leer el ID. Abr${i} el programa y lo vas a ver ah${i}." }
                Start-Sleep -Seconds 2
            }
        }

        # 5. Acceso permanente, solo si el cliente quiere. La clave se genera en este equipo y no se guarda en ningun archivo.
        $clave = ''
        Write-Host ''
        Write-Host "  ${preg}Quer${e}s dejar acceso permanente?" -ForegroundColor White
        Write-Host "  Sirve para que Palta PC pueda conectarse sin que tengas que aceptar cada vez." -ForegroundColor Gray
        $resp = Read-Host "  Escrib${i} S para s${i}, o Enter para no"
        if ($resp -match '^\s*[sS]') {
            $letras = 'abcdefghjkmnpqrstuvwxyz23456789'   # sin 0/o, 1/l/i: facil de dictar
            $azar = New-Object byte[] 12
            [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($azar)
            $clave = -join ($azar | ForEach-Object { $letras[$_ % $letras.Length] })
            $r = (& $EXE --password $clave | Out-String).Trim()
            if ($r -notmatch 'Done') {
                Write-Host "  No se pudo poner la clave ($r). Se sigue sin acceso permanente." -ForegroundColor Yellow
                $clave = ''
            }
        }

        try { Set-Clipboard -Value $id } catch { }

        Write-Host ''
        Write-Host '  ==========================================' -ForegroundColor Green
        Write-Host '   Listo. Pasale estos datos a Palta PC:' -ForegroundColor Green
        Write-Host ''
        Write-Host "     ID:     $id" -ForegroundColor White
        if ($clave) { Write-Host "     Clave:  $clave" -ForegroundColor White }
        Write-Host ''
        Write-Host "   (el ID ya qued${o} copiado: pod${e}s pegarlo en WhatsApp)" -ForegroundColor Gray
        Write-Host '  ==========================================' -ForegroundColor Green
        Write-Host ''

        # Abrir el programa como usuario normal (no como administrador).
        try { Start-Process explorer.exe -ArgumentList "`"$EXE`"" } catch { }
    } catch {
        if ($_.Exception.Message -ne 'PALTA-FALLA') {
            Write-Host ''
            Write-Host "  Error inesperado: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Pod${e}s bajar el programa a mano desde $PAGINA o avisarnos por WhatsApp." -ForegroundColor Yellow
        }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
