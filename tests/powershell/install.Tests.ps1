# ============================================================
# install.ps1 测试
# 使用 Pester (PowerShell 测试框架)
# ============================================================

BeforeAll {
    # 导入 Mock 模块
    Import-Module (Join-Path $PSScriptRoot "helpers\Mocks.psm1") -Force
    
    # 脚本路径
    $script:ScriptPath = Join-Path $PSScriptRoot ".." ".." "install.ps1"
}

# ============================================================
# 语法测试
# ============================================================

Describe "install.ps1 语法验证" {
    It "脚本语法正确" {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $script:ScriptPath -Raw),
            [ref]$errors
        )
        $errors.Count | Should -Be 0
    }
    
    It "脚本可以加载" {
        { . $script:ScriptPath -Help } | Should -Not -Throw
    }
}

# ============================================================
# 帮助信息测试
# ============================================================

Describe "帮助信息" {
    It "-Help 显示帮助信息并退出" {
        $output = & $script:ScriptPath -Help 2>&1
        $output | Should -Match "OpenClaw 汉化版安装脚本"
        $output | Should -Match "-Nightly"
    }
}

# ============================================================
# 参数解析测试
# ============================================================

Describe "参数解析" {
    It "接受 -Nightly 参数" {
        # 只验证参数被接受，不实际执行安装
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "param\s*\("
        $scriptContent | Should -Match "\[switch\]\`$Nightly"
    }
    
    It "接受 -Help 参数" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "\[switch\]\`$Help"
    }
}

# ============================================================
# 函数测试 (使用 Mock)
# ============================================================

Describe "Test-NodeVersion 函数" {
    BeforeEach {
        # 加载脚本中的函数
        . $script:ScriptPath -Help 2>$null
    }
    
    It "接受 Node.js 22+" {
        Mock -CommandName node -MockWith { "v22.12.0" }
        
        if (Get-Command Test-NodeVersion -ErrorAction SilentlyContinue) {
            { Test-NodeVersion } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "Test-NodeVersion 函数不存在"
        }
    }
    
    It "拒绝 Node.js 21" {
        Mock -CommandName node -MockWith { "v21.0.0" }
        
        if (Get-Command Test-NodeVersion -ErrorAction SilentlyContinue) {
            { Test-NodeVersion } | Should -Throw
        } else {
            Set-ItResult -Skipped -Because "Test-NodeVersion 函数不存在"
        }
    }
    
    It "检测缺失的 Node.js" {
        Mock -CommandName node -MockWith { throw "command not found" }
        
        if (Get-Command Test-NodeVersion -ErrorAction SilentlyContinue) {
            { Test-NodeVersion } | Should -Throw
        } else {
            Set-ItResult -Skipped -Because "Test-NodeVersion 函数不存在"
        }
    }
}

Describe "Test-Npm 函数" {
    BeforeEach {
        . $script:ScriptPath -Help 2>$null
    }
    
    It "检测已安装的 npm" {
        Mock -CommandName npm -MockWith { "10.2.0" }
        
        if (Get-Command Test-Npm -ErrorAction SilentlyContinue) {
            { Test-Npm } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "Test-Npm 函数不存在"
        }
    }
    
    It "检测缺失的 npm" {
        Mock -CommandName npm -MockWith { throw "command not found" }
        
        if (Get-Command Test-Npm -ErrorAction SilentlyContinue) {
            { Test-Npm } | Should -Throw
        } else {
            Set-ItResult -Skipped -Because "Test-Npm 函数不存在"
        }
    }
}

# ============================================================
# 安装流程测试 (使用 Mock)
# ============================================================

Describe "Install-ChineseVersion 函数" {
    BeforeEach {
        . $script:ScriptPath -Help 2>$null
    }
    
    It "调用正确的 npm 命令 (稳定版)" {
        Mock -CommandName npm -MockWith { 
            param($args)
            "npm $args"
        }
        
        if (Get-Command Install-ChineseVersion -ErrorAction SilentlyContinue) {
            $script:NpmTag = "latest"
            Install-ChineseVersion
            
            Should -Invoke npm -Times 1 -ParameterFilter {
                $args -contains "install" -and 
                $args -contains "-g" -and
                $args -match "@qingchencloud/openclaw-zh@latest"
            }
        } else {
            Set-ItResult -Skipped -Because "Install-ChineseVersion 函数不存在"
        }
    }
}

# ============================================================
# 卸载原版测试 (使用 Mock)
# ============================================================

Describe "Remove-OriginalOpenClaw 函数" {
    BeforeEach {
        . $script:ScriptPath -Help 2>$null
    }
    
    It "检测并卸载原版" {
        Mock -CommandName npm -MockWith {
            param($cmd)
            if ($cmd -eq "list") {
                return "openclaw@1.0.0"
            }
            return $null
        }
        $global:LASTEXITCODE = 0
        
        if (Get-Command Remove-OriginalOpenClaw -ErrorAction SilentlyContinue) {
            { Remove-OriginalOpenClaw } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "Remove-OriginalOpenClaw 函数不存在"
        }
    }
    
    It "原版不存在时跳过" {
        Mock -CommandName npm -MockWith { return $null }
        $global:LASTEXITCODE = 1
        
        if (Get-Command Remove-OriginalOpenClaw -ErrorAction SilentlyContinue) {
            { Remove-OriginalOpenClaw } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "Remove-OriginalOpenClaw 函数不存在"
        }
    }
}

# ============================================================
# 集成测试
# ============================================================

Describe "脚本集成测试" {
    It "脚本包含必要的函数" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        
        # 检查必要函数存在
        $scriptContent | Should -Match "function Show-Banner"
        $scriptContent | Should -Match "function Test-NodeVersion"
        $scriptContent | Should -Match "function Test-Npm"
        $scriptContent | Should -Match "function Install-ChineseVersion"
        $scriptContent | Should -Match "function Show-Success"
    }
    
    It "脚本设置 ErrorActionPreference" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
    }
    
    It "脚本定义版本变量" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match '\$NpmTag'
        $scriptContent | Should -Match '\$VersionName'
    }
}
