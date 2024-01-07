#!/bin/bash
# 2023/12/17
# Bash script utilizing Azure CLI to deploy an Azure Infrastructure, 
# setting up a static web app enabling users to upload images and obtain descriptions using Azure Vision


##################################################################

######   THIS SCRIPT ISN'T FINISHED, IT SHOULD NOT BE RUN   ######
######  So far, it creates most of the resources, but the   ######
######        web application isn't finished, and the       ######
######       function outbound binding to Azure Cosmos      ######
######                  DB doesn't work                     ######

##################################################################

################## Variable block ##################
# basic stuff
randomIdentifier=$((RANDOM*RANDOM))
location="francecentral"
resourceGroup="rg-imagerecognition-$randomIdentifier"
tag="website-to-upload-images-and-get-descriptions"
# storage account
storage_account="storage$randomIdentifier"
container="container-imagerecognition-$randomIdentifier"
# web app
web_app_name="webappnameimagerecognition$randomIdentifier"
app_service_plan_name="app-service-plan-imagerecognition-$randomIdentifier" 
app_service_plan_sku="FREE"
webapp_runtime='NODE:18LTS'
# computer vision
vision_account_name="imagerecognition-computervision-acc-$randomIdentifier"
# cosmos db
cosmosdb_account="cosmosdb-account-imagerecognition-$randomIdentifier"
cosmosdb_database="cosmosdb-database-imagerecognition-$randomIdentifier"
cosmosdb_container="cosmosdb-container-imagerecognition-$randomIdentifier"
# function app
functionApp="func-imagerecognition-$randomIdentifier"
function_runtime="python"
skuStorage="Standard_LRS"
functionsVersion="4"

# Connect to Azure Cloud (interactive mode)
az login

# Create a Resource Group
echo "Creating $resourceGroup in $location..."
az group create \
    --name $resourceGroup \
    --location "$location" \
    --tags $tag

################## STORAGE BACKEND CREATION ##################

# Create a Storage Account for the function app. 
echo "Creating $storage_account"
az storage account create \
    --name $storage_account \
    --location "$location" \
    --resource-group $resourceGroup \
    --sku $skuStorage \
    --allow-blob-public-access true

# Create a Container for image storage 
echo "Creating $container"
az storage container create \
    --name $container \
    --account-name $storage_account \
    --fail-on-exist \
    --public-access blob

# Setup CORS rule for Azure the Storage Account 
az storage cors add \
    --methods GET POST PUT OPTIONS \
    --origins '*' \
    --allowed-headers '*' \
    --exposed-headers '*' \
    --services b \
    --account-name $storage_account 

# Get Storage Account connection string 
storageConnectionString=$(az storage account show-connection-string \
    --name $storage_account \
    --resource-group $resourceGroup \
    --output tsv)
echo "storageConnectionString: $storageConnectionString"

# # Update Storage Account property to enable static website
# echo "Update storage property"
# az storage blob service-properties update \
#     --account-name $storage_account \
#     --static-website \
#     --index-document index.html

################## WEB APP CREATION ##################

# # /!\ This does not generate a token with enough/the right privilege /!\
# container_sas_token=$(az storage container generate-sas \
#     --account-name $storage_account  \
#     --name $container \
#     --permissions acdlrw \
#     --output tsv)
# echo "sas_token: $container_sas_token"

# container_url=$(az storage account show \
#     --name $storage_account \
#     --resource-group $resourceGroup \
#     --query "primaryEndpoints.blob" \
#     --output tsv)
# echo "container_url: $container_url"

# container_sas_url="$container_url?$container_sas_token"
# sed -i "s|<SAS_URL>|$container_sas_token|g" index.js
sed -i "s|<container-name>|$container|g" index.js

# # Temporary workaround :
# Update <placeholder> with your Blob service SAS URL string within the file webapp/index.js
# On Azure Portal, SAS URL can be found under Storage Account > Shared Access Signature/Signature d'accès partagé :
echo "Sorry for that..."
echo "Manually update <placeholder> with your Blob service SAS URL string within the file webapp/index.js (line ~20)"
echo "Then press Enter twice to continue."
read -r
read -r

# Create an app service plan
az appservice plan create \
    --name $app_service_plan_name \
    --resource-group $resourceGroup \
    --sku $app_service_plan_sku 

# Create the web app in the app service
az webapp create \
    --name $web_app_name \
    --runtime $webapp_runtime \
    --plan $app_service_plan_name \
    --resource-group $resourceGroup 

