<#
 # This script performs some basic IIQ file maintenance
 # (log archival and temp directory cleanup)
 #>
$ErrorActionPreference = "Stop"

#####     FUNCTION DEFINITIONS     #####

# Function to remove all files in the given Path that have not been modified after the given date
function Remove-FilesNotModifiedAfter {
	param( 
        [parameter(Mandatory)][ValidateScript({Test-Path $_})][string] $Path,
		[ValidateNotNullOrEmpty()][ValidateScript({$_ -ge 0})][int]$HoursSinceLastWrite = 12, # default to 12 hours since list write
        [switch]$DeleteEmptyFolders
	)
    # Get current date
    $currentDateTime = Get-Date
    Write-Host ("Current Date: " + $currentDateTime)
    $hoursBack = (0 - $HoursSinceLastWrite)
    Write-Host ("Hours to go back: " + $HoursSinceLastWrite)
    # Set cutoff date.  Since we're going backwards, we need to flip the $HoursSinceLastWrite to a negative
    $cutoffDateTime = $currentDateTime.AddHours($hoursBack)
    Write-Host ("Cutoff Date: " + $cutoffDateTime)
    # Var to set max threads for multithreading
    $maxThreads = 0
    foreach ($cpu in (Get-WmiObject -Class Win32_Processor -Property NumberOfLogicalProcessors)) {
        # NumberOfCores,NumberOfLogicalProcessors
        $maxThreads = $maxThreads + $cpu.NumberOfLogicalProcessors
    }
    # we will use the total number of logical processors seen by the OS *10 (to better expand the pipeline)
    $maxThreads = $maxThreads * 10
    Write-Host ("Total number of threads that will be allocated for deletion: " + $maxThreads)
    # Get our objects to delete
    Write-Host ("Getting objects...")
	#$objsToDelete = New-Object Collections.Generic.List[String]
    $objsToDelete = New-Object System.Collections.ArrayList
    try {
        [void]$objsToDelete.AddRange( (Get-ChildItem -Path $Path -Recurse -Force -File | %{$_.FullName} | Where-Object -FilterScript {$_.LastWriteTime -lt $cutoffDateTime}) )
	    Write-Host ("Got multiple objects")
    }
    catch {
        try {
	        $singleFileCheck = ( (Get-ChildItem -Path $Path -Recurse -Force -File | %{$_.FullName} | Where-Object -FilterScript {$_.LastWriteTime -lt $cutoffDateTime}) )
            if ($null -eq $singleFileCheck) {
                Write-Host ("No files to delete")
            }
            else {
                [void]$objsToDelete.Add( (Get-ChildItem -Path $Path -Recurse -Force -File | %{$_.FullName} | Where-Object -FilterScript {$_.LastWriteTime -lt $cutoffDateTime}) )
                Write-Host ("Got single object")
            }
        }
        catch {
            Write-Host ("Could not build list of files to clean")
            Write-Host ("Exception: " + $_.Exception.Message)
        }
    }
    ################### Write-Host ("Total files: 877,650")
    # Scriptblock defining the function to multithread
    $deleteItemScriptBlock = {
        param(
            [int]$threadID,
            [string]$filePath
        )
        $return = $false
        try {
            Remove-Item -Path $filePath -Force
            # If above didn't throw an exception, update return
            $return = $true
        }
        catch {
            Write-Host ("Could not delete file: " + $filePath)
            Write-Host ("Exception: " + $_.Exception.Message)
        }
        return $return
    }
    # Initialize PoSh multithreaded runspace
    $runSpacePool = [RunspaceFactory]::CreateRunspacePool(
        1,           # minimum number of threads
        $maxThreads  # maximum number of threads
    )
    $runSpacePool.Open()
    # ArrayList to track asyc job status for completion
    $jobs = New-Object System.Collections.ArrayList
    # Begin processing items to delete
    $count = 0
    # Write-Host ("ObjToDelete Class: " + $objsToDelete.getType().FullName)
    # Write-Host ("jobs Class: " + $jobs.getType().FullName)
    $objsToDeleteInitialSize = $objsToDelete.Count
    Write-Host ("Number of files to delete: " + $objsToDeleteInitialSize)
    if ($objsToDeleteInitialSize -gt 0) {
        # Using a pure 'for' loop so that we can remove items from the array as we process them
        for ($i=0; $i -le $objsToDelete.Count; $i++) {
            $file = $objsToDelete[$i]
            $count++
            # Now the fun of multithreaded execution and job management...
            # Check to see if we've assigned jobs to all our threads (runspaces)
            # if so, see if any are completed so we can vacate the thread and assign a new job
            # otherwise, take a brief snooze and check again
            # Write-Host ("Job Count: " + $jobs.Count)
            if ($jobs.Count -ge $runSpacePool.GetMaxRunspaces()) {
                # Iterate our jobs array
                # Write-Host ("All runspaces occupied...")
                do {
                    # Again, using a pure 'for' loop so that we can remove items from the array as we process them
                    for ($j=0; $j -le $jobs.Count; $j++) {
                        $thread = $jobs[$j]
                        # If a job is complete, close process and remove it from the jobs array.
                        # Write-Host ("Thread Complete: " + $thread.Result.IsCompleted)
                        # Write-Host ("Pipe: " + $thread.Pipe)
                        if ($thread.Result.IsCompleted -eq $true) {
                            # Write-Host ("Job complete, clearing runspace reference")
                            [void]$thread.Pipe.EndInvoke($thread.Result)
                            [void]$jobs.RemoveAt($j)
                            # Since we removed an element from the jobs array (and decreased the array indexing accordingly,
                            # We would normally need to decrement the loop counter $j, but since we only needed to make room
                            # for a single new job to launch (and we did by removing an object from the $jobs array), 
                            # it doesn't matter in this case as jobs will be removed on a first-come first-served bases
                        }
                    }
                    # short sleep to help throttle CPU a smidge...
                    # Start-Sleep -Milliseconds 1
                }
                while (!( $jobs.Count -lt $runSpacePool.GetMaxRunspaces() ))
            }
            # We have an available thread, launch the job
            $threadID = [appdomain]::GetCurrentThreadId();
            $job = [PowerShell]::Create().AddScript($deleteItemScriptBlock).AddParameter("threadID",$threadID).AddParameter("filePath",$file)
            $job.RunspacePool = $runSpacePool
            $task = New-Object PSObject -Property @{
                Pipe = $job
                Result = $job.BeginInvoke()
            }
            [void]$jobs.Add($task)
            # Since we've launched the delete job, we can remove the object from the original list to (hopefully) save some RAM
            [void]$objsToDelete.RemoveAt($i)
            # Since removing the object alterts the array indexing, we need to decrement our counter by 1 to compensate
            # However, since our loop uses a '-ge 0', we need to check the array count post-removal and *not* decrement if the array count is now 0
            # Write-Host ("ObjsToDelete Size: " + $objsToDelete.Count)
            if ($objsToDelete.Count -ne 0) {
                $i--
            }
	    }
        # Now that the file iteration loop is complete and all our jobs have been launched,
        # clean up the runspace and close up the last remaining threads
        do {
            # short sleep to help throttle CPU a smidge...
            # Start-Sleep -Milliseconds 1
            for ($k=0; $k -le $jobs.Count; $k++) {
                $finalThread = $jobs[$k]
                if ($finalThread.Result.IsCompleted -eq $true) {
                    # Write-Host ("Job complete, clearing runspace reference")
                    [void]$finalThread.Pipe.EndInvoke($finalThread.Result)
                    [void]$jobs.RemoveAt($k)
                    # Since we removed an element from the jobs array (and decreased the array indexing accordingly,
                    # We would normally need to decrement the loop counter $k, but since we are reiterating the array
                    # from the start at each cycle and $jobs.Count will decrease as a result, the loop will continue
                    # until all jobs are completed and the $jobs array contains 0 elements
                }
            }
        }
        while($jobs.Count -gt 0)
        # Now that all jobs have completed, we can close and dispose of the runspace pool to release the resource handles
        $runspacePool.Close()
        $runspacePool.Dispose()
    }
    Write-Host("Final count of file matches: " + $count)
    if ($DeleteEmptyFolders) {
        Write-Host ("DeleteEmptyFolders switch detected, cleaning out left-behind empty directories")
        # clear our earlier arrays to be safe on memory
        [void]$jobs.Clear()
        [void]$objsToDelete.Clear()
        Remove-EmptyDirectories -Path $Path
    }
}

