function Get-TS { return "{0:HH:mm:ss}" -f [DateTime]::Now }
Write-Output "$(Get-TS): Starting media refresh"
$OS_ISO_PATH = 'C:\Users\danti\OneDrive\Things\ISOs\SW_DVD9_Win_Pro_11_21H2_64BIT_English_Pro_Ent_EDU_N_MLF_-3_X22-89962.ISO'
$APP_DRV = 'C:'
$APP_ROOT = 'mediarefresh'
$APP_PATH = ("{0}\{1}" -f $APP_DRV, $APP_ROOT)
Write-Output "$(Get-TS): Creating directories"
#Create directory structure
$null = New-Item -Path $APP_PATH -ItemType Directory
$null = New-Item -Path $APP_PATH -ItemType Directory -Name packages
$null = New-Item -Path ("{0}\packages" -f $APP_PATH) -ItemType Directory -Name lcu
$null = New-Item -Path ("{0}\packages" -f $APP_PATH) -ItemType Directory -Name setup_du
$null = New-Item -Path ("{0}\packages" -f $APP_PATH) -ItemType Directory -Name dotnet_du
$null = New-Item -Path $APP_PATH -ItemType Directory -Name oldmedia
$null = New-Item -Path $APP_PATH -ItemType Directory -Name newmedia
$null = New-Item -Path $APP_PATH -ItemType Directory -Name temp
$null = New-Item -Path ("{0}\temp" -f $APP_PATH) -ItemType Directory -Name mainOSmount
$null = New-Item -Path ("{0}\temp" -f $APP_PATH) -ItemType Directory -Name winREmount
$null = New-Item -Path ("{0}\temp" -f $APP_PATH) -ItemType Directory -Name winPEmount
Write-Output "$(Get-TS): Copying updates"
$null = Copy-Item -Path C:\packages\* -Destination ("{0}\packages" -f $APP_PATH) -Recurse -Force
# Declare variables
$LCU_PATH = Get-ChildItem -Path "$APP_PATH\packages\lcu" | Select-Object -ExpandProperty FullName
$SETUP_DU_PATH = Get-ChildItem -Path "$APP_PATH\packages\setup_du" | Select-Object -ExpandProperty FullName
$DOTNET_CU_PATH = Get-ChildItem -Path "$APP_PATH\packages\dotnet_du" | Select-Object -ExpandProperty FullName
$MEDIA_OLD_PATH = "$APP_PATH\oldmedia"
$MEDIA_NEW_PATH = "$APP_PATH\newmedia"
$WORKING_PATH = "$APP_PATH\temp"
$MAIN_OS_MOUNT = "$APP_PATH\temp\mainOSmount"

# mount the OS ISO
Write-Output "$(Get-TS): mounting OS ISO"
$OS_ISO_DRIVE_LETTER = (mount-DiskImage -ImagePath $OS_ISO_PATH -ErrorAction stop | Get-Volume).DriveLetter
$OS_PATH = $OS_ISO_DRIVE_LETTER + ":\"
Write-Output "$(Get-TS): Copying original media to new media path"
$null = Copy-Item -Path ("{0}\*" -f $OS_PATH) -Destination $MEDIA_OLD_PATH -Force -Recurse -ErrorAction stop
$null = Copy-Item -Path ("{0}\*" -f $MEDIA_OLD_PATH) -Destination $MEDIA_NEW_PATH -Force -Recurse -ErrorAction stop
$null = Get-ChildItem -Path $MEDIA_NEW_PATH -Recurse | Where-Object { -not $_.PSIsContainer -and $_.IsReadOnly } | ForEach-Object { $_.IsReadOnly = $false }
#Export Professional image from wim
Write-Output "$(Get-TS): Exporting Windows 11 Pro image from install.wim to $MEDIA_NEW_PATH\sources\install.wim"
$null = Export-WindowsImage -SourceImagePath ("{0}\sources\install.wim" -f $MEDIA_OLD_PATH) -SourceIndex:5 -DestinationImagePath ("{0}\sources\install.wim" -f $MEDIA_NEW_PATH)
# mount the main operating system, used throughout the script
Write-Output "$(Get-TS): mounting main OS"
$null = Mount-WindowsImage -ImagePath ("{0}\sources\install.wim" -f $MEDIA_NEW_PATH) -Index 1 -Path $MAIN_OS_MOUNT
#
# update Main OS
# Add latest cumulative update
Write-Output "$(Get-TS): Adding package $LCU_PATH"
$null = Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $LCU_PATH -ErrorAction stop
# Perform image cleanup
Write-Output "$(Get-TS): Performing image cleanup on main OS"
#$null = DISM /image:$MAIN_OS_MOUNT /cleanup-image /StartComponentCleanup
$null = Repair-WindowsImage -Path $MAIN_OS_MOUNT -StartComponentCleanup
Write-Output "$(Get-TS): Adding NetFX3~~~~"
$null = Add-WindowsCapability -Name "NetFX3~~~~" -Path $MAIN_OS_MOUNT -Source ("{0}\sources\SXS" -f $MEDIA_NEW_PATH) -ErrorAction stop | Out-Null
# Add .NET Cumulative Update
Write-Output "$(Get-TS): Adding package $DOTNET_CU_PATH"
$null = Add-WindowsPackage -Path $MAIN_OS_MOUNT -PackagePath $DOTNET_CU_PATH -ErrorAction stop | Out-Null
#
# update remaining files on media
#
# Add Setup DU by copy the files from the package into the newMedia
Write-Output "$(Get-TS): Adding package $SETUP_DU_PATH"
cmd.exe /c $env:SystemRoot\System32\expand.exe $SETUP_DU_PATH -F:* $MEDIA_NEW_PATH"\sources" | Out-Null
$null = Dismount-WindowsImage -Path $MAIN_OS_MOUNT -Save -ErrorAction stop
# Remove our working folder
Remove-Item -Path $WORKING_PATH -Recurse -Force -ErrorAction stop | Out-Null
# Dismount ISO images
Write-Output "$(Get-TS): Dismounting ISO images"
Dismount-DiskImage -ImagePath $$OS_ISO_PATH -ErrorAction stop | Out-Null
Write-Output "$(Get-TS): Media refresh completed!"


