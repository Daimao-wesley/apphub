param(
    [ValidateSet('generic', 'substore')]
    [string]$Template = 'generic',

    [string]$RepoRoot = '.',

    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [string]$AppTitle,

    [ValidateSet('BuildWebsite', 'Database', 'Storage', 'Tools', 'Middleware', 'AI', 'Media', 'Email', 'DevOps', 'System')]
    [string]$AppType = 'Tools',

    [string]$AppTypeCN = 'Tools',

    [Parameter(Mandatory = $false)]
    [string]$Image,

    [int]$HostPortDefault = 3001,
    [int]$ContainerPort = 3001,

    [string]$Description = '',
    [string]$HomeUrl = '',
    [string]$HelpUrl = '',

    [string]$Version = 'latest',
    [string]$BackendPathDefault = '/change_this_to_random_path',

    [string[]]$ExtraComposeEnv = @(),

    [switch]$DownloadIcon,
    [string]$IconUrl = '',

    [switch]$GitAdd,
    [switch]$GitCommit,
    [string]$CommitMessage = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function To-SnakeLower([string]$value) {
    $clean = $value -replace '[^A-Za-z0-9]+', '_'
    $clean = $clean.Trim('_')
    return $clean.ToLowerInvariant()
}

function To-SnakeUpper([string]$value) {
    $clean = $value -replace '[^A-Za-z0-9]+', '_'
    $clean = $clean.Trim('_')
    return $clean.ToUpperInvariant()
}

function Write-JsonFile([string]$Path, $Object) {
    $json = $Object | ConvertTo-Json -Depth 30
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($AppTitle)) {
    $AppTitle = $AppName
}

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = "Docker app template for $AppTitle"
}

if ([string]::IsNullOrWhiteSpace($Image)) {
    if ($Template -eq 'substore') {
        $Image = 'xream/sub-store'
    }
    else {
        throw 'Parameter -Image is required when Template=generic.'
    }
}

$repo = Resolve-Path $RepoRoot
$apphubRoot = Join-Path $repo 'apphub'
if (-not (Test-Path $apphubRoot)) {
    throw "Cannot find apphub root: $apphubRoot"
}

$appDir = Join-Path $apphubRoot $AppName
$verDir = Join-Path $appDir $Version
New-Item -ItemType Directory -Force -Path $verDir | Out-Null

$unixTs = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$keyBaseLower = To-SnakeLower $AppName
$keyBaseUpper = To-SnakeUpper $AppName
$portKeyLower = "${keyBaseLower}_api_port"
$pathKeyLower = "${keyBaseLower}_backend_path"
$portKeyUpper = "${keyBaseUpper}_API_PORT"
$pathKeyUpper = "${keyBaseUpper}_BACKEND_PATH"

$fieldItems = @(
    @{
        attr = 'domain'
        name = 'Domain'
        type = 'textarea'
        default = ''
        suffix = 'Optional domain for reverse proxy'
        unit = ''
    },
    @{
        attr = 'allow_access'
        name = 'Allow external access'
        type = 'checkbox'
        default = $true
        suffix = 'Allow host IP + port access'
        unit = ''
    },
    @{
        attr = $portKeyLower
        name = 'Service port'
        type = 'number'
        default = $HostPortDefault
        suffix = 'Exposed host port'
        unit = ''
    }
)

$envItems = @(
    @{
        key = $portKeyLower
        type = 'port'
        default = $null
        desc = 'Service port'
    },
    @{
        key = 'app_path'
        type = 'path'
        default = $null
        desc = 'App data path'
    },
    @{
        key = 'host_ip'
        type = 'string'
        default = $null
        desc = 'Host IP'
    },
    @{
        key = 'cpus'
        type = 'number'
        default = $null
        desc = 'CPU limit'
    },
    @{
        key = 'memory_limit'
        type = 'number'
        default = $null
        desc = 'Memory limit'
    }
)

$volumesObj = @{
    data = @{
        type = 'path'
        desc = 'Data directory'
    }
}

$composeEnv = @()
$containerDataPath = '/data'
$composeServiceName = $keyBaseLower
$composeExtraLines = @()

