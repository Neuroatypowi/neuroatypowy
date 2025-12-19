# -*- coding: utf-8 -*-
"""
AIWRITER - Pakiet rozszerzen AI dla LibreOffice Writer
=======================================================

AIWRITER to framework dla roznych modulow AI:
- POLONISTA: Prosty Jezyk (Bielik-11B via NVIDIA NIM)
- [przyszle moduly]

SCIEZKA INSTALACJI:
    Windows: %APPDATA%/LibreOffice/4/user/Scripts/python/AIWRITER/
    Linux:   ~/.config/libreoffice/4/user/Scripts/python/AIWRITER/
    macOS:   ~/Library/Application Support/LibreOffice/4/user/Scripts/python/AIWRITER/

UZYCIE W LIBREOFFICE:
    Narzedzia > Makra > Uruchom makro > AIWRITER > polonista_menu

Autor: Stowarzyszenie Zwykle "Neuroatypowi"
Strona: https://neuroatypowi.org
Licencja: MIT
"""

from __future__ import absolute_import

__version__ = "2.1.0"
__author__ = "Stowarzyszenie Neuroatypowi"
__email__ = "kontakt@neuroatypowi.org"
__url__ = "https://neuroatypowi.org"
__license__ = "MIT"

# Dostepne moduly AI
AVAILABLE_MODULES = {
    "polonista": {
        "name": "POLONISTA",
        "description": "Prosty Jezyk - upraszczanie tekstu",
        "backend": "nvidia_nim",
        "model": "Bielik-11B",
        "menu_file": "polonista_menu.py",
    },
    # Przyszle moduly:
    # "tlumacz": {...},
    # "korektor": {...},
}

DEFAULT_MODULE = "polonista"


def get_version():
    """Zwraca wersje AIWRITER."""
    return __version__


def list_modules():
    """Zwraca liste dostepnych modulow AI."""
    return list(AVAILABLE_MODULES.keys())


def get_module_info(name):
    """Zwraca informacje o module."""
    return AVAILABLE_MODULES.get(name.lower())


__all__ = [
    "__version__",
    "__author__",
    "AVAILABLE_MODULES",
    "DEFAULT_MODULE",
    "get_version",
    "list_modules",
    "get_module_info",
]
