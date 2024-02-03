using module Selenium

function Start-AsusSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [OpenQA.Selenium.IWebDriver] $Driver, 
        [Parameter(Mandatory)]
        [string] $Username, 
        [Parameter(Mandatory)]
        [string] $Password
    )

    Enter-SeUrl http://www.asusrouter.com -Driver $Driver | Out-Null
    $loginEl = Find-SeElement -Driver $Driver -Id login_username
    $passwdEl = Find-SeElement -Driver $Driver -Name login_passwd
    $buttonEl = Find-SeElement -Driver $Driver -By CssSelector ".button"

    Send-SeKeys -Element $loginEl $Username | Out-Null
    Send-SeKeys -Element $passwdEl $Password | Out-Null
    Invoke-SeClick -Element $buttonEl | Out-Null
}

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

function Get-AsusDHCPAssignments {
    [CmdletBinding()]
    param(
        [OpenQA.Selenium.IWebDriver] 
        [Parameter(Mandatory)] $Driver,
        [switch] $SkipNavigate
    )

    if(-not $SkipNavigate) {    
        Enter-SeUrl http://www.asusrouter.com/Advanced_DHCP_Content.asp -Driver $Driver | Out-Null
    }
    $table = Find-SeElement -Driver $Driver -By CssSelector '#dhcp_staticlist_table'
    $rows = $table.FindElementsByXPath('tbody/tr')
    $rows | ForEach-Object {
        $cells = $_.FindElementsByXPath('td')
        $iconDiv = $cells[0].FindElementByCssSelector('div .clientIcon')
        $nameAndMacSubcell = $cells[0].FindElementByCssSelector('tr :nth-child(2)') #nested tables!
        $clientNameDiv = $nameAndMacSubcell.FindElementByCssSelector(':nth-child(1)')
        $macDiv = $nameAndMacSubcell.FindElementByCssSelector(':nth-child(2)')
        [PSCustomObject]@{
            IconName = $iconDiv.GetAttribute('class').Split(' ')[1]
            ClientName = $clientNameDiv.Text
            IPAddress = $cells[1].Text
            ClientMAC = $macDiv.Text
            DNSServer = $cells[2].Text
            HostName = $cells[3].Text
        }
    }
}

function Get-AsusDHCPAssignment {
    [CmdletBinding()]
    param(
        [OpenQA.Selenium.IWebDriver] 
        [Parameter(Mandatory)] $Driver,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $ClientMAC,
        [switch] $SkipNavigate
    )
    Get-AsusDHCPAssignments $Driver -SkipNavigate:$SkipNavigate] |
        Where-Object {
            $_.ClientMAC -eq $ClientMAC
        }
}

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
    } 
    process {
        if(Get-AsusDHCPAssignment $Driver $ClientMAC -SkipNavigate) {
            Write-Warning "ClientMAC '$ClientMAC' already set. Skipping..."
            #TODO: drop and re-add functionality.
            return
        }

        if($DNSServer -eq 'Default') {
            $DNSServer = ''
        }

        Write-Verbose "Enabling manual assignment..."
        Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By Name dhcp_static_x) | Out-Null

        Write-Verbose "Setting values that are done on create for MAC '$ClientMac'..."
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
        Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By CssSelector ".btn_add") | Out-Null

        if($IconName -or $ClientName) {
            Write-Verbose "Setting ClientName/Icon for MAC '$ClientMac'..."
            #find parent row
            $macRowEl = Find-SeElement -Driver $Driver -By XPath "//tr[td/div[text()='$ClientMAC']]"   
            if($ClientName) {
                Send-SeKeys -Keys $ClientName -Element (Find-SeElement -Driver $Driver -By Id card_client_name) | Out-Null
            }
            if($IconName) {
                #show icon menu
                Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By Id card_changeIconTitle) | Out-Null
                #pick icon
                Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By ClassName $IconName) | Out-Null
            }
            #apply
            Invoke-SeClick -Element ($macRowEl.FindElementByCssSelector('div.clientIcon')) | Out-Null
        }
    } 
    end {
        Write-Verbose "Applying all changes..."
        Invoke-SeClick -Element (Find-SeElement -Driver $Driver -By CssSelector "div.apply_gen input.button_gen") | Out-Null
        Write-Verbose "Done."
    }
}