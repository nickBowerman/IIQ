
##############################################################################################
#
#
#
#  This script can be used to generate and output token/value pairs, as well as replace XML values with the tokens
#  It will need to be customized based on the connector type and tokens you wish to generate
#
#
#  Auther: Corey McCosh
#  Date: 4/3/2018
#
#
#
#############################################################################################


#############################################################################################
# There are many variables throughout this script in it's current state that need to be edited
# and heavily depend on the connector class and the tokens necessary for the environment you
# are working in
#############################################################################################


# This is the path with your un-tokenized connector XML files
# THEY SHOULD ALL BE OF THE SAME TYPE

$TargetPath = "C:\"

# Where to output tokenized XML
$TokenizedXMLPath = "C:\"

# Generate an output file for target.properties
$TokenOutput = "C:\target.properties"

# Gather the XML files into a variable to loop through
$ConnectorXML = Get-ChildItem -Path $TargetPath -Recurse -Filter *.xml | Sort-Object Name


#############################################################################################
# We should use the properties from the exported properties file in the other script to 
# determine "Global" tokens and then generate those and file-specific tokens below
#############################################################################################

# Now let's input our tokens and replace the XML values in a new file copy    
# Let's generate "global" tokens first

# An empty array for global tokens
$GlobalTokens = @()

# Here's a prefix for the token names
$GTPrefix = "%%GLOBAL_TOKEN_PREFIX_"

# Here are the tokens and their values declared
# The token value should be evaluated and pulled from the XML files for a specifc environment
# For exmaple, value may be the name of a rule or the password for your DEV environment

$GlobalToken1 = "" | Select Token,Value
$GlobalToken1.Token = $GTPrefix + 'CUSTOMIZATION_RULE%%='
$GlobalToken1.Value = "RULENAME"

$GlobalToken2 = "" | Select Token,Value
$GlobalToken2.Token = $GTPrefix + 'TOKEN_NAME%%='
$GlobalToken2.Value = "VALUE"

$GlobalToken3 = "" | Select Token,Value
$GlobalToken3.Token = $GTPrefix + 'TOKEN_NAME%%='
$GlobalToken3.Value = "VALUE"

$GlobalToken4 = "" | Select Token,Value
$GlobalToken4.Token = $GTPrefix + 'TOKEN_NAME%%='
$GlobalToken4.Value = "VALUE"

$GlobalToken5 = "" | Select Token,Value
$GlobalToken5.Token = $GTPrefix + 'TOKEN_NAME%%='
$GlobalToken5.Value = "VALUE"

$GlobalToken6 = "" | Select Token,Value
$GlobalToken6.Token = $GTPrefix + 'TOKEN_NAME%%='
$GlobalToken6.Value = "VALUE"

$GlobalToken7 = "" | Select Token,Value
$GlobalToken7.Token = $GTPrefix + 'TOKEN_NAME%%='
$GlobalToken7.Value = "VALUE"

$GlobalToken8 = "" | Select Token,Value
$GlobalToken8.Token = $GTPrefix + 'TOKEN_NAME%%='
$GlobalToken8.Value = "VALUE"

$GlobalToken9 = "" | Select Token,Value
$GlobalToken9.Token = $GTPrefix + 'TOKEN_NAME%%='
$GlobalToken9.Value = "VALUE"

# Comment out or delete extra tokens if you don't need them all

#$GlobalToken10 = "" | Select Token,Value
#$GlobalToken10.Token = $GTPrefix + 'TOKEN_NAME%%='
#$GlobalToken10.Value = "VALUE"


# Write out a header for the properties file if desired to the target.properties fle

$GlobalHeader = "#############################################################################`n##	<Connector Type> Global Tokens`n#############################################################################"
Out-File $TokenOutput -InputObject $GlobalHeader


# Add all of the global tokens to an array and spit out the array
# Comment out tokens that weren't declared

$GlobalTokens += $GlobalToken1, `
                    $GlobalToken2, `
                    $GlobalToken3, `
                    $GlobalToken4, `
                    $GlobalToken5, `
                    $GlobalToken6, `
                    $GlobalToken7, `
                    $GlobalToken8, `
                    $GlobalToken9
                    #$GlobalToken10

# Write out the global tokens and their values to target.properties file

Out-File $TokenOutput -InputObject $GlobalTokens -Append


#############################################################################################
# The below section performs the global token replacement as well as the declaration and
# replacements for different files
#############################################################################################

#Declare an empty token array for non-global tokens
$ConnectorTokens = @()

