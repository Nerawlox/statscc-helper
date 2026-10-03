function Select-ListItem($Items, [string]$Title) {
    if (!$Items.Count) { throw 'NoCompatibleProfiles' }
    $form = New-Object Windows.Forms.Form
    $form.Text=$Title; $form.Width=540; $form.Height=390; $form.StartPosition='CenterScreen'
    $list = New-Object Windows.Forms.ListBox
    $list.SetBounds(15,15,490,265); $list.DisplayMember='Label'
    foreach ($item in $Items) { [void]$list.Items.Add($item) }
    $list.SelectedIndex=0
    $ok=New-Object Windows.Forms.Button; $ok.Text='Select'; $ok.SetBounds(315,295,90,30)
    $ok.DialogResult=[Windows.Forms.DialogResult]::OK
    $cancel=New-Object Windows.Forms.Button; $cancel.Text='Cancel'; $cancel.SetBounds(415,295,90,30)
    $cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel
    $form.Controls.AddRange(@($list,$ok,$cancel)); $form.AcceptButton=$ok; $form.CancelButton=$cancel
    if ($form.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $form.Dispose(); throw 'Cancelled' }
    $selected=$list.SelectedItem.Value
    $form.Dispose()
    return $selected
}

function Select-SetupOutbound([string]$SourceRoot) {
    $choice = [Windows.Forms.MessageBox]::Show("Import a connection from Throne?`n`nYes: select a Throne profile.`nNo: select an Xray outbound or full config JSON file.`n`nYour connection parameters stay on this computer.", 'stats.cc connection setup','YesNoCancel','Question')
    if ($choice -eq [Windows.Forms.DialogResult]::Cancel) { throw 'Cancelled' }
    $picker=New-Object Windows.Forms.OpenFileDialog
    if ($choice -eq [Windows.Forms.DialogResult]::Yes) {
        $db=Join-Path $env:APPDATA 'Throne\config\throne.db'
        if (!(Test-Path -LiteralPath $db)) {
            $picker.Title='Select throne.db (including portable Throne)'; $picker.Filter='Throne database|throne.db|SQLite databases|*.db'
            if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw 'Cancelled' }
            $db=$picker.FileName
        }
        Add-Type -Path "$SourceRoot\ThroneSqlite.cs"
        $profiles=@(Get-ThroneProfiles $db)
        $items=@($profiles | ForEach-Object { [pscustomobject]@{Label=($_.Name+' ['+$_.Type+']');Value=$_.Id} })
        $id=Select-ListItem $items 'Throne profile for the independent connection'
        return Get-ThroneOutbound $db ([int]$id)
    }
    $picker.Title='Xray outbound or config JSON'; $picker.Filter='JSON|*.json|All files|*.*'
    if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw 'Cancelled' }
    $outbounds=@(Get-XrayOutbounds ([IO.File]::ReadAllText($picker.FileName)))
    if ($outbounds.Count -eq 1) { return $outbounds[0] }
    $items=@($outbounds | ForEach-Object { [pscustomobject]@{Label=($_.protocol+' / '+$_.tag);Value=$_} })
    return Select-ListItem $items 'Select an Xray connection'
}
