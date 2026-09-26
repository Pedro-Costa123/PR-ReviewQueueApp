param([ValidateSet('Restrict','Protect','Unprotect')][string]$Operation, [string]$Directory)
$ErrorActionPreference = 'Stop'
if ($Operation -eq 'Restrict') {
  $workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
  $target = [IO.Path]::GetFullPath($Directory)
  if (-not $target.StartsWith((Join-Path $workspace 'backups') + [IO.Path]::DirectorySeparatorChar)) { throw 'Backup directory must stay under workspace backups.' }
  $acl = New-Object Security.AccessControl.DirectorySecurity
  $acl.SetAccessRuleProtection($true, $false)
  $owner = [Security.Principal.WindowsIdentity]::GetCurrent().User
  $acl.SetOwner($owner)
  foreach ($sid in @($owner, (New-Object Security.Principal.SecurityIdentifier('S-1-5-18')))) {
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
    $acl.AddAccessRule($rule)
  }
  Set-Acl -LiteralPath $target -AclObject $acl
  $check = Get-Acl -LiteralPath $target
  if (-not $check.AreAccessRulesProtected -or $check.Access.Count -ne 2) { throw 'Restricted ACL verification failed.' }
  'Restricted to current operator and SYSTEM.'
} else {
  Add-Type -AssemblyName System.Security
  $bytes = [Convert]::FromBase64String([Console]::In.ReadToEnd())
  if ($Operation -eq 'Protect') {
    $result = [Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  } else {
    $result = [Security.Cryptography.ProtectedData]::Unprotect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  }
  [Console]::Out.Write([Convert]::ToBase64String($result))
}