# function to remove any empty directories in a given Path, including those who may become empty after the Remove-FilesNotModifiedAfterDate has been executed
# Since the number of empty folders should be significantly less than the number of files and proceed qickly, this can be single-threaded.
function Remove-EmptyDirectories {
	param(
		[parameter(Mandatory)][ValidateScript({Test-Path $_})][string]$Path
	)
    $dirsToDelete = New-Object System.Collections.ArrayList
    try {
        [void]$dirsToDelete.AddRange( (Get-ChildItem -Path $Path -Recurse -Force -Directory | %{$_.FullName} | Where-Object -FilterScript {(Get-ChildItem -Path $_ -Recurse -Force -File) -eq $null}) )
    }
    catch {
        try {
            $checkDirsToDelete = (Get-ChildItem -Path $Path -Recurse -Force -Directory | %{$_.FullName} | Where-Object -FilterScript {(Get-ChildItem -Path $_ -Recurse -Force -File) -eq $null})
            if ($null -eq $checkDirsToDelete) {
                Write-Host ("No empty folders found")
            }
            else {
                [void]$dirsToDelete.Add( (Get-ChildItem -Path $Path -Recurse -Force -Directory | %{$_.FullName} | Where-Object -FilterScript {(Get-ChildItem -Path $_ -Recurse -Force -File) -eq $null}) )
                Write-Host ("Got single folder")
            }
        }
        catch {
            Write-Host ("Could not populate list of directories to delete")
            Write-Host ("Exception:" + $_.Exception.Message)
        }
    }
    Write-Host ("dirsToDelete Count: " + $dirsToDelete.Count)
    $emptyDirCount = 0
    foreach ($dir in $dirsToDelete) {
        Remove-Item -Path $dir -Force
        $emptyDirCount++
    }
    Write-Host ("Empty directories deleted: " + $emptyDirCount)
}

