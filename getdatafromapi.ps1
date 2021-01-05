#----------------------------------------------------------------------------------------------
#This script will call API and get the data
#Once get the data it will parse the content and check whether particular string exit or not
#If string exist then call and execute the file which is existing in same system
#If string Not exist then do nothing
#Script will read all necessary variable values from Json config file
#----------------------------------------------------------------------------------------------

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

#Set values to variables
$jsondata = (Get-Content "$Jsonfile" -Raw)
$jsondata = ConvertFrom-Json $jsondata

$apiUrl = $jsondata.apiUrl
$apiKey = $jsondata.apiKey
$scriptlocation = $jsondata.scriptlocation
$startupscript = "index.py"
$lfolder = $jsondata.lfolder
$lfile = $jsondata.lfile
$logfile = "$lfolder/$lfile"
$searchstring = $jsondata.searchstring
$trackfolder = $jsondata.trackfolder

#Create necessary log and track fodler
if (!(Test-Path -Path "$lfolder")) {
    New-Item -name "$lfolder" -ItemType Directory  -ErrorAction SilentlyContinue  >$null
}

if (!(Test-Path -Path "$logfile")) {
    New-Item -name "$logfile" -ItemType File  -ErrorAction SilentlyContinue  >$null
}

if (!(Test-Path -Path "$trackfolder")) {
    New-Item -Name "$trackfolder" -ItemType Directory -ErrorAction SilentlyContinue  >$null
}

if (!(Test-Path -Path $lfolder))
{
    new-item -Path $lfolder -ItemType Directory -ErrorAction SilentlyContinue  >$null
}

#-----------------------------------------------------------------------------
#This function used to call the API URL with access details and get the data
#Once get the data from API it return to caller for further processing
#-----------------------------------------------------------------------------
function getdatafromAPI
{
    $response = Invoke-WebRequest -Uri "$apiUrl" -Method GET -UseBasicParsing
    return $response
}

#-----------------------------------------------
#Infinite loop keep loop until stop the service
#-----------------------------------------------
    
$data =  getdatafromAPI

#Match the search string with API return data

if ($data -notmatch "$searchstring")
{
    #Matched, do nothing, just wait for interval and move next cycle
    echo "$(dt) - Search string value NOT matched - do nothing, waiting $interval seconds" >> "$logfile" 
    exit
}
else
{       

    $global:camfolder = @()
    $content = $data.Content
    $content = $content  -replace '^\['," "
    $content = $content  -replace '\]$'," "
    $content = $content  -replace '\\',""
    $content = $content  -replace '"',""
    $content = $content  -replace ' ',""
    $scriptarry = $content -split("\,\[") 
    $scriptarry = $scriptarry[1..($scriptarry.Length-1)] 
    
    $scriptarry  | ForEach-Object{
    $content = $_ -replace '\['," "
    $content = $content  -replace '\]'," "
    $content = $content  -replace '\\',""
    $content = $content  -replace '"',""
    $content = $content  -replace ' ',""
    $arrayval = $content -split(",")                  
    $arrayval1  = $arrayval[2..($arrayval.Length-1)]   
    $folder = $arrayval[0]                    
    $camfolder += $folder                
    $url = $arrayval[1]  
                
    echo "$(dt) - Checking python [ $($folder) ] job flag whether job running or not" >> "$logfile"     

    if (!(Test-Path -Path "$($trackfolder)/$($folder).flag"))
    {
        echo "$(dt) - Python job [ $($folder) ] not running, proceed next" >> "$logfile"     

        #Creating folder under download locatoin and downloading the files
        if (!(Test-Path -Path "$($scriptlocation)/$($folder)"))
        {        
            echo "$(dt) - $folder - Folder not exist, create folder and download the files" >> "$logfile" 

            New-Item -Path $scriptlocation -Name $folder -ItemType Directory -ErrorAction Stop              
        
            #Downloading the files
            $arrayval1  | ForEach-Object{
                $scriptname  = $_
                $downloadURL = "$($url)$($scriptname)"  

                $downloadURL = $downloadURL -replace "http:", "https:"              
            
                echo "$(dt) - Downloading file - $($downloadURL)" >> "$logfile"         
                
                try
                {
                   Invoke-WebRequest -Uri "$downloadURL" -OutFile "$($scriptlocation)/$($folder)/$($scriptname)" -ErrorAction stop
                }
                catch
                {
                    Write-Warning $Error[0] >> "$logfile" 
                }
            }
                                  
            #Only when call powershell script        
            #powershell.exe "$script"

            echo "$(dt) - Starting the package" >> "$logfile"       

            if ([System.IO.Path]::GetExtension("$startupscript") -eq ".exe") 
            {
                try
                {
                    Start-Process -FilePath "$($scriptlocation)/$($folder)/$($startupscript)"                
                }
                catch
                {
                    Write-Warning $Error[0] >> "$logfile" 
                }
            }               

            #Only when call python
            if ([System.IO.Path]::GetExtension("$startupscript") -eq ".py") 
            {
                try
                {

                    "$($trackfolder)/$($folder).flag"

                    echo "$(dt) - $($scriptlocation)/$($folder)/$($startupscript)" >> "$logfile"  
                 
                    echo "cd $($scriptlocation)/$($folder)/" > "$($trackfolder)/$($folder).ps1"
                    #$cid = $folder.Substring($folder.get_Length()-2)
					$cid = ($folder) -replace '.*?(\d+)$','$1'
				    echo "python3 $($startupscript) $($cid)" >> "$($trackfolder)/$($folder).ps1"
                    echo "echo 'Completed' > '$($MyDir)/$($trackfolder)/$($folder).flag'" >> "$($trackfolder)/$($folder).ps1"                                        
                    echo "" > "$($trackfolder)/$($folder).flag"								
				
                    echo "$(dt) - $($folder).flag file created" >> "$logfile"  
              
                    $argList = "-file `"$($trackfolder)/$($folder).ps1`""
                    Start-Process pwsh -argumentlist $argList

                }
                catch
                {
                    Write-Warning $Error[0] >> "$logfile" 
                }
            }
                echo "$(dt) - Package [ $($trackfolder)/$($folder).ps1 ] triggered sucessfully " >> "$logfile"             
        }
    }
    else
    {
        echo "$(dt) - [ $($folder).flag ] exist, wait until it finish " >> "$logfile"                 
    }
    }
}