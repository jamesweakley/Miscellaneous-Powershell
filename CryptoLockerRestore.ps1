function CryptoLockerRestore{
    <#
    .SYNOPSIS

    Used for restoring a CryptoLocker infected directory structure from backup.

    IMPORTANT NOTE: Before using this script, visit https://www.decryptcryptolocker.com/ and see whether your files are able to be decrypted using the keys recovered during Operation Tovar.
    
    .DESCRIPTION

    Iterates a directory recursively and looks for files ending with ".encrypted". 
    For each file, it will attempt to restore a file with the same name (sans the ".encrypted" suffix) from a backup location over the top.

    .PARAMETER liveFolder

    The path where the encrypted files reside.

    .PARAMETER backupCopy

    The path where the most recent backup resides. Generally this will be a locally mounted image-based backup.
    Ensure that this path points to the equivalent root directory of liveFolder

    .PARAMETER testMode

    Set this to $true to display a report of what would have occurred.

    Set to $false to actually perform the restores.
    
    .EXAMPLE

    CryptoLockerRestore -liveFolder "C:\Data" -backupCopy "X:Data" -testMode $false
    
    .NOTES

    You need to run this function as a user who has read and write access to the directory tree.

    #>
    param( 
         [string]$liveFolder   = $(throw "LiveFolder parameter not specified") 
        ,[string]$backupCopy     = $(throw "BackupCopy parameter not specified")
        ,[boolean]$testMode= $(throw "testMode parameter not specified")) 
    
    write-host "Enumerating files..."
    
    gci -Force -LiteralPath $liveFolder -recurse | where-object {$_.Name -like "*.encrypted"} | % {
        $thisFileLivePath = $_.FullName;
        $thisFileNameOnly = $_.Name;
        $backupCopyPath = $thisFileLivePath.Replace($liveFolder,$backupCopy);
        $backupCopyPath = $backupCopyPath.Replace(".encrypted","");
        
        if ($testMode -eq $true)
        {
            write-host "'$backupCopyPath' would be copied over '$thisFileLivePath'";
        }
        else
        {
            write-host "copying '$backupCopyPath' over '$thisFileLivePath'";
            copy-item -LiteralPath $backupCopyPath $thisFileLivePath
            $thisFileLivePathRenamedBack = $thisFileLivePath.Replace(".encrypted","");
            write-host "Renaming '$thisFileLivePath' to '$thisFileLivePathRenamedBack'";
            Move-Item -LiteralPath $thisFileLivePath -destination $thisFileLivePathRenamedBack
        }
    }
    write-host "Completed"
}

