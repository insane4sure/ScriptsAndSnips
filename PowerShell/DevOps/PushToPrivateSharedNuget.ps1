

 # PowerShell script to push .nupkg files to a NuGet source

# Define the directory containing the .nupkg files
$directoryPath = "C:\git\packages\packages"

# Define the NuGet source and API key
$nugetSource = "private-shared-nuget"
$apiKey = "az"

# Change directory to the location of the NuGet files
Set-Location -Path $directoryPath

# Get all .nupkg files in the directory
$nupkgFiles = Get-ChildItem -Path $directoryPath -Filter *.nupkg

# Loop through each .nupkg file and push it to the NuGet source
foreach ($file in $nupkgFiles) {
    # Build the push command
    $nugetPushCommand = "./nuget.exe push -source `"$nugetSource`" -ApiKey `"$apiKey`" `"$($file.FullName)`""

    # Execute the push command
    Write-Host "Pushing $($file.Name) to $nugetSource..."
    Invoke-Expression -Command $nugetPushCommand

    if ($?) {
        Write-Host "$($file.Name) pushed successfully."
    } else {
        Write-Host "Failed to push $($file.Name)"
    }
}