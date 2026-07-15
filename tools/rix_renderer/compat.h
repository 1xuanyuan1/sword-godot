// Copyright (C) 2026 sword-godot contributors
// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once

// The selected SDLPal AdPlug files only need SDL_strcasecmp from common.h.
// Defining its include guard lets this offline tool avoid linking SDL itself.
#ifndef _COMMON_H
#define _COMMON_H
#endif

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <strings.h>

#define SDL_strcasecmp strcasecmp
#define USE_RIX_EXTRA_INIT 0

