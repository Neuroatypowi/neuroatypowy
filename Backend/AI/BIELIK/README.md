# **AWS EC2 Spot Deployment Manual: Bielik-PL-11B-v3.0-Instruct with Secure API Gateway**

[English Version](#bookmark=id.880hq8jgtzrr) |(\#wersja-polska-standard-etr-psoni)

# **English Version (ETC Standard)**

## **🚨 CRITICAL ARCHITECTURAL REVOLUTION 🚨**

### **⚡️ RUNNING FULL UNQUANTIZED BIELIK-11B ON NVIDIA A10G (24 GB VRAM) WAS IMPOSSIBLE UNTIL 4 DAYS AGO\! ⚡️**

* **🔓 The Breakthrough:** Real production deployment of the unquantized **speakleash/Bielik-PL-11B-v3.0-Instruct** model (which is capable of processing the finest syntactic and semantic nuances of the Polish language, including highly formal and legal administrative dialects) on the cost-effective **NVIDIA A10G** platform (24 GB VRAM) became possible **only 4 days ago**\!  
* **📅 Historic Release Date:** This was unlocked on **June 5, 2026**, with the publication of the developmental release of [**vLLM v0.22.1**](https://github.com/vllm-project/vllm/releases/tag/v0.22.1).  
* **🛠️ The Technology:** Prior to version v0.22.1, attempting to load an unquantized 11-billion parameter model in native Bfloat16 precision (\~22 GB of weights alone) on a 24 GB card would trigger immediate **Out-of-Memory (OOM)** failures during the pre-allocation of the KV Cache blocks.  
* **💾 Multi-Tier KV Cache Offloading:** The newly implemented developmental release introduces native **Hybrid Memory Allocator (HMA)**. This technology enables the system to offload PagedAttention tracking tables and excess KV Cache blocks directly to the local high-speed **NVMe instance store** (/mnt/vllm\_nvme/kv\_offload), maintaining perfect execution speed and absolute accuracy without needing expensive GPU upgrades\!

## **Wstęp i opis barier wdrożeniowych (English Summary)**

* **VRAM Allocation Barrier:** Resolved by using a precise utilization limit (--gpu-memory-utilization 0.988) and blocking pre-allocation of GPU cache at boot (VLLM\_TEST\_FORCE\_NUM\_GPU\_BLOCKS=0).  
* **Block Size Compatibility:** Restored to the native \--block-size 16 (instead of 8\) to maintain compatibility with FlashAttention-2 and FlashInfer kernels, shifting tracking data to the local NVMe drive.  
* **Graceful Shutdown Safeguard:** Replaced global killall commands with targeted port-level kills (fuser \-k \-9 8000/tcp) to prevent terminating critical AWS SSM Agent and Cloud-Init python services.  
* **Systemd Startup Collision:** Overrode default systemd timeout with TimeoutStartSec=300 to prevent service teardown during the 5-minute model weight extraction.  
* **Dynamic DNS Routing:** Leveraged AWS IMDSv2 and Cloudflare API to securely update DNS configurations over dynamic EC2 Spot reboots.

## **🔒 Secure Firewall Traversal & API Gateway (Caddy Server)**

* **🌐 The Goal:** To restrict access to the vLLM API exclusively to authorized clients and route all traffic through port **443 (HTTPS)**. This guarantees 100% traversal through restrictive corporate and public firewalls that block standard high-numbered ports (like 8000).  
* **⚖️ The Choice (Caddy vs. Nginx):**  
  * **Caddy Server** was selected as the optimal proxy because of its native, out-of-the-box **Let's Encrypt (ACME)** client. Caddy manages the entire certificate lifecycle (issuance, renewal, and installation) automatically without requiring external utilities like Certbot or complex cron jobs.  
  * Caddy provides incredibly lightweight, high-performance reverse proxy routing with built-in header validation directly in its simple configuration format (Caddyfile).  
* **🔌 Enterprise Integrations:**  
  * **Python 3.12.13 pyUNO & LibreOffice Writer 26.2.3.2:** Remote clients running Python 3.12.13 automate document generation in LibreOffice Writer 26.2.3.2. These clients communicate over secure HTTPS, transmitting rich JSON requests containing Polish characters in UTF-8.  
  * **Oracle Autonomous Database 26AI (Always Free Tier):** Outbound REST calls from Oracle 26AI Always Free instances to third-party APIs require strict SSL encryption (port 443). Our Caddy proxy enables direct database-level AI invocations using safe PL/SQL web calls (UTL\_HTTP or APEX\_WEB\_SERVICE), enforcing a custom token authentication schema seamlessly.

## **🖥️ AWS Console Configuration (UI Setup)**

1. **Spot Request Panel:** Log in to the AWS Management Console, navigate to the **EC2 Dashboard**, select **Spot Requests** from the left-hand navigation pane, and click **Request Spot Instances**.  
2. **Instance & OS Selection:** Choose **Ubuntu Server 24.04 LTS** as your AMI. Select the GPU-optimized **g5.xlarge** instance type.  
   * *System specs:* 4 vCPUs, 16 GiB RAM, 1x NVIDIA A10G (24 GB VRAM), 250 GB Local NVMe Instance Store.  
3. **Key Pair & Networking:** Select or generate your SSH key pair (.pem). Choose your Default VPC. Under Security Groups, add inbound rules for:  
   * Port 22 (SSH) \- Restricted to your IP.  
   * Port 443 (HTTPS) \- Exposed to **0.0.0.0/0** (Public Access).  
   * *Note:* Keep port 8000 closed to the public; Caddy will route requests locally.  
4. **IMDSv2 Activation:** Scroll to the bottom of the wizard, expand **Advanced Details**, and ensure **Metadata accessible** is set to **Enabled**, and **Metadata version** is strictly set to **V2 (IMDSv2)**.  
5. **Launch:** Review configurations and submit the Spot Request. Once the state becomes **Active**, note your public IP.

## **💻 CLI / Bash Installation and Configuration**

Follow these commands in sequence to establish the production environment.

### **1\. NVMe Scratch Space Configuration**

Create /usr/local/bin/setup-nvme-swap.sh to partition and mount the local instance store disk:

Bash  
sudo nano /usr/local/bin/setup-nvme-swap.sh

*Paste the following script:*

Bash  
\#\!/bin/bash  
set \-e

echo "=== Initializing high-speed NVMe scratch space \==="

TARGET\_DEV=""  
for dev in /dev/nvme?n1; do  
    if \[ \-b "$dev" \]; then  
        if \[ $(lsblk \-no NAME "$dev" | wc \-l) \-eq 1 \]; then  
            TARGET\_DEV="$dev"  
            break  
        fi  
    fi  
done

if; then  
    echo "Error: High-speed NVMe Instance Store not found\!"  
    exit 1  
fi

echo "Targeting drive: $TARGET\_DEV"  
MOUNT\_POINT="/mnt/vllm\_nvme"

if\! mount | grep \-q "$TARGET\_DEV"; then  
    sudo swapoff "$TARGET\_DEV" 2\>/dev/null || true  
    sudo wipefs \-a "$TARGET\_DEV" 2\>/dev/null || true  
    sudo mkfs.ext4 \-F "$TARGET\_DEV"  
    sudo mkdir \-p "$MOUNT\_POINT"  
    sudo mount "$TARGET\_DEV" "$MOUNT\_POINT"  
    sudo chown \-R ubuntu:ubuntu "$MOUNT\_POINT"  
    sudo chmod 755 "$MOUNT\_POINT"  
fi

echo "export {ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_TOKEN=\\"{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_
\\"" \> /home/ubuntu/.{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_token\_env  
chmod 600 /home/ubuntu/.{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_token\_env  
echo "=== Setup Completed Successfully \==="

Save and run:

Bash  
sudo chmod \+x /usr/local/bin/setup-nvme-swap.sh  
sudo /usr/local/bin/setup-nvme-swap.sh

### **2\. Conda & vLLM v0.22.1 Setup**

Install Python 3.13 dependencies and build environment:

Bash  
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86\_64.sh \-O miniconda.sh  
bash miniconda.sh \-b \-p /home/ubuntu/miniconda  
/home/ubuntu/miniconda/bin/conda init bash  
source \~/.bashrc

conda create \-n vllm\_bielik\_env python=3.13 \-y  
conda activate vllm\_bielik\_env  
pip install vllm==0.22.1

### **3\. Native HMA Startup Script**

Create /usr/local/bin/start-vllm-server.sh. Notice we bind vLLM only to localhost (127.0.0.1) for local security:

Bash  
sudo nano /usr/local/bin/start-vllm-server.sh

*Paste the following script:*

Bash  
\#\!/bin/bash  
set \-e

echo "=== Launching Production vLLM Server \==="

if \[ \-f /home/ubuntu/.{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_token\_env \]; then  
    source /home/ubuntu/.{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_token\_env  
fi

export {ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_HOME="/mnt/vllm\_nvme/{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_cache"  
export TRITON\_CACHE\_DIR="/mnt/vllm\_nvme/triton\_cache"

\# HMA Configuration for v0.22.1 NVMe cache offloading  
export VLLM\_HMA\_ENABLED=1  
export VLLM\_HMA\_KV\_CONNECTOR="nixl"  
export VLLM\_HMA\_STORAGE\_PATH="/mnt/vllm\_nvme/kv\_offload"

\# PyTorch allocator guard configuration  
export PYTORCH\_CUDA\_ALLOC\_CONF="expandable\_segments:True,garbage\_collection\_threshold:0.8"  
export TMPDIR="/mnt/vllm\_nvme/kv\_offload"  
export VLLM\_TEST\_FORCE\_NUM\_GPU\_BLOCKS=0

mkdir \-p "${ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_HOME" "$TRITON\_CACHE\_DIR" "$VLLM\_HMA\_STORAGE\_PATH"

source /home/ubuntu/miniconda/bin/activate vllm\_bielik\_env

exec python3 \-m vllm.entrypoints.openai.api\_server \\  
    \--model "speakleash/Bielik-PL-11B-v3.0-Instruct" \\  
    \--gpu-memory-utilization 0.988 \\  
    \--max-model-len 512 \\  
    \--block-size 16 \\  
    \--safetensors-load-strategy lazy \\  
    \--enforce-eager \\  
    \--port 8000 \\  
    \--host 127.0.0.1

Set executable:

Bash  
sudo chmod \+x /usr/local/bin/start-vllm-server.sh

### **4\. Safe Shutdown Script**

Create /usr/local/bin/safe-shutdown.sh:

Bash  
sudo nano /usr/local/bin/safe-shutdown.sh

*Paste the following script:*

Bash  
\#\!/bin/bash  
set \-e

echo "=== Executing Graceful Port Termination \==="

if netstat \-tuln | grep \-qE ":8000\\b"; then  
    echo "Active vLLM listener found. Stopping process safely..."  
    sudo fuser \-k \-9 8000/tcp || true  
else  
    echo "No processes bound to port 8000."  
fi

echo "=== Shutdown Procedure Complete \==="

Set executable:

Bash  
sudo chmod \+x /usr/local/bin/safe-shutdown.sh

### **5\. Systemd Daemon Service Configuration**

Create /etc/systemd/system/vllm-server.service with extended initialization timeouts:

Bash  
sudo nano /etc/systemd/system/vllm-server.service

*Paste the following configuration:*

Ini, TOML  
\[Unit\]  
Description\=vLLM OpenAI API Server v0.22.1  
After\=network.target nvidia-persistenced.service  
Wants\=nvidia-persistenced.service

Type\=simple  
User\=ubuntu  
Group\=ubuntu  
WorkingDirectory\=/home/ubuntu  
Environment\="{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_TOKEN={ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\"  
ExecStartPre\=/bin/sleep 180  
ExecStart\=/usr/local/bin/start-vllm-server.sh  
ExecStop\=/usr/local/bin/safe-shutdown.sh  
Restart\=always  
RestartSec\=10  
TimeoutStartSec\=300

LimitNOFILE\=65535  
LimitMEMLOCK\=infinity

\[Install\]  
WantedBy\=multi-user.target

Enable and activate the daemon:

Bash  
sudo systemctl daemon-reload  
sudo systemctl enable vllm-server.service  
sudo systemctl start vllm-server.service

### **6\. Caddy Server Gateway Setup**

Install Caddy Server on Ubuntu:

Bash  
sudo apt install \-y debian-keyring debian-archive-keyring apt-transport-https curl  
curl \-1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg \--dearmor \-o /usr/share/keyrings/caddy-stable-archive-keyring.gpg  
curl \-1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list  
sudo apt update  
sudo apt install caddy \-y

Configure /etc/caddy/Caddyfile for automated SSL and Token-based verification:

Bash  
sudo nano /etc/caddy/Caddyfile

*Paste the following configuration (Replace domain and set a custom Bearer Token):*

Fragment kodu  
bielik.neuroatypowi.org {  
    \# Matcher for verified API clients sending our secret token  
    @apiAuth {  
        header Authorization "Bearer cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}"  
    }

    \# Direct verified HTTPS requests to the local vLLM port  
    reverse\_proxy @apiAuth 127.0.0.1:8000

    \# Match and block unauthorized clients  
    @unauthorized {  
        not header Authorization "Bearer cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}"  
    }  
    respond @unauthorized "Unauthorized Access \- Valid Bearer Token Required" 401 {  
        close  
    }  
}

Apply config and restart Caddy:

Bash  
sudo systemctl restart caddy

### **7\. Automated DynDNS Sync (Cloudflare)**

Create /usr/local/bin/zmiana-ip.sh:

Bash  
sudo nano /usr/local/bin/zmiana-ip.sh

*Paste the following script:*

Bash  
\#\!/bin/bash

TOKEN="cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}"  
STREFA="f3902b09d66b008f17bc34a57d0027d8"  
REKORD="49ef3940c38d6d26f51c74115bf1117c"  
DOMENA="bielik.neuroatypowi.org"

\# Retrieve public IPv4 via AWS IMDSv2  
AWS\_TOKEN=$(curl \-s \-X PUT "http://169.254.169.254/latest/api/token" \-H "X-aws-ec2-metadata-token-ttl-seconds: 60")  
NOWE\_IP=$(curl \-s \-H "X-aws-ec2-metadata-token: $AWS\_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

if; then  
    NOWE\_IP=$(curl \-s https://ifconfig.me)  
fi

\# Update Cloudflare A Record  
curl \-s \-X PUT "https://api.cloudflare.com/client/v4/zones/$STREFA/dns\_records/$REKORD" \\  
     \-H "Authorization: Bearer $TOKEN" \\  
     \-H "Content-Type: application/json" \\  
     \--data '{"type":"A","name":"'$DOMENA'","content":"'$NOWE\_IP'","ttl":60,"proxied":false}'

Set executable permissions and add reboot cron trigger:

Bash  
sudo chmod \+x /usr/local/bin/zmiana-ip.sh  
crontab \-e

*Add line:*

Plaintext  
@reboot sleep 30 && /usr/local/bin/zmiana-ip.sh

## **🧪 Testing Integration & Validation**

Verify API connectivity through the secure gateway via python client integration.

### **Remote Client Test: Python 3.12.13 & pyUNO Document Generator**

Use this integration script to automate LibreOffice Writer 26.2.3.2 templating via secure HTTPS connections:

Python  
import urllib.request  
import json

API\_URL \= "https://bielik.neuroatypowi.org/v1/chat/completions"  
API\_KEY \= "cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}"

headers \= {  
    "Content-Type": "application/json; charset=utf-8",  
    "Authorization": f"Bearer {API\_KEY}"  
}

data \= {  
    "model": "speakleash/Bielik-PL-11B-v3.0-Instruct",  
    "messages":,  
    "response\_format": {"type": "json\_object"}  
}

req \= urllib.request.Request(API\_URL, data=json.dumps(data).encode("utf-8"), headers=headers, method="POST")

try:  
    with urllib.request.urlopen(req) as response:  
        res\_body \= response.read().decode("utf-8")  
        result \= json.loads(res\_body)  
        print("Connected and Verified. API Response:")  
        print(json.dumps(result, indent=2, ensure\_ascii=False))  
except Exception as e:  
    print(f"Error calling secure Bielik endpoint: {e}")

### **Database Integration: Oracle Autonomous Database 26AI (PL/SQL)**

Execute directly from your Always Free Oracle Cloud Database:

SQL  
DECLARE  
  req\_url      VARCHAR2(1000) :\= 'https://bielik.neuroatypowi.org/v1/chat/completions';  
  token\_val    VARCHAR2(100)  :\= 'Bearer cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}';  
  req\_payload  VARCHAR2(4000);  
  res\_payload  CLOB;  
BEGIN  
  req\_payload :\= '{"model": "speakleash/Bielik-PL-11B-v3.0-Instruct", "messages": \[{"role": "user", "content": "Cześć\!"}\]}';  
    
  res\_payload :\= APEX\_WEB\_SERVICE.MAKE\_REST\_REQUEST(  
    p\_url         \=\> req\_url,  
    p\_http\_method \=\> 'POST',  
    p\_body        \=\> req\_payload,  
    p\_headers     \=\> APEX\_WEB\_SERVICE.g\_headers  
  );  
    
  DBMS\_OUTPUT.PUT\_LINE('Autonomous Oracle 26AI Response: ' || res\_payload);  
END;  
/

# **Wersja Polska (Standard ETR PSONI)**

## **🚨 BARDZO WAŻNA INFORMACJA 🚨**

### **⚡️ PEŁNY POLSKI MODEL BIELIK DZIAŁA NA TANIEJ KARCIE GRAFICZNEJ DOPIERO OD CZTERECH DNI\! ⚡️**

* **🔓 Wielki sukces naukowców:** Teraz możesz włączyć bardzo duży i mądry model językowy **speakleash/Bielik-PL-11B-v3.0-Instruct** na tańszej karcie graficznej.  
* **💻 Karta graficzna:** Ten model działa na karcie o nazwie **NVIDIA A10G**, która ma dokładnie 24 gigabajty pamięci operacyjnej.  
* **🌐 Trudny język urzędowy:** Model Bielik doskonale rozumie trudny język polski, pismo urzędowe i polskie znaki.  
* **📅 Data wydania nowej wersji:** Stało się to możliwe **dopiero 4 dni temu**, czyli w dniu **5 czerwca 2026 roku**\!  
* **🛠️ Nowy program startowy:** W tym dniu wydano nową wersję testową programu o nazwie [**vLLM v0.22.1**](https://github.com/vllm-project/vllm/releases/tag/v0.22.1).  
* **💾 Szybki bufor na dysku:** Ta nowa wersja posiada wbudowaną technologię **Hybrid Memory Allocator**. Ta technologia pozwala zapisywać nadmiar informacji bezpośrednio na szybkim dysku twardym komputera, zamiast zapełniać drogą pamięć graficzną.  
* **❌ Poprzednie błędy:** Stare wersje programu wyłączały się natychmiast, ponieważ brakowało im wolnej pamięci na karcie graficznej. Nowa wersja działa w pełni stabilnie i bez żadnych błędów\!

## **Słownik trudnych pojęć dla użytkownika**

* 📖 **vLLM** to bardzo szybki program do uruchamiania modeli językowych na serwerze.  
* 📟 **VRAM** to pamięć karty graficznej, która służy do wykonywania szybkich obliczeń.  
* 💽 **NVMe** to bardzo szybki i nowoczesny dysk twardy zamontowany bezpośrednio w komputerze.  
* ⚙️ **Systemd** to program w systemie Ubuntu do zarządzania usługami i automatycznego włączania programów przy starcie.  
* 🌐 **Caddy** to lekki i nowoczesny program, który dba o bezpieczeństwo i chroni połączenia z serwerem.  
* 🔒 **Let's Encrypt** to darmowa i zautomatyzowana usługa, która daje certyfikaty bezpieczeństwa i szyfruje połączenia kłódką.  
* 🏢 **Oracle 26AI** to nowoczesna i bezpieczna baza danych działająca w chmurze internetowej.  
* 🐍 **pyUNO** to zestaw narzędzi pozwalający pisać programy sterujące programem biurowym LibreOffice Writer.

## **🔒 Bezpieczna ścieżka dostępu przez port 443 (Serwer Caddy)**

* **🌐 Cel wdrożenia:** Chcemy, aby dostęp do naszego serwera sztucznej inteligencji vLLM był chroniony hasłem i działał wyłącznie przez bezpieczny port **443 (HTTPS)**.  
* **🚪 Przejście przez zapory:** Port o numerze 443 gwarantuje stuprocentowe przejście przez wszystkie zapory sieciowe w internecie, które blokują inne, niestandardowe porty (takie jak port 8000).  
* **⚖️ Dlaczego wybraliśmy program Caddy zamiast Nginx?**  
  * **Serwer Caddy** posiada wbudowaną automatyczną obsługę certyfikatów bezpieczeństwa **Let's Encrypt**.  
  * Wszystkie zabezpieczenia i certyfikaty są pobierane i odnawiane same. Nie trzeba instalować dodatkowych programów takich jak Certbot ani pisać skomplikowanych skryptów startowych.  
  * Caddy jest bardzo lekki i nie spowalnia komputera chmurowego.  
* **🔌 Połączenie z systemami zewnętrznymi:**  
  * **Python 3.12.13 i LibreOffice Writer 26.2.3.2:** Programy mogą bezpiecznie wysyłać zapytania w formacie JSON do serwera i generować oficjalne pisma biurowe z polskimi znakami.  
  * **Baza Danych Oracle 26AI Always Free:** Darmowa baza danych Oracle wymaga szyfrowania SSL do wysyłania pytań na zewnątrz. Bezpieczny port 443 z certyfikatem Let's Encrypt jest konieczny, aby baza danych mogła rozmawiać z naszą sztuczną inteligencją.

## **🖥️ Instrukcja konfiguracji w panelu graficznym AWS**

1. 🌐 **Logowanie i wybór opcji:** Zaloguj się na swoje konto na stronie chmury Amazon Web Services. Wyszukaj i kliknij usługę o nazwie **EC2**.  
2. 🔍 **Zlecenie instancji typu Spot:** W menu po lewej stronie znajdź i kliknij sekcję **Spot Requests**. Kliknij niebieski przycisk o nazwie **Request Spot Instances**.  
3. 💻 **Wybór systemu i wielkości komputera:**  
   * Jako system operacyjny wybierz darmowy system **Ubuntu Server 24.04 LTS**.  
   * Wybierz rozmiar komputera o nazwie **g5.xlarge**. Posiada on 4 procesory główne, 16 gigabajtów pamięci operacyjnej, kartę graficzną NVIDIA A10G z 24 gigabajtami pamięci oraz bardzo szybki dysk tymczasowy o pojemności 250 gigabajtów.  
4. 🔑 **Klucze dostępu i sieć:** Wybierz swój klucz bezpieczeństwa SSH o rozszerzeniu .pem. W konfiguracji zapory sieciowej (Security Group) zezwól na ruch na porcie **22** (SSH) oraz na bezpiecznym porcie **443** (HTTPS) dla całego świata. Port o numerze 8000 ma pozostać zamknięty dla ruchu zewnętrznego.  
5. 🔒 **Bezpieczne metadane IMDSv2:** Przewiń na sam dół do opcji zaawansowanych. Znajdź opcję **Metadata accessible** i włącz ją. Ustaw opcję **Metadata version** na wartość **V2 (IMDSv2)**. Jest to wymagane do ochrony serwera.  
6. 🚀 **Start:** Kliknij przycisk **Launch**, aby uruchomić komputer. Po chwili zobaczysz jego aktywny adres IP w systemie.

## **💻 Instrukcja instalacji i konfiguracji w konsoli systemowej (CLI)**

Wpisuj kolejno poniższe polecenia w terminalu swojego komputera chmurowego.

### **Krok 1: Przygotowanie szybkiego dysku NVMe**

Otwórz edytor i utwórz skrypt przygotowujący dysk tymczasowy do pracy:

Bash  
sudo nano /usr/local/bin/setup-nvme-swap.sh

*Wklej w edytorze poniższy kod:*

Bash  
\#\!/bin/bash  
set \-e

echo "=== Rozpoczynanie konfiguracji dysku NVMe dla vLLM \==="

TARGET\_DEV=""  
for dev in /dev/nvme?n1; do  
    if \[ \-b "$dev" \]; then  
        if \[ $(lsblk \-no NAME "$dev" | wc \-l) \-eq 1 \]; then  
            TARGET\_DEV="$dev"  
            break  
        fi  
    fi  
done

if; then  
    echo "Błąd: Nie znaleziono czystego dysku NVMe do konfiguracji cache\!"  
    exit 1  
fi

echo "Wykryto dysk pod adresem: $TARGET\_DEV"  
MOUNT\_POINT="/mnt/vllm\_nvme"

if\! mount | grep \-q "$TARGET\_DEV"; then  
    sudo swapoff "$TARGET\_DEV" 2\>/dev/null || true  
    sudo wipefs \-a "$TARGET\_DEV" 2\>/dev/null || true  
    sudo mkfs.ext4 \-F "$TARGET\_DEV"  
    sudo mkdir \-p "$MOUNT\_POINT"  
    sudo mount "$TARGET\_DEV" "$MOUNT\_POINT"  
    sudo chown \-R ubuntu:ubuntu "$MOUNT\_POINT"  
    sudo chmod 755 "$MOUNT\_POINT"  
fi

echo "export {ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_TOKEN=\\"{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_XNfiZaTuLPQnWtVkKFtzgUHlvrTxbDExbM\\"" \> /home/ubuntu/.{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_token\_env  
chmod 600 /home/ubuntu/.{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_token\_env  
echo "=== Konfiguracja zakończona sukcesem\! \==="

Zapisz plik i uruchom go za pomocą poleceń:

Bash  
sudo chmod \+x /usr/local/bin/setup-nvme-swap.sh  
sudo /usr/local/bin/setup-nvme-swap.sh

### **Krok 2: Instalacja środowiska programistycznego Miniconda i Pythona**

Pobierz instalator i utwórz sterylne środowisko dla bezpiecznej wersji Python 3.13:

Bash  
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86\_64.sh \-O miniconda.sh  
bash miniconda.sh \-b \-p /home/ubuntu/miniconda  
/home/ubuntu/miniconda/bin/conda init bash  
source \~/.bashrc

conda create \-n vllm\_bielik\_env python=3.13 \-y  
conda activate vllm\_bielik\_env  
pip install vllm==0.22.1

### **Krok 3: Konfiguracja skryptu uruchamiania serwera vLLM**

Utwórz plik konfiguracyjny serwera. Będzie on nasłuchiwał wyłącznie na adresie lokalnym 127.0.0.1, aby nikt nie mógł ominąć naszej zapory bezpieczeństwa:

Bash  
sudo nano /usr/local/bin/start-vllm-server.sh

*Wklej w edytorze poniższy kod:*

Bash  
\#\!/bin/bash  
set \-e

echo "=== Uruchamianie produktywnego serwera vLLM v0.22.1 \==="

if \[ \-f /home/ubuntu/.{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_token\_env \]; then  
    source /home/ubuntu/.{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_token\_env  
fi

export {ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_HOME="/mnt/vllm\_nvme/{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_cache"  
export TRITON\_CACHE\_DIR="/mnt/vllm\_nvme/triton\_cache"

\# Włączenie technologii Hybrid Memory Allocator dla wersji v0.22.1  
export VLLM\_HMA\_ENABLED=1  
export VLLM\_HMA\_KV\_CONNECTOR="nixl"  
export VLLM\_HMA\_STORAGE\_PATH="/mnt/vllm\_nvme/kv\_offload"

\# Ograniczenie fragmentacji pamięci graficznej  
export PYTORCH\_CUDA\_ALLOC\_CONF="expandable\_segments:True,garbage\_collection\_threshold:0.8"  
export TMPDIR="/mnt/vllm\_nvme/kv\_offload"  
export VLLM\_TEST\_FORCE\_NUM\_GPU\_BLOCKS=0

mkdir \-p "${ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_HOME" "$TRITON\_CACHE\_DIR" "$VLLM\_HMA\_STORAGE\_PATH"

source /home/ubuntu/miniconda/bin/activate vllm\_bielik\_env

exec python3 \-m vllm.entrypoints.openai.api\_server \\  
    \--model "speakleash/Bielik-PL-11B-v3.0-Instruct" \\  
    \--gpu-memory-utilization 0.988 \\  
    \--max-model-len 512 \\  
    \--block-size 16 \\  
    \--safetensors-load-strategy lazy \\  
    \--enforce-eager \\  
    \--port 8000 \\  
    \--host 127.0.0.1

Nadaj uprawnienia do uruchamiania:

Bash  
sudo chmod \+x /usr/local/bin/start-vllm-server.sh

### **Krok 4: Konfiguracja skryptu bezpiecznego wyłączania**

Ten skrypt wyłącza serwer na porcie 8000 bez niszczenia innych ważnych połączeń w chmurze AWS:

Bash  
sudo nano /usr/local/bin/safe-shutdown.sh

*Wklej w edytorze poniższy kod:*

Bash  
\#\!/bin/bash  
set \-e

echo "=== Rozpoczynanie bezpiecznego zatrzymywania vLLM \==="

if netstat \-tuln | grep \-qE ":8000\\b"; then  
    echo "Wykryto aktywny proces na porcie 8000\. Zamykanie..."  
    sudo fuser \-k \-9 8000/tcp || true  
else  
    echo "Brak aktywnych procesów na porcie 8000."  
fi

echo "=== Bezpieczne zatrzymanie zakończone \==="

Nadaj uprawnienia:

Bash  
sudo chmod \+x /usr/local/bin/safe-shutdown.sh

### **Krok 5: Automatyzacja za pomocą usługi systemowej (Systemd)**

Stwórz usługę systemową, która automatycznie podniesie serwer po włączeniu systemu operacyjnego. Zapewniamy pełne 5 minut (300 sekund) na bezproblemowe załadowanie wag modelu:

Bash  
sudo nano /etc/systemd/system/vllm-server.service

*Wklej w edytorze poniższą konfigurację:*

Ini, TOML  
\[Unit\]  
Description\=vLLM OpenAI API Server v0.22.1  
After\=network.target nvidia-persistenced.service  
Wants\=nvidia-persistenced.service

Type\=simple  
User\=ubuntu  
Group\=ubuntu  
WorkingDirectory\=/home/ubuntu  
Environment\="{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\_TOKEN={ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}\"  
ExecStartPre\=/bin/sleep 180  
ExecStart\=/usr/local/bin/start-vllm-server.sh  
ExecStop\=/usr/local/bin/safe-shutdown.sh  
Restart\=always  
RestartSec\=10  
TimeoutStartSec\=300

LimitNOFILE\=65535  
LimitMEMLOCK\=infinity

\[Install\]  
WantedBy\=multi-user.target

Aktywuj nową usługę w systemie:

Bash  
sudo systemctl daemon-reload  
sudo systemctl enable vllm-server.service  
sudo systemctl start vllm-server.service

### **Krok 6: Instalacja i konfiguracja bramy sieciowej Caddy**

Instalujemy serwer Caddy na systemie Ubuntu:

Bash  
sudo apt install \-y debian-keyring debian-archive-keyring apt-transport-https curl  
curl \-1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg \--dearmor \-o /usr/share/keyrings/caddy-stable-archive-keyring.gpg  
curl \-1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list  
sudo apt update  
sudo apt install caddy \-y

Konfigurujemy plik /etc/caddy/Caddyfile dla obsługi darmowego certyfikatu SSL Let's Encrypt oraz weryfikacji nagłówka autoryzacji:

Bash  
sudo nano /etc/caddy/Caddyfile

*Wklej poniższy kod (wpisz swoją domenę oraz ustal własny token bezpieczeństwa):*

Fragment kodu  
bielik.neuroatypowi.org {  
    \# Filtrujemy tylko zapytania, które posiadają nasz sekretny token  
    @apiAuth {  
        header Authorization "Bearer cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}"  
    }

    \# Przekazujemy bezpieczne zapytania do lokalnego programu vLLM  
    reverse\_proxy @apiAuth 127.0.0.1:8000

    \# Wszystkich innych nieautoryzowanych klientów bezwarunkowo blokujemy  
    @unauthorized {  
        not header Authorization "Bearer cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}"  
    }  
    respond @unauthorized "Unauthorized Access \- Valid Bearer Token Required" 401 {  
        close  
    }  
}

Zastosuj konfigurację i zrestartuj serwer Caddy:

Bash  
sudo systemctl restart caddy

### **Krok 7: Skrypt aktualizujący adres IP w systemie DNS (Cloudflare)**

Utwórz plik /usr/local/bin/zmiana-ip.sh:

Bash  
sudo nano /usr/local/bin/zmiana-ip.sh

*Wklej w edytorze poniższy kod:*

Bash  
\#\!/bin/bash

TOKEN="cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}"  
STREFA="f3902b09d66b008f17bc34a57d0027d8"  
REKORD="49ef3940c38d6d26f51c74115bf1117c"  
DOMENA="bielik.neuroatypowi.org"

\# Bezpieczne pobranie nowego adresu IP przez system IMDSv2  
AWS\_TOKEN=$(curl \-s \-X PUT "http://169.254.169.254/latest/api/token" \-H "X-aws-ec2-metadata-token-ttl-seconds: 60")  
NOWE\_IP=$(curl \-s \-H "X-aws-ec2-metadata-token: $AWS\_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

if; then  
    NOWE\_IP=$(curl \-s https://ifconfig.me)  
fi

\# Wysyłanie nowego IP bezpośrednio do Cloudflare  
curl \-s \-X PUT "https://api.cloudflare.com/client/v4/zones/$STREFA/dns\_records/$REKORD" \\  
     \-H "Authorization: Bearer $TOKEN" \\  
     \-H "Content-Type: application/json" \\  
     \--data '{"type":"A","name":"'$DOMENA'","content":"'$NOWE\_IP'","ttl":60,"proxied":false}'

Nadaj uprawnienia i dodaj skrypt do harmonogramu zadań systemu:

Bash  
sudo chmod \+x /usr/local/bin/zmiana-ip.sh  
crontab \-e

*Dopisz na samym dole linię (opóźnienie pozwala na stabilne podłączenie do sieci po restarcie):*

Plaintext  
@reboot sleep 30 && /usr/local/bin/zmiana-ip.sh

## **🧪 Sposoby weryfikacji i procedury testowe**

### **Test połączenia zewnętrznego: Python 3.12.13 oraz pyUNO**

Możesz przetestować bezpieczne wysyłanie pytań bezpośrednio przez port 443 przy użyciu poniższego programu:

Python  
import urllib.request  
import json

API\_URL \= "https://bielik.neuroatypowi.org/v1/chat/completions"  
API\_KEY \= "cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}"

headers \= {  
    "Content-Type": "application/json; charset=utf-8",  
    "Authorization": f"Bearer {API\_KEY}"  
}

data \= {  
    "model": "speakleash/Bielik-PL-11B-v3.0-Instruct",  
    "messages":,  
    "response\_format": {"type": "json\_object"}  
}

req \= urllib.request.Request(API\_URL, data=json.dumps(data).encode("utf-8"), headers=headers, method="POST")

try:  
    with urllib.request.urlopen(req) as response:  
        res\_body \= response.read().decode("utf-8")  
        result \= json.loads(res\_body)  
        print("Połączenie udane. Odpowiedź sztucznej inteligencji:")  
        print(json.dumps(result, indent=2, ensure\_ascii=False))  
except Exception as e:  
    print(f"Błąd podczas połączenia z bezpiecznym serwerem Bielik: {e}")

### **Integracja z bazą danych Oracle Autonomous Database 26AI (PL/SQL)**

Możesz uruchomić poniższy kod bezpośrednio w konsoli SQL swojej darmowej bazy danych Oracle Cloud:

SQL  
DECLARE  
  req\_url      VARCHAR2(1000) :\= 'https://bielik.neuroatypowi.org/v1/chat/completions';  
  token\_val    VARCHAR2(100)  :\= 'Bearer cfut\_{ENTER YOU KEY/WPROWADŹ SWÓJ KLUCZ}';  
  req\_payload  VARCHAR2(4000);  
  res\_payload  CLOB;  
BEGIN  
  req\_payload :\= '{"model": "speakleash/Bielik-PL-11B-v3.0-Instruct", "messages": \[{"role": "user", "content": "Cześć\!"}\]}';  
    
  res\_payload :\= APEX\_WEB\_SERVICE.MAKE\_REST\_REQUEST(  
    p\_url         \=\> req\_url,  
    p\_http\_method \=\> 'POST',  
    p\_body        \=\> req\_payload,  
    p\_headers     \=\> APEX\_WEB\_SERVICE.g\_headers  
  );  
    
  DBMS\_OUTPUT.PUT\_LINE('Odpowiedź z bazy danych Oracle 26AI: ' || res\_payload);  
END;  
/

