param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [ValidateSet("Marek SZEWCZYK","Patrycja SZEWCZYK","Agata SZEWCZYK")]
    [string]$Subject = "Marek SZEWCZYK",

    [string]$Author = "Neuroatypowi",
    [string]$Lang = "pl-PL"
)

$ErrorActionPreference = "Stop"

$Root        = Split-Path -Parent $PSScriptRoot
$FiltersDir  = Join-Path $Root "filters"
$TemplatesDir= Join-Path $Root "templates"
$AssetsDir   = Join-Path $Root "assets"

$PdfaFilter  = Join-Path $FiltersDir "pdfa.lua"
$Template    = Join-Path $TemplatesDir "neuroatypowi.latex"
$LogoPath    = Join-Path $AssetsDir "Neuroatypowi.200px_TXT.png"

function Assert-FileExists {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Brak wymaganego pliku: $Path"
    }
}

Assert-FileExists $PdfaFilter
Assert-FileExists $Template
Assert-FileExists $LogoPath
Assert-FileExists $InputFile

function Test-ContainsEmoji {
    param([string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    foreach ($ch in $content.ToCharArray()) {
        $code = [int][char]$ch
        if (
            ($code -ge 0x1F300 -and $code -le 0x1FAFF) -or
            ($code -ge 0x2600  -and $code -le 0x27BF)  -or
            ($code -ge 0xFE00  -and $code -le 0xFE0F)
        ) {
            return $true
        }
    }
    return $false
}

$HasEmoji = Test-ContainsEmoji -Path $InputFile
Write-Host "Wykryto emoji: $HasEmoji"

function Test-FontInstalled {
    param([string]$FontName)
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Fonts"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) {
            $values = Get-ItemProperty -Path $path
            foreach ($prop in $values.PSObject.Properties) {
                $name  = $prop.Name
                $value = $prop.Value
                if ($name -match $FontName -or $value -match $FontName) {
                    return $true
                }
            }
        }
    }
    return $false
}

$RequiredFonts = @("Inter","OpenDyslexic","Noto Color Emoji")
foreach ($f in $RequiredFonts) {
    if (-not (Test-FontInstalled -FontName $f)) {
        Write-Warning "Font '$f' nie został znaleziony w systemie. Zainstaluj go ręcznie (zalecane)."
    } else {
        Write-Host "Font '$f' wykryty."
    }
}

function Get-PandocVariables {
    param(
        [string]$MainFont,
        [string]$SansFont,
        [string]$MonoFont,
        [bool]$IncludeEmoji
    )
    $vars = @(
        "--variable=mainfont=$MainFont",
        "--variable=sansfont=$SansFont",
        "--variable=monofont=$MonoFont",
        "--variable=fontsize=11pt",
        "--variable=geometry:margin=2.5cm",
        "--variable=logo-path=$LogoPath",
        "--variable=logo-width=3cm"
    )
    if ($IncludeEmoji) {
        $vars += "--variable=emoji-font=Noto Color Emoji"
    }
    return $vars
}

function Invoke-MdToPdfProfile {
    param(
        [string]$ProfileName,
        [string]$OutputFile,
        [string]$MainFont,
        [string]$SansFont,
        [string]$MonoFont
    )

    $vars = Get-PandocVariables -MainFont $MainFont -SansFont $SansFont -MonoFont $MonoFont -IncludeEmoji:$HasEmoji

    $args = @(
        $InputFile,
        "--from", "markdown",
        "--to", "pdf",
        "--pdf-engine=xelatex",
        "--template=$Template",
        "--lua-filter=$PdfaFilter",
        "--metadata=title=$(Split-Path $InputFile -Leaf)",
        "--metadata=author=$Author",
        "--metadata=lang=$Lang",
        "--metadata=subject=$Subject",
        "--metadata=pdfa=true",
        "--metadata=pdfa:2b",
        "--toc",
        "--toc-depth=2"
    ) + $vars + @(
        "--output=$OutputFile"
    )

    Write-Host "Generuję profil $ProfileName → $OutputFile"
    & pandoc @args
}

$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$DirName  = Split-Path -Parent $InputFile

$OutInter = Join-Path $DirName ($BaseName + "_Inter.pdf")
$OutOpenD = Join-Path $DirName ($BaseName + "_OpenDyslexic.pdf")

Invoke-MdToPdfProfile -ProfileName "Inter" -OutputFile $OutInter `
    -MainFont "Inter" -SansFont "Inter" -MonoFont "Inter"

Invoke-MdToPdfProfile -ProfileName "OpenDyslexic" -OutputFile $OutOpenD `
    -MainFont "OpenDyslexic" -SansFont "Inter" -MonoFont "Inter"

Write-Host "Wygenerowano:"
Write-Host " - $OutInter"
Write-Host " - $OutOpenD"

function Get-CertificateByThumbprint {
    param(
        [string]$Thumbprint
    )
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My","CurrentUser")
    $store.Open("ReadOnly")
    $cert = $store.Certificates | Where-Object { $_.Thumbprint -eq $Thumbprint }
    $store.Close()
    if (-not $cert) {
        throw "Nie znaleziono certyfikatu o Thumbprint: $Thumbprint w CurrentUser\My."
    }
    return $cert
}

function Sign-PdfWithSmime {
    param(
        [string]$PdfPath,
        [string]$CertThumbprint
    )
    $cert = Get-CertificateByThumbprint -Thumbprint $CertThumbprint
    Write-Warning "Hook do podpisu PDF jest przygotowany. Uzupełnij wywołanie narzędzia CLI w funkcji Sign-PdfWithSmime."
}
