param (
    [string]$rule = ""
)

$BASEDIR=$PSScriptRoot
#echo BASEDIR=$BASEDIR

function all {
    clean
    import
    pkg
}

function _init {
    $global:app_pkgid = "git"
    $global:app_displayname = "Git for Windows Portable"
    $global:app_version = Get-ChildItem $BASEDIR\..\ext\*.exe | %{$_.Name -replace "PortableGit-", "" -replace "-32-.*", "" }
    $global:app_revision = (git log --pretty=oneline).count
    $global:app_build = git rev-parse --short HEAD

    $global:app_pkgname = "$app_pkgid-$app_version-$app_revision-$app_build"
}

function _template {
    param (
        [string] $inputfile,
        [string] $outputfile
    )
    Get-Content $inputfile | %{ $_ `
        -replace "%app_pkgid%", "$app_pkgid" `
        -replace "%app_version%", "$app_version" `
        -replace "%app_displayname%", "$app_displayname" `
        -replace "%app_revision%", "$app_revision" `
        -replace "%app_build%", "$app_build"
    }
}


function import {
    "# import ..."
    mkdir BUILD/root -ea SilentlyContinue *> $null

    & $BASEDIR\..\ext\PortableGit*.exe -o BUILD/root -y | Out-Null
}

function pkg {
    "# packaging ..."
    mkdir PKG *> $null
    
    cd BUILD
    Compress-Archive -Path root\* -DestinationPath ..\PKG\$app_pkgname.zip
    cd ..
    "## created $BASEDIR\PKG\$app_pkgname.zip"
}

function clean {
    "# clean ..."
    rm -r -fo -ea SilentlyContinue PKG
    rm -r -fo -ea SilentlyContinue BUILD
}

$funcs = Select-String -Path $MyInvocation.MyCommand.Path -Pattern "^function ([^_]\S+) " | %{$_.Matches.Groups[1].Value}
if(! $funcs.contains($rule)) {
    "no such rule: '$rule'"
    ""
    "RULES"
    $funcs | %{"    $_"}
    exit 1
}

cd "$BASEDIR"
_init

"##### Executing rule '$rule'"
& $rule $args
"##### done"
