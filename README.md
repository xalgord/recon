# recon
a script for automation

## To use the script:
1. Make it executable: chmod +x recon.sh
2. Run it with a domain: ./recon.sh example.com


## Here's a summary of what the script does:

1. **Input Validation and Setup**:
  - Validates domain argument
  - Creates necessary directories
  - Checks for required tools (subfinder, findomain, assetfinder, sublist3r, httpx, nuclei, gowitness)
2. **Subdomain Enumeration**:
  - Runs multiple tools (subfinder, findomain, assetfinder, sublist3r)
  - Combines and deduplicates results in all_subdomains.txt
3. **Live Subdomain Verification**:
  - Uses httpx to verify live domains
  - Saves results to both live-subs.txt and live.txt
4. **Web Enumeration**:
  - Captures screenshots of live domains using gowitness
  - Saves screenshots to the screenshots directory
5. **Security Testing**:
  - Runs nuclei vulnerability scanner on live domains
  - Saves results with timestamp in both text and JSON formats
  - Provides a summary of findings
