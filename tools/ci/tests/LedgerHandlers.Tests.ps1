#Requires -Version 7.0
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Ledger.ps1')
}

Describe 'ConvertTo-LedgerHandlerSurfaceMap' {
    It 'reads the flat allowlist of skills 6.8.5 and earlier' {
        $m = ConvertTo-LedgerHandlerSurfaceMap @{ 'sql-scalar' = @('sql'); 'mcp-count' = @('mcp') }
        $m['sql-scalar'] | Should -Be @('sql')
        $m['mcp-count'] | Should -Be @('mcp')
    }

    It 'reads the handlers block of skills 6.8.6 (dynamicweb/skills #240) to the same map' {
        $m = ConvertTo-LedgerHandlerSurfaceMap @{
            handlers = @{ 'sql-scalar' = @{ surfaces = @('sql'); assertions = @('scalar') }; 'mcp-count' = @{ surfaces = @('mcp'); assertions = @('scalar') } }
            mcpReadTools = @('x'); adminReadQueries = @('y'); dwapiReadRoutes = @('z')
        }
        $m.Keys | Sort-Object | Should -Be @('mcp-count', 'sql-scalar')
        $m['sql-scalar'] | Should -Be @('sql')
    }

    It 'gives an empty map for an unreadable registry, so no check is passed as executable' {
        (ConvertTo-LedgerHandlerSurfaceMap $null).Count | Should -Be 0
        (ConvertTo-LedgerHandlerSurfaceMap 'text').Count | Should -Be 0
    }
}
