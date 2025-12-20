# Medical Document Analysis System: Complete Technical Guide

**The "gpt-oss-120b" model exists but is text-only—it cannot process medical PDFs with graphics.** For multimodal RAG with Polish medical documents, use **Qwen2.5-VL-72B** (open-source, matches GPT-4o's 75% OCR accuracy) or **GPT-4o** directly. A critical infrastructure finding: **Pathway does not natively support ARM64**, requiring x86_64 emulation on Oracle A1 instances. The proposed workload of 720 pages/month fits comfortably within Cloudflare's free tier (10,000 neurons/day), and Google Cloud Run's scale-to-zero configuration yields **$0 monthly cost** for 4 hours/week usage within free tier limits.

---

## gpt-oss-120b cannot process images or PDFs

OpenAI released gpt-oss-120b (GPT OSS 120B) as an open-weight model with **117B parameters and 5.1B active** (Mixture of Experts architecture). However, it was trained on a "mostly English, text-only dataset" and explicitly **lacks vision/multimodal capabilities**. OpenAI's release notes state: "For those seeking multimodal support, models available through our API platform remain the best option."

For medical document analysis with Polish/English/Latin text and embedded graphics, the recommended alternatives are:

| Model | OCR Accuracy | Polish Support | Vision | License | Best For |
|-------|--------------|----------------|--------|---------|----------|
| **GPT-4o** | ~75% | 79.7% on Polish medical exams | ✅ Native | Proprietary | Production medical systems |
| **Qwen2.5-VL-72B** | ~75% | Supported (European languages) | ✅ Native | Apache 2.0 | Self-hosted HIPAA compliance |
| **Qwen2.5-VL-32B** | ~75% | Supported | ✅ Native | Apache 2.0 | Cost-effective alternative |
| **InternVL3.5** | #1 DocVQA | Strong | ✅ | Open | Charts and tables |

gpt-oss-120b can serve as the **text reasoning component** after visual content extraction by a vision model, but cannot perform initial document processing.

---

## Pathway's ARM64 limitation blocks direct Oracle A1 deployment

Pathway's documentation explicitly states: "For compatibility reasons, you should use x86_64 Linux container." The Docker images and Rust engine require x86_64 architecture. **Direct deployment on Oracle's ARM-based A1 Flex instances is not supported.**

**Workarounds for ARM64:**
1. **QEMU emulation**: Run x86_64 containers with `--platform=linux/x86_64` flag (performance penalty of 30-50%)
2. **Separate x86_64 instance**: Use Oracle E2.1.Micro (free tier, x86_64) for Pathway components
3. **Hybrid architecture**: Oracle A1 for general processing, Cloud Run (x86_64) for Pathway workloads

### LLM integration through LiteLLM

Pathway supports external providers through its LiteLLM wrapper:

```yaml
# pathway-config.yaml
llm: !pw.xpacks.llm.llms.LiteLLMChat
  model: "together_ai/meta-llama/Llama-3.3-70b"  # Together AI
  # model: "openrouter/anthropic/claude-3-sonnet"  # OpenRouter
  # model: "cloudflare/@cf/meta/llama-3.1-8b-instruct"  # Cloudflare
```

### Fuzzy Join for medical document matching

Pathway's `smart_fuzzy_join` uses phonetic, token-based, and distance-based matching algorithms. For finding similarities between family members' medical documents:

```python
import pathway as pw

family_records = pw.io.csv.read("./family_medical/", schema=FamilyRecords)
external_records = pw.io.csv.read("./external_labs/", schema=LabRecords)

matches = pw.ml.smart_table_ops.fuzzy_match_tables(
    family_records, external_records,
    left_projection={"patient_name": "C1", "date": "C2"},
    right_projection={"name": "C1", "lab_date": "C2"},
)
high_confidence = matches.filter(pw.this.weight > 0.8)
```

For Polish handwritten text, use **PaddleOCR** or external services (Azure Vision OCR) as Docling lacks handwriting support.

---

## Token consumption fits within free tiers

### Calculation methodology

| Component | Tokens per A4 Page |
|-----------|-------------------|
| Text (Inter 12pt, ~3000 chars) | 750-900 tokens |
| Image (high detail) | 765 tokens |
| **Total per page** | 835-1,665 tokens |

For 15 documents × 12 pages × 6-8x RAG multiplier: **1.5-2.5 million tokens/month**

### Cloudflare Workers AI free tier capacity

The free tier provides 10,000 neurons/day. Using Llama 3.2 3B as reference:
- Input: ~2.2M tokens per 10K neurons
- Output: ~328K tokens per 10K neurons

**Your target of 720 pages/month requires approximately 8,550 pages capacity available—11x headroom.** The free tier comfortably handles this workload for text processing. For vision models, ~4,410 neurons per 1M input tokens applies.

### Together AI Batch API (50% discount confirmed)

| Model | Standard/1M tokens | Batch Rate (50% off) |
|-------|-------------------|---------------------|
| Llama 3.1 8B | $0.18 | **$0.09** |
| Llama 3.3 70B | $0.88 | **$0.44** |
| DeepSeek-V3 | $0.60/$1.70 | **$0.30/$0.85** |

For 2M tokens/month: **$0.18-1.65/month** depending on model choice. Batch processing completes within 24 hours (most finish in hours).

---

## Oracle Cloud A1 European availability remains challenging

Frankfurt (eu-frankfurt-1) has three availability domains but frequently shows "Out of host capacity" errors. The most effective solution is upgrading to **Pay-As-You-Go** (no charges for Always Free resources) which provides priority for instance launches.

### Terraform installation on Windows 11 Pro

```powershell
# Method 1: Winget (Recommended)
winget install Hashicorp.Terraform
terraform --version

# OCI CLI Installation
# Download MSI from: https://github.com/oracle/oci-cli/releases
# Run installer, then:
oci setup config
```

### Complete Terraform configuration

**File: `main.tf`**
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

variable "tenancy_ocid" { type = string }
variable "user_ocid" { type = string }
variable "fingerprint" { type = string }
variable "private_key_path" { type = string }
variable "region" { type = string; default = "eu-frankfurt-1" }
variable "compartment_ocid" { type = string }
variable "ssh_public_key" { type = string }

# VCN
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "a1-vcn"
  dns_label      = "a1vcn"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "a1-igw"
  enabled        = true
}

resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "a1-rt"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "a1-security-list"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "6"
    stateless = false
    tcp_options { min = 22; max = 22 }
  }

  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "6"
    stateless = false
    tcp_options { min = 443; max = 443 }
  }
}

resource "oci_core_subnet" "main" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "a1-public-subnet"
  dns_label                  = "a1subnet"
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
  prohibit_public_ip_on_vnic = false
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "a1_flex" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "a1-medical-rag"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.oracle_linux.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

output "instance_public_ip" { value = oci_core_instance.a1_flex.public_ip }
output "ssh_command" { value = "ssh -i ~/.ssh/id_rsa opc@${oci_core_instance.a1_flex.public_ip}" }
```

---

## Cloud Run scale-to-zero costs $0 within free tier

For 4 hours/week (16 hours/month) with 1 vCPU and 512Mi memory:

| Resource | Usage | Free Tier | Billable |
|----------|-------|-----------|----------|
| CPU | 57,600 vCPU-seconds | 180,000 | $0 |
| Memory | 28,800 GiB-seconds | 360,000 | $0 |
| Requests | ~10,000 | 2,000,000 | $0 |

**File: `cloudrun.tf`**
```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.28.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" { type = string }
variable "region" { type = string; default = "us-central1" }

resource "google_cloud_run_v2_service" "api_proxy" {
  name     = "medical-rag-api"
  location = var.region

  template {
    scaling {
      min_instance_count = 0  # Scale to zero
      max_instance_count = 5
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/api-repo/api-proxy:latest"

      resources {
        limits = { cpu = "1"; memory = "512Mi" }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      ports { container_port = 8080 }
    }

    timeout = "300s"
    max_instance_request_concurrency = 80
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  location = google_cloud_run_v2_service.api_proxy.location
  name     = google_cloud_run_v2_service.api_proxy.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "service_url" { value = google_cloud_run_v2_service.api_proxy.uri }
```

**Deployment commands:**
```bash
gcloud run deploy medical-rag-api \
  --source . \
  --region=us-central1 \
  --min-instances=0 \
  --max-instances=5 \
  --cpu=1 \
  --memory=512Mi \
  --allow-unauthenticated
```

---

## Cloudflare Workers AI Python integration

**File: `cloudflare_client.py`**
```python
import requests
import os
from typing import Optional

ACCOUNT_ID = os.environ["CLOUDFLARE_ACCOUNT_ID"]
API_TOKEN = os.environ["CLOUDFLARE_API_TOKEN"]

def generate_text(prompt: str, model: str = "@cf/meta/llama-3.1-8b-instruct") -> str:
    """Generate text using Cloudflare Workers AI."""
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/run/{model}"
    
    response = requests.post(
        url,
        headers={"Authorization": f"Bearer {API_TOKEN}", "Content-Type": "application/json"},
        json={"messages": [{"role": "user", "content": prompt}]}
    )
    response.raise_for_status()
    return response.json()["result"]["response"]

def get_embeddings(texts: list[str], model: str = "@cf/baai/bge-m3") -> list[list[float]]:
    """Get multilingual embeddings (Polish supported via bge-m3)."""
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/run/{model}"
    
    response = requests.post(
        url,
        headers={"Authorization": f"Bearer {API_TOKEN}", "Content-Type": "application/json"},
        json={"text": texts}
    )
    response.raise_for_status()
    return response.json()["result"]["data"]

# OpenAI SDK compatible usage
from openai import OpenAI

client = OpenAI(
    api_key=API_TOKEN,
    base_url=f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/ai/v1"
)

response = client.chat.completions.create(
    model="@cf/meta/llama-3.1-8b-instruct",
    messages=[{"role": "user", "content": "Explain RAG in Polish"}]
)
```

**Terraform import for existing Cloudflare configuration:**
```bash
# Install cf-terraforming
brew install cloudflare/cloudflare/cf-terraforming

# Generate config preserving security rules
cf-terraforming generate --resource-type cloudflare_zone --zone $ZONE_ID > zone.tf
cf-terraforming generate --resource-type cloudflare_ruleset --zone $ZONE_ID > waf.tf
cf-terraforming import --resource-type cloudflare_zone --modern-import-block --zone $ZONE_ID >> imports.tf
```

---

## Google Apps Script "Audyt AI" menu implementation

**File: `Code.gs`**
```javascript
// KONFIGURACJA (Polski komentarz dla dostępności)
const CONFIG = {
  CLOUD_RUN_URL: 'https://twoja-usluga-xxxxxx-uc.a.run.app',
  MAX_CHUNK_SIZE: 10000
};

// Trigger - Menu przy otwarciu dokumentu
function onOpen(e) {
  DocumentApp.getUi()
    .createMenu('🔍 Audyt AI')
    .addItem('📄 Analizuj cały dokument', 'analizujDokument')
    .addItem('✏️ Analizuj zaznaczony tekst', 'analizujZaznaczenie')
    .addSeparator()
    .addItem('🔄 Sprawdź połączenie', 'sprawdzPolaczenie')
    .addItem('❓ Pomoc', 'pokazPomoc')
    .addToUi();
}

// Analiza dokumentu
function analizujDokument() {
  const ui = DocumentApp.getUi();
  try {
    const tresc = DocumentApp.getActiveDocument().getBody().getText();
    if (!tresc.trim()) {
      ui.alert('⚠️ Uwaga', 'Dokument jest pusty.', ui.ButtonSet.OK);
      return;
    }
    
    const token = ScriptApp.getIdentityToken();
    const response = UrlFetchApp.fetch(CONFIG.CLOUD_RUN_URL + '/analyze', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      },
      payload: JSON.stringify({
        tekst: tresc,
        dokument_id: DocumentApp.getActiveDocument().getId()
      }),
      muteHttpExceptions: true
    });
    
    const kod = response.getResponseCode();
    if (kod >= 200 && kod < 300) {
      const wyniki = JSON.parse(response.getContentText());
      wyswietlWyniki(wyniki);
    } else {
      ui.alert('❌ Błąd', 'Serwer zwrócił kod: ' + kod, ui.ButtonSet.OK);
    }
  } catch (error) {
    ui.alert('❌ Błąd', error.message, ui.ButtonSet.OK);
  }
}

function wyswietlWyniki(wyniki) {
  const html = HtmlService.createHtmlOutput(
    '<div style="font-family:Arial;padding:16px;">' +
    '<h2 style="color:#1a73e8;">📋 Wyniki analizy</h2>' +
    '<div style="background:#f8f9fa;padding:12px;border-radius:8px;">' +
    '<p>' + (wyniki.podsumowanie || 'Brak podsumowania') + '</p>' +
    '</div></div>'
  ).setWidth(400).setHeight(300);
  DocumentApp.getUi().showSidebar(html);
}

function sprawdzPolaczenie() {
  const ui = DocumentApp.getUi();
  try {
    const token = ScriptApp.getIdentityToken();
    const response = UrlFetchApp.fetch(CONFIG.CLOUD_RUN_URL + '/health', {
      method: 'GET',
      headers: { 'Authorization': 'Bearer ' + token },
      muteHttpExceptions: true
    });
    ui.alert('✅ Status', 'Połączenie OK (kod: ' + response.getResponseCode() + ')', ui.ButtonSet.OK);
  } catch (e) {
    ui.alert('❌ Błąd', 'Nie można połączyć: ' + e.message, ui.ButtonSet.OK);
  }
}

function pokazPomoc() {
  DocumentApp.getUi().alert('❓ Pomoc Audyt AI',
    'Krok 1: Kliknij "Analizuj dokument" aby przesłać do AI\n' +
    'Krok 2: Poczekaj na wyniki w panelu bocznym\n' +
    'Krok 3: Przeczytaj sugestie i poprawki\n\n' +
    'W razie problemów: sprawdź połączenie', DocumentApp.getUi().ButtonSet.OK);
}
```

**File: `appsscript.json`**
```json
{
  "timeZone": "Europe/Warsaw",
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "oauthScopes": [
    "https://www.googleapis.com/auth/documents.currentonly",
    "https://www.googleapis.com/auth/script.container.ui",
    "https://www.googleapis.com/auth/script.external_request"
  ]
}
```

---

## Oracle Linux setup shell script

**File: `setup-oracle-linux.sh`**
```bash
#!/bin/bash
# Skrypt instalacyjny dla Oracle Linux 9 ARM64
# UWAGA: Pathway wymaga emulacji x86_64

echo "=== Krok 1: Aktualizacja systemu ==="
sudo dnf update -y

echo "=== Krok 2: Instalacja Python 3.11 ==="
sudo dnf install -y python3.11 python3.11-pip python3.11-devel

echo "=== Krok 3: Instalacja Docker ==="
sudo dnf install -y docker-engine
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker opc

echo "=== Krok 4: Instalacja QEMU dla emulacji x86_64 ==="
sudo dnf install -y qemu-user-static
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

echo "=== Krok 5: Tworzenie środowiska wirtualnego ==="
python3.11 -m venv ~/pathway-env
source ~/pathway-env/bin/activate

echo "=== Krok 6: Instalacja zależności ==="
pip install --upgrade pip
pip install requests flask gunicorn openai langchain

echo "=== Krok 7: Uruchomienie Pathway w kontenerze x86_64 ==="
docker run --platform=linux/x86_64 -d \
  --name pathway-rag \
  -p 8000:8000 \
  -v ~/documents:/app/documents \
  -e OPENAI_API_KEY=$OPENAI_API_KEY \
  python:3.11 \
  bash -c "pip install pathway && python /app/rag_pipeline.py"

echo "=== Weryfikacja ==="
docker ps
curl http://localhost:8000/health

echo "=== Instalacja zakończona ==="
echo "Połącz się: ssh -i ~/.ssh/id_rsa opc@<IP>"
```

---

## Complete Pathway RAG pipeline

**File: `rag_pipeline.py`**
```python
"""
Medical Document RAG Pipeline with Pathway
Supports: Cloudflare, Together AI, OpenRouter via LiteLLM
"""
import pathway as pw
from pathway.xpacks.llm import embedders, llms, parsers, splitters
from pathway.xpacks.llm.question_answering import BaseRAGQuestionAnswerer
from pathway.xpacks.llm.document_store import DocumentStore
import os

# Configuration
CLOUDFLARE_ACCOUNT_ID = os.environ.get("CLOUDFLARE_ACCOUNT_ID")
CLOUDFLARE_API_TOKEN = os.environ.get("CLOUDFLARE_API_TOKEN")

# LLM via LiteLLM (supports multiple providers)
chat = llms.LiteLLMChat(
    model="together_ai/meta-llama/Llama-3.3-70b-Instruct-Turbo",
    # Alternative: "openrouter/anthropic/claude-3-sonnet"
    # Alternative: "cloudflare/@cf/meta/llama-3.1-8b-instruct"
    retry_strategy=pw.udfs.ExponentialBackoffRetryStrategy(max_retries=6),
    cache_strategy=pw.udfs.DefaultCache(),
    capacity=4,  # Rate limiting
)

# Document parser with OCR
parser = parsers.DoclingParser(
    table_parsing_strategy="llm",
    image_parsing_strategy="llm",
    multimodal_llm=chat,
)

# Embeddings (multilingual for Polish)
embedder = embedders.OpenAIEmbedder(
    model="text-embedding-3-small",
    cache_strategy=pw.udfs.DefaultCache()
)

# Document processing
splitter = splitters.TokenCountSplitter(min_tokens=100, max_tokens=500)
index = pw.indexing.BruteForceKnnFactory(embedder=embedder)

# Data source
medical_docs = pw.io.fs.read(
    path="./documents/",
    format="binary",
    with_metadata=True,
)

# Document store
doc_store = DocumentStore(
    [medical_docs],
    retriever_factory=index,
    splitter=splitter,
    parser=parser,
)

# RAG application
app = BaseRAGQuestionAnswerer(
    llm=chat,
    indexer=doc_store,
    search_topk=6,
)

# Fuzzy Join for family document matching
class FamilyRecord(pw.Schema):
    patient_name: str
    date: str
    diagnosis: str

family_records = pw.io.csv.read("./family/", schema=FamilyRecord)
external_records = pw.io.csv.read("./external/", schema=FamilyRecord)

matches = pw.ml.smart_table_ops.fuzzy_match_tables(
    family_records, external_records
)
high_confidence_matches = matches.filter(pw.this.weight > 0.8)

# Serve API
if __name__ == "__main__":
    app.build_server(host="0.0.0.0", port=8000)
    app.run_server(with_cache=True)
```

---

## Recommended architecture and cost summary

The optimal architecture separates compute by platform capability:

| Component | Platform | Monthly Cost |
|-----------|----------|--------------|
| Pathway RAG | Cloud Run (x86_64, scale-to-zero) | $0 (free tier) |
| Document storage | Oracle A1 (24GB RAM) | $0 (free tier) |
| Text embeddings | Cloudflare Workers AI | $0 (free tier) |
| Heavy reasoning | Together AI Batch | $0.18-1.65 |
| Vision processing | GPT-4o-mini (low detail) | ~$0.50 |
| **Total** | | **~$0.70-2.15/month** |

For your workload of 15 documents/month with 10-15 pages each, both Cloudflare free tier (10,000 neurons/day) and Google Cloud Run free tier (180,000 vCPU-seconds) provide ample capacity. Together AI's 50% Batch discount makes reasoning tasks extremely affordable at $0.09-0.44 per million tokens.

## Conclusion

This medical document analysis system is feasible within free tier limits with minimal paid usage. The key constraints are: use Qwen2.5-VL or GPT-4o for vision (not gpt-oss-120b), run Pathway on x86_64 via Cloud Run rather than Oracle A1 directly, and leverage Cloudflare's bge-m3 embeddings for Polish language support. The complete Terraform, Python, and Apps Script code provided enables deployment with CLI-focused, step-by-step instructions suitable for users requiring accessibility accommodations.