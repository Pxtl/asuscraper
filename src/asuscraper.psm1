using module Selenium

#.SYNOPSIS
# Connect to http://www.asusrouter.com and log-in with the given username and
# password.
#
#.DESCRIPTION
# Uses a Selenium driver to remote-control a browser window and connect to your
# router admin page at www.asusrouter.com, and logs in using the given username
# and password.  This means there is the security issue - if you do *not* trust
# the router page hosted at www.asusrouter.com, DO NOT USE THIS TOOL.
function Start-AsusSession {
    [CmdletBinding()]
    param(
        # Any standard Selenium driver that is compatible with the AsusWRT server.
        [Parameter(Mandatory)]
        [OpenQA.Selenium.IWebDriver] $Driver, 
        # Your AsusWRT username
        [Parameter(Mandatory)]
        [string] $Username, 
        # Your AsusWRT password
        [Parameter(Mandatory)]
        [string] $Password
    )

    $driver.Manage().Timeouts().ImplicitWait = 0

    Enter-SeUrl http://www.asusrouter.com -Driver $Driver | Out-Null
    $loginEl = Find-SeElement -Driver $Driver -Id login_username -Wait
    $passwdEl = Find-SeElement -Driver $Driver -Name login_passwd
    $buttonEl = Find-SeElement -Driver $Driver -By CssSelector ".button"

    Send-SeKeys -Element $loginEl $Username | Out-Null
    Send-SeKeys -Element $passwdEl $Password | Out-Null
    Invoke-SeClick -Element $buttonEl | Out-Null
}


#.SYNOPSIS
# Navigate to the main network map pager and download all entries from the
# client list.
function Get-AsusClientInfo {
    [CmdletBinding()]
    param(
        [OpenQA.Selenium.IWebDriver] 
        [Parameter(Mandatory)]$Driver
    )

    Enter-SeUrl http://www.asusrouter.com/index.asp -Driver $Driver | Out-Null
    Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By XPath '//input[@value="View List"]') | Out-Null
    Start-Sleep 1 #need a moment to load the list

    $table = Find-SeElement -Driver $Driver -By CssSelector '#clientlist_viewlist_block table.list_table'
    $rows = $table.FindElementsByXPath('tbody/tr')
    $rows | ForEach-Object {
        $cells = $_.FindElementsByXPath('td')
        $iconDiv = $cells[1].FindElementByCssSelector('div')
        [PSCustomObject]@{
            IconTitle = $iconDiv.GetAttribute('title')
            IconName = $iconDiv.GetAttribute('class').Split(' ')[1]
            ClientName = $cells[2].Text
            ClientIP = $cells[3].Text.Split("`n")[0].Trim()
            ClientIPType = $cells[3].Text.Split("`n")[1].Trim()
            ClientMAC = $cells[4].Text
        }
    }
}


#.SYNOPSIS
# Uses Selenium to navigate to the WAN/DHCP page of your ASUS admin page and
# extract all manual DHCP assignments as PSCustomObjects.
#
#.OUTPUTS
# A list of PSCustomObjects with the following members:
# - IconName (not user-friendly, usually of the form typeNN eg type60 for a smartbulb)
# - ClientName
# - IPAddress
# - ClientMAC
# - DNSServer
# - HostName
#
#.EXAMPLE
# To export the result into CSV:
# ```
# Get-DHCPManualAssignments $Driver | 
#   Export-Csv .\myfiles\DHCPManualAssignments.csv -NoTypeInformation 
# ```
function Get-AsusDHCPAssignments {
    [CmdletBinding()]
    param(
        # Any standard Selenium driver that is compatible with the AsusWRT server.
        [OpenQA.Selenium.IWebDriver] 
        [Parameter(Mandatory)] $Driver,
        # If set, the command will assume the DHCP config page is already
        # visible and will skip the navigation step.
        [switch] $SkipNavigate
    )

    if(-not $SkipNavigate) {    
        Enter-SeUrl http://www.asusrouter.com/Advanced_DHCP_Content.asp -Driver $Driver | Out-Null
    }
    
    $rowCount = (Find-SeElement -Driver $Driver -By XPath "//table[@id='dhcp_staticlist_table']/tbody/tr" -Wait | Measure-Object).Count
    #we can't iterate across the raw table because it will get rebuilt, so we'll fetch the row instead.
    1..$rowCount | ForEach-Object {
        $row = Find-SeElement -Driver $Driver -By XPath "//table[@id='dhcp_staticlist_table']/tbody/tr[position()=$_]" -Wait
        $cells = $row.FindElementsByXPath('td')
        if(($cells | Measure-Object).Count -eq 1) {
            Write-Warning "Found one big 'no data in table' cell." + 
                "DHCP Manual Assignments table is empty." + 
                "Disregard this warning if that's expected."

            return;
        }
        $iconEl = $cells[0].FindElementByCssSelector('div.clientIcon, img.imgUserIcon_card')
        $nameAndMacSubcell = $cells[0].FindElementByCssSelector('tr :nth-child(2)') #nested tables!
        $clientNameDiv = $nameAndMacSubcell.FindElementByCssSelector(':nth-child(1)')
        $macDiv = $nameAndMacSubcell.FindElementByCssSelector(':nth-child(2)')
        $iconName = ''
        if($iconEl.TagName -eq 'div') {
            #if it's a div, then it's a predefined image.  If it's an img, it's just dynamic and can't be stored.
            $iconName = $iconEl.GetAttribute('class').Split(' ')[1]
        }

        [PSCustomObject]@{
            IconName = $iconName
            ClientName = $clientNameDiv.Text
            IPAddress = $cells[1].Text
            ClientMAC = $macDiv.Text
            DNSServer = $cells[2].Text
            HostName = $cells[3].Text
        }
    }   
}


