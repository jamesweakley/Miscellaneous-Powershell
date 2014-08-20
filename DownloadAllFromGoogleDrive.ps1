
function DownloadFromGoogleDrive{ 
    <#
    .SYNOPSIS

    Used for downloading a directory tree recursively from a Google drive folder.

    
    .DESCRIPTION

    Accepts a URL representing a Google Drive folder and a local folder path. Retrieves the HTML and downloads each file to the specified path.
    For each subfolder, calls itself recursively to download the entire tree.

    .PARAMETER webUrl

    The URL for the Google Drive folder

    .PARAMETER localFolder

    The path to download the files to locally.
    
    .EXAMPLE

    DownloadFromGoogleDrive -webUrl "https://someidentifier.googledrive.com/host/anotheridentifier/" -localFolder "C:\LocalCopy\"
    
    .NOTES

    Folders will be created if they are missing.

    #>
    param( 
         [System.Uri]$webUrl = $(throw "webUrl parameter not specified"),
         [String]$localFolder = ".\") 
    
    write-host "Creating folder if it doesn't exist"

    if (!$localFolder.EndsWith("\"))
    {
        $localFolder=$localFolder+"\"
    }

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