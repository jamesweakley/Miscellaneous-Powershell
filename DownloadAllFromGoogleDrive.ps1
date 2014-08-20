
function DownloadFromGoogleDrive{ 
    param( 
         [System.Uri]$webUrl = $(throw "webUrl parameter not specified"),
         [String]$localFolder = ".\") 
    
    write-host "Creating folder if it doesn't exist"

    New-Item -ItemType Directory -Force -Path $localFolder

    write-host "Downloading file list from $webUrl"
    
    $webFolderResponse = Invoke-WebRequest -Uri $webUrl.AbsoluteUri

    $rootUri = $webUrl.AbsoluteUri.Replace($webUrl.PathAndQuery,"")

    $webFolderResponse.Links | % {
        
        if ($_.outerText.IndexOf(".") -gt 0)
        {
            $thisItemUrl = "$rootUri$($_.href)"

            $localFile = "$localFolder$($_.outerText)"

            
            if (Test-Path $localFile)
            {
                write-host "skipping $thisItemUrl as it already exists locally"
            }
            else
            {
                write-host "downloading $thisItemUrl to $localFile"
                Invoke-WebRequest -Uri $thisItemUrl -OutFile $localFile
            }
        }
        elseif (!$_.outerText.Equals("Back to parent") -and !$_.outerText.Equals("Drive"))
        {
            $subfolder=$webUrl.AbsoluteUri+$_.outerText+"/"
            $targetFolder = $localFolder+$_.outerText+"\"
            write-host "Downloading subdirectory $subfolder"
            DownloadFromGoogleDrive -webUrl $subfolder -localFolder $targetFolder
        }
    }

    write-host "Completed $webUrl"
}