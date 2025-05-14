# Reconnaissance Automation Script (`recon.sh`)

A powerful Bash script designed to automate the process of domain reconnaissance, including subdomain enumeration, live host detection, directory bruteforcing, and basic security testing using industry-standard tools.

---

## 🧰 Tools Used

This script integrates with the following open-source tools (must be installed beforehand):

| Tool        | Purpose |
|-------------|---------|
| [Subfinder](https://github.com/projectdiscovery/subfinder) | Passive subdomain discovery |
| [Findomain](https://github.com/Findomain/Findomain) | Fast subdomain discovery using Certificate Transparency logs |
| [Assetfinder](https://github.com/tomnomnom/assetfinder) | Find related domains and subdomains |
| [HTTPX](https://github.com/projectdiscovery/httpx) | Live host validation |
| [FFUF](https://github.com/ffuf/ffuf) | Web directory & content bruteforcer |
| [Nuclei](https://github.com/projectdiscovery/nuclei) | Fast vulnerability scanning |

Ensure all these tools are installed and accessible in your system's `PATH`.

---

## 📁 Directory Structure

The script organizes output files under a structured directory located at `$HOME/targets/<domain>`:

```
$HOME/targets/
└── <domain>/
    ├── urls/
    │   ├── subfinder-recursive.txt
    │   ├── findomain.txt
    │   ├── assetfinder.txt
    │   ├── all-domains.txt
    │   ├── live-subs.txt
    │   ├── live-dev-subs.txt
    │   └── all-live.txt
    ├── testing/
    └── reports/
        ├── FFUF.txt
        └── nuclei-results-YYYYMMDD-HHMMSS.txt
```

---

## ⚙️ Usage

### Prerequisites

1. Install required tools.
2. Make the script executable:
   ```bash
   chmod +x recon.sh
   ```

### Running the Script

```bash
./recon.sh example.com anotherdomain.org test.co.uk
```

You can pass multiple domains separated by spaces.

---

## 🛡️ Features

- **Automated directory creation** for each target domain
- **Subdomain Enumeration** with multiple tools
- **Live Host Detection** via HTTP(S) probing
- **Port Scanning** for common development ports
- **Directory Bruteforce** using FFUF
- **Security Testing** with Nuclei templates
- **Clean Output Organization** into logical directories
- **Basic Domain Validation** and error handling

---

## 📌 Example Output

After running:

```sh
./recon.sh example.com
```

You'll see organized results like:

```
[INFO] Processing domain: example.com
[INFO] Created directory: /home/user/targets/example.com
... various steps ...
[INFO] Found 45 unique subdomains
[INFO] Found 12 live subdomains
[INFO] FFUF scan completed
[INFO] Nuclei scan completed successfully
Found 3 potential security issues
```

---

## 📝 Notes

- Ensure wordlist `/usr/share/wordlists/cleaned_custom.txt` exists or change it in the script.
- The script skips duplicate directories but wipes previous FFUF results inside them.
- For large scopes, consider tuning rate limits and timeouts in tool commands.

---

## 🔐 Disclaimer

Use this script only on assets you own or have explicit permission to assess. Unauthorized use is illegal and unethical.

---

## ✨ License

MIT License – Feel free to modify and share!
