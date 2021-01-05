#Varaible and values assignment
$Jsonfile = "./config/config.json"
$MyDir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
set-location $MyDir 

#------------------------------------------------------------------------
#This function used to return the date with format for logging purpse
#------------------------------------------------------------------------
function dt 
{
    echo $(get-date -Format 'hh:mm:ss yyy/MM/dd')
}

#-----------------------------
#Check Json file valid or not
#-----------------------------
function checkJsonfile ($jsonfile)
{
    try {
        $jsondata = (Get-Content "$jsonFile" -Raw) 
        $jsondata  = ConvertFrom-Json $jsondata  -ErrorAction Stop
        $val = "Valid"
    } catch {
        $val = "Invalid"        
    }
    return $val
}

#---------------------------------------------------------------------------
#Validating Json file and get necessary values from Json configuration file
#---------------------------------------------------------------------------

$jsoncheck = checkJsonfile $Jsonfile  

if($jsoncheck -eq "Invalid"){
    echo  "$(dt) - Invalid Json configuration file, please check and fix the configuration file issue"  
    exit
}
else
{
    echo "$(dt) - Valid Json configuration file, Proceeding next"
}

$jsondata = (Get-Content "$Jsonfile" -Raw)
$jsondata = ConvertFrom-Json $jsondata

$lfolder = $jsondata.lfolder
$lfile = $jsondata.pyjobtracklog
$logfile = "$lfolder\$lfile"
$trackfolder = $jsondata.trackfolder
$scriptlocation = $jsondata.scriptlocation

if ((Get-ChildItem -Path $trackfolder -Filter *.flag).count -eq 0)
{
    exit
}

Get-ChildItem -Path $trackfolder -Filter *.flag | ForEach-Object {

    echo "$(dt) - Found $($_.name) flag" >> "$logfile"
       
    $val = Get-Content $_.FullName
    if ( $val -eq 'Completed')
    {
        Remove-Item -path $_.FullName
        $fname = $_.Name
        $foldername = [io.path]::GetFileNameWithoutExtension($fname)
        Remove-Item -path "$trackfolder\$foldername.ps1"            
        
        Remove-Item  "$($scriptlocation)\$($foldername)" -Force -Recurse -ErrorAction SilentlyContinue > $null

        echo "$(dt) - $($_.name) Job completed and removed all temp files" >> "$logfile"
    }
    else
    {
        echo "$(dt) - $($_.name) Job NOT completed, wait until next schedule" >> "$logfile"
    }
}