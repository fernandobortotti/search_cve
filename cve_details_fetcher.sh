#!/bin/bash

# Define 
## Colors
green='\033[0;32m'
blue='\033[0;34m'
red='\033[0;31m'
yellow='\033[0;33m'
reset='\033[0m'

## Divider

line_divider(){
# Obter a largura do terminal
largura_terminal=$(tput cols)

# Definir o caractere de preenchimento
caractere_preenchimento="="

# Repetir o caractere até o final da linha
for ((i=0; i<$largura_terminal; i++)); do
  echo -n "$caractere_preenchimento"
done

# Exibir a linha preenchida
echo
}


# Check if required tools are installed
if ! command -v curl &>/dev/null; then
    echo "curl is required but not installed. Please install curl and try again."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "jq is required but not installed. Please install jq and try again."
    exit 1
fi

# Function to fetch CVE details from the API
fetch_cve_details() {
    local cve_id=$1
    local ref_limit=$2
    local show_exploits=$3

    response=$(curl -s "https://cve.circl.lu/api/cve/CVE-$cve_id")

    if [[ -z "$response" || "$response" == "null" ]]; then
        echo -e "${blue} CVE: ${green}CVE-$cve_id${reset}"
        echo "No information found for CVE ID: $cve_id"
        line_divider
        return
    fi

    summary=$(echo "$response" | jq -r '.summary')
    references=$(echo "$response" | jq -r '.references[]' | head -n "$ref_limit")

    echo -e "${blue} CVE: ${green}CVE-$cve_id${reset}"
    echo -e "${blue} Summary:${reset} $summary"
    echo -e "${blue} References:${reset}"
    echo -e "${green}$references${reset}"

    # Check if user wants to see exploits

    if [[ "$show_exploits" == "true" ]]; then
        echo -e "${blue} Exploits from CVE API:${reset}"
        
        resultado=$(bash ~/ferramentasPentest/search_cve/exploitdb/searchsploit --cve $cve_id)

        if [ $? -eq 0 ]; then
            numero_linhas=$(echo "$resultado" | wc -l)

            if [ $numero_linhas -lt 5 ]; then
                echo -e "${red} Nenhum exploit encontrado para o CVE-$cve_id.${reset}"
            else
                echo -e "${green}$exploits${reset}"
                echo -e "${green}"
                echo -e "$resultado"
                echo -e "${reset}"
                echo "For view exploit: cat $HOME/search_cve/exploitdb/exploits/PATH"

            fi

        fi

    fi
    # Exibir a mensagem ajustada
    echo -e "${yellow}"
    line_divider
    echo -e "${reset}"
    echo ""

}

# Default number of references to show
default_ref_limit=3

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
    echo "Example: $0 --cve 2022-0001 --ref 5 --e"
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
