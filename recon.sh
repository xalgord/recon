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
    else
        mkdir -p "$DOMAIN_DIR" || error "Failed to create directory for $DOMAIN"
        info "Created directory: $DOMAIN_DIR"
    fi

    # Create subdirectories
    SCREENSHOTS_DIR="$DOMAIN_DIR/screenshots"
    URLS_DIR="$DOMAIN_DIR/urls"
    TESTING_DIR="$DOMAIN_DIR/testing"
    REPORTS_DIR="$DOMAIN_DIR/reports"
    mkdir -p "$SCREENSHOTS_DIR" "$URLS_DIR" "$TESTING_DIR" "$REPORTS_DIR" || \
        error "Failed to create subdirectories for $DOMAIN"
    info "Created subdirectories for $DOMAIN"

    # Display path information
    echo "Domain: $DOMAIN"
    echo "├── Main directory: $DOMAIN_DIR"
    echo "├── Screenshots: $SCREENSHOTS_DIR"
    echo "├── URLs: $URLS_DIR"
    echo "├── Testing: $TESTING_DIR"
    echo "└── Reports: $REPORTS_DIR"
    echo

    # Path variables for this domain
    SUBFINDER_OUTPUT="$URLS_DIR/subfinder-recursive.txt"
    FINDOMAIN_OUTPUT="$URLS_DIR/findomain.txt"
    ASSETFINDER_OUTPUT="$URLS_DIR/assetfinder.txt"
    ALL_DOMAINS_OUTPUT="$URLS_DIR/all-domains.txt"
    GOWITNESS_DB="$SCREENSHOTS_DIR/gowitness.db"
    NUCLEI_OUTPUT="$REPORTS_DIR/nuclei"

    # Create nuclei output directory
    mkdir -p "$NUCLEI_OUTPUT"
    echo "Path variables for $DOMAIN:"
    echo "├── Subfinder output: $SUBFINDER_OUTPUT"
    echo "├── Findomain output: $FINDOMAIN_OUTPUT"
    echo "├── Assetfinder output: $ASSETFINDER_OUTPUT"
    echo "├── Combined domains: $ALL_DOMAINS_OUTPUT"
    echo "├── Gowitness DB: $GOWITNESS_DB"
    echo "└── Nuclei output: $NUCLEI_OUTPUT"
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

    LIVE_SUBS="$URLS_DIR/live-subs.txt"
    LIVE_TXT="$URLS_DIR/live.txt"

    # Verify live subdomains using httpx
    info "Running httpx to identify live subdomains..."
    cat "$ALL_DOMAINS_OUTPUT" | httpx -silent -o "$LIVE_SUBS" || \
        warning "httpx failed to verify live subdomains"

    # Verify live subdomains with additional ports
    info "Running httpx to identify live subdomains + ports..."
    httpx -l "$ALL_DOMAINS_OUTPUT" -p 80,443,8080,8000,8443,8888,81,82,8081,8090,3000,5000,7000 -o "$LIVE_TXT" || \
        warning "httpx failed to verify live subdomains with ports"

    LIVE_COUNT=$(wc -l < "$LIVE_SUBS")
    info "Live subdomain verification completed"
    info "Results saved to $LIVE_SUBS and $LIVE_TXT"
    info "Found $LIVE_COUNT live subdomains out of $(wc -l < "$ALL_DOMAINS_OUTPUT") total"

    # =============================================
    # Phase 3: Web Enumeration
    # =============================================
    info "Starting web enumeration phase..."

    if [ "$LIVE_COUNT" -gt 0 ]; then
        info "Capturing screenshots of live domains using gowitness..."

        # Run gowitness
        gowitness scan file -f "$LIVE_SUBS" --timeout 10 \
            --chrome-window-x 1920 --chrome-window-y 1080 \
            --screenshot-path "$SCREENSHOTS_DIR" \
            --write-db --write-db-uri "sqlite://$GOWITNESS_DB" || \
            warning "Gowitness failed to capture screenshots"

        info "Screenshots captured successfully. Database and screenshots saved to $SCREENSHOTS_DIR"
    else
        warning "No live domains found, skipping screenshot capture"
    fi

    # =============================================
    # Phase 4: Security Testing
    # =============================================
    info "Starting security testing phase..."

    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    NUCLEI_OUTPUT="$REPORTS_DIR/nuclei-results-${TIMESTAMP}.txt"
    NUCLEI_JSON="$REPORTS_DIR/nuclei-results-${TIMESTAMP}.json"

    if [ "$LIVE_COUNT" -gt 0 ]; then
        info "Running nuclei vulnerability scanner on live domains..."

        # Run nuclei
        nuclei -l "$LIVE_SUBS" -sa -dc -headless -t http -o "$NUCLEI_OUTPUT" -silent || \
            warning "Nuclei failed to scan live domains"

        if [ -s "$NUCLEI_OUTPUT" ]; then
            VULN_COUNT=$(wc -l < "$NUCLEI_OUTPUT")
            info "Nuclei scan completed successfully"
            info "Found $VULN_COUNT potential security issues"
            info "Results saved to $NUCLEI_OUTPUT and $NUCLEI_JSON"

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
