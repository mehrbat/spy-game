# AWS Infrastructure Setup Script for Spy Game
# This script sets up S3 bucket, CloudFront distribution, and Origin Access Identity

# Load environment variables from .env file
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.+)$' -and $_ -notmatch '^#') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Variable -Name $name -Value $value
        }
    }
    Write-Host "✓ Loaded configuration from .env" -ForegroundColor Green
} else {
    Write-Host "✗ Error: .env file not found. Please copy .env.example to .env and configure it." -ForegroundColor Red
    exit 1
}

# Configuration
$BUCKET_NAME = "spy-game-$BUCKET_GUID"
$DISTRIBUTION_COMMENT = "Spy Game CloudFront Distribution"

Write-Host "=== Spy Game AWS Deployment ===" -ForegroundColor Cyan
Write-Host "Bucket Name: $BUCKET_NAME" -ForegroundColor Yellow
Write-Host "Region: $AWS_REGION" -ForegroundColor Yellow
Write-Host ""

# Check if bucket exists
Write-Host "Checking if S3 bucket exists..." -ForegroundColor Green
$bucketExists = $false
try {
    aws s3 ls "s3://$BUCKET_NAME" --profile $AWS_PROFILE 2>$null
    if ($LASTEXITCODE -eq 0) {
        $bucketExists = $true
        Write-Host "✓ Bucket already exists" -ForegroundColor Green
    }
} catch {
    $bucketExists = $false
}

# Create bucket if it doesn't exist
if (-not $bucketExists) {
    Write-Host "Creating S3 bucket..." -ForegroundColor Green
    aws s3 mb "s3://$BUCKET_NAME" --region $AWS_REGION --profile $AWS_PROFILE
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Bucket created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create bucket" -ForegroundColor Red
        exit 1
    }
    
    # Wait a bit for bucket to be ready
    Start-Sleep -Seconds 2
}

# Block public access (bucket will only be accessible via CloudFront)
Write-Host "Configuring bucket to block public access..." -ForegroundColor Green
aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --profile $AWS_PROFILE

# Check if CloudFront Origin Access Identity (OAI) exists
Write-Host "Checking for CloudFront Origin Access Identity..." -ForegroundColor Green
$oaiComment = "spy-game-oai"
$oaiList = aws cloudfront list-cloud-front-origin-access-identities --profile $AWS_PROFILE --output json | ConvertFrom-Json
$existingOAI = $oaiList.CloudFrontOriginAccessIdentityList.Items | Where-Object { $_.Comment -eq $oaiComment }

if ($existingOAI) {
    Write-Host "✓ Origin Access Identity already exists" -ForegroundColor Green
    $oaiId = $existingOAI.Id
} else {
    Write-Host "Creating Origin Access Identity..." -ForegroundColor Green
    
    $oaiConfig = @"
{
    "CallerReference": "$BUCKET_GUID-oai-$(Get-Date -Format 'yyyyMMddHHmmss')",
    "Comment": "$oaiComment"
}
"@
    
    $oaiConfigFile = "oai-config-temp.json"
    $oaiConfig | Out-File -FilePath $oaiConfigFile -Encoding utf8
    
    $oaiResult = aws cloudfront create-cloud-front-origin-access-identity --cloud-front-origin-access-identity-config file://$oaiConfigFile --profile $AWS_PROFILE --output json | ConvertFrom-Json
    $oaiId = $oaiResult.CloudFrontOriginAccessIdentity.Id
    
    Remove-Item $oaiConfigFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Origin Access Identity created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create Origin Access Identity" -ForegroundColor Red
        exit 1
    }
}

# Check if CloudFront distribution already exists for this bucket
Write-Host "Checking for existing CloudFront distribution..." -ForegroundColor Green
$distributions = aws cloudfront list-distributions --profile $AWS_PROFILE --output json | ConvertFrom-Json
$existingDistribution = $null