# Function to archive and clean up log files
function Archive-LogsNotModifiedAfter {
	param( 
        [parameter(Mandatory)][ValidateScript({Test-Path $_})][string] $Path,
		[parameter(Mandatory)][string] $ArchivePath,
		[parameter(Mandatory)][ValidateScript({Test-Path $_})][string] $CLIFilePath,
		[ValidateNotNullOrEmpty()][ValidateScript({$_ -ge 0})][int]$HoursSinceLastWrite = 12 # default to 12 hours since list write
	)
    # Get current date
    $currentDateTime = Get-Date
    Write-Host ("Current Date: " + $currentDateTime)
    $hoursBack = (0 - $HoursSinceLastWrite)
    Write-Host ("Hours to go back: " + $HoursSinceLastWrite)
    # Set cutoff date.  Since we're going backwards, we need to flip the $HoursSinceLastWrite to a negative
    $cutoffDateTime = $currentDateTime.AddHours($hoursBack)
    Write-Host ("Cutoff Date: " + $cutoffDateTime)
	# Check for log archival directory, create if it doesn't exist
	if (!(Test-Path -Path $ArchivePath)) {
		# Archival directory does not exist, create it
		Write-Host ("Log archival directory not found, creating it...")
		New-Item -Path $ArchivePath -ItemType Directory
		Write-Host ("Log archival directory created.")
	}
	# Build list of logs to archive and purge
	$logsToArchive = New-Object System.Collections.ArrayList
    try {
        [void]$logsToArchive.AddRange( (Get-ChildItem -Path $Path -Recurse -Force -File | %{$_.FullName} | Where-Object -FilterScript {$_.LastWriteTime -lt $cutoffDateTime}) )
	    Write-Host ("Got multiple objects")
    }
    catch {
        try {
	        $singleFileCheck = ( (Get-ChildItem -Path $Path -Recurse -Force -File | %{$_.FullName} | Where-Object -FilterScript {$_.LastWriteTime -lt $cutoffDateTime}) )
            if ($null -eq $singleFileCheck) {
                Write-Host ("No files to delete")
            }
            else {
                [void]$logsToArchive.Add( (Get-ChildItem -Path $Path -Recurse -Force -File | %{$_.FullName} | Where-Object -FilterScript {$_.LastWriteTime -lt $cutoffDateTime}) )
                Write-Host ("Got single object")
            }
        }
        catch {
            Write-Host ("Could not build list of files to clean")
            Write-Host ("Exception: " + $_.Exception.Message)
        }
    }
	# For simplicity, we will temporarily move the log files to a temp folder, zip them, then delete them and the temp folder
	$logsTempDir = $Path + "\logsTemp"
	if (!(Test-Path -Path $logsTempDir)) {
		Write-Host ("Creating temp log archival/purge folder")
		New-Item -Path $logsTempDir -ItemType Directory
		Write-Host ("Temp log archival/purge folder created.")
	}
	# Move logs to temp directory
	foreach ($file in $logsToArchive) {
		try {
			Move-Item -Path $file -Destination $logsTempDir -Force
		}
		catch {
			Write-Host ("Could not move file " + $file )
			Write-Host ("Exception: " + $_.Exception.Message)
		}
	}
	# Perform log zipping
	Write-Host ("Archiving old logs...")
	# TODO:  Refactor this to use the 7zip CLI
	try {
		# Have to back-convert the mapped drive to resolve the full path
		$srcDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($logsTempDir)
		# $srcDir = $logsTempDir
		$destZip = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ArchivePath + "\logs_archive_" + $datestamp + ".zip")
		# $destZip = ($ArchivePath + "\logs_archive_" + $datestamp + ".zip")
		$fullTempDirPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($logsTempDir)
		$cmd = ('& "' + $CLIFilePath + '" a -tzip "' + $destZip + '" "' + $fullTempDirPath + '\*"')
		Write-Host ("PoSh command: powershell.exe -ExecutionPolicy Bypass " + $cmd)
		$res = powershell.exe -ExecutionPolicy Bypass $cmd
		Write-Host ("Result: " + $res)
		$zipSuccessful = $false
		foreach ($line in $res) {
			if (($line.Trim().Length -gt 0) -and ($line.Trim().ToLower().Equals("Everything is Ok".ToLower()))) {
				$zipSuccessful =  $true
				Write-Host ("Log archival successful")
			}
		}
		if (!($zipSuccessful)) {
			Write-Host ("Log archival failed")
		}
	}
	catch {
		# Archival failed, catch the exception and make a note but continue the rest of the process
		Write-Host ("An error occurred when attempting to archive old logs.")
		Write-Host ("Exception: " + $_.Exception.Message)
		Write-Host ("Inner Exception: " + $_.Exception.InnerException)
	}	
	# Clean up temp log stash and directory
	if (Test-Path -Path $logsTempDir) {
		Write-Host ("Removing temp log archival/purge folder")
		Get-ChildItem -Path $logsTempDir -Recurse | Remove-Item -Force
		Remove-Item -Path $logsTempDir -Force
		Write-Host ("Temp log archival/purge folder removed.")
	}
}

