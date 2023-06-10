$ScriptName = 'N64 Save Converter'

Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'
[Windows.Forms.Application]::EnableVisualStyles()
[Windows.Forms.Application]::VisualStyleState = [Windows.Forms.VisualStyles.VisualStyleState]::ClientAndNonClientAreasEnabled

$global:DisableHighDPIMode = $False
$global:Interface = $global:Last = @{}

Add-Type -Namespace Console -Name Window -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null

function GetScriptPath() {
    
    if ($CommandType -eq "ExternalScript") { # This is the command that should have been stored
        $SplitDef  = $Definition.Split('\') # Split the path on every "\" and grab the last one
        $InputFile = $SplitDef[$SplitDef.Count-1]
        $global:ExternalScript = $True
        $Path = $Definition.Replace(($InputFile), '')
        $Path = $Path.substring(0, $Path.length-1)
        return $Path # If it was, the definition will hold the full path to the script
    }

    $FullPath  = ([Environment]::GetCommandLineArgs()[0]).ToString()
    $SplitDef  = $FullPath.Split('\')
    $InputFile = $SplitDef[$SplitDef.Count-1].Substring(0, $SplitDef[$SplitDef.Count-1].Length - 4) + '.exe'
    $global:ExternalScript = $False
    if ($ScriptPath) { $ScriptPath = $FullPath.Replace(($InputFile), '') } else { $ScriptPath = "." }
    $Paths.FullBase = $FullPath.Replace(($InputFile), '')
    $Paths.FullBase = $Paths.Fullbase.substring(0, $Paths.Fullbase.length-1)
    return $ScriptPath

}

$global:Paths = @{}
$Paths.Base  = GetScriptPath

function SetFonts() {

    $global:Fonts = @{}
    $Fonts.Medium         = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $Fonts.Small          = New-Object System.Drawing.Font("Segoe UI", 8,  [System.Drawing.FontStyle]::Regular)
    $Fonts.SmallBold      = New-Object System.Drawing.Font("Segoe UI", 8,  [System.Drawing.FontStyle]::Bold)
    $Fonts.SmallUnderline = New-Object System.Drawing.Font("Segoe UI", 8,  [System.Drawing.FontStyle]::Underline)
    $Fonts.TextFile       = New-Object System.Drawing.Font("Consolas", 8,  [System.Drawing.FontStyle]::Regular)
    $Fonts.Editor         = New-Object System.Drawing.Font("Consolas", 16, [System.Drawing.FontStyle]::Regular)

}

$Source = @"
using System;
using System.Runtime.InteropServices;
public class DPI {
  [DllImport("user32.dll")]
  public static extern bool SetProcessDPIAware();
  public static void SetProcessAware() { SetProcessDPIAware(); }
}
"@

$RefAssem = "System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
Add-Type -TypeDefinition $Source -ReferencedAssemblies $RefAssem -Language 'CSharp' | Out-Null

function DPISize($Value, [switch]$Round=$false, $Add=0, $AddX=0, $AddY=0) {
    
    if ($DisableHighDPIMode) { return $Value }
    $ValueType = $Value.GetType().ToString()
    $RMode     = [System.MidpointRounding]::AwayFromZero

    if ($ValueType -eq "System.String") {
        if (($ValueType -like "*.*") -and ($Value -as [decimal] -is [decimal])) {
            $Value = [Convert]::ToDecimal($Value)
            $ValueType = "System.Decimal"
        }
        elseif ($Value -as [int] -is [int]) {
            $Value = [Convert]::ToInt32($Value)
            $ValueType = "System.Int32"
        }
    }
    switch ($ValueType) {
        'System.Int16' {
            if (!$Round)   { $Value = [int16][Math]::Truncate($Value * $DPIMultiplier) } 
            else           { $Value = [int16][Math]::Round(($Value * $DPIMultiplier), $RMode) }
            return         ( $Value + $Add + $AddX + $AddY )
        }
        'System.Int32' {
            if (!$Round)   { $Value = [int32][Math]::Truncate($Value * $DPIMultiplier) } 
            else           { $Value = [int32][Math]::Round(($Value * $DPIMultiplier), $RMode) }
            return         ( $Value + $Add + $AddX + $AddY )
        }
        'System.Int64' {
            if (!$Round)   { $Value = [int64][Math]::Truncate($Value * $DPIMultiplier) }
            else           { $Value = [int64][Math]::Round(($Value * $DPIMultiplier), $RMode) }
            return         ( $Value + $Add + $AddX + $AddY )
        }
        'System.Single' {
            if (!$Round)   { $Value = [single][Math]::Truncate($Value * $DPIMultiplier) }
            else           { $Value = [single][Math]::Round(($Value * $DPIMultiplier), $RMode) }
            return         ( $Value + $Add + $AddX + $AddY )
        }
        'System.Double' {
            if (!$Round)   { $Value = [double][Math]::Truncate($Value * $DPIMultiplier) }
            else           { $Value = [double][Math]::Round(($Value * $DPIMultiplier), $RMode) }
            return         ( $Value + $Add + $AddX + $AddY )
        }
        'System.Decimal' {
            if (!$Round)   { $Value = [decimal]($Value * $DPIMultiplier) }
            else           { $Value = [decimal][Math]::Round(($Value * $DPIMultiplier), $RMode) }
            return         ( $Value + $Add + $AddX + $AddY )
        }
        'System.Drawing.Size' {
            if (!$Round)   { $Value = New-Object Drawing.Size([int][Math]::Truncate($Value.Width * $DPIMultiplier), [int32][Math]::Truncate($Value.Height * $DPIMultiplier)) }
            else           { $Value = New-Object Drawing.Size([int][Math]::Round(($Value.Width * $DPIMultiplier), $RMode), [int32][Math]::Round(($Value.Height * $DPIMultiplier), $RMode)) }
            return         ( New-Object Drawing.Size(($Value.Width + $Add + $AddX), ($Value.Height + $Add + $AddY)) )
        }
        'System.Drawing.Point' {
            if (!$Round)   { $Value = New-Object Drawing.Point([int][Math]::Truncate($Value.X * $DPIMultiplier), [int32][Math]::Truncate($Value.Y * $DPIMultiplier)) }
            else           { $Value = New-Object Drawing.Point([int][Math]::Round(($Value.X * $DPIMultiplier), $RMode), [int32][Math]::Round(($Value.Y * $DPIMultiplier), $RMode)) }
            return         ( New-Object Drawing.Point(($Value.X + $Add + $AddX), ($Value.Y + $Add + $AddY)) )
        }
    }

}

function InitializeHiDPIMode() {

    if (!$DisableHighDPIMode) { [DPI]::SetProcessAware() }
    $DPI_Form = New-Object Windows.Forms.Form
    $Graphics = $DPI_Form.CreateGraphics();
    $DPIValue = [Convert]::ToInt32($Graphics.DpiX)
    $DPI_Form.Dispose();
    if (!$DisableHighDPIMode) { $global:DPIMultiplier = ($DPIValue / 24) * 0.25 }

}

function IsSet([object]$Elem, [int16]$Min, [int16]$Max, [int16]$MinLength, [int16]$MaxLength, [switch]$HasInt) {

    if ($Elem -eq $null -or $Elem -eq "")                                               { return $False }
    if ($HasInt) {
        if ($Elem -NotMatch "^\d+$" )                                                   { return $False }
        if ($Min -ne $null -and $Min -ne "" -and [int16]$Elem -lt $Min)                 { return $False }
        if ($Max -ne $null -and $Max -ne "" -and [int16]$Elem -gt $Max)                 { return $False }
    }
    if ($MinLength -ne $null -and $MinLength -ne "" -and $Elem.Length -lt $MinLength)   { return $False }
    if ($MaxLength -ne $null -and $MaxLength -ne "" -and $Elem.Length -gt $MaxLength)   { return $False }

    return $True

}

function IsChecked([object]$Elem, [switch]$Not) {
    
    if (!(IsSet $Elem))   { return $False }
    if (!$Elem.Active)    { return $False }
    if ( $Elem.Checked)   { return !$Not  }
    if (!$Elem.Checked)   { return  $Not  }
    return $False

}

function TestFile([string]$Path, [switch]$Container) {
    
    if ($Path -eq "")   { return $False }
    if ($Container)     { return Test-Path -LiteralPath $Path -PathType Container }
    else                { return Test-Path -LiteralPath $Path -PathType Leaf }

}

function CreateToolTip($Form, $Info) {

    # Create ToolTip
    $ToolTip = New-Object System.Windows.Forms.ToolTip
    $ToolTip.AutoPopDelay = 32767
    $ToolTip.InitialDelay = 500
    $ToolTip.ReshowDelay = 0
    $ToolTip.ShowAlways = $True
    if ( (IsSet $Form) -and (IsSet $Info) ) { $ToolTip.SetToolTip($Form, $Info) }
    return $ToolTip

}

function CreateForm([uint16]$X=0, [uint16]$Y=0, [uint16]$Width=0, [uint16]$Height=0, [object]$Form, [object]$AddTo) {
    
    $Form.Size     = DPISize(New-Object System.Drawing.Size($Width, $Height))
    $Form.Location = DPISize(New-Object System.Drawing.Size($X, $Y))
    if (IsSet $AddTo) { $AddTo.Controls.Add($Form) }
    Add-Member -InputObject $Form -NotePropertyMembers @{ Active = $True }
    return $Form

}

function CreateGroupBox([uint16]$X, [uint16]$Y, [uint16]$Width, [uint16]$Height, [string]$Text, [object]$AddTo=$Last.Panel) {
    
    $Last.Group = CreateForm -X $X -Y $Y -Width $Width -Height $Height -Form (New-Object System.Windows.Forms.GroupBox) -AddTo $AddTo
    $Last.Hide  = $False
    $Last.Group.Font = $Fonts.Small
    if (IsSet $Text) { $Last.Group.Text = (" " + $Text + " ") }
    $Last.GroupName = $Name
    return $Last.Group

}

function CreatePanel([uint16]$X, [uint16]$Y, [uint16]$Width, [uint16]$Height,[boolean]$Hide, [object]$AddTo=$MainDialog) {
    
    $Last.Panel = CreateForm -X $X -Y $Y -Width $Width -Height $Height -Form (New-Object System.Windows.Forms.Panel) -AddTo $AddTo
    if ($Hide) { $Last.Panel.Hide() }
    return $Last.Panel

}

function CreateTextBox([uint16]$X=0, [uint16]$Y=0, [uint16]$Width=0, [uint16]$Height=0, [byte]$Length=0, [switch]$ReadOnly, [string]$Text="", [string]$Info, [switch]$TextFileFont, [object]$AddTo=$Last.Group) {
    
    $TextBox = CreateForm -X $X -Y $Y -Width $Width -Height $Height -Form (New-Object System.Windows.Forms.TextBox) -AddTo $AddTo
    $ToolTip = CreateToolTip -Form $TextBox -Info $Info
    $TextBox.Text = $Text
    $TextBox.Font = $Fonts.Small
    if ($Length -gt 0) { $TextBox.MaxLength = $Length }

    if ($ReadOnly) {
        $TextBox.ReadOnly = $True
        $TextBox.Cursor = 'Default'
        $TextBox.ShortcutsEnabled = $False
        $TextBox.BackColor = "White"
        $TextBox.Add_Click({ $this.SelectionLength = 0 })
    }
    
    Add-Member -InputObject $TextBox -NotePropertyMembers @{ Default = $Text }
    return $TextBox

}

function CreateLabel([uint16]$X=0, [uint16]$Y=0, [uint16]$Width=0, [uint16]$Height=20, [string]$Text="", [System.Drawing.Font]$Font=$Fonts.Small, [string]$Info="", [object]$AddTo=$Last.Group) {
    
    $Label = CreateForm -X $X -Y $Y -Width $Width -Height $Height -Form (New-Object System.Windows.Forms.Label) -AddTo $AddTo
    if (  IsSet $Text)    { $Label.Text     = $Text }
    if (!(IsSet $Width))  { $Label.AutoSize = $True }
    $Label.Font = $Font
    $ToolTip = CreateToolTip -Form $Label -Info $Info
    return $Label

}

function CreateCheckBox([uint16]$X=0, [uint16]$Y=0, [switch]$Checked, [switch]$Disable, [switch]$IsRadio, [string]$Info="", [object]$Label, [object]$AddTo=$Last.Group) {
    
    if ($IsRadio)   { $CheckBox = CreateForm -X $X -Y $Y -Width (DPISize 20) -Height (DPISize 20) -Form (New-Object System.Windows.Forms.RadioButton) -AddTo $AddTo }
    else            { $CheckBox = CreateForm -X $X -Y $Y -Width (DPISize 20) -Height (DPISize 20) -Form (New-Object System.Windows.Forms.CheckBox)    -AddTo $AddTo }
    $ToolTip = CreateToolTip -Form $CheckBox -Info $Info
    $CheckBox.Enabled = !$Disable
    $CheckBox.Checked = $Checked
    Add-Member -InputObject $CheckBox -NotePropertyMembers @{ Default = $Checked }
    
    if (IsSet $Label) {
        Add-Member -InputObject $Label -NotePropertyMembers @{ CheckBox = $Checkbox }
        $Label.Add_Click({ if ($this.CheckBox.Enabled) { $this.CheckBox.Checked = !$this.CheckBox.Checked } })
    }

    return $CheckBox

}

function CreateButton([uint16]$X=0, [uint16]$Y=0, [uint16]$Width=(DPISize 100), [uint16]$Height=(DPISize 20), [string]$ForeColor, [string]$BackColor, [string]$Text="", [System.Drawing.Font]$Font=$Fonts.Small, [string]$Info="", [object]$AddTo=$Last.Group) {
    
    $Button = CreateForm -X $X -Y $Y -Width $Width -Height $Height -Form (New-Object System.Windows.Forms.Button) -AddTo $AddTo
    if (IsSet $Text)        { $Button.Text = $Text }
    $Button.Font = $Font
    if (IsSet $ForeColor)   { $Button.ForeColor = $ForeColor }
    if (IsSet $BackColor)   { $Button.BackColor = $BackColor }
    if (IsSet $Info)        { $ToolTip = CreateToolTip -Form $Button -Info $Info }
    return $Button

}

function PathButton([object]$TextBox, [string]$Description, [String[]]$FileNames) {
    
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.InitialDirectory = $Paths.Base
    $fileDialog.ShowDialog() | Out-Null
    $SelectedPath = $fileDialog.FileName
    if ($SelectedPath -ne '' -and (TestFile $SelectedPath)) { Finish -Path $SelectedPath }

}

function DragDrop() {

    if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
        $DroppedPath = [string]($_.Data.GetData([Windows.Forms.DataFormats]::FileDrop))
        if (TestFile $DroppedPath) { Finish -Path $DroppedPath }
    }

}

function Finish([string]$Path) {
    
    $file = (Get-Item -LiteralPath $Path)
    $ext = $file.Extension

    if ( ( ($file.Length)/256KB) -gt 1) { return }

    if     ($ext -eq ".gci")                                           { Unlock -Path $path -Format "GameCube"    }
    elseif ($ext -eq ".eep" -or $ext -eq ".fla" -or $ext -eq ".sra")   { Unlock -Path $path -Format "Nintendo 64" }
    else                                                               { Unlock -Path $path -Format "Wii VC"      }

}

function Unlock([string]$Path, [string]$Format, [string]$Game, [string]$Input, [string]$Output) {

    $global:SavePath                 = $file
    $Interface.Input.Text            = $Path
    $Interface.Format2Label.Text     = $Format
    if ($Interface.GCBox.Checked)   { $Interface.ConvertButton.Enabled = ( (IsSet $GCPath) -and (IsSet $SavePath) ) }
    else                            { $Interface.ConvertButton.Enabled = (IsSet $SavePath)                          }

}

function ExportBytes([string]$File, [string]$Offset, [string]$End, [string]$Length, [string]$Output) {
    
    $array = [IO.File]::ReadAllBytes($File)
    [uint32]$Offset = GetDecimal $Offset

    if (IsSet $End) {
        [uint32]$End = GetDecimal $End
        if (TestFile $Output) { Remove-Item -LiteralPath $output -Force }
        [io.file]::WriteAllBytes($Output, $array[$Offset..($End - 1)])
    }
    elseif (IsSet $Length) {
        [uint32]$Length = GetDecimal $Length
        if (TestFile $Output) { Remove-Item -LiteralPath $Output -Force }
        [io.file]::WriteAllBytes($Output, $array[$Offset..($Offset + $Length - 1)])
    }

}

function SearchBytes([string]$File, [string]$Start="0", [string]$End, [object]$Values) {
    
    $values = $values -split ' '
    $array = [IO.File]::ReadAllBytes($File)

    [uint32]$Start = GetDecimal $Start
    if (IsSet $End)   { [uint32]$End = GetDecimal $End }
    else              { [uint32]$End = $array.Length }

    foreach ($i in $Start..($End-1)) {
        $search = $True
        foreach ($j in 0..($Values.Length-1)) {
            if ($array[$i + $j] -ne (GetDecimal $Values[$j]) -and $Values[$j] -ne "xx") {
                $search = $False
                break
            }
        }
        if ($search) { return '{0:X6}' -f $i }
    }

    return -1;

}

function GetDecimal([string]$Hex) {
    
    try     { return [uint32]("0x" + $Hex) }
    catch   { return -1 }

}

function GUI() {

    $global:MainDialog          = New-Object System.Windows.Forms.Form
    $MainDialog.Text            = $ScriptName
    $MainDialog.Size            = DPISize (New-Object System.Drawing.Size(500, 205))
    $MainDialog.MaximizeBox     = $False
    $MainDialog.AutoScale       = $True
    $MainDialog.AutoScaleMode   = [Windows.Forms.AutoScaleMode]::None
    $MainDialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $MainDialog.StartPosition   = "CenterScreen"
    $MainDialog.KeyPreview      = $True
  # $MainDialog.Icon            = $Files.icon.main
    $MainDialog.Add_Shown({ $MainDialog.Activate() })

    $Interface.Groupbox = CreateGroupBox -X 10 -Y 10 -Width 470 -Height 60 -Text "Save Data Paths" -AddTo $MainDialog

    $Interface.Input = CreateTextBox -X 10 -Y 30 -Width 420 -Text "Select your save data..." -ReadOnly
    $Interface.Input.AllowDrop = $True
    $Interface.Input.Add_DragEnter({ $_.Effect = [Windows.Forms.DragDropEffects]::Copy })
    $Interface.Input.Add_DragDrop({ DragDrop })

    $Interface.PathButton = CreateButton -X 435 -Y 27 -Width 24 -Height 24 -Text "..." -Info "Select your save file using file explorer"
    $Interface.PathButton.Add_Click({ PathButton -TextBox $InputPaths.GameTextBox -Description "Save File" })

    $Interface.Groupbox = CreateGroupBox -X 10 -Y 75 -Width 470 -Height 80 -Text "Utility" -AddTo $MainDialog

    $Interface.ConvertButton         = CreateButton -X 10 -Y 20 -Width 200 -Height 50 -Text "Convert Save File" -Info "Convert your Save File"
    $Interface.ConvertButton.Enabled = $False
    $Interface.ConvertButton.Add_Click({ MainFunction })

    $Interface.Panel        = CreatePanel    -X 230 -Y 25 -Width 170 -Height 45   -AddTo $Interface.GroupBox
    $Interface.Format1Label = CreateLabel    -X 0   -Y 0  -AddTo $Interface.Panel -Font $Fonts.SmallBold -Text "Save File Format:"
    $Interface.Format2Label = CreateLabel    -X 100 -Y 0  -AddTo $Interface.Panel                        -Text "Not Selected"
    $Interface.SwapLabel    = CreateLabel    -X 0   -Y 20 -AddTo $Interface.Panel -Font $Fonts.SmallBold -Text "Swap Format:" -Info "Swap the save file format between Little Endian (N64) and Big Endian (Wii VC / GC)"
    $Interface.SwapBox      = CreateCheckbox -X 100 -Y 10 -AddTo $Interface.Panel -Checked -Label $Interface.SwapLabel        -Info "Swap the save file format between Little Endian (N64) and Big Endian (Wii VC / GC)"

}

function MainFunction() {
    
    if (IsSet $SavePath) { if (!(TestFile $SavePath)) { return } }

    $input  = $SavePath
    $output = $input.Directory.toString() + "\" + $input.BaseName.toString() + "_converted"

    if ($SavePath.Extension -eq ".gci" -and !$Interface.GCBox.Checked) {
        if ( (SearchBytes -File $input -End "10" -Values "5A 45 4C 44 41 32") -ge 0) { # MM
            $offset = SearchBytes -File $input -Start "6000" -Values "5A 45 4C 44 41 33"
            $offset = '{0:X6}' -f ( (GetDecimal $offset) - 36)
            ExportBytes -File $input -Offset $offset -Length "20300" -Output $output
            $input = (Get-Item -LiteralPath $output)
        }
        
        elseif ( (SearchBytes -File $input -End "10" -Values "5A 45 4C 44 41") -ge 0) { # OoT
            $offset = SearchBytes -File $input -Start "6000" -Values "21 5A 45 4C 44 41"
            $offset = '{0:X6}' -f ( (GetDecimal $offset) - 6)
            ExportBytes -File $input -Offset $offset -Length "8000" -Output $output
            $input = (Get-Item -LiteralPath $output)
        }
    }

    if ($Interface.SwapBox.Checked) {
        $array = [IO.File]::ReadAllBytes($input)

        $ext = ""
        if ($input.extension -eq ".gci" -or $input.extension -eq "") {
            if ($input.length/2kB  -le 1)   { $ext = ".eep" }
            if ($input.length/32kB -gt 1)   { $ext = ".fla" }
            else                            { $ext = ".sra" }
        }
        if (TestFile $output) { Remove-Item -LiteralPath $output -Force }

        for ($i=0; $i -lt $array.length; $i+=4) {
            $temp = @($array[$i], $array[$i + 1], $array[$i + 2], $array[$i + 3])
            $array[$i]     = $temp[3]
            $array[$i + 1] = $temp[2]
            $array[$i + 2] = $temp[1]
            $array[$i + 3] = $temp[0]
        }

        if ($input.extension -eq ".eep" -or $input.extension -eq ".sra" -or $input.extension -eq ".fla") {
            [Collections.Generic.List[Byte]]$array = $array
            if     ($input.length/2kB  -le 1)   { while ($array.Count/32kB -lt 1)    { $array.Add(170) } } # .eep
            elseif ($input.length/32kB -gt 1)   { while ($array.Count/256kB -lt 1)   { $array.Add(170) } } # .fla
            else                                { while ($array.Count/32kB -lt 1)    { $array.Add(170) } } # .sra
        }

        [IO.File]::WriteAllBytes(($output + $ext), $array)
    }

}

InitializeHiDPIMode
SetFonts
GUI
$MainDialog.ShowDialog() | Out-Null
Exit