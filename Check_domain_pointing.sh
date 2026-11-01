
#!/bin/bash

read -rp "Enter the application name: " APP_NAME

APACHE_CONF="/etc/apache2/sites-available/${APP_NAME}.conf"
CONFIG_FILE="/home/master/applications/$APP_NAME/conf/server.nginx"

POINTED_DOMAINS_FILE="/tmp/pointed_domains.txt"
NON_POINTED_DOMAINS_FILE="/tmp/non_pointed_domains.txt"

# Validate application configuration
if [[ ! -f "$APACHE_CONF" ]]; then
    echo "Error: Apache configuration not found for '$APP_NAME'."
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Nginx configuration not found for '$APP_NAME'."
    exit 1
fi

# Extract webroot
WEBROOT=$(awk '$1 == "DocumentRoot" {
    print $2
    exit
}' "$APACHE_CONF" | tr -d '"')

if [[ -z "$WEBROOT" || ! -d "$WEBROOT" ]]; then
    echo "Error: Webroot not found."
    exit 1
fi

echo "Webroot: $WEBROOT"

# Create test file without overwriting an existing file
TEST_FILE="$WEBROOT/usman.html"
CREATED_TEST=0

if [[ -e "$TEST_FILE" ]]; then
    if [[ "$(cat "$TEST_FILE")" != "HelloWorld" ]]; then
        echo "Error: Existing usman.html contains different content."
        exit 1
    fi
else
    printf 'HelloWorld\n' > "$TEST_FILE" || exit 1
    CREATED_TEST=1
fi

cleanup() {
    if [[ "$CREATED_TEST" -eq 1 ]]; then
        rm -f -- "$TEST_FILE"
    fi
}
trap cleanup EXIT

# Clear previous results
> "$POINTED_DOMAINS_FILE"
> "$NON_POINTED_DOMAINS_FILE"

echo
echo "========== CHECKING DOMAINS =========="

while IFS= read -r domain; do
    [[ -z "$domain" || "$domain" == _* || "$domain" == *'*'* ]] && continue

    response=$(curl -skL --max-time 5 \
        "https://$domain/usman.html" 2>/dev/null)

    if [[ "$response" == "HelloWorld" ]]; then
        echo "[✔] $domain" | tee -a "$POINTED_DOMAINS_FILE"
    else
        echo "[✘] $domain" | tee -a "$NON_POINTED_DOMAINS_FILE"
    fi

done < <(
    grep -oP '(?<=server_name\s)[^;]+' "$CONFIG_FILE" |
    tr -s '[:space:]' '\n' |
    sort -u
)

echo
echo "========================================="
echo "          FINAL DOMAIN REPORT"
echo "========================================="

echo
echo "========== POINTED DOMAINS =========="
cat "$POINTED_DOMAINS_FILE"

echo
echo "========== NON-POINTED DOMAINS =========="
cat "$NON_POINTED_DOMAINS_FILE"

echo
echo "========== SUMMARY =========="
echo "Pointed Domains: $(wc -l < "$POINTED_DOMAINS_FILE")"
echo "Non-Pointed Domains: $(wc -l < "$NON_POINTED_DOMAINS_FILE")"

echo
echo "========== OUTPUT FILES =========="
echo "$POINTED_DOMAINS_FILE"
echo "$NON_POINTED_DOMAINS_FILE"

echo "========================================="
