Param(
    [string]$Message
)

# Ensure working directory
Set-Location -LiteralPath 'C:\KyWorkspace'

if (-not (Test-Path -Path '.git')) {
    Write-Error 'No git repository found at C:\KyWorkspace. Initialize or run inside a repo.'
    exit 1
}

# Show status
Write-Output "Repository: $(Get-Location)"
Write-Output "Git status:"
git status --short

$porcelain = git status --porcelain
if ($porcelain -and $porcelain.Trim().Length -gt 0) {
    if (-not $Message) {
        $Message = "Auto-sync: $(Get-Date -Format u)"
    }
    Write-Output 'Staging changes...'
    git add -A
    Write-Output 'Committing...'
    git commit -m "$Message" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
} else {
    Write-Output 'No local changes to commit.'
}

# Update from remote and push
Write-Output 'Pulling latest from origin/main with rebase...'
git pull --rebase origin main
if ($LASTEXITCODE -ne 0) {
    Write-Error 'git pull failed. Resolve conflicts and re-run the script.'
    exit $LASTEXITCODE
}

Write-Output 'Pushing to origin/main...'
git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Error 'git push failed.'
    exit $LASTEXITCODE
}

Write-Output 'Sync complete.'
