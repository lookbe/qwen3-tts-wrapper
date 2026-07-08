#include "qwen.h"
#include <stdio.h>
#include <stdlib.h>

// This is a wrapper to ensure the symbols are exported as qwen3
// but we can just use the existing qt_* functions from qwen.h
// since they are already marked with QT_API (dllexport/dllimport).

// If the user wants specific "qwen3_" prefixed functions, we can add them here.
// For now, we will just export the existing API.

extern "C" {
    // We can add convenience wrappers here if needed, 
    // similar to how PocketTTSLib wraps its internal engine.
}