if ($Template -eq 'substore') {
    $fieldItems += @{
        attr = $pathKeyLower
        name = 'Frontend backend path'
        type = 'string'
        default = $BackendPathDefault
        suffix = 'Use a random long path in production'
        unit = ''
    }

    $envItems = @(
        @{
            key = $portKeyLower
            type = 'port'
            default = $null
            desc = 'Sub-Store service port'
        },
        @{
            key = $pathKeyLower
            type = 'string'
            default = $null
            desc = 'Sub-Store frontend backend path'
        },
        @{
            key = 'app_path'
            type = 'path'
            default = $null
            desc = 'App data path'
        },
        @{
            key = 'host_ip'
            type = 'string'
            default = $null
            desc = 'Host IP'
        },
        @{
            key = 'cpus'
            type = 'number'
            default = $null
            desc = 'CPU limit'
        },
        @{
            key = 'memory_limit'
            type = 'number'
            default = $null
            desc = 'Memory limit'
        }
    )

    $containerDataPath = '/opt/app/data'
    $composeServiceName = 'substore'
    $composeEnv = @(
        'SUB_STORE_BACKEND_API_HOST=0.0.0.0',
        "SUB_STORE_BACKEND_API_PORT=$ContainerPort",
        'SUB_STORE_BACKEND_MERGE=true',
        "SUB_STORE_FRONTEND_BACKEND_PATH=`${$pathKeyUpper}",
        'SUB_STORE_BACKEND_SYNC_CRON=50 23 * * *'
    )
}

foreach ($line in $ExtraComposeEnv) {
    if (-not [string]::IsNullOrWhiteSpace($line)) {
        $composeEnv += $line
    }
}

$appJsonObj = [ordered]@{
    appid = -1
    appname = $AppName
    apptitle = $AppTitle
    apptype = $AppType
    appTypeCN = $AppTypeCN
    appversion = @(
        @{
            m_version = $Version
            s_version = @()
        }
    )
    appdesc = $Description
    appstatus = 1
    home = $HomeUrl
    help = $HelpUrl
    updateat = $unixTs
    depend = $null
    field = $fieldItems + @(
        @{
            attr = 'cpus'
            name = 'CPU limit'
            type = 'number'
            default = 0
            suffix = '0 means unlimited'
            unit = ''
        },
        @{
            attr = 'memory_limit'
            name = 'Memory limit'
            type = 'number'
            default = 0
            suffix = '0 means unlimited'
            unit = ''
        }
    )
    env = $envItems
    volumes = $volumesObj
}

$appJsonPath = Join-Path $appDir 'app.json'
Write-JsonFile -Path $appJsonPath -Object $appJsonObj

$composePath = Join-Path $verDir 'docker-compose.yml'

$envLines = @()
foreach ($item in $composeEnv) {
    $envLines += "      - $item"
}
if ($envLines.Count -eq 0) {
    $envLines += '      - TZ=Etc/UTC'
}

$portRef = '${' + $portKeyUpper + '}'

$compose = @"
services:
    ${composeServiceName}:
    image: $Image
    restart: always
    deploy:
      resources:
        limits:
          cpus: `${CPUS}
          memory: `${MEMORY_LIMIT}
    environment:
$($envLines -join "`n")
    ports:
            - `${HOST_IP}:${portRef}:$ContainerPort
    volumes:
      - `${APP_PATH}/data:$containerDataPath
    labels:
      createdBy: "bt_apps"
    networks:
      - baota_net

networks:
  baota_net:
    external: true
"@
Set-Content -Path $composePath -Value $compose -Encoding UTF8

$envPath = Join-Path $verDir '.env'
$envFileLines = @($portKeyUpper)
if ($Template -eq 'substore') {
    $envFileLines += $pathKeyUpper
}
$envFileLines += @('HOST_IP', 'CPUS', 'MEMORY_LIMIT', 'APP_PATH')
$envContent = ($envFileLines | ForEach-Object { "$_=" }) -join "`n"
Set-Content -Path $envPath -Value ($envContent + "`n") -Encoding UTF8

$iconPath = Join-Path $appDir 'icon.png'
if ($DownloadIcon -and -not [string]::IsNullOrWhiteSpace($IconUrl)) {
    try {
        Invoke-WebRequest -Uri $IconUrl -OutFile $iconPath
    }
    catch {
        Write-Warning "Icon download failed: $($_.Exception.Message)"
    }
}
elseif (-not (Test-Path $iconPath)) {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap 100, 100
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(24, 24, 24))
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(250, 250, 250))
    $font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $text = ($AppName.Substring(0, [Math]::Min(2, $AppName.Length))).ToUpperInvariant()
    $size = $g.MeasureString($text, $font)
    $x = (100 - $size.Width) / 2
    $y = (100 - $size.Height) / 2
    $g.DrawString($text, $font, $brush, $x, $y)
    $bmp.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $brush.Dispose()
    $font.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

Write-Host "Created app template files:"
Write-Host "- $appJsonPath"
Write-Host "- $composePath"
Write-Host "- $envPath"
Write-Host "- $iconPath"

if ($GitAdd -or $GitCommit) {
    Push-Location $repo
    try {
        git add "apphub/$AppName"
        if ($GitCommit) {
            if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
                $CommitMessage = "feat: add $AppName app template"
            }
            git commit -m $CommitMessage
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "Done. Next: review generated files and run git push."
