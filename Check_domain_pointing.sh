#!/bin/bash

# Prompt user for the application name
read -p "Enter the application name: " APP_NAME

# Define the Apache config path
APACHE_CONF="/etc/apache2/sites-available/${APP_NAME}.conf"

# Check if the Apache config exists
if [[ ! -f "$APACHE_CONF" ]]; then
    echo "Error: Apache configuration not found for app '$APP_NAME'."
    exit 1
fi

# Extract the DocumentRoot (webroot)
WEBROOT=$(grep -oP '(?<=DocumentRoot\s).*' "$APACHE_CONF" | head -n 1)

# Check if we found a webroot
if [[ -z "$WEBROOT" ]]; then
    echo "Error: Could not determine webroot for '$APP_NAME'."
    exit 1
fi

# Echo the webroot path
echo "Webroot for '$APP_NAME': $WEBROOT"

# Create 'usman.html' inside the webroot
echo "HelloWorld" > "$WEBROOT/usman.html"

# Confirm file creation
if [[ -f "$WEBROOT/usman.html" ]]; then
    echo "File 'usman.html' created successfully in $WEBROOT"
else
    echo "Failed to create 'usman.html'"
    exit 1
fi

# Define the Nginx server config path
CONFIG_FILE="/home/master/applications/$APP_NAME/conf/server.nginx"

# Check if the Nginx config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Nginx configuration file not found for app '$APP_NAME'."
    exit 1
fi

# Extract domains and check for "HelloWorld" response
grep -oP '(?<=server_name\s)[^;]+' "$CONFIG_FILE" | tr -s ' ' '\n' | sort -u | while read domain; do
    response=$(curl -sk --max-time 5 "https://$domain/usman.html")
    if [[ "$response" == "HelloWorld" ]]; then
        echo "[✔] $domain: HelloWorld"
    else
        echo "[✘] $domain: NOT HelloWorld (Got: '$response')"
    fi
done