#####     MAIN ACTION SECTION     #####

$apacheDir = (($env:TomcatWebappsDir).Replace("\webapps",""))
$logsDir = "logs"
$logsArchiveDir = "old_logs"
$tempDir = "temp"
$datestamp = Get-Date -Format yyyy-MM-dd
$appServers = [System.Collections.ArrayList]@(($env:App_Servers).split(","))
$hrsToGoBack = [int]$env:HoursToRetainFiles
$remoteCreds = New-Object System.Management.Automation.PSCredential($env:DeployUserName,(ConvertTo-SecureString -String $env:DeployUserPass -AsPlainText -Force))
$zipCLILocation = $env:zipCLIFilePath

foreach ($srv in $appServers) {
	# Map SMB share to Tomcat directory
	$mappedDestPart = $apacheDir.Replace('D:\',"")
	$mappedDest = ('\\' + $srv + '\D$\' + ($mappedDestPart))
	Write-Host ("Set destination: " + ($mappedDest))
	Write-Host ("Mapping remote destination " + $srv + " to local 'T'")
	New-PSDrive –Name "T" –PSProvider FileSystem –Root $mappedDest # -Credential $remoteCreds
	Write-Host ("Remote destination " + $srv + " successfully mapped to local 'T'")
	$mappedDestDir = ('T:\')
	# Begin log and temp management....
	$start = Get-Date
	Write-Host ("Start: " + $start )
	$logsFilePath = $mappedDestDir + $logsDir
	$logsArchivePath = $mappedDestDir + $logsArchiveDir
	$tempFilePath = $mappedDestDir + $tempDir
	# TODO:  Parameterize this
	Remove-FilesNotModifiedAfter -Path $tempFilePath -HoursSinceLastWrite $hrsToGoBack -DeleteEmptyFolders
	Archive-LogsNotModifiedAfter -Path $logsFilePath -ArchivePath $logsArchivePath -CLIFilePath $zipCLILocation -HoursSinceLastWrite $hrsToGoBack
	$end = Get-Date
	Write-Host ("End: " + $end )
	$time = New-TimeSpan -Start $start -End $end
	Write-Host ("Total Run: " + $time)	
	# Unmap the SMB share/drive
	Write-Host ("Disconnecting from SMB drive...")
	Remove-PSDrive –PSProvider FileSystem -Name "T"
	Write-Host ("SMB drive disconnection complete.")
}