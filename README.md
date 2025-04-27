# recon
a script for automation

## To use the script:
1. Make it executable: chmod +x recon.sh
2. Run it with a domain: ./recon.sh example.com


## Here's a summary of what the script does:

1. **Input Validation and Setup**:
  - Validates domain argument
  - Creates necessary directories
  - Checks for required tools (subfinder, findomain, assetfinder, httpx, ffuf, nuclei)
2. **Subdomain Enumeration**:
  - Runs multiple tools (subfinder, findomain, assetfinder)
  - Combines and deduplicates results in all_domains.txt
3. **Live Subdomain Verification**:
  - Uses httpx to verify live domains
  - Saves results to both live-subs.txt and live-dev-subs.txt, and append both of the files to all-live.txt
4. **Directory Bruteforce**:
  - Runs FFUF tool for directory enumeration using cleaned-custom.txt wordlist.
  - Saves results in reports/FFUF.txt
5. **Security Testing**:
  - Runs nuclei vulnerability scanner on live domains
  - Saves results reports/nuclei-results.txt
  - Provides a summary of findings
