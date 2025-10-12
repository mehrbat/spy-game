# Deploy Files to AWS Script
# This script uploads game files to S3 and invalidates CloudFront cache

# Load environment variables from .env file
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.+)$' -and $_ -notmatch '^#') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value
        }
    }
} else {
    Write-Host "✗ Error: .env file not found. Please copy .env.example to .env and configure it." -ForegroundColor Red
    exit 1
}

# Configuration
$BUCKET_NAME = "spy-game-$BUCKET_GUID"

Write-Host "=== Deploying Game Files to AWS ===" -ForegroundColor Cyan
Write-Host "Bucket: $BUCKET_NAME" -ForegroundColor Yellow
Write-Host ""

# Verify bucket exists
Write-Host "Verifying S3 bucket exists..." -ForegroundColor Green
$bucketCheck = aws s3 ls "s3://$BUCKET_NAME" --profile $AWS_PROFILE 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Bucket does not exist. Please run setup-aws.ps1 first." -ForegroundColor Red
    exit 1
}
Write-Host "✓ Bucket verified" -ForegroundColor Green

# Upload files to S3
Write-Host "Uploading game files to S3..." -ForegroundColor Green
aws s3 cp game.html "s3://$BUCKET_NAME/game.html" --content-type "text/html" --profile $AWS_PROFILE
aws s3 cp words.txt "s3://$BUCKET_NAME/words.txt" --content-type "text/plain" --profile $AWS_PROFILE

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to upload files" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Files uploaded successfully" -ForegroundColor Green

# Find CloudFront distribution for this bucket
Write-Host "Finding CloudFront distribution..." -ForegroundColor Green
$distributions = aws cloudfront list-distributions --profile $AWS_PROFILE --output json | ConvertFrom-Json
$distribution = $null

foreach ($dist in $distributions.DistributionList.Items) {
    if ($dist.Origins.Items[0].DomainName -like "*$BUCKET_NAME*") {
        $distribution = $dist
        break
    }
}

if (-not $distribution) {
    Write-Host "✗ CloudFront distribution not found. Please run setup-aws.ps1 first." -ForegroundColor Red
    exit 1
}

$distributionId = $distribution.Id
$distributionDomain = $distribution.DomainName
Write-Host "✓ Found distribution: $distributionId" -ForegroundColor Green

# Create CloudFront invalidation
Write-Host "Creating CloudFront cache invalidation..." -ForegroundColor Green

$invalidationResult = aws cloudfront create-invalidation `
    --distribution-id $distributionId `
    --paths "/*" `
    --profile $AWS_PROFILE `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    $invalidationId = $invalidationResult.Invalidation.Id
    Write-Host "✓ CloudFront invalidation created: $invalidationId" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create invalidation" -ForegroundColor Red
    exit 1
}

# Display results
Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files uploaded:" -ForegroundColor Yellow
Write-Host "  - game.html" -ForegroundColor White
Write-Host "  - words.txt" -ForegroundColor White
Write-Host ""
Write-Host "CloudFront URL: https://$distributionDomain/game.html" -ForegroundColor Yellow
Write-Host "Invalidation ID: $invalidationId" -ForegroundColor Yellow
Write-Host ""
Write-Host "⏱ Cache invalidation in progress..." -ForegroundColor Cyan
Write-Host "Changes will be live in 1-5 minutes" -ForegroundColor Cyan
Write-Host ""
Write-Host "Check invalidation status:" -ForegroundColor White
Write-Host "  aws cloudfront get-invalidation --distribution-id $distributionId --id $invalidationId --profile $AWS_PROFILE" -ForegroundColor Gray