foreach ($dist in $distributions.DistributionList.Items) {
    if ($dist.Origins.Items[0].DomainName -like "*$BUCKET_NAME*") {
        $existingDistribution = $dist
        break
    }
}

if ($existingDistribution) {
    Write-Host "✓ CloudFront distribution already exists" -ForegroundColor Green
    $distributionId = $existingDistribution.Id
    $distributionDomain = $existingDistribution.DomainName
} else {
    # Create CloudFront distribution
    Write-Host "Creating CloudFront distribution..." -ForegroundColor Green
    
    $s3Origin = "$BUCKET_NAME.s3.$AWS_REGION.amazonaws.com"
    
    $distributionConfig = @"
{
    "CallerReference": "$BUCKET_GUID-$(Get-Date -Format 'yyyyMMddHHmmss')",
    "Comment": "$DISTRIBUTION_COMMENT",
    "DefaultRootObject": "game.html",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-$BUCKET_NAME",
                "DomainName": "$s3Origin",
                "S3OriginConfig": {
                    "OriginAccessIdentity": "origin-access-identity/cloudfront/$oaiId"
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-$BUCKET_NAME",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            }
        },
        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000,
        "Compress": true,
        "TrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        }
    },
    "Enabled": true,
    "PriceClass": "PriceClass_All"
}
"@
    
    # Save distribution config to temp file
    $distConfigFile = "distribution-config-temp.json"
    $distributionConfig | Out-File -FilePath $distConfigFile -Encoding utf8
    
    # Create the distribution
    $result = aws cloudfront create-distribution --distribution-config file://$distConfigFile --profile $AWS_PROFILE --output json | ConvertFrom-Json
    
    # Clean up temp file
    Remove-Item $distConfigFile
    
    if ($LASTEXITCODE -eq 0) {
        $distributionId = $result.Distribution.Id
        $distributionDomain = $result.Distribution.DomainName
        Write-Host "✓ CloudFront distribution created successfully" -ForegroundColor Green
        
        # Wait a bit for distribution to be created
        Start-Sleep -Seconds 5
    } else {
        Write-Host "✗ Failed to create CloudFront distribution" -ForegroundColor Red
        exit 1
    }
}

# Update S3 bucket policy to allow CloudFront OAI access
Write-Host "Updating S3 bucket policy for CloudFront access..." -ForegroundColor Green

$bucketPolicy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFrontOAI",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity $oaiId"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
        }
    ]
}
"@

$policyFile = "bucket-policy-temp.json"
$bucketPolicy | Out-File -FilePath $policyFile -Encoding utf8

# Remove public access block to allow bucket policy
aws s3api delete-public-access-block --bucket $BUCKET_NAME --profile $AWS_PROFILE 2>$null

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://$policyFile --profile $AWS_PROFILE

Remove-Item $policyFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Bucket policy updated successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to update bucket policy" -ForegroundColor Red
    exit 1
}

# Display results
Write-Host ""
Write-Host "=== AWS Setup Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "S3 Bucket: $BUCKET_NAME" -ForegroundColor Yellow
Write-Host "Region: $AWS_REGION" -ForegroundColor Yellow
Write-Host ""
Write-Host "CloudFront Distribution ID: $distributionId" -ForegroundColor Yellow
Write-Host "CloudFront URL: https://$distributionDomain/game.html" -ForegroundColor Yellow
Write-Host ""
Write-Host "Note: CloudFront distribution may take 15-20 minutes to fully deploy if newly created." -ForegroundColor Cyan
Write-Host "Check distribution status: aws cloudfront get-distribution --id $distributionId --profile $AWS_PROFILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "Security: S3 bucket is private and only accessible via CloudFront using Origin Access Identity (OAI)" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Wait for CloudFront distribution to deploy (if newly created)" -ForegroundColor White
Write-Host "  2. Run .\deploy-files.ps1 to upload game files" -ForegroundColor White
