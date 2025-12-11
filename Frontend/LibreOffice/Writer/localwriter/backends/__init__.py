# -*- coding: utf-8 -*-
"""
localwriter/backends/__init__.py
================================

Rejestracja backendow dla projektu localwriter.
Rozszerzenie o NVIDIA NIM Backend z modelem Bielik-11B.

Autor: github.com/balisujohn (oryginal)
Rozszerzenie: Stowarzyszenie Zwykle "Neuroatypowi"
"""

from __future__ import absolute_import

# Import dostepnych backendow
from .nvidia_nim_backend import (
    NvidiaNimBackend,
    get_backend,
    simplify,
    process_paragraphs,
)

# Rejestr backendow
AVAILABLE_BACKENDS = {
    "nvidia_nim": NvidiaNimBackend,
    "bielik": NvidiaNimBackend,  # Alias
    "polonista": NvidiaNimBackend,  # Alias dla POLONISTA
}

# Domyslny backend
DEFAULT_BACKEND = "nvidia_nim"


def get_backend_class(name=None):
    """
    Zwraca klase backendu po nazwie.
    
    Args:
        name: Nazwa backendu (np. "nvidia_nim", "bielik", "polonista")
              Jesli None, zwraca domyslny backend.
    
    Returns:
        Klasa backendu
    
    Raises:
        ValueError: Jesli backend nie istnieje
    """
    if name is None:
        name = DEFAULT_BACKEND
    
    name = name.lower().strip()
    
    if name not in AVAILABLE_BACKENDS:
        available = ", ".join(AVAILABLE_BACKENDS.keys())
        raise ValueError(
            f"Backend '{name}' nie istnieje. "
            f"Dostepne backendy: {available}"
        )
    
    return AVAILABLE_BACKENDS[name]


def create_backend(name=None, config=None):
    """
    Tworzy instancje backendu.
    
    Args:
        name: Nazwa backendu (opcjonalna)
        config: Slownik z konfiguracja (opcjonalny)
    
    Returns:
        Instancja backendu
    """
    backend_class = get_backend_class(name)
    return backend_class(config)


def list_backends():
    """Zwraca liste dostepnych backendow."""
    return list(AVAILABLE_BACKENDS.keys())


__all__ = [
    "NvidiaNimBackend",
    "get_backend",
    "get_backend_class",
    "create_backend",
    "list_backends",
    "simplify",
    "process_paragraphs",
    "AVAILABLE_BACKENDS",
    "DEFAULT_BACKEND",
]
