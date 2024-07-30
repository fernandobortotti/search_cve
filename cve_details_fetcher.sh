#!/bin/bash
#
# cve_details_fetcher.sh
# This script facilitates the retrieval of summarized information about specific vulnerabilities,
# including descriptions, references, and potential exploits, directly from the command line.
#
# configure:
# colors
green='\033[0;32m'
blue='\033[0;34m'
red='\033[0;31m'
yellow='\033[0;33m'
reset='\033[0m'

# Default number of references to show
default_ref_limit=3

# Define divider
line_divider(){
    largura_terminal=$(tput cols)
    caractere_preenchimento="="
    for ((i=0; i<$largura_terminal; i++)); do
      echo -n "$caractere_preenchimento"
    done
    echo
}
# --------
#
# Check if required tools are installed
if ! command -v curl &>/dev/null; then
    echo "curl is required but not installed. Please install curl and try again."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "jq is required but not installed. Please install jq and try again."
    exit 1
fi

if ! command -v searchsploit &> /dev/null; then
    if [ ! -f "/usr/share/exploitdb/searchsploit" ]; then
        echo "Error: searchsploit is required but not installed."
        echo "Please install searchsploit and try again."
        echo "Option 1: Install searchsploit: sudo apt install searchsploit"
        echo "Option 2: Download searchsploit: git clone https://gitlab.com/exploit-database/exploitdb.git /usr/share/exploitdb"
        echo
        exit 1
    else
        Searchsploit=/usr/share/exploitdb/searchsploit
    fi
fi
#------

# Decode HTML entities in a given string.
#
# Parameters:
#   - $1: The string containing HTML entities to decode.
#
# Returns:
#   - The decoded string with HTML entities replaced.
decode_html() {
    echo "$1" | sed 's/&quot;/"/g' | sed "s/&#039;/'/g" | sed 's/&amp;/&/g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g'
}

# new_font - Fetches and displays details for a given CVE ID from Vulmon API.
#
# Parameters:
#   - cve_id: The CVE ID to fetch details for.
#
# Returns:
#   - None
#
# Description:
#   This function fetches details for a given CVE ID from the Vulmon API and displays
#   them in a formatted way. It constructs the URL using the CVE ID, fetches the HTML
#   content of the page, extracts the summary using sed, decodes HTML entities using
#   the decode_html function, and then prints the CVE ID, summary, and references in
#   a colored format. If no information is found for the given CVE ID, it displays a
#   message indicating that.
new_font(){
    URL="https://vulmon.com/vulnerabilitydetails?qid=CVE-$cve_id"
    HTML=$(curl -s --connect-timeout 10 --max-time 25  "$URL")
    SUMMARY=$(echo "$HTML" | sed -n 's/.*<p class="jsdescription1 content_overview">\([^<]*\)<\/p>.*/\1/p')
    DECODED_SUMMARY=$(decode_html "$SUMMARY")
    if [ -n "$DECODED_SUMMARY" ]; then
        echo -e "${blue} CVE: ${green}CVE-$cve_id${reset}"
        echo -e "${blue} SUMMARY:${reset} $DECODED_SUMMARY"
        echo -e "${blue} References:${reset} $URL"
    else
        echo -e "${blue} CVE: ${green}CVE-$cve_id${reset}"
        echo "[-] No information found for CVE ID: $cve_id"
        echo -e "${red} [-] View url: ${reset} $URL"

    fi

}


# POC CVE GitHub function
    # Fetches and displays the PoC (Proof of Concept) in GitHub for a given CVE ID.
    #
    # Parameters:
    #   - cve_id: The CVE ID to fetch the PoC for.
    #
    # Returns:
    #   - None
    #
    # Description:
    #   This function fetches the PoC (Proof of Concept) in GitHub for a given CVE ID.
    #   It extracts the year from the CVE ID, constructs the URL to fetch the JSON file
    #   containing the PoC details, and uses `curl` and `jq` to extract the `html_url`
    #   from the JSON response. If the `html_url` is empty, it displays a message
    #   indicating that no PoC was found. Otherwise, it displays the `html_url` in
    #   a formatted way.
