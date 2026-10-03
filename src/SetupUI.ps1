function Select-ListItem($Items, [string]$Title) {
    if (!$Items.Count) { throw 'NoCompatibleProfiles' }
    $form = New-Object Windows.Forms.Form
    $form.Text=$Title; $form.Width=540; $form.Height=390; $form.StartPosition='CenterScreen'
    $list = New-Object Windows.Forms.ListBox
    $list.SetBounds(15,15,490,265); $list.DisplayMember='Label'
    foreach ($item in $Items) { [void]$list.Items.Add($item) }
    $list.SelectedIndex=0
    $ok=New-Object Windows.Forms.Button; $ok.Text='Выбрать'; $ok.SetBounds(315,295,90,30)
    $ok.DialogResult=[Windows.Forms.DialogResult]::OK
    $cancel=New-Object Windows.Forms.Button; $cancel.Text='Отмена'; $cancel.SetBounds(415,295,90,30)
    $cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel
    $form.Controls.AddRange(@($list,$ok,$cancel)); $form.AcceptButton=$ok; $form.CancelButton=$cancel
    if ($form.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $form.Dispose(); throw 'Cancelled' }
    $selected=$list.SelectedItem.Value
    $form.Dispose()
    return $selected
}

function Select-SetupOutbound([string]$SourceRoot) {
    $choice = [Windows.Forms.MessageBox]::Show("Импортировать подключение из Throne?`n`nДа — выбрать профиль Throne.`nНет — выбрать JSON outbound или полный config Xray из файла.`n`nПараметры останутся только на этом компьютере.", 'stats.cc — настройка подключения','YesNoCancel','Question')
    if ($choice -eq [Windows.Forms.DialogResult]::Cancel) { throw 'Cancelled' }
    $picker=New-Object Windows.Forms.OpenFileDialog
    if ($choice -eq [Windows.Forms.DialogResult]::Yes) {
        $db=Join-Path $env:APPDATA 'Throne\config\throne.db'
        if (!(Test-Path -LiteralPath $db)) {
            $picker.Title='Выбери throne.db (в том числе для portable Throne)'; $picker.Filter='Throne database|throne.db|SQLite databases|*.db'
            if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw 'Cancelled' }
            $db=$picker.FileName
        }
        Add-Type -Path "$SourceRoot\ThroneSqlite.cs"
        $profiles=@(Get-ThroneProfiles $db)
        $items=@($profiles | ForEach-Object { [pscustomobject]@{Label=($_.Name+' ['+$_.Type+']');Value=$_.Id} })
        $id=Select-ListItem $items 'Профиль Throne для отдельного соединения'
        return Get-ThroneOutbound $db ([int]$id)
    }
    $picker.Title='JSON outbound или config Xray'; $picker.Filter='JSON|*.json|All files|*.*'
    if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw 'Cancelled' }
    $outbounds=@(Get-XrayOutbounds ([IO.File]::ReadAllText($picker.FileName)))
    if ($outbounds.Count -eq 1) { return $outbounds[0] }
    $items=@($outbounds | ForEach-Object { [pscustomobject]@{Label=($_.protocol+' / '+$_.tag);Value=$_} })
    return Select-ListItem $items 'Выбери подключение Xray'
}
