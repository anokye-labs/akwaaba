function ConvertTo-EscapedGraphQL {
    <#
    .SYNOPSIS
        Safely escapes text for use in GraphQL string literals.

    .DESCRIPTION
        This utility function escapes text to make it safe for use in GraphQL string literals.
        It handles newlines, quotes, backslashes, and preserves emoji and unicode characters.
        Designed to be pipe-friendly and handle multiline content including heredocs.

    .PARAMETER InputObject
        The text to escape. Can be passed via pipeline.

    .PARAMETER Value
        The text to escape. Alternative to pipeline input.

    .EXAMPLE
        "Hello `"World`"" | ConvertTo-EscapedGraphQL
        # Returns: Hello \"World\"

    .EXAMPLE
        ConvertTo-EscapedGraphQL -Value "Line 1`nLine 2"
        # Returns: Line 1\nLine 2

    .EXAMPLE
        @"
        Multi-line
        text with "quotes"
        and \ backslashes
    "@ | ConvertTo-EscapedGraphQL
        # Properly escapes all special characters for GraphQL

    .EXAMPLE
        "Emoji test: 🚀 and unicode: café" | ConvertTo-EscapedGraphQL
        # Preserves emoji and unicode characters

    .NOTES
        Author: Anokye Labs
        Purpose: Addresses escaping bugs identified in PR #6 review comments
        
        GraphQL string literal escaping rules:
        - Backslash (\) must be escaped as \\
        - Double quote (") must be escaped as \"
        - Newline must be escaped as \n
        - Carriage return must be escaped as \r
        - Tab must be escaped as \t
        - Emoji and unicode are preserved as-is
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$InputObject,
        
        [Parameter()]
        [string]$Value
    )

    begin {
        $accumulator = @()
    }

    process {
        # If using -Value parameter, use it; otherwise accumulate pipeline input
        if ($PSBoundParameters.ContainsKey('Value')) {
            $textToProcess = $Value
        } else {
            $accumulator += $InputObject
            return
        }
        
        # Process the text
        if ($null -eq $textToProcess) {
            return ""
        }
        
        # Escape in the correct order to avoid double-escaping
        # 1. First escape backslashes (\ -> \\)
        $escaped = $textToProcess -replace '\\', '\\'
        
        # 2. Then escape double quotes (" -> \")
        $escaped = $escaped -replace '"', '\"'
        
        # 3. Escape newlines (actual newline characters -> \n)
        $escaped = $escaped -replace "`r`n", '\n'  # Windows CRLF
        $escaped = $escaped -replace "`n", '\n'     # Unix LF
        $escaped = $escaped -replace "`r", '\r'     # Old Mac CR
        
        # 4. Escape tabs
        $escaped = $escaped -replace "`t", '\t'
        
        # 5. Emoji and unicode characters are preserved as-is (UTF-8)
        # GraphQL accepts unicode in string literals
        
        return $escaped
    }

    end {
        # If we accumulated pipeline input, process it now
        if ($accumulator.Count -gt 0) {
            $textToProcess = $accumulator -join "`n"
            
            if ($null -eq $textToProcess) {
                return ""
            }
            
            # Escape in the correct order to avoid double-escaping
            # 1. First escape backslashes (\ -> \\)
            $escaped = $textToProcess -replace '\\', '\\'
            
            # 2. Then escape double quotes (" -> \")
            $escaped = $escaped -replace '"', '\"'
            
            # 3. Escape newlines (actual newline characters -> \n)
            $escaped = $escaped -replace "`r`n", '\n'  # Windows CRLF
            $escaped = $escaped -replace "`n", '\n'     # Unix LF
            $escaped = $escaped -replace "`r", '\r'     # Old Mac CR
            
            # 4. Escape tabs
            $escaped = $escaped -replace "`t", '\t'
            
            # 5. Emoji and unicode characters are preserved as-is (UTF-8)
            # GraphQL accepts unicode in string literals
            
            return $escaped
        }
    }
}
