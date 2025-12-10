import sys
import unohelper
import officehelper
import json
import urllib.request
import urllib.parse
from com.sun.star.task import XJobExecutor
import uno
import os 
import logging

# --- REJESTR MODELI (STRATEGIA GOOGLE-FIRST) ---
# Zgodność: Python 3.8+ (Wbudowany w LO).
# Niezależność: Brak bezpośrednich wiązań do JRE (Safe for OpenJDK 17).

MODELS_REGISTRY = {
    "local": {
        "name": "Local (Ollama/WebUI)",
        "default_url": "http://localhost:11434/v1/chat/completions",
        "default_model": "llama3",
        "auth_type": "none"
    },
    "bielik": {
        "name": "Bielik-11B (Google Cloud Run)",
        "default_url": "https://TWOJA-USLUGA.run.app/v1/chat/completions", 
        "default_model": "bielik-11b-v2.3",
        "auth_type": "bearer"
    },
    "gemini": {
        "name": "Gemini 3 Pro (Deep Research)",
        "default_url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent",
        "default_model": "gemini-1.5-pro",
        "auth_type": "api_key_query" # Gemini często używa klucza w URL
    },
    "claude": {
        "name": "Claude 4.5 Sonnet (Anthropic)",
        "default_url": "https://api.anthropic.com/v1/messages", 
        "default_model": "claude-3-5-sonnet-20240620",
        "auth_type": "header_x_api_key"
    },
    "openai_o3": {
        "name": "OpenAI o3-pro (High Reasoning)",
        "default_url": "https://api.openai.com/v1/chat/completions",
        "default_model": "o3-pro",
        "auth_type": "bearer"
    }
}

