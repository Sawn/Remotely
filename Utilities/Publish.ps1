<#
.SYNOPSIS
   Publishes the Remotely clients.
.DESCRIPTION
   Publishes the Remotely clients.
   To deploy the server, supply the following arguments: -rid win10-x64 -outdir path\to\dir -hostname https://mysite.mydomain.com
.COPYRIGHT
   Copyright 2019 Translucency Software.  All rights reserved.
.EXAMPLE
   Run it from the Utilities folder (located in the solution directory).
   Or run "powershell -f Publish.ps1 -rid win10-x64 -outdir path\to\dir -hostname https://mysite.mydomain.com
#>

$ErrorActionPreference = "Stop"
$Year = (Get-Date).Year.ToString()
$Month = (Get-Date).Month.ToString().PadLeft(2, "0")
$Day = (Get-Date).Day.ToString().PadLeft(2, "0")
$Hour = (Get-Date).Hour.ToString().PadLeft(2, "0")
$Minute = (Get-Date).Minute.ToString().PadLeft(2, "0")
$CurrentVersion = "$Year.$Month.$Day.$Hour$Minute"
$OutDir = ""
# RIDs are described here: https://docs.microsoft.com/en-us/dotnet/core/rid-catalog
$RID = ""
$Hostname = ""
$MSBuildPath = (Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\" -Recurse -Filter "MSBuild.exe" -File)[0].FullName
$Root = (Get-Item -Path $PSScriptRoot).Parent.FullName
$CertificatePath = ""
$CertificatePassword = ""
$SignAssemblies = $false

Set-Location -Path $Root


#region Functions

function Replace-LineInFile($FilePath, $MatchPattern, $ReplaceLineWith, $MaxCount = -1){
    [string[]]$Content = Get-Content -Path $FilePath
    $Count = 0
    for ($i = 0; $i -lt $Content.Length; $i++)
    {
        if ($Content[$i] -ne $null -and $Content[$i].Contains($MatchPattern)) {
            $Content[$i] = $ReplaceLineWith
            $Count++
        }
        if ($MaxCount -gt 0 -and $Count -ge $MaxCount) {
            break
        }
    }
    ($Content | Out-String).Trim() | Out-File -FilePath $FilePath -Force -Encoding utf8
}

#endregion

if ([string]::IsNullOrWhiteSpace($MSBuildPath) -or !(Test-Path -Path $MSBuildPath)) {
    Write-Host
    Write-Host "ERROR: Unable to find the path to MSBuild.exe." -ForegroundColor Red
    Write-Host
    pause
    return
}


for ($i = 0; $i -lt $args.Count; $i++)
{ 
    $arg = $args[$i].ToString().ToLower()
    if ($arg.Contains("outdir")){
        $OutDir = $args[$i+1]
    }
    elseif ($arg.Contains("rid")){
        $RID = $args[$i+1]
    }
    elseif ($arg.Contains("hostname")){
        $Hostname = $args[$i+1]
    }
    elseif ($arg.Contains("certificate")){
        $CertificatePath = $args[$i+1]
    }
     elseif ($arg.Contains("certpassword")){
        $CertificatePassword = $args[$i+1]
    }
}

if ($CertificatePath.Length -gt 0 -and 
    (Test-Path -Path $CertificatePath) -eq $true -and 
    $CertificatePassword.Length -gt 0) 
{
    $SignAssemblies = $true
}


# Add Current Version file to root content folder for client update checks.
Set-Content -Path "$Root\Server\CurrentVersion.txt" -Value $CurrentVersion.Trim() -Encoding UTF8 -Force

# Update hostname.
if ($Hostname.Length -gt 0) {
    Replace-LineInFile -FilePath "$Root\Desktop.Win\Services\Config.cs" -MatchPattern "public string Host " -ReplaceLineWith "public string Host { get; set; } = `"$($Hostname)`";" -MaxCount 1
    Replace-LineInFile -FilePath "$Root\Desktop.Linux\Services\Config.cs" -MatchPattern "public string Host " -ReplaceLineWith "public string Host { get; set; } = `"$($Hostname)`";" -MaxCount 1
}
else {
    Write-Host "`nWARNING: No hostname parameter was specified.  The server name will need to be entered manually in the desktop client.`n" -ForegroundColor DarkYellow
}

    
# Clear publish folders.
if ((Test-Path -Path "$Root\Agent\bin\Release\netcoreapp3.1\win10-x64\publish") -eq $true) {
	Get-ChildItem -Path "$Root\Agent\bin\Release\netcoreapp3.1\win10-x64\publish" | Remove-Item -Force -Recurse
}
if ((Test-Path -Path  "$Root\Agent\bin\Release\netcoreapp3.1\win10-x86\publish" ) -eq $true) {
	Get-ChildItem -Path  "$Root\Agent\bin\Release\netcoreapp3.1\win10-x86\publish" | Remove-Item -Force -Recurse
}
if ((Test-Path -Path "$Root\Agent\bin\Release\netcoreapp3.1\linux-x64\publish") -eq $true) {
	Get-ChildItem -Path "$Root\Agent\bin\Release\netcoreapp3.1\linux-x64\publish" | Remove-Item -Force -Recurse
}


# Publish Core clients.
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion --runtime win10-x64 --configuration Release --no-self-contained --output "$Root\Agent\bin\Release\netcoreapp3.1\win10-x64\publish" "$Root\Agent"
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion --runtime linux-x64 --configuration Release --no-self-contained --output "$Root\Agent\bin\Release\netcoreapp3.1\linux-x64\publish" "$Root\Agent"
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion --runtime win10-x86 --configuration Release --no-self-contained --output "$Root\Agent\bin\Release\netcoreapp3.1\win10-x86\publish" "$Root\Agent"

New-Item -Path "$Root\Agent\bin\Release\netcoreapp3.1\win10-x64\publish\ScreenCast\" -ItemType Directory -Force
New-Item -Path "$Root\Agent\bin\Release\netcoreapp3.1\win10-x86\publish\ScreenCast\" -ItemType Directory -Force
New-Item -Path "$Root\Agent\bin\Release\netcoreapp3.1\linux-x64\publish\ScreenCast\" -ItemType Directory -Force


# Publish Linux ScreenCaster
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion -p:PublishProfile=linux-x64 --configuration Release "$Root\ScreenCast.Linux\"

# Publish Linux GUI App
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion -p:PublishProfile=linux-x64 --configuration Release "$Root\Desktop.Linux\"


# Publish Windows ScreenCaster (32-bit)
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion -p:PublishProfile=win-x86 --configuration Release "$Root\ScreenCast.Win"

# Publish Windows ScreenCaster (64-bit)
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion -p:PublishProfile=win-x64 --configuration Release "$Root\ScreenCast.Win"

# Publish Windows GUI App (64-bit)
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion -p:PublishProfile=win-x64 --configuration Release "$Root\Desktop.Win"

if ($SignAssemblies) {
    &"$Root\Utilities\signtool.exe" sign /f "$CertificatePath" /p $CertificatePassword /t http://timestamp.digicert.com "$Root\Server\wwwroot\Downloads\Win-x64\Remotely_Desktop.exe"
}

# Publish Windows GUI App (32-bit)
dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion -p:PublishProfile=win-x86 "$Root\Desktop.Win"

if ($SignAssemblies) {
    &"$Root\Utilities\signtool.exe" sign /f "$CertificatePath" /p $CertificatePassword /t http://timestamp.digicert.com "$Root\Server\wwwroot\Downloads\Win-x86\Remotely_Desktop.exe"
}



# Compress Core clients.
$PublishDir =  "$Root\Agent\bin\Release\netcoreapp3.1\win10-x64\publish"
Compress-Archive -Path "$PublishDir\*" -DestinationPath "$PublishDir\Remotely-Win10-x64.zip" -CompressionLevel Optimal -Force
while ((Test-Path -Path "$PublishDir\Remotely-Win10-x64.zip") -eq $false){
    Start-Sleep -Seconds 1
}
Move-Item -Path "$PublishDir\Remotely-Win10-x64.zip" -Destination "$Root\Server\wwwroot\Downloads\Remotely-Win10-x64.zip" -Force

$PublishDir =  "$Root\Agent\bin\Release\netcoreapp3.1\win10-x86\publish"
Compress-Archive -Path "$PublishDir\*" -DestinationPath "$PublishDir\Remotely-Win10-x86.zip" -CompressionLevel Optimal -Force
while ((Test-Path -Path "$PublishDir\Remotely-Win10-x86.zip") -eq $false){
    Start-Sleep -Seconds 1
}
Move-Item -Path "$PublishDir\Remotely-Win10-x86.zip" -Destination "$Root\Server\wwwroot\Downloads\Remotely-Win10-x86.zip" -Force

$PublishDir =  "$Root\Agent\bin\Release\netcoreapp3.1\linux-x64\publish"
Compress-Archive -Path "$PublishDir\*" -DestinationPath "$PublishDir\Remotely-Linux.zip" -CompressionLevel Optimal -Force
while ((Test-Path -Path "$PublishDir\Remotely-Linux.zip") -eq $false){
    Start-Sleep -Seconds 1
}
Move-Item -Path "$PublishDir\Remotely-Linux.zip" -Destination "$Root\Server\wwwroot\Downloads\Remotely-Linux.zip" -Force



if ($RID.Length -gt 0 -and $OutDir.Length -gt 0) {
    if ((Test-Path -Path $OutDir) -eq $false){
        New-Item -Path $OutDir -ItemType Directory
    }
    dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion --runtime $RID --configuration Release --output $OutDir "$Root\Server\"
}
else {
    Write-Host "`r`nSkipping server deployment.  Params -outdir and -rid not specified." -ForegroundColor DarkYellow
}