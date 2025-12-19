# -*- coding: utf-8 -*-
"""
AIWRITER/backends/__init__.py
==============================

Rejestracja backendow AI dla projektu AIWRITER.

SCIEZKA:
    %APPDATA%/LibreOffice/4/user/Scripts/python/AIWRITER/backends/__init__.py
"""

from __future__ import absolute_import

# Import backendu NVIDIA NIM
from .nvidia_nim_backend import (
    NvidiaNimBackend,
    get_backend,
    reset_backend,
    simplify,
)

# Rejestr backendow
AVAILABLE_BACKENDS = {
    "nvidia_nim": NvidiaNimBackend,
    "bielik": NvidiaNimBackend,
    "polonista": NvidiaNimBackend,
}

DEFAULT_BACKEND = "nvidia_nim"


def get_backend_class(name=None):
    """Zwraca klase backendu po nazwie."""
    if name is None:
        name = DEFAULT_BACKEND
    name = name.lower().strip()
    if name not in AVAILABLE_BACKENDS:
        raise ValueError("Backend '{}' nie istnieje".format(name))
    return AVAILABLE_BACKENDS[name]


def create_backend(name=None, config=None):
    """Tworzy instancje backendu."""
    backend_class = get_backend_class(name)
    return backend_class(config)


def list_backends():
    """Lista dostepnych backendow."""
    return list(AVAILABLE_BACKENDS.keys())


__all__ = [
    "NvidiaNimBackend",
    "get_backend",
    "reset_backend",
    "get_backend_class",
    "create_backend",
    "list_backends",
    "simplify",
    "AVAILABLE_BACKENDS",
    "DEFAULT_BACKEND",
]
