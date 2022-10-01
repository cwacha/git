param (
    [string]$rule = ""
)

$BASEDIR = $PSScriptRoot
#echo BASEDIR=$BASEDIR

function all {
    "# building: $app_pkgname"
    clean
    import
    #zip
    nupkg
    checksums
}

function _init {
    $global:app_pkgid = "git"
    $global:app_displayname = "Git for Windows Portable"
    $global:app_version = Get-ChildItem $BASEDIR\..\ext\*.exe | % { $_.Name -replace "PortableGit-", "" -replace "-64-.*", "" }
    # keep only first 3 parts of version to prevent messing up version string in case ov vendor version = 2.30.0.2
    $global:app_version = ($app_version -split "\." | select -first 3) -join "."
    $global:app_revision = git rev-list --count HEAD
    $global:app_build = git rev-parse --short HEAD

    $global:app_pkgname = "$app_pkgid-$app_version-$app_revision-$app_build"
}

function _template {
    param (
        [string] $inputfile
    )
    Get-Content $inputfile | % { $_ `
            -replace "%app_pkgid%", "$app_pkgid" `
            -replace "%app_displayname%", "$app_displayname" `
            -replace "%app_version%", "$app_version" `
            -replace "%app_revision%", "$app_revision" `
            -replace "%app_build%", "$app_build"
    }
}

function import {
    "# import ..."
    mkdir -fo BUILD/root *> $null

    & $BASEDIR\..\ext\PortableGit*.exe -o BUILD/root -y | Out-Null
    cp -r -fo ..\src\* BUILD/root
    # Prevent shimming of git files
    Get-ChildItem BUILD\root\mingw64 -Recurse -Include *.exe | Select-Object FullName | ForEach-Object { New-Item -ItemType File "$($_.FullName).ignore" | Out-Null }
    Get-ChildItem BUILD\root\usr -Recurse -Include *.exe | Select-Object FullName | ForEach-Object { New-Item -ItemType File "$($_.FullName).ignore" | Out-Null }
    # whitelist some useful executables from shimming
    rm BUILD\root\usr\bin\less.exe.ignore
    rm BUILD\root\usr\bin\nano.exe.ignore
    rm BUILD\root\usr\bin\vim.exe.ignore
}

function zip {
    "# packaging ZIP ..."
    mkdir -fo PKG/zip *> $null
    
    cd BUILD
    Compress-Archive -Path root\* -DestinationPath ..\PKG\$app_pkgname.zip
    cd ..
    "## created $BASEDIR\PKG\$app_pkgname.zip"
}

function nupkg {
    if (!(Get-Command "choco.exe" -ea SilentlyContinue)) {
        "## WARNING: cannot build chocolatey package, choco-client missing"
        return
    }
    "# packaging nupkg ..."
    mkdir -fo PKG *> $null

    cp -r -fo nupkg PKG
    mkdir PKG\nupkg\tools *> $null
    cp -r -fo BUILD\* PKG\nupkg\tools
    _template nupkg\package.nuspec | Out-File -Encoding "UTF8" PKG\nupkg\$app_pkgid.nuspec
    rm PKG\nupkg\package.nuspec
    cd PKG\nupkg
    choco pack -outputdirectory $BASEDIR\PKG
    cd $BASEDIR
}

function checksums {
    "# checksums ..."
    mkdir -fo PKG *> $null
    cd PKG
    Get-FileHash *.zip, *.nupkg, *.msi | Select-Object Hash, @{l = "File"; e = { split-path $_.Path -leaf } } | % { "$($_.Hash) $($_.File)" } | Out-File -Encoding "UTF8" $app_pkgname-checksums-sha256.txt
    Get-Content $app_pkgname-checksums-sha256.txt
    cd ..
}

function clean {
    "# clean ..."
    rm -r -fo -ea SilentlyContinue PKG
    rm -r -fo -ea SilentlyContinue BUILD
}

$funcs = Select-String -Path $MyInvocation.MyCommand.Path -Pattern "^function ([^_]\S+) " | % { $_.Matches.Groups[1].Value }
if (! $funcs.contains($rule)) {
    "no such rule: '$rule'"
    ""
    "RULES"
    $funcs | % { "    $_" }
    exit 1
}

Push-Location
cd "$BASEDIR"
_init

"##### Executing rule '$rule'"
& $rule $args
"##### done"

Pop-Location
