#!/usr/bin/env bash

##? This script will help you to create terraform remote azurerm backend resources.
##? Please go through the notifications/notes available in the script.
##? Script will create and check if existing: Resource Group, Storage Account, and Storage Container.
##? To Override the names for the resources, kindly set the respective environment variables.
##? LOCATION :: RESOURCE_GROUP_NAME :: STORAGE_ACCOUNT_NAME :: CONTAINER_NAME

# https://mywiki.wooledge.org/BashFAQ/105 :: ref to "So-called strict mode"
set -euo pipefail

## Colours output
YELLOW="$(tput -Txterm setaf 3)"
RESET="$(tput -Txterm sgr0)"
GREEN="$(tput -Txterm setaf 2)"
RED="$(tput -Txterm setaf 1)"

## Banner for the script
cat <<-EOF
${RED}

################################################################
### IMPORTANT NOTE ###
################################################################
${RESET}

Please login to Azure first using az login and set up the correct Azure subscription"
az login                                         => Login to azure cli."
az account list --output table                   => Check which Azure accounts/subscriptions you have."
az account set -s <your-azure-subscription-id>   => Set the right azure account."

EOF

cat <<-EOF

${YELLOW}
Default Values for location, resource group, storage account, and container name are set...
To override the values, please export below environment variables with the required values:

### "YOUR VALUE" HAS TO BE REPLACED WITH YOUR REQUIRED INPUT ###

export LOCATION="YOUR VALUE"
export RESOURCE_GROUP_NAME="YOUR VALUE"
export STORAGE_ACCOUNT_NAME="YOUR VALUE"
export CONTAINER_NAME="YOUR VALUE"
export KEY_NAME="YOUR VALUE"
${RESET}
EOF

echo -n "${GREEN}Kindly Read the above Info and Press yes or y to continue: ${RESET}"
read -r RESPONSE
echo ""

# LOWER_CASE_RESPONSE="$(echo "$RESPONSE" | tr '[:upper:]' '[:lower:]')"
LOWER_CASE_RESPONSE="$(echo "$RESPONSE" | awk '{ print tolower($1) }')"

## Default Values
LOCATION=${LOCATION:-"westeurope"}
RESOURCE_GROUP_NAME=${RESOURCE_GROUP_NAME:-"rg-terraform-backend-001"}
STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME:-"stguniquename001"}
CONTAINER_NAME=${CONTAINER_NAME:-"tfstate"}
KEY_NAME=${KEY_NAME:-"terraform.tfstate"}


if [[ "$LOWER_CASE_RESPONSE" == "yes" || "$LOWER_CASE_RESPONSE" == "y" ]]; then

  printf "#######################################################################\n"
  printf "#### Creating Storage Account for Terraform backend configuration ####\n"
  printf "#######################################################################\n\n"
  if [[ $(command -v az) ]]; then
    # Check and Create a resource group
    RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP_NAME")
    if [[ $RG_EXISTS != "true" ]]; then
      echo "${GREEN}-> Creating Resource Group with name $RESOURCE_GROUP_NAME${RESET}"
      az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    else
      echo "${YELLOW}-> Resource group with name $RESOURCE_GROUP_NAME already exists. Please provide another name.${RESET}"
    fi

    # Create and Check the storage account
    if ! az storage account show --resource-group "$RESOURCE_GROUP_NAME" --name "$STORAGE_ACCOUNT_NAME" &>/dev/null; then
      echo "${GREEN}-> Creating Storage Account with name $STORAGE_ACCOUNT_NAME${RESET}"
      az storage account create --resource-group "$RESOURCE_GROUP_NAME" --name "$STORAGE_ACCOUNT_NAME" --sku Standard_LRS --encryption-services blob
    else
      echo "-${YELLOW}> Storage Account with name $STORAGE_ACCOUNT_NAME already exists, please use another globally unique name${RESET}"
    fi

    # Get storage account key, Create and Check blob container
    ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" -o tsv)
    if ! az storage container show --account-name "$STORAGE_ACCOUNT_NAME" --name "$CONTAINER_NAME" --account-key "$ACCOUNT_KEY" &>/dev/null; then
      echo "${GREEN}-> Creating Storage Container with name $CONTAINER_NAME in storage account $STORAGE_ACCOUNT_NAME${RESET}"
      az storage container create --name "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$ACCOUNT_KEY"
    else
      echo -e "${YELLOW}-> Storage Container with name $CONTAINER_NAME already exists in storage account $STORAGE_ACCOUNT_NAME \n${RESET}"
    fi

    echo ""
    echo "Resource Group Name: ${GREEN}$RESOURCE_GROUP_NAME ${RESET}"
    echo "Storage Account Name: ${GREEN}$STORAGE_ACCOUNT_NAME${RESET}"
    echo "Terraform State Container Name: ${GREEN}$CONTAINER_NAME${RESET}"
    echo -e "Backend Key: ${GREEN}$KEY_NAME${RESET}\n"


    echo "################################################################"
    echo "${RED}Configure the terraform backend with the below configurations${RESET}"
    printf "##############################################################\n\n"

    ## Helper to print the terraform backend configuration and use it as it is.
    cat <<-EOF
      ${GREEN}
terraform {
  backend "azurerm" {
    resource_group_name  = "${RESOURCE_GROUP_NAME}"
    storage_account_name = "${STORAGE_ACCOUNT_NAME}"
    container_name       = "${CONTAINER_NAME}"
    key                  = "${KEY_NAME}"
  }
}
${RESET}
EOF
  else
    if [[ $(command -v brew) ]]; then
      brew install az
    else
      echo "Please Install az cli using https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
    fi
  fi
else
  echo "Did you change your mind, No worries meet the requirements and come back again"
fi
