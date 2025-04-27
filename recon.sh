#!/bin/bash
# recon.sh - Reconnaissance setup and execution script
# Creates directory structure for domain reconnaissance and performs subdomain enumeration, live checks, web enumeration, and security testing.

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# Function to display error messages
error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
    exit 1
}

# Function to display information messages
info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

# Function to display warning messages
warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

# Base directory for reconnaissance
BASE_DIR="$HOME/targets"

# Ensure base directory exists
if [ ! -d "$BASE_DIR" ]; then
    info "Creating base directory: $BASE_DIR"
    mkdir -p "$BASE_DIR" || error "Failed to create base directory $BASE_DIR"
fi

# Validate command line arguments
if [ $# -eq 0 ]; then
    error "Usage: $0 <domain1> [domain2] [domain3] ..."
fi

# Process each domain
for DOMAIN in "$@"; do
    info "Processing domain: $DOMAIN"

    # Basic domain format validation
    if ! echo "$DOMAIN" | grep -q -E '^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z]{2,}(\.[a-zA-Z]{2,})?$'; then
        warning "Domain $DOMAIN doesn't seem to be valid. Continuing anyway..."
    fi

    # Create domain-specific directory
    DOMAIN_DIR="$BASE_DIR/$DOMAIN"
    if [ -d "$DOMAIN_DIR" ]; then
        warning "Directory for $DOMAIN already exists. Using existing directory."
        rm -rf "$FFUF_OUTPUT"
    else
        mkdir -p "$DOMAIN_DIR" || error "Failed to create directory for $DOMAIN"
        info "Created directory: $DOMAIN_DIR"
    fi

    # Create subdirectories
    URLS_DIR="$DOMAIN_DIR/urls"
    TESTING_DIR="$DOMAIN_DIR/testing"
    REPORTS_DIR="$DOMAIN_DIR/reports"
    mkdir -p "$URLS_DIR" "$TESTING_DIR" "$REPORTS_DIR" || \
        error "Failed to create subdirectories for $DOMAIN"
    info "Created subdirectories for $DOMAIN"

    # Display path information
    echo "Domain: $DOMAIN"
    echo "├── Main directory: $DOMAIN_DIR"
    echo "├── URLs: $URLS_DIR"
    echo "├── Testing: $TESTING_DIR"
    echo "└── Reports: $REPORTS_DIR"
    echo

    # Path variables for this domain
    SUBFINDER_OUTPUT="$URLS_DIR/subfinder-recursive.txt"
    FINDOMAIN_OUTPUT="$URLS_DIR/findomain.txt"
    ASSETFINDER_OUTPUT="$URLS_DIR/assetfinder.txt"
    ALL_DOMAINS_OUTPUT="$URLS_DIR/all-domains.txt"
    LIVE_SUBS="$URLS_DIR/live-subs.txt"
    LIVE_DEV_SUBS="$URLS_DIR/live-dev-subs.txt"
    ALL_LIVE="$URLS_DIR/all-live.txt"
    NUCLEI_OUTPUT="$REPORTS_DIR/nuclei-results.txt"
    FFUF_OUTPUT="$REPORTS_DIR/FFUF.txt"

    # Create nuclei and FFUF output directories
    mkdir -p "$NUCLEI_OUTPUT"
    info "Path variables for $DOMAIN:"
    echo "├── Subfinder output: $SUBFINDER_OUTPUT"
    echo "├── Findomain output: $FINDOMAIN_OUTPUT"
    echo "├── Assetfinder output: $ASSETFINDER_OUTPUT"
    echo "├── Combined domains: $ALL_DOMAINS_OUTPUT"
    echo "├── Live subdomains: $LIVE_SUBS"
    echo "├── Live dev subdomains: $LIVE_DEV_SUBS"
    echo "├── All live subdomains: $ALL_LIVE"
    echo "├── Nuclei output: $NUCLEI_OUTPUT"
    echo "└── FFUF output: $FFUF_OUTPUT"
    echo

    # =============================================
    # Phase 1: Subdomain Enumeration
    # =============================================
    info "Starting subdomain enumeration phase..."

    # Run subfinder
    info "Running subfinder..."
    subfinder -d "$DOMAIN" -all -recursive -t 200 -silent -o "$SUBFINDER_OUTPUT" || \
        warning "Subfinder failed for $DOMAIN"

    # Run findomain
    info "Running findomain..."
    findomain --quiet -t "$DOMAIN" | tee "$FINDOMAIN_OUTPUT" || \
        warning "Findomain failed for $DOMAIN"

    # Run assetfinder
    info "Running assetfinder..."
    assetfinder -subs-only "$DOMAIN" | tee "$ASSETFINDER_OUTPUT" || \
        warning "Assetfinder failed for $DOMAIN"

    # Combine and deduplicate results
    info "Combining and deduplicating subdomain results..."
    cat "$SUBFINDER_OUTPUT" "$FINDOMAIN_OUTPUT" "$ASSETFINDER_OUTPUT" | sort -u > "$ALL_DOMAINS_OUTPUT"
    info "All subdomain results combined and deduplicated in $ALL_DOMAINS_OUTPUT"
    info "Found $(wc -l < "$ALL_DOMAINS_OUTPUT") unique subdomains"

    # =============================================
    # Phase 2: Live Subdomain Verification
    # =============================================
    info "Starting live subdomain verification phase..."

    # Verify live subdomains using httpx
    info "Running httpx to identify live subdomains..."
    cat "$ALL_DOMAINS_OUTPUT" | httpx -silent -o "$LIVE_SUBS" || \
        warning "httpx failed to verify live subdomains"

    # Verify live subdomains with additional ports
    info "Running httpx to identify live subdomains + ports..."
    httpx -l "$ALL_DOMAINS_OUTPUT" -p 8080,8000,8888,81,82,8081,8090,3000,5000,7000 -o "$LIVE_DEV_SUBS" || \
        warning "httpx failed to verify live subdomains with ports"

    # Combine live-subs.txt and live-dev-subs.txt into all-live.txt
    info "Combining live subdomains into all-live.txt..."
    cat "$LIVE_SUBS" "$LIVE_DEV_SUBS" | sort -u > "$ALL_LIVE"
    LIVE_COUNT=$(wc -l < "$ALL_LIVE")
    info "Live subdomain verification completed"
    info "Results saved to $ALL_LIVE"
    info "Found $LIVE_COUNT live subdomains out of $(wc -l < "$ALL_DOMAINS_OUTPUT") total"

    # =============================================
    # Phase 3: Directory Bruteforcing with FFUF
    # =============================================
    info "Starting directory bruteforcing with FFUF..."

    if [ "$LIVE_COUNT" -gt 0 ]; then
        info "Running FFUF on all live subdomains..."

        # Clear previous FFUF output
        > "$FFUF_OUTPUT"

        # Run FFUF on each live subdomain
        for domain in $(cat "$ALL_LIVE"); do
            info "Running FFUF on $domain..."
            ffuf -w /usr/share/wordlists/cleaned_custom.txt -u "$domain/FUZZ" -ac -mc 200 -c -r | tee -a "$FFUF_OUTPUT" || \
                warning "FFUF failed for $domain"
        done

        info "FFUF scan completed"
        info "Results saved to $FFUF_OUTPUT"
    else
        warning "No live domains found, skipping FFUF scan"
    fi

    # =============================================
    # Phase 4: Security Testing
    # =============================================
    info "Starting security testing phase..."

    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    NUCLEI_OUTPUT="$REPORTS_DIR/nuclei-results-${TIMESTAMP}.txt"

    if [ "$LIVE_COUNT" -gt 0 ]; then
        info "Running nuclei vulnerability scanner on all live domains..."

        # Run nuclei
        nuclei -l "$ALL_LIVE" -headless -es info,low -o "$NUCLEI_OUTPUT" || \
            warning "Nuclei failed to scan live domains"

        if [ -s "$NUCLEI_OUTPUT" ]; then
            VULN_COUNT=$(wc -l < "$NUCLEI_OUTPUT")
            info "Nuclei scan completed successfully"
            info "Found $VULN_COUNT potential security issues"
            info "Results saved to $NUCLEI_OUTPUT"

            # Display top 5 findings as a summary
            echo "=== Security Findings Summary ==="
            echo "Top findings (up to 5 shown):"
            head -n 5 "$NUCLEI_OUTPUT"
            echo "For full details, check the output files in the reports directory"
        else
            info "Nuclei scan completed - no vulnerabilities found"
        fi
    else
        warning "No live domains found, skipping security testing"
    fi

    info "Security testing phase completed"
done

info "All domains processed successfully!"
info "Base directory: $BASE_DIR"
info "Run with specific domain to see path information again."

# Make the script executable
chmod +x "$0"
