---
name: Okyerema
description: Structured JSON logging for all Okyerema operations
---

# Okyerema Logging Skill

## Overview

Okyerema provides structured JSON logging capabilities for operations within the Akwaaba system. The name "Okyerema" comes from Akan/Twi meaning "drummer" or "one who communicates through drums" - fitting for a logging system that communicates operational status.

## Features

- **Structured JSON Output**: All logs are emitted as valid JSON for easy parsing and processing
- **Multiple Log Levels**: Support for Info, Warn, Error, and Debug levels
- **Rich Context**: Every log includes timestamp, operation name, and correlation ID
- **Clean Output Streams**: Logs go to stderr, keeping stdout clean for pipeline data
- **Quiet Mode**: Optional `-Quiet` switch suppresses console output for silent operation

## Scripts

### Write-OkyeremaLog.ps1

Writes structured JSON log entries to stderr with proper formatting and context.

**Usage:**

```powershell
# Basic logging
Write-OkyeremaLog -Level Info -Operation "Deploy" -Message "Deployment started"

# With correlation ID
Write-OkyeremaLog -Level Warn -Operation "Validate" -Message "Missing field" -CorrelationId "abc-123"

# Quiet mode (no console output)
Write-OkyeremaLog -Level Error -Operation "Build" -Message "Build failed" -Quiet
```

## References

- [Write-OkyeremaLog.ps1](Write-OkyeremaLog.ps1) - Main logging script
- [Test-OkyeremaLog.ps1](Test-OkyeremaLog.ps1) - Test suite
- [Examples-OkyeremaLog.ps1](Examples-OkyeremaLog.ps1) - Real-world usage examples
- [README.md](README.md) - Complete documentation
