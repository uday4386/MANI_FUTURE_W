param(
    [Parameter(Mandatory = $true)]
    [string]$ServerHost,

    [string]$User = "root",
    [string]$RemoteDir = "/var/www/samanyudu-tv",
    [string]$SshKey = ""
)

$ErrorActionPreference = "Stop"

function Run-Step {
    param([string]$Title, [scriptblock]$Action)
    Write-Host ""
    Write-Host "==> $Title"
    & $Action
}

function Build-SshArgs {
    param([string]$KeyPath)
    if ([string]::IsNullOrWhiteSpace($KeyPath)) { return @() }
    return @("-i", $KeyPath)
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Get-EnvValue {
    param(
        [string]$EnvPath,
        [string]$Key
    )
    if (!(Test-Path $EnvPath)) { return $null }
    $line = Get-Content $EnvPath | Where-Object { $_ -match "^\s*$Key=" } | Select-Object -First 1
    if (!$line) { return $null }
    return ($line -split "=", 2)[1].Trim()
}

Run-Step "Validate production environment file" {
    $envPath = Join-Path $Root "backend_api/.env.production"
    if (!(Test-Path $envPath)) {
        throw "Missing backend_api/.env.production"
    }

    $databaseUrl = Get-EnvValue -EnvPath $envPath -Key "DATABASE_URL"
    if ([string]::IsNullOrWhiteSpace($databaseUrl)) {
        throw "DATABASE_URL is missing in backend_api/.env.production"
    }
    if ($databaseUrl -match "localhost|127\.0\.0\.1") {
        throw "DATABASE_URL points to localhost. Use your production PostgreSQL host."
    }
    if ($databaseUrl -match "YOUR_|<|>") {
        throw "DATABASE_URL contains placeholder text. Set real production DB credentials."
    }
    if ($databaseUrl -match "db-hostname-do-user-\d+-0\.g\.db\.ondigitalocean\.com") {
        throw "DATABASE_URL host looks like template text. Replace with your actual DigitalOcean PostgreSQL host."
    }

    try {
        $uri = [System.Uri]$databaseUrl
        $dbHost = $uri.Host
        if ([string]::IsNullOrWhiteSpace($dbHost)) {
            throw "Could not parse DB host from DATABASE_URL."
        }
        try {
            Resolve-DnsName -Name $dbHost -ErrorAction Stop | Out-Null
        }
        catch {
            throw "DB host '$dbHost' did not resolve from this machine. Verify the DATABASE_URL host."
        }
    }
    catch {
        throw "DATABASE_URL is not a valid URI. Check format: postgresql://user:pass@host:port/db?sslmode=require"
    }
}

$SshArgs = Build-SshArgs -KeyPath $SshKey
$Target = "$User@$ServerHost"
$Bundle = "deploy_bundle_{0}.tgz" -f (Get-Date -Format "yyyyMMdd_HHmmss")
$RemoteBundle = "/tmp/$Bundle"

Run-Step "Build admin dashboard (dist)" {
    npm run build
}

Run-Step "Create deploy bundle" {
    if (Test-Path $Bundle) {
        Remove-Item $Bundle -Force
    }
    tar -czf $Bundle `
        --exclude='node_modules' `
        backend_api `
        dist `
        public_web_app `
        nginx_samanyudutv.in.conf
}

Run-Step "Upload bundle to DigitalOcean Droplet" {
    & scp @SshArgs $Bundle "$Target`:$RemoteBundle"
}

$RemoteScript = @'
set -e
echo "==> Unpacking bundle to [[RemoteDir]]"
mkdir -p "[[RemoteDir]]"
tar -xzf "[[RemoteBundle]]" -C "[[RemoteDir]]"
cd "[[RemoteDir]]/backend_api"

# Environment setup
if [ -f '.env.production' ]; then
  cp '.env.production' '.env'
fi

echo "==> Installing backend dependencies"
npm ci --omit=dev || npm install --omit=dev

echo "==> Restarting PM2 process"
if pm2 describe samanyudu-api >/dev/null 2>&1; then
  pm2 restart samanyudu-api --update-env
else
  pm2 start index.js --name samanyudu-api
fi
pm2 save

echo "==> Setting permissions"
sudo chown -R root:www-data "[[RemoteDir]]"
sudo chmod -R 755 "[[RemoteDir]]"

echo "==> Updating Nginx configuration"
NGINX_CONF="[[RemoteDir]]/nginx_samanyudutv.in.conf"
if [ -f "$NGINX_CONF" ]; then
    sudo sed -i "s|/var/www/samanyudu-tv|[[RemoteDir]]|g" "$NGINX_CONF"
    sudo cp "$NGINX_CONF" /etc/nginx/sites-available/samanyudutv.in.conf
    sudo ln -sf /etc/nginx/sites-available/samanyudutv.in.conf /etc/nginx/sites-enabled/samanyudutv.in.conf
    
    echo "==> Testing Nginx configuration"
    sudo nginx -t
    echo "==> Reloading Nginx"
    sudo systemctl reload nginx
else
    echo "WARN: nginx_samanyudutv.in.conf not found"
fi

echo "==> Health Check"
curl -fsS http://127.0.0.1:5000/api/health || echo "Health check failed"
echo "Deployment Successful!"
'@.Replace('[[RemoteDir]]', $RemoteDir).Replace('[[RemoteBundle]]', $RemoteBundle)

Run-Step "Deploy and restart services on Droplet" {
    $RemoteScript | ssh @SshArgs $Target "bash -s"
}

Run-Step "Cleanup local bundle" {
    Remove-Item $Bundle -Force
}

Write-Host ""
Write-Host "Deployment complete."
Write-Host "Verify:"
Write-Host "  https://api.samanyudutv.in/api/health"
Write-Host "  https://admin.samanyudutv.in"
Write-Host "  https://samanyudutv.in"