#.SYNOPSIS
# Uses Selenium to navigate to the WAN/DHCP page of your ASUS admin page and
# extract a single manual DHCP assignments as PSCustomObject for the given MAC
# address.
#
# See Get-AsusDHCPAssignments for more details.
function Get-AsusDHCPAssignment {
    [CmdletBinding()]
    param(
        [OpenQA.Selenium.IWebDriver] 
        [Parameter(Mandatory)] $Driver,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $ClientMAC,
        [switch] $SkipNavigate
    )
    Get-AsusDHCPAssignments $Driver -SkipNavigate:$SkipNavigate |
        Where-Object {
            $_.ClientMAC -eq $ClientMAC
        }
}


#.SYNOPSIS
# Uses Selenium to navigate to the WAN/DHCP page of your ASUS admin page, enable
# manual DHCP binding, and load in the given parameters into the page.
#
#.DESCRIPTION
# This command allows you to load-in manual DHCP assignments into your ASUSWRT
# router admin pages.  This is a pipeline command.  At the beginning of the
# pipeline it will execute a navigate step, and at completion it will execute
# the "apply" button that will result in a router settings update operation.
#
#.EXAMPLE
# To export the result into CSV:
# ```
# Import-Csv .\myfiles\DHCPManualAssignments.csv | 
#    Set-DHCPManualAssignments $Driver   
# ```
function Set-AsusDHCPAssignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] 
        [OpenQA.Selenium.IWebDriver] $Driver,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $ClientMAC,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $IPAddress,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $IconName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $DNSServer,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $HostName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ClientName
    )
    begin {
        Enter-SeUrl http://www.asusrouter.com/Advanced_DHCP_Content.asp -Driver $Driver | Out-Null
        Write-Verbose "Enabling manual assignment..."
        Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By CssSelector 'input[name="dhcp_static_x"][value="1"]' -Wait) | Out-Null
    } 
    process {
        #helper function to find the MAC address row.
        function Get-MACRow() {
            param()

            #within the static-list table, find the row that contains the div that contain the clientMAC.
            Find-SeElement -Driver $Driver -Timeout 0.1 `
                -By XPath "//table[@id='dhcp_staticlist_table']/tbody/tr[.//div[text()='$ClientMAC']]"
        }

        #brief sleep needed because just after load the Get call can fail because the table is still being rebuilt.
        Start-Sleep -Milliseconds 250
        Write-Verbose "Checking if '$ClientMAC' is already set..."
        $macRowEl = Get-MACRow
        if($macRowEl) {
            Write-Verbose "ClientMAC '$ClientMAC' is already set. Removing..."
            Invoke-SeClick -Element ($macRowEl.FindElementByCssSelector(".remove_btn")) | Out-Null
            Start-Sleep -Milliseconds 250
        }

        if($DNSServer -eq 'Default') {
            $DNSServer = ''
        }

        Write-Verbose "Setting insert values for MAC '$ClientMac'..."
        #set values that are done on create
        Send-SeKeys -Keys $ClientMAC -Element (Find-SeElement -Driver $Driver -By Name dhcp_staticmac_x_0)
        Send-SeKeys -Keys $IPAddress -Element (Find-SeElement -Driver $Driver -By Name dhcp_staticip_x_0)
        if($DNSServer) {
            Send-SeKeys -Keys $DNSServer -Element (Find-SeElement -Driver $Driver -By Name dhcp_dnsip_x_0)
        }
        if($HostName) {
            Send-SeKeys -Keys $HostName -Element (Find-SeElement -Driver $Driver -By Name dhcp_hostname_x_0)
        }

        Write-Verbose "Adding MAC '$ClientMac' to table..."
        Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By CssSelector ".add_btn") | Out-Null

        if($IconName -or $ClientName) {
            Start-Sleep -Milliseconds 250
            Write-Verbose "Finding row that was just added for MAC '$ClientMac' to set ClientName/Icon..."
            $macRowEl = Get-MACRow
            if(-not $macRowEl) {
                Write-Warning "MAC address addition for '$ClientMAC' failed."
                return
            }
            # icon DOM varies between div.clientIcon vs img.imgUserIcon_card edepending on how it was loaded.
            Write-Verbose "Opening detail window to set ClientName/Icon for '$ClientMac'..."
            Invoke-SeClick -Element ($macRowEl.FindElementByCssSelector('div.clientIcon, img.imgUserIcon_card'))
            if($ClientName) {
                $clientNameEl = (Find-SeElement -Driver $Driver -By Id card_client_name)
                $clientNameEl.Clear()
                $clientNameEl.SendKeys($ClientName) 
            }
            if($IconName) {
                #show icon menu
                Invoke-SeClick -Element  (Find-SeElement -Driver $Driver -By Id card_changeIconTitle) | Out-Null
                #pick icon
                Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By CssSelector "#card_custom_image .$IconName") | Out-Null
            }
            #apply
            Write-Verbose "Applying ClientName/Icon for MAC '$ClientMac'..."
            Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By Id card_client_confirm) | Out-Null
        }
        Start-Sleep -Milliseconds 250
    } 
    end {
        Write-Verbose "Final apply/submit all changes..."
        Start-Sleep -Milliseconds 2000 #sometimes complains about button being obscured.  give it time.
        Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By CssSelector "div.apply_gen input.button_gen" -Wait) | Out-Null
        Write-Verbose "Done."
    }
}