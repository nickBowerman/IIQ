##############################################################################################
#
#
#
#  This script can be used to output as CSV the values of certain XML nodes
#  It is recommended to use this when determining what values can be declared as "Global Tokens"
#  vs. "Inidividual tokens" in the XML-Token-Replacement script
#  It will need to be customized based on the connector type and values you wish to generate
#
#
#  Auther: Corey McCosh
#  Date: 4/3/2018
#
#
#
#############################################################################################

# This is the path with your un-tokenized connector XML files
# THEY SHOULD ALL BE OF THE SAME TYPE
$TargetPath = "C:\"

# Report path
$ConnectorPropsReportPath = "C:\XML-Properties.csv"

# Gather the XML files into a variable to loop through
$ConnectorXML = Get-ChildItem -Path $TargetPath -Recurse -Filter *.xml

# Declare empty array for reporting out properties
$ConnectorProps = @()

# Loop through connector XML to get Properties
foreach($Con in $ConnectorXML){
    # Declare the connector as an XML object variable
    [xml]$XmlCon = Get-Content $Con.PSPath

    # Set the values for your reporting array. 

    #############################################################################################
    # Nearly all of the values below will need to be customized based on the connector class
    # that you are working with
    #############################################################################################

    $Props = "" | Select Name,ApplicationType,CorrelationConfig,CorrelationRule,CustomizationRule,ManagedAttributeCustomizationRule,ProxyApplication,Owner,Remediator, `  #Most of these are on every connector class
                    server,user,password,IQServiceHost,IQServicePort     # Connector class specific SELECT

    # These attributes are standard for most connector types
    $Props.Name = $XmlCon.Application.Name
    $Props.ApplicationType = $XmlCon.Application.Type
    $Props.CorrelationConfig = $XmlCon.Application.AccountCorrelationConfig.Reference.name
    $Props.CorrelationRule = $XmlCon.Application.CorrelationRule.Reference.name
    $Props.CustomizationRule = $XmlCon.Application.CustomizationRule.Reference.name
    $Props.ManagedAttributeCustomizationRule = $XmlCon.Application.ManagedAttributeCustomizationRule.Reference.name
    $Props.ProxyApplication = $XmlCon.Application.ProxyApplication.Reference.name
    $Props.Owner = $XmlCon.Application.Owner.Reference.name
    $Props.Remediator = $XmlCon.Application.Remediators.Reference.name
    
    # These attributes are pulled from the <Attributes><Map> node and vary by connector type
    $Props.password = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'password' }).Value  
    $Props.server = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'server' }).Value  
    $Props.user = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'user' }).Value
    $Props.IQServiceHost = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'IQServiceHost' }).Value
    $Props.IQServicePort = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'IQServicePort' }).Value 
    #$Props.driverClass = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'driverClass' }).Value
    #$Props.provisionRule = ($XmlCon.Application.Attributes.Map.Entry | Where-Object { $_.Key -eq 'provisionRule' }).Value


    # Add your attributes to the array
    $ConnectorProps += $Props
}


$ConnectorProps | Export-Csv $ConnectorPropsReportPath -NoTypeInformation