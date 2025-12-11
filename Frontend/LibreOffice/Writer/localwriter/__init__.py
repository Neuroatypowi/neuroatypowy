# -*- coding: utf-8 -*-
"""
localwriter - Pakiet do upraszczania tekstu w LibreOffice Writer
================================================================

Rozszerzenie POLONISTA z integracją NVIDIA NIM API i modelem Bielik-11B.

Autor oryginalny: github.com/balisujohn
Rozszerzenie: Stowarzyszenie Zwykłe "Neuroatypowi" (https://neuroatypowi.org)

INSTALACJA:
    Windows: %APPDATA%/LibreOffice/4/user/Scripts/python/localwriter/
    Linux:   ~/.config/libreoffice/4/user/Scripts/python/localwriter/
    macOS:   ~/Library/Application Support/LibreOffice/4/user/Scripts/python/localwriter/

UŻYCIE:
    W LibreOffice Writer:
    1. Narzędzia → Makra → Uruchom makro
    2. Moje makra → localwriter → polonista_menu
    3. Wybierz funkcję i kliknij Uruchom

LICENCJA: MIT
"""

from __future__ import absolute_import

__version__ = "2.1.0"
__author__ = "balisujohn + Neuroatypowi"
__email__ = "kontakt@neuroatypowi.org"
__url__ = "https://neuroatypowi.org"
__license__ = "MIT"

# Import głównych komponentów
try:
    from .localwriter import (
        validate_api_key,
        smart_chunk_text,
        process_document_text,
        extract_paragraphs,
        parse_api_response,
        show_error_dialog,
        SimplifySelection,
        SimplifyDocument,
        ShowInfo,
    )
except ImportError:
    pass

try:
    from .polonista_menu import (
        RedagujZaznaczenie,
        RedagujCayDokument,
        PokazInformacje,
        SprawdzKonfiguracje,
        TestPolaczenia,
        OtwsStrone,
        PobierzKluczAPI,
    )
except ImportError:
    pass

try:
    from .backends import (
        NvidiaNimBackend,
        get_backend,
        create_backend,
        list_backends,
        simplify,
        process_paragraphs,
    )
except ImportError:
    pass

__all__ = [
    # Wersja
    "__version__",
    "__author__",
    # localwriter
    "validate_api_key",
    "smart_chunk_text",
    "parse_api_response",
    "SimplifySelection",
    "SimplifyDocument",
    # polonista_menu
    "RedagujZaznaczenie",
    "RedagujCayDokument",
    "PokazInformacje",
    "SprawdzKonfiguracje",
    "TestPolaczenia",
    # backends
    "NvidiaNimBackend",
    "get_backend",
    "simplify",
]
