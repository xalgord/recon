#!/bin/bash

# recon.sh - A reconnaissance script for domain enumeration and security testing
# Usage: ./recon.sh <domain>

# Exit on error
set -e

# Display banner
echo "========================================="
echo "      Domain Reconnaissance Script       "
echo "========================================="
echo

# Check if domain argument is provided
if [ $# -eq 0 ]; then
    echo "Error: Domain argument is required"
    echo "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

# Set domain variable
DOMAIN=$1
echo "[+] Target domain: $DOMAIN"

# Create necessary directories
echo "[+] Creating output directories..."
mkdir -p screenshots
mkdir -p urls
mkdir -p testing
mkdir -p reports
echo "[+] Directories created successfully"

# Check for required tools
echo "[+] Checking for required tools..."
REQUIRED_TOOLS=("subfinder" "findomain" "assetfinder" "sublist3r" "httpx" "nuclei" "gowitness")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v $tool &> /dev/null; then
        MISSING_TOOLS+=($tool)
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "Error: The following required tools are missing:"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo
    echo "Please install these tools before running this script."
    exit 1
fi

echo "[+] All required tools are installed"
echo "[+] All required tools are installed"
echo "[+] Setup complete. Ready to proceed with reconnaissance on $DOMAIN"

# =============================================
# Phase 2: Subdomain Enumeration
# =============================================
echo
echo "[+] Starting subdomain enumeration phase..."

# Run subfinder for subdomain discovery
echo "[+] Running subfinder..."
subfinder -d $DOMAIN -o subfinder-recursive.txt
echo "[+] Subfinder completed. Results saved to subfinder-recursive.txt"

# Run findomain for subdomain discovery
echo "[+] Running findomain..."
findomain -t $DOMAIN -o findomain.txt
echo "[+] Findomain completed. Results saved to findomain.txt"

# Run assetfinder for subdomain discovery
echo "[+] Running assetfinder..."
assetfinder $DOMAIN > assetfinder.txt
echo "[+] Assetfinder completed. Results saved to assetfinder.txt"

# Run sublist3r for subdomain discovery
echo "[+] Running sublist3r..."
sublist3r -d $DOMAIN -o sublist3r.txt
echo "[+] Sublist3r completed. Results saved to sublist3r.txt"

# Combine and deduplicate results
echo "[+] Combining and deduplicating subdomain results..."
cat subfinder-recursive.txt findomain.txt assetfinder.txt sublist3r.txt | sort -u > all_subdomains.txt
echo "[+] All subdomain results combined and deduplicated in all_subdomains.txt"
echo "[+] Found $(wc -l < all_subdomains.txt) unique subdomains"

# =============================================
# Phase 3: Live Subdomain Verification
# =============================================
echo
echo "[+] Starting live subdomain verification phase..."

# Verify live subdomains using httpx
echo "[+] Running httpx to identify live subdomains..."
cat all_subdomains.txt | httpx -silent -o live-subs.txt
cp live-subs.txt live.txt  # Create a copy with alternate name for consistency

# Count and display results
LIVE_COUNT=$(wc -l < live-subs.txt)
echo "[+] Live subdomain verification completed"
echo "[+] Results saved to live-subs.txt and live.txt"
echo "[+] Found $LIVE_COUNT live subdomains out of $(wc -l < all_subdomains.txt) total"

# =============================================
# Phase 4: Web Enumeration
# =============================================
echo
echo "[+] Starting web enumeration phase..."

# Capture screenshots of live domains using gowitness
echo "[+] Running gowitness to capture screenshots of live domains..."
if [ $LIVE_COUNT -gt 0 ]; then
    echo "[+] Clearing previous gowitness database..."
    gowitness clean --database sqlite://gowitness.db
    
    echo "[+] Capturing screenshots of live domains..."
    gowitness file -f live-subs.txt --timeout 10 --resolution "1920x1080" --database sqlite://gowitness.db
    
    # Move screenshots to the screenshots directory
    echo "[+] Moving screenshots to the screenshots directory..."
    mv screenshots.html screenshots/
    mv gowitness.db screenshots/
    mv screenshots/*.png screenshots/ 2>/dev/null || true
    
    echo "[+] Web enumeration completed successfully"
    echo "[+] Screenshots saved to the screenshots directory"
else
    echo "[!] No live domains found, skipping screenshot capture"
fi

# =============================================
# Phase 5: Security Testing
# =============================================
echo
echo "[+] Starting security testing phase..."

# Get current timestamp for output file
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
NUCLEI_OUTPUT="testing/nuclei-results-${TIMESTAMP}.txt"
NUCLEI_JSON="testing/nuclei-results-${TIMESTAMP}.json"

# Run nuclei on live domains
if [ $LIVE_COUNT -gt 0 ]; then
    echo "[+] Running nuclei vulnerability scanner on live domains..."
    
    # Run nuclei with basic templates and output to both text and JSON formats
    nuclei -l live-subs.txt -o $NUCLEI_OUTPUT -json -j $NUCLEI_JSON -silent
    
    # Check if nuclei found any issues
    if [ -s "$NUCLEI_OUTPUT" ]; then
        VULN_COUNT=$(wc -l < $NUCLEI_OUTPUT)
        echo "[+] Nuclei scan completed successfully"
        echo "[+] Found $VULN_COUNT potential security issues"
        echo "[+] Results saved to $NUCLEI_OUTPUT and $NUCLEI_JSON"
        
        # Display top 5 findings as a summary
        echo
        echo "=== Security Findings Summary ==="
        echo "Top findings (up to 5 shown):"
        head -n 5 $NUCLEI_OUTPUT
        echo
        echo "For full details, check the output files in the testing directory"
    else
        echo "[+] Nuclei scan completed - no vulnerabilities found"
    fi
else
    echo "[!] No live domains found, skipping security testing"
fi

echo "[+] Security testing phase completed"
