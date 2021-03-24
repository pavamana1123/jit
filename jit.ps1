$global:fcount=0
$global:pcount=0

function getprog {
    Write-Output $([math]::Round($($global:pcount/$fcount*100),2))
}

function getActText {
    Write-Output "Scanning for changes: $(getprog)% complete"  
}

function isdir {
    param (
        $path
    )
    Write-Output $((Get-Item $path) -is [System.IO.DirectoryInfo])
}

function abspath {
    param (
        $path
    )
    $path=$($path -replace [regex]::escape("/"),"\")
    $a=$(Resolve-Path $path).Path
    if($(isdir $a) -eq $true -and $a -notmatch '\\$'){
        $a="$a\"
    }
    Write-Output $(convert-path $a)
}

function dirdiff {
    param (
        $s,
        $d
    )

    if ($null -eq $s -or $s -eq "" -or $null -eq $d -or $d -eq ""){
        Write-Output "Invalid arguments"
    }else{
        # resolve to abs path
        $s=$(abspath $s)
        $d=$(abspath $d)


        Get-ChildItem $s | ForEach-Object {
            $currPath=$_.FullName
            $testPath=$($currPath -replace [regex]::escape($s),$d)

            if($(test-path $testPath) -eq $true){
                if($(isdir $currPath) -eq $true){
                    # if is dir
                    dirdiff $currPath $testPath
                }else{
                    $global:pcount++
                    Write-Progress -Activity $(getActText) -Status $currPath -PercentComplete $($global:pcount/$fcount*100)

                    $currHash=$(Get-FileHash $currPath).Hash
                    $testHash=$(Get-FileHash $testPath).Hash

                    if($currHash -ne $testHash){
                        Write-Output $currPath
                    }
                }
            }else{
                $global:pcount+=$(Get-ChildItem -Recurse -File $currPath | measure-object).count
                Write-Progress -Activity $(getActText) -Status $currPath -PercentComplete $($global:pcount/$fcount*100)
                Write-Output $currPath
            }
        }
    }
}

function cpdif {
    param (
        $s,
        $d
    )

    $diffs = $(dirdiff $s $d)

    Write-Progress  -Activity "Scanning for changes" -Completed

    if($diffs.count -ne 0){
        $diffs | ForEach-Object {
            $src = $(abspath $_)
            $s=$(abspath $s)
            $d=$(abspath $d)
            $des = $($src -replace [regex]::escape($s),$d)
            Copy-Item $src $des -Verbose -Recurse
        }
    }else{
        Write-Output "No changes found!"
    }
}

$opt=$args[0]
$usage= "Usage: jit init | push | pull"

switch -wildcard ( $opt )
{
    "init" {        
        if($(test-path ./.jit.json) -eq $true){
            Write-Output "jit is already initialised here"
        }else{
            $remote = $(read-host "Enter remote path")
            if($(test-path $remote) -eq $false){
                Write-Output "$remote is not a valid path"
            }else {
                $cfg=@{remote=$(abspath $remote)}
                $cfg | ConvertTo-Json -depth 100 | Out-File ./.jit.json
                if($(test-path ./.jit.json) -eq $true){
                    Write-Output "jit is now initialized at $remote"
                }else{
                    Write-Output "Could not initialise jit!"
                }
            }
        }
     }
    "pu*" { 
        $save=$pwd
        $isjit=$true
        while ($(test-path ./.jit.json) -eq $false) {
            if($(split-path -parent $pwd) -eq ""){
                $isjit=$false
                break
            }else{
                Set-Location ..
            }
        }
        if($isjit -eq $false){
            Write-Output "this folder in not jit initialised"
        }else{
            $remote=$((Get-Content './.jit.json' | Out-String | ConvertFrom-Json).remote)
            switch ($opt) {
                "push" {
                    $fcount=(Get-ChildItem -Recurse -File ./ | measure-object).count
                    cpdif ./ $remote
                }
                "pull" {
                    $fcount=(Get-ChildItem -Recurse -File $remote | measure-object).count
                    cpdif $remote ./
                }
                default {
                    Write-Output $usage
                }
            }
        }
        Set-Location $save
     }

    default { 
        Write-Output $usage
    }
}
