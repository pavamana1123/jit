$usage= "Usage: jit init | push | pull"
$opt=$args[0]

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
                    robocopy $pwd $remote /e /xo
                }
                "pull" {
                    robocopy $remote $pwd /e /xo
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
