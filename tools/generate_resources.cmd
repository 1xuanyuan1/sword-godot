@echo off
rem Copyright (C) 2026 sword-godot contributors
rem SPDX-License-Identifier: GPL-3.0-or-later

setlocal
set "SCRIPT_DIR=%~dp0"

where py >nul 2>nul
if errorlevel 1 goto try_python
py -3 "%SCRIPT_DIR%generate_resources.py" %*
exit /b %errorlevel%

:try_python
where python >nul 2>nul
if errorlevel 1 goto no_python
python "%SCRIPT_DIR%generate_resources.py" %*
exit /b %errorlevel%

:no_python
echo Error: Python 3 is required to generate resources. 1>&2
exit /b 2
