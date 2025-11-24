# Permission checker script for ALIE project (Windows PowerShell version)
# Ensures all .sh files have execute permissions
# Run this script to verify and fix permissions if needed

Write-Host "🔍 Checking execute permissions on shell scripts..." -ForegroundColor Cyan

# Get list of all .sh files in the repository
$shFiles = git ls-files "*.sh"

if (-not $shFiles) {
    Write-Host "✅ No .sh files found to check" -ForegroundColor Green
    exit 0
}

# Check each .sh file for execute permissions
$needsFix = @()
foreach ($file in $shFiles) {
    # Check if file has execute permissions in Git index
    $stageInfo = git ls-files --stage $file
    $perms = ($stageInfo -split ' ')[0]
    if ($perms -ne "100755") {
        $needsFix += @{File=$file; Perms=$perms}
    }
}

if ($needsFix.Count -gt 0) {
    Write-Host "⚠️  Found .sh files without execute permissions:" -ForegroundColor Yellow
    foreach ($item in $needsFix) {
        Write-Host "   $($item.File) (current perms: $($item.Perms))" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "🔧 Fixing permissions..." -ForegroundColor Cyan
    foreach ($item in $needsFix) {
        git update-index --chmod=+x $item.File
        Write-Host "   ✅ Fixed: $($item.File)" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "📝 Remember to commit these permission changes:" -ForegroundColor Cyan
    Write-Host "   git commit -m `"Fix execute permissions on shell scripts`"" -ForegroundColor White
} else {
    Write-Host "✅ All shell scripts have correct execute permissions" -ForegroundColor Green
}