class MainJob(unohelper.Base, XJobExecutor):
    def __init__(self, ctx):
        self.ctx = ctx
        try:
            self.sm = ctx.getServiceManager()
            self.desktop = XSCRIPTCONTEXT.getDesktop()
        except NameError:
            self.sm = ctx.ServiceManager
            self.desktop = self.ctx.getServiceManager().createInstanceWithContext(
                "com.sun.star.frame.Desktop", self.ctx)

    # --- KONFIGURACJA (JSON) ---
    def get_config_path(self):
        name_file = "localwriter_v2.json"
        path_settings = self.sm.createInstanceWithContext('com.sun.star.util.PathSettings', self.ctx)
        user_config_path = getattr(path_settings, "UserConfig")
        if user_config_path.startswith('file://'):
            user_config_path = str(uno.fileUrlToSystemPath(user_config_path))
        return os.path.join(user_config_path, name_file)

    def load_config(self):
        default_config = {
            "current_profile": "local",
            "profiles": {}, 
            "common": {"extend_max_tokens": 500, "system_prompt": "Jesteś ekspertem prawnym."}
        }
        path = self.get_config_path()
        if not os.path.exists(path): return default_config
        try:
            with open(path, 'r') as file:
                data = json.load(file)
                if "profiles" not in data: data["profiles"] = {}
                return data
        except: return default_config

    def save_config(self, config):
        try:
            with open(self.get_config_path(), 'w') as file:
                json.dump(config, file, indent=4)
        except Exception as e: print(f"Config Error: {e}")

    def get_active_profile_settings(self, config):
        profile_key = config.get("current_profile", "local")
        # Fallback do 'local' jeśli klucz nie istnieje
        registry_data = MODELS_REGISTRY.get(profile_key, MODELS_REGISTRY["local"])
        user_profile = config["profiles"].get(profile_key, {})
        
        return {
            "key": profile_key,
            "name": registry_data["name"],
            "url": user_profile.get("url", registry_data["default_url"]),
            "model": user_profile.get("model", registry_data["default_model"]),
            "api_key": user_profile.get("api_key", ""),
            "auth_type": registry_data["auth_type"]
        }

    # --- UI (UNO Dialogs) ---
    def input_box(self, message, title="", default=""):
        # Standardowy dialog UNO kompatybilny z każdym backendem GUI
        ctx = self.ctx
        sm = self.sm
        dialog = sm.createInstanceWithContext("com.sun.star.awt.UnoControlDialog", ctx)
        model = sm.createInstanceWithContext("com.sun.star.awt.UnoControlDialogModel", ctx)
        dialog.setModel(model)
        model.Title = title; model.Width = 300; model.Height = 100
        
        lbl = model.createInstance("com.sun.star.awt.UnoControlFixedTextModel")
        lbl.PositionX = 10; lbl.PositionY = 10; lbl.Width = 280; lbl.Height = 20
        lbl.Label = message; model.insertByName("lbl", lbl)
        
        edt = model.createInstance("com.sun.star.awt.UnoControlEditModel")
        edt.PositionX = 10; edt.PositionY = 35; edt.Width = 280; edt.Height = 20
        edt.Text = str(default); model.insertByName("edt", edt)
        
        btn = model.createInstance("com.sun.star.awt.UnoControlButtonModel")
        btn.PositionX = 100; btn.PositionY = 65; btn.Width = 100; btn.Height = 25
        btn.Label = "OK"; btn.PushButtonType = 1; model.insertByName("btn", btn)
        
        frame = self.desktop.getCurrentFrame()
        window = frame.getContainerWindow() if frame else None
        dialog.createPeer(sm.createInstanceWithContext("com.sun.star.awt.Toolkit", ctx), window)
        
        if dialog.execute(): return dialog.getControl("edt").getModel().Text
        return ""

    def show_settings_dialog(self):
        config = self.load_config()
        active = self.get_active_profile_settings(config)
        
        url = self.input_box(f"Endpoint URL ({active['name']}):", "Konfiguracja", active['url'])
        if not url: return
        model = self.input_box("Nazwa modelu:", "Konfiguracja", active['model'])
        
        key_prompt = "Podaj API Key:"
        if active['auth_type'] == 'bearer': key_prompt = "Podaj Identity Token (gcloud auth print-identity-token):"
        key = self.input_box(key_prompt, "Autoryzacja", active['api_key'])

        pk = active['key']
        if pk not in config["profiles"]: config["profiles"][pk] = {}
        config["profiles"][pk].update({"url": url, "model": model, "api_key": key})
        self.save_config(config)
        self.msg_box("Zapisano.")

    def msg_box(self, message):
        try:
            parent = self.desktop.getCurrentFrame().getContainerWindow()
            tk = self.sm.createInstanceWithContext("com.sun.star.awt.Toolkit", self.ctx)
            tk.createMessageBox(parent, "INFOBOX", 1, "localwriter", message).execute()
        except: pass

    # --- KOMUNIKACJA SIECIOWA (Hardened for Cloud Run) ---
    def call_llm(self, prompt, is_edit_mode=False):
        config = self.load_config()
        s = self.get_active_profile_settings(config)
        
        # Budowanie payloadu
        messages = [{"role": "user", "content": prompt}]
        sys_prompt = config["common"].get("system_prompt", "")
        if sys_prompt: messages.insert(0, {"role": "system", "content": sys_prompt})

        # Specyficzna obsługa Gemini (Google format) vs OpenAI format
        if "gemini" in s['key']:
            # Gemini native format (simplified adapter)
            data = {
                "contents": [{"parts": [{"text": prompt}]}]
            }
            # System prompt dla Gemini jest w innym polu, ale dla uproszczenia tutaj pomijamy
        else:
            # Standard OpenAI/Bielik/Claude-via-proxy format
            data = {
                "model": s['model'],
                "messages": messages,
                "temperature": 0.7,
                "stream": False
            }
            if not is_edit_mode: data["max_tokens"] = int(config["common"].get("extend_max_tokens", 200))

        json_data = json.dumps(data).encode('utf-8')
        headers = {'Content-Type': 'application/json'}

        # Autoryzacja
        if s['auth_type'] == 'bearer' and s['api_key']:
            headers['Authorization'] = f"Bearer {s['api_key']}"
        elif s['auth_type'] == 'header_x_api_key' and s['api_key']:
            headers['x-api-key'] = s['api_key']
            headers['anthropic-version'] = '2023-06-01'
        
        # URL adjustments
        req_url = s['url']
        if s['auth_type'] == 'api_key_query' and s['api_key']:
            separator = "&" if "?" in req_url else "?"
            req_url += f"{separator}key={s['api_key']}"

        req = urllib.request.Request(req_url, data=json_data, headers=headers, method='POST')

        try:
            # WAŻNE: timeout=120 sekund dla Cloud Run Cold Start i o3-pro reasoning
            with urllib.request.urlopen(req, timeout=120) as response:
                res_body = response.read().decode('utf-8')
                result = json.loads(res_body)
                
                # Parsowanie odpowiedzi (Adaptery)
                if "gemini" in s['key']:
                    try: return result['candidates'][0]['content']['parts'][0]['text']
                    except: return f"Gemini Error: {str(result)}"
                elif "content" in result: # Claude native direct
                    return result['content'][0]['text']
                elif "choices" in result: # OpenAI / Bielik standard
                    if "text" in result["choices"][0]: return result["choices"][0]["text"]
                    return result["choices"][0]["message"]["content"]
                else:
                    return f"Nieznany format: {str(result)}"
                    
        except urllib.error.HTTPError as e:
            return f"Błąd HTTP {e.code}: {e.read().decode('utf-8')}"
        except Exception as e:
            return f"Błąd połączenia ({s['name']}): {str(e)}"

    def trigger(self, args):
        if args.startswith("SwitchModel_"):
            new_profile = args.replace("SwitchModel_", "")
            config = self.load_config()
            if new_profile in MODELS_REGISTRY:
                config["current_profile"] = new_profile
                self.save_config(config)
                self.msg_box(f"Aktywowano: {MODELS_REGISTRY[new_profile]['name']}")
            else: self.msg_box("Nieznany profil.")
            return

        if args == "Settings":
            self.show_settings_dialog(); return

        # Obsługa dokumentu
        model = self.desktop.getCurrentComponent()
        if not hasattr(model, "CurrentController"): return
        sel = model.CurrentController.getSelection()
        if not sel or sel.getCount() == 0: return
        item = sel.getByIndex(0)
        text = item.getString()
        if not text: return

        if args == "ExtendSelection":
            res = self.call_llm(text, False)
            item.setString(text + " " + res)
        elif args == "EditSelection":
            instr = self.input_box("Instrukcja edycji:", "Edycja")
            if instr:
                full_prompt = f"Tekst: {text}\nInstrukcja: {instr}\nPoprawiona wersja:"
                res = self.call_llm(full_prompt, True)
                item.setString(res)

def main(): print("Uruchom w LibreOffice.")
g_ImplementationHelper = unohelper.ImplementationHelper()
g_ImplementationHelper.addImplementation(MainJob, "org.extension.sample.do", ("com.sun.star.task.Job",), )