# Ahed for Windows 10/11 (64-bit). Windows PowerShell 5.1 and PowerShell 7.
# irm https://raw.githubusercontent.com/swarnim-sawane/ahed-releases/main/install.ps1 | iex
# AHED_UPDATE_FEED permits a local file feed for testing; it never changes the signing key.
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    function Initialize-AhedPresentation {
        # Redirected output and hosts such as ISE cannot safely rewrite a console
        # line. Keep those transcripts plain, and never change the user's encoding.
        $interactive = $false; $width = 80
        try {
            $interactive = $Host.Name -eq 'ConsoleHost' -and ![Console]::IsOutputRedirected -and $env:TERM -ne 'dumb'
            if ($interactive) { $width = [Console]::WindowWidth; if ($width -lt 2) { $interactive = $false } }
        } catch { $interactive = $false }
        $unicode = $interactive -and ($env:WT_SESSION -or [Console]::OutputEncoding.CodePage -eq 65001)
        $script:AhedPresentation = @{ Interactive=$interactive; Color=($interactive -and $null -eq $env:NO_COLOR);
            Width=$width; Tick='OK'; Arrow='->|'; Pending=0; LastPercent=-1; LastSeconds=-10; SetupStarted=$false }
        if ($unicode) { $script:AhedPresentation.Tick = [string][char]0x2713; $script:AhedPresentation.Arrow = ([string][char]0x2192) + '|' }
    }
    function Complete-AhedProgress {
        if ($script:AhedPresentation -and $script:AhedPresentation.Pending -gt 0) {
            Write-Host ''; $script:AhedPresentation.Pending = 0
        }
    }
    function Write-AhedMessage([string]$Text, [string]$Kind = 'Note') {
        if (!$script:AhedPresentation) { Initialize-AhedPresentation }
        Complete-AhedProgress
        $prefix = switch ($Kind) { 'Done' { $script:AhedPresentation.Tick }; 'Status' { '..' }; default { '  ' } }
        $line = '  ' + $prefix + '  ' + $Text
        if ($Kind -in @('Brand','Error')) { $line = '  ' + $Text }
        if ($script:AhedPresentation.Color -and $Kind -in @('Done','Brand','Error')) {
            $color = if ($Kind -eq 'Error') { 'Red' } else { 'Green' }
            Write-Host $line -ForegroundColor $color
        } else { Write-Host $line }
    }
    function Write-AhedFailure([string]$Message) {
        Write-Host ''
        Write-AhedMessage 'Installation paused' 'Error'
        Write-AhedMessage $Message
        if ($script:AhedPresentation.SetupStarted) {
            Write-AhedMessage 'Setup was started, but completion could not be confirmed. Your saved account and settings were not reset.'
        } else { Write-AhedMessage 'No installer was run. Your existing Ahed installation was kept.' }
        Write-AhedMessage 'Check the message above, then run the same install command to try again.'
        Write-Host ''
    }
    function Get-AhedPinnedKey {
        'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE/bKtaJoFOcd5k8b5T81NqWtzNarddG1d2heqLHWUq3iC5D9tBsBlwVaxoS0Ue/ODTZwQ1KdJ+TioKT0qicyShA=='
    }
    function Get-AhedInstallDirectory { Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\Ahed' }
    function Get-AhedVersion([string]$Text) {
        $parsed = $null
        if ($Text -notmatch '^[0-9]+\.[0-9]+(?:\.[0-9]+)?$' -or ![version]::TryParse($Text, [ref]$parsed)) { return $null }
        return [version]::new($parsed.Major, $parsed.Minor, [Math]::Max(0, $parsed.Build))
    }
    function Assert-AhedUri([uri]$Uri, [bool]$AllowFile) {
        if (!$Uri.IsAbsoluteUri -or $Uri.UserInfo -or $Uri.Fragment) { throw 'Invalid download address.' }
        if ($Uri.Scheme -eq 'https') { return }
        if ($AllowFile -and $Uri.IsFile -and !$Uri.IsUnc) { return }
        throw 'Downloads require HTTPS; only an explicit local test feed may use local files.'
    }
    function Read-AhedResource([uri]$Uri, [string]$Destination, [long]$Limit, [long]$Expected = 0, [bool]$AllowFile = $false) {
        Assert-AhedUri $Uri $AllowFile
        $response = $null; $inputStream = $null; $outputStream = $null
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $showProgress = $Destination -and !$Uri.IsFile; $lastProgress = [long]0
        try {
            if ($Uri.IsFile) { $inputStream = [IO.File]::OpenRead($Uri.LocalPath); $advertised = $inputStream.Length }
            else {
                $current = $Uri
                for ($redirect = 0; ; $redirect++) {
                    $request = [Net.HttpWebRequest]::Create($current)
                    # Bound an unresponsive connection/read, not the total transfer. Large
                    # signed installers can legitimately take longer than five minutes.
                    $request.AllowAutoRedirect = $false; $request.Timeout = 120000; $request.ReadWriteTimeout = 120000
                    $request.UserAgent = 'Ahed-Windows-Installer'; $request.UseDefaultCredentials = $false
                    $response = $request.GetResponse()
                    if ([int]$response.StatusCode -notin @(301,302,303,307,308)) { break }
                    if ($redirect -ge 4 -or !$response.Headers['Location']) { throw 'Too many download redirects.' }
                    $next = [uri]::new($current, $response.Headers['Location']); Assert-AhedUri $next $false
                    $response.Dispose(); $response = $null; $current = $next
                }
                $advertised = $response.ContentLength; $inputStream = $response.GetResponseStream()
            }
            if ($advertised -gt $Limit -or ($Expected -gt 0 -and $advertised -ge 0 -and $advertised -ne $Expected)) { throw 'Download size does not match the release.' }
            $outputStream = if ($Destination) { [IO.File]::Create($Destination) } else { [IO.MemoryStream]::new() }
            $buffer = New-Object byte[] 65536; $total = [long]0
            $progressLength = if ($Expected -gt 0) { $Expected } elseif ($advertised -gt 0) { $advertised } else { 0 }
            if ($showProgress) {
                if (!$script:AhedPresentation) { Initialize-AhedPresentation }
                $script:AhedPresentation.LastPercent = -1; $script:AhedPresentation.LastSeconds = -10
                Write-AhedDownloadProgress $total $progressLength $clock.Elapsed.TotalSeconds; $lastProgress = $clock.ElapsedMilliseconds
            }
            while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $total += $read
                if ($total -gt $Limit -or ($Expected -gt 0 -and $total -gt $Expected)) { throw 'Download exceeded its size limit.' }
                $outputStream.Write($buffer, 0, $read)
                if ($showProgress -and $clock.ElapsedMilliseconds - $lastProgress -ge 1000) {
                    Write-AhedDownloadProgress $total $progressLength $clock.Elapsed.TotalSeconds; $lastProgress = $clock.ElapsedMilliseconds
                }
            }
            if ($total -eq 0 -or ($Expected -gt 0 -and $total -ne $Expected)) { throw 'Download was empty or incomplete.' }
            if ($showProgress) { Write-AhedDownloadProgress $total $progressLength $clock.Elapsed.TotalSeconds $true }
            if (!$Destination) { return ,$outputStream.ToArray() }
        }
        catch {
            $cause = $_.Exception.GetBaseException()
            if ($cause -is [Net.WebException] -and $cause.Status -eq [Net.WebExceptionStatus]::Timeout) {
                throw 'The download made no progress for two minutes. Run the same install command to try again. No installer was run.'
            }
            throw
        }
        finally {
            if ($outputStream) { $outputStream.Dispose() }; if ($inputStream) { $inputStream.Dispose() }; if ($response) { $response.Dispose() }
            if ($showProgress) { Complete-AhedProgress }
        }
    }
    function Write-AhedDownloadProgress([long]$Bytes, [long]$Expected, [double]$Seconds = 0, [bool]$Complete = $false) {
        if (!$script:AhedPresentation) { Initialize-AhedPresentation }
        $ui = $script:AhedPresentation
        $percent = if ($Expected -gt 0) { [Math]::Min(100, [Math]::Floor(100.0 * $Bytes / $Expected)) } else { -1 }
        # An unknown transfer length has no honest percentage or ETA. Average
        # throughput is feedback only; the transport still owns stall timeouts.
        $text = if ($Expected -gt 0) { '{0,3}%  {1:N1} / {2:N1} MB' -f $percent, ($Bytes / 1000000.0), ($Expected / 1000000.0) }
            else { '{0:N1} MB' -f ($Bytes / 1000000.0) }
        $speed = if ($Seconds -gt 0) { $Bytes / $Seconds } else { 0 }
        if ($speed -gt 0) {
            $text += '  {0:N1} MB/s' -f ($speed / 1000000.0)
            if ($Expected -gt $Bytes) {
                $remaining = [Math]::Ceiling(($Expected - $Bytes) / $speed)
                $text += '  ~{0}m {1:00}s left' -f [Math]::Floor($remaining / 60), ($remaining % 60)
            }
        } elseif ($Bytes -eq 0) { $text += '  waiting for data' }
        if ($ui.Interactive) {
            # Reserve the last column to avoid a console wrap leaving old progress
            # behind. Narrow windows keep the numbers and omit the optional bar.
            try { if ([Console]::WindowWidth -gt 1) { $ui.Width = [Console]::WindowWidth } } catch { }
            $bar = ''
            if ($percent -ge 0 -and $ui.Width -ge $text.Length + 28) {
                $filled = [int][Math]::Floor($percent / 5)
                $bar = '[' + ('=' * $filled) + (' ' * (20 - $filled)) + '] '
            }
            $line = '     ' + $bar + $text
            $limit = [Math]::Max(1, $ui.Width - 1)
            if ($line.Length -gt $limit) { $line = $line.Substring(0, $limit) }
            Write-Host (("`r" + $line.PadRight([Math]::Min($limit, [Math]::Max($line.Length, $ui.Pending))))) -NoNewline
            $ui.Pending = $line.Length
        } elseif ($Complete -or $ui.LastSeconds -lt 0 -or ($percent -ge 0 -and [Math]::Floor($percent / 10) -gt [Math]::Floor($ui.LastPercent / 10)) -or $Seconds - $ui.LastSeconds -ge 10) {
            Write-AhedMessage ('Downloading: ' + $text)
            $ui.LastPercent = $percent; $ui.LastSeconds = $Seconds
        }
    }
    function Get-AhedLatestRelease([string]$Xml, [bool]$AllowFile = $false, [bool]$CustomFeed = $false) {
        $Xml = $Xml.TrimStart([char]0xFEFF) # Windows PowerShell writes a UTF-8 BOM in local test feeds.
        $settings = [Xml.XmlReaderSettings]::new(); $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null; $settings.MaxCharactersInDocument = 1048576
        $reader = [Xml.XmlReader]::Create([IO.StringReader]::new($Xml), $settings)
        try { $feed = [Xml.XmlDocument]::new(); $feed.XmlResolver = $null; $feed.Load($reader) } finally { $reader.Dispose() }
        $ns = [Xml.XmlNamespaceManager]::new($feed.NameTable)
        $ns.AddNamespace('sparkle', 'http://www.andymatuschak.org/xml-namespaces/sparkle'); $latest = $null
        foreach ($item in $feed.SelectNodes('/rss/channel/item', $ns)) {
            try {
                $versionNode = $item.SelectSingleNode('sparkle:version', $ns); $display = $item.SelectSingleNode('sparkle:shortVersionString', $ns)
                if (!$versionNode -or !$display -or !$display.InnerText.Trim()) { continue }
                $version = Get-AhedVersion $versionNode.InnerText.Trim(); $enclosures = $item.SelectNodes('enclosure[@sparkle:os="windows"]', $ns)
                if (!$version -or $enclosures.Count -ne 1) { continue }
                $enclosure = $enclosures[0]; $uri = $null; $length = [long]0
                if (![uri]::TryCreate($enclosure.GetAttribute('url'), [UriKind]::Absolute, [ref]$uri)) { continue }
                Assert-AhedUri $uri $AllowFile
                if (!$CustomFeed -and ($uri.Host -ne 'github.com' -or !$uri.AbsolutePath.StartsWith('/swarnim-sawane/ahed-releases/releases/download/', [StringComparison]::Ordinal))) { continue }
                if ([IO.Path]::GetFileName($uri.LocalPath) -cne ('AhedSetup-' + $version.ToString(3) + '.exe')) { continue }
                if (![long]::TryParse($enclosure.GetAttribute('length'), [ref]$length) -or $length -le 0 -or $length -gt 536870912) { continue }
                $signature = [Convert]::FromBase64String($enclosure.GetAttribute('ahedSignature', 'http://www.andymatuschak.org/xml-namespaces/sparkle'))
                if ($signature.Length -ne 64) { continue }
                if (!$latest -or $version -gt $latest.Version) { $latest = [pscustomobject]@{ Version=$version; Uri=$uri; Length=$length; Signature=$signature } }
            } catch { continue }
        }
        return $latest
    }
    function Get-AhedFileVersion([string]$Path) {
        $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
        if (!$info.FileVersion) { throw 'The executable has no readable version; it will not be installed.' }
        return [version]::new($info.FileMajorPart, $info.FileMinorPart, $info.FileBuildPart)
    }
    function Get-AhedRegisteredVersion {
        $saved = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Ahed' -ErrorAction SilentlyContinue
        if ($saved -and $saved.DisplayVersion) {
            $version = Get-AhedVersion $saved.DisplayVersion
            if (!$version) { throw 'The existing installation version could not be read. Repair it with the same or a newer installer.' }
            return $version
        }
        return $null
    }
    function Get-AhedInstalledVersion([string]$Exe) {
        $version = Get-AhedRegisteredVersion
        if (Test-Path -LiteralPath $Exe) { $fileVersion = Get-AhedFileVersion $Exe; if (!$version -or $fileVersion -gt $version) { $version = $fileVersion } }
        return $version
    }
    function Test-AhedInstaller([IO.Stream]$Stream, [byte[]]$Signature, [string]$Path, [version]$Version) {
        if ($Signature.Length -ne 64) { throw 'The release signature is invalid.' }
        $spki = [Convert]::FromBase64String((Get-AhedPinnedKey))
        $blob = [byte[]](0x45,0x43,0x53,0x31,0x20,0,0,0) + $spki[($spki.Length-64)..($spki.Length-1)]
        $cng = [Security.Cryptography.CngKey]::Import($blob, [Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
        $ecdsa = [Security.Cryptography.ECDsaCng]::new($cng); $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $Stream.Position = 0; $hash = $sha.ComputeHash($Stream)
            if (!$ecdsa.VerifyHash($hash, $Signature)) { throw 'Signature check failed. The installer will not be run.' }
            if ((Get-AhedFileVersion $Path) -ne $Version) { throw 'The signed installer version does not match the feed. Nothing was installed.' }
        } finally { $sha.Dispose(); $ecdsa.Dispose(); $cng.Dispose() }
    }
    function Invoke-AhedSetup([string]$Path) {
        $process = Start-Process -FilePath $Path -ArgumentList '/S /relaunch' -WindowStyle Hidden -PassThru
        $script:AhedPresentation.SetupStarted = $true
        # Start-Process -Wait also waits for the relaunched app. Wait for Setup alone.
        $process.WaitForExit(); $process.Refresh()
        if ($process.ExitCode -ne 0) { throw ('Ahed Setup stopped with code ' + $process.ExitCode + '. Your saved settings and sign-in were kept.') }
    }
    function Open-AhedInstalledApp([string]$Path) { Start-Process -FilePath $Path -WorkingDirectory (Split-Path $Path -Parent) -WindowStyle Hidden }
    function Invoke-AhedBootstrap {
        Initialize-AhedPresentation
        Write-Host ''
        Write-AhedMessage ($script:AhedPresentation.Arrow + ' ahed.') 'Brand'
        Write-Host '  A little closer to your next idea.'
        Write-Host ''
        if ([Environment]::OSVersion.Platform -ne 'Win32NT' -or ![Environment]::Is64BitOperatingSystem) { throw 'Ahed needs 64-bit Windows 10 or 11.' }
        $os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        if ($os.CurrentMajorVersionNumber -lt 10) { throw 'Ahed needs Windows 10 or 11.' }
        $feedText = $env:AHED_UPDATE_FEED; $custom = ![string]::IsNullOrWhiteSpace($feedText)
        if (!$custom) { $feedText = 'https://github.com/swarnim-sawane/ahed-releases/releases/download/windows-feed/appcast-windows.xml' }
        $feedUri = [uri]$feedText; Assert-AhedUri $feedUri $custom; $allowFile = $custom -and $feedUri.IsFile
        Write-AhedMessage 'Finding the latest Ahed for Windows...' 'Status'
        try { $xml = [Text.Encoding]::UTF8.GetString((Read-AhedResource $feedUri '' 1048576 0 $allowFile)) }
        catch { throw 'The Windows release feed could not be read. It may not be published yet. No installation was changed.' }
        $release = Get-AhedLatestRelease $xml $allowFile $custom
        if (!$release) { throw 'The feed has no valid signed Windows release. No installer was run.' }
        $directory = Get-AhedInstallDirectory; $exe = Join-Path $directory 'Ahed.Windows.exe'; $installed = Get-AhedInstalledVersion $exe
        if ($installed -and $installed -ge $release.Version) {
            if (!(Test-Path -LiteralPath $exe)) { throw 'Ahed is registered at this or a newer version, but its executable is missing. Repair it with the same or a newer installer.' }
            Write-AhedMessage ('Ahed ' + $installed + ' is already installed. No downgrade or reinstall needed.') 'Done'
            Write-AhedMessage 'Opening Ahed...' 'Status'; Open-AhedInstalledApp $exe
            Write-AhedMessage 'Ahed opened.' 'Done'; Write-Host ''; return
        }
        $action = if ($installed) { 'Updating Ahed from ' + $installed + ' to ' } else { 'Installing Ahed ' }
        Write-AhedMessage ($action + $release.Version) 'Status'
        Write-AhedMessage 'Installs for your Windows user. No administrator password needed.'
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()); $temp = Join-Path $tempRoot ('AhedInstall-' + [Guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($temp) | Out-Null
        try {
            $setup = Join-Path $temp ('AhedSetup-' + $release.Version.ToString(3) + '.exe')
            Write-AhedMessage 'Downloading Ahed...' 'Status'; Read-AhedResource $release.Uri $setup 536870912 $release.Length $allowFile
            Write-AhedMessage 'Download complete.' 'Done'
            $locked = [IO.File]::Open($setup, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            try {
                Write-AhedMessage 'Verifying download signature and version...' 'Status'
                Test-AhedInstaller $locked $release.Signature $setup $release.Version
                Write-AhedMessage 'Download verified.' 'Done'
                $nowInstalled = Get-AhedInstalledVersion $exe
                if ($nowInstalled -and $nowInstalled -ge $release.Version) { Write-AhedMessage 'Another installer already updated Ahed.' 'Done'; return }
                Write-AhedMessage 'Installing and opening Ahed. This can take a moment...' 'Status'
                Invoke-AhedSetup $setup
            } finally { $locked.Dispose() }
            if (!(Test-Path -LiteralPath $exe) -or (Get-AhedFileVersion $exe) -ne $release.Version) { throw 'Setup completed, but the installed version could not be confirmed.' }
            Write-AhedMessage ('Ahed ' + $release.Version + ' installed.') 'Done'
            Write-AhedMessage 'Look for Ahed in your system tray.'
            Write-AhedMessage 'Your settings, sign-in and device identity are kept.'
            Write-Host ''
            Write-AhedMessage 'A little more space to think.'
            Write-Host ''
        }
        finally {
            $absolute = [IO.Path]::GetFullPath($temp)
            if ($absolute.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($absolute).StartsWith('AhedInstall-')) { Remove-Item -LiteralPath $absolute -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    function Invoke-AhedInstallFlow {
        try { Invoke-AhedBootstrap }
        catch {
            Write-AhedFailure $_.Exception.Message
            # Preserve a terminating error for callers and scripts. Never exit the
            # user's interactive shell or turn a failed installation into success.
            throw
        }
    }
    Invoke-AhedInstallFlow
}