# Now we need to get individual token values and do our value replacements
foreach($Con in $ConnectorXML){

    # Declare the connector as an XML object variable
    [xml]$XmlCon = Get-Content $Con.PSPath

    # Aplication-specific token prefixes
    $ConnectorNamePrefix = ($XmlCon.Application.Name).ToUpper()
    $ConnectorNamePrefixFinal = $ConnectorNamePrefix -replace "-", "_" -replace " ", "_" -replace "\.", "_"

    #Global Replacements

    #############################################################################################
    # Some of the global tokens below are examples of XML nodes at different levels. Values
    # such as Owner/Remediator have a different format that entries contained in the 
    # <Attributes> map
    # These should all be used a reference and matched up to the global tokens you generated 
    # above
    #############################################################################################

    $GlobalReplace1 = $XmlCon.Application.CustomizationRule.Reference
    $GlobalReplace1.name = $GlobalToken1.Token -replace "=", ""
    
    $GlobalReplace2 = $XmlCon.Application.ManagedAttributeCustomizationRule.Reference
    $GlobalReplace2.name = $GlobalToken2.Token -replace "=", ""
    
    $GlobalReplace3 = $XmlCon.Application.AccountCorrelationConfig.Reference
    $GlobalReplace3.name = $GlobalToken3.Token -replace "=", ""
    
    $GlobalReplace4 = $XmlCon.Application.Remediators.Reference
    $GlobalReplace4.name = $GlobalToken4.Token -replace "=", ""

    $GlobalReplace5 = $XmlCon.Application.CorrelationRule.Reference
    $GlobalReplace5.name = $GlobalToken5.Token -replace "=", ""
   
    $GlobalReplace6 = $XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'user' }
    $GlobalReplace6.Value = $GlobalToken6.Token -replace "=", ""

    $GlobalReplace7 = $XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'password' }
    $GlobalReplace7.Value = $GlobalToken7.Token -replace "=", ""

    $GlobalReplace8 = $XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'IQServiceHost' }
    $GlobalReplace8.Value = $GlobalToken8.Token -replace "=", ""

    $GlobalReplace9 = $XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'IQServicePort' }
    $GlobalReplace9.Value = $GlobalToken9.Token -replace "=", ""

    #$GlobalReplace10 = $XmlCon.Application.ProxyApplication.Reference
    #$GlobalReplace10.name = $GlobalToken10.Token -replace "=", ""


    # An application name header for each section
    $Separator = '# ' + $XmlCon.Application.Name

    # Here are the tokens and their values declared, plus the value replacement action

    #############################################################################################
    # Again, the below tokens and replacements should be used as examples and modified for the 
    # population of files that you are performing replacements for.
    # There are different formats depending where the XML node value falls
    #############################################################################################

    $Token1 = "" | Select Token,Value
    $Token1.Token = '%%' + $ConnectorNamePrefixFinal + '_APP_OWNER%%='
    $Token1.Value = $XmlCon.Application.Owner.Reference.name
    # Change the value to the token
    $Replace1 = $XmlCon.Application.Owner.Reference
    $Replace1.name = $Token1.Token -replace "=", ""

    $Token2 = "" | Select Token,Value
    $Token2.Token = '%%' + $ConnectorNamePrefixFinal + '_MAP_TOKEN%%='
    $Token2.Value = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'MapEntryName' }).Value
    # Change the value to the token
    $Replace2 = $XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'MapEntryName' }
    $Replace2.Value = $Token2.Token -replace "=", ""

    $Token3 = "" | Select Token,Value
    $Token3.Token = '%%' + $ConnectorNamePrefixFinal + '_MAP_TOKEN%%='
    $Token3.Value = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'MapEntryName' }).Value
    # Change the value to the token
    $Replace3 = $XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'MapEntryName' }
    $Replace3.Value = $Token3.Token -replace "=", ""

    #$Token4 = "" | Select Token,Value
    #$Token4.Token = '%%' + $ConnectorNamePrefixFinal + '_APP_PROXY%%='
    #$Token4.Value = $XmlCon.Application.ProxyApplication.Reference.name
    ## Change the value to the token
    #$Replace4 = $XmlCon.Application.ProxyApplication.Reference
    #$Replace4.name = $Token4.Token -replace "=", ""

    #$Token5 = "" | Select Token,Value
    #$Token5.Token = '%%' + $ConnectorNamePrefixFinal + '_REMEDIATOR%%='
    #$Token5.Value = $XmlCon.Application.Remediators.Reference.name
    # Change the value to the token
    #$Replace5 = $XmlCon.Application.Remediators.Reference
    #$Replace5.name = $Token5.Token -replace "=", ""
    

    # Save a copy of the tokenized XML file
    $XmlCon.Save($TokenizedXMLPath+$Con.Name)

    # Add all of the custom tokens to the array
    $ConnectorTokens += $Separator, `
                        $Token1, `
                        $Token2, `
                        $Token3
                        #$Token4
                        #$Token5

}

# Append the individual token values for all XML files, increase the width and make sure no values are truncated
Out-File $TokenOutput -Width 4096 -InputObject $ConnectorTokens -Append


#We need to change the encoding type to UTF-8 (without BOM) to be compatible with IIQ imports
$FilesToReEncode = Get-ChildItem $TokenizedXMLPath
foreach($file in $FilesToReEncode){
$MyPath = $file.FullName
$MyFile = Get-Content $MyPath
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($MyPath, $MyFile, $Utf8NoBomEncoding)
}

# Just a reminder message
Write-Host "Check $TokenOutput for target.properties file. You may need to Find & Replace some white space"