cd webapp
az webapp up \
    --name $web_app_name \
    --resource-group $resourceGroup \
    --plan $app_service_plan_name \
    --sku $app_service_plan_sku 
cd ..


################## COMPUTER VISION SETUP ##################

az cognitiveservices account create \
    --resource-group $resourceGroup \
    --name $vision_account_name \
    --location $location \
    --kind ComputerVision \
    --sku S1 \
    --yes

vision_account_region=$(az cognitiveservices account show \
    --resource-group $resourceGroup \
    --name $vision_account_name \
    --query location \
    --output tsv)
echo $vision_account_region

vision_account_key=$(az cognitiveservices account keys list \
    --resource-group $resourceGroup \
    --name $vision_account_name \
    --query key1 \
    --output tsv)
echo $vision_account_key

################## COSMOS DB CREATION ##################

# Create an Azure Cosmos DB database account.
echo "Creating $cosmosdb_account"
az cosmosdb create \
    --name $cosmosdb_account \
    --resource-group $resourceGroup

# Create an Azure Cosmos DB database.
az cosmosdb sql database create \
    --account-name $cosmosdb_account \
    --name $cosmosdb_database \
    --resource-group $resourceGroup

# Create container is Azure Cosmos DB
az cosmosdb sql container create \
    --account-name $cosmosdb_account \
    --database-name $cosmosdb_database \
    --name $cosmosdb_container \
    --partition-key-path "/id" \
    --resource-group $resourceGroup

# Get the Azure Cosmos DB endpoint.
cosmosdb_endpoint=$(az cosmosdb show \
    --name $cosmosdb_account \
    --resource-group $resourceGroup \
    --query "documentEndpoint" \
    --output tsv)
echo "cosmosdb_endpoint: $cosmosdb_endpoint"

# Get the Azure Cosmos DB key.
cosmosdb_key=$(az cosmosdb keys list \
    --name $cosmosdb_account \
    --resource-group $resourceGroup \
    --query primaryMasterKey \
    --output tsv)
echo "cosmosdb_key: $cosmosdb_key"

# Get the Azure Cosmos DB connection String
cosmosdb_connection_string=$(az cosmosdb keys list \
    --type connection-strings \
    --resource-group $resourceGroup \
    --name $cosmosdb_account \
    --query "connectionStrings[?keyKind == 'Primary'].connectionString" \
    --output tsv)
echo "cosmosdb_connection_string: $cosmosdb_connection_string"


################## FUNCTION APP CREATION ##################

# Create a serverless Function App in the resource group.
# Update ressource in files
#local.settings.json
sed -i "s|<storageConnectionString>|$storageConnectionString|g" ./azure_function/local.settings.json
sed -i "s|<cosmosdb_connection_string>|$cosmosdb_connection_string|g" ./azure_function/local.settings.json
#function.json
sed -i "s|<container-name>|$container|g" ./azure_function/function.json
sed -i "s|<cosmosdb_database>|$cosmosdb_database|g" ./azure_function/function.json
sed -i "s|<cosmosdb_container>|$cosmosdb_container|g" ./azure_function/function.json
#function_app.py
sed -i "s|<cosmosdb_database>|$cosmosdb_database|g" ./azure_function/function_app.py
sed -i "s|<cosmosdb_container>|$cosmosdb_container|g" ./azure_function/function_app.py
sed -i "s|<container-name>|$container|g" ./azure_function/function_app.py
sed -i "s|<vision_account_key>|$vision_account_key|g" ./azure_function/function_app.py
sed -i "s|<vision_account_region>|$vision_account_region|g" ./azure_function/function_app.py

echo "Creating $functionApp"
az functionapp create \
    --name $functionApp \
    --resource-group $resourceGroup \
    --storage-account $storage_account \
    --consumption-plan-location "$location" \
    --functions-version $functionsVersion \
    --runtime $function_runtime \
    --os-type Linux

# Configure function app settings to use the Azure Cosmos DB connection string.
az functionapp config appsettings set \
    --name $functionApp \
    --resource-group $resourceGroup \
    --setting CosmosDB_Endpoint="$cosmosdb_endpoint" CosmosDB_Key="$cosmosdb_key"

# Get the Azure Function URL
functionAppURL=$(az functionapp show \
    --name $functionApp \
    --resource-group $resourceGroup \
    --query "defaultHostName" \
    --output tsv)
echo "FunctionAppURL: $functionAppURL"

cd ./azure_function/
func azure functionapp publish "$functionApp" --force
cd ..

# # Clean Azure resources
# az group delete --name $resourceGroup -y