poc_cve_github(){
    local cve_id=$1
    local year=$(echo $cve_id | awk -F"-" '{ print $1 }')
    echo "+========+========+==========+========+========+==========+========+========+==========+"
    echo -e "${blue}[+] GITHUB search result:${reset}"
    html_url=$(curl -s --connect-timeout 10 --max-time 20 -X GET "https://raw.githubusercontent.com/nomi-sec/PoC-in-GitHub/master/$year/CVE-$cve_id.json" | jq -r '.[] | .html_url')

    if [ -z "$html_url" ]; then
        echo -e "${red} [-] No PoC in GitHub found for CVE-$cve_id${reset}."
    else
        echo -e "${blue}[+] PoC in GitHub: ${reset}"
        echo -e "${green}$html_url${reset}"
    fi
}

# Fetch CVE details from the API
# Fetches and displays details about a specified CVE (Common Vulnerabilities and Exposures) ID.
#
# Parameters:
#   - cve_id: The CVE ID to fetch details for.
#   - ref_limit: The maximum number of references to display.
#   - show_exploits: Whether to display exploits or not.
#
# Returns:
#   None.
#
# Description:
#   This function fetches the details of a specified CVE ID from the CVE API.
#   It displays the CVE ID, summary, and references. If the user wants to see
#   exploits, it fetches the exploits from the exploitdb. If no exploits are
#   found, it displays a message indicating that. Finally, it displays the PoC
#   (Proof of Concept) in GitHub for the CVE ID.
fetch_cve_details() {
    local cve_id=$1
    local ref_limit=$2
    local show_exploits=$3

    response=$(curl -s --connect-timeout 1 --max-time 5 -X GET "https://cve.circl.lu/api/cve/CVE-$cve_id")

    if [[ -z "$response" || "$response" == "" ]]; then
        new_font "$cve_id"
        line_divider
        return
    fi

    SUMMARY=$(echo "$response" | jq -r '.SUMMARY')

    echo -e "${blue} CVE: ${green}CVE-$cve_id${reset}"
    echo -e "${blue} SUMMARY:${reset} $SUMMARY"

    references=$(echo "$response" | jq -r '.references[]' | head -n "$ref_limit")

    echo -e "${blue} References:${reset}"
    echo -e "${green}$references${reset}"

    # Check if user wants to see exploits
    if [[ "$show_exploits" == "true" ]]; then
        echo -e "${blue} Exploits from CVE API:${reset}"
        
        if [ "$Searchsploit" ]; then
            resultado=$(bash $Searchsploit --cve $cve_id)
        else
            resultado=$(searchsploit --cve $cve_id)
        fi

        if [ $? -eq 0 ]; then
            numero_linhas=$(echo "$resultado" | wc -l)

            if [ $numero_linhas -lt 5 ]; then
                echo -e "${red} [-] No exploits found for CVE-$cve_id in the exploitdb${reset}."
            else
                echo -e "${green}$exploits${reset}"
                echo -e "${green}$resultado${reset}"
                echo "***************************************************************"
                echo -e "${blue} [+] FOR SEE EXPLOITS:${reset}"
                echo -e "${green} cat /usr/share/exploitdb/exploits/PATH${reset}"
            fi
        fi
        poc_cve_github "$cve_id"
    fi

    echo -e "${yellow}"
    line_divider
    echo -e "${reset}"
    echo "\n"
}
# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --cve) cve_id="$2"; shift ;;
        --list) cve_list="$2"; shift ;;
        --ref) ref_limit="$2"; shift ;;
        --e) show_exploits="true"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Set reference limit to user-provided value or default
ref_limit="${ref_limit:-$default_ref_limit}"

# Validate parameters
if [[ -z "$cve_id" && -z "$cve_list" ]]; then
    echo "Please provide a CVE ID or a list of CVE IDs."
    echo "Usage: $0 --cve <CVE ID> [--ref <number of references to show>] [--e]"
    echo "Usage for a list of CVE IDs: $0 --list <CVE list file> [--ref <number of references to show>] [--e]"
    echo "Example: $0 --cve 2021-3156 --ref 5 --e"
    exit 1
fi

# Fetch and display CVE details
if [[ -n "$cve_id" ]]; then
    fetch_cve_details "$cve_id" "$ref_limit" "$show_exploits"
elif [[ -n "$cve_list" ]]; then
    if [[ ! -f "$cve_list" ]]; then
        echo "File $cve_list not found."
        exit 1
    fi

    while IFS= read -r cve_id; do
        fetch_cve_details "$cve_id" "$ref_limit" "$show_exploits"
    done < "$cve_list"
fi
