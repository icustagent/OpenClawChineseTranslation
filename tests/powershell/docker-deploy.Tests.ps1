# ============================================================
# docker-deploy.ps1 测试
# 使用 Pester (PowerShell 测试框架)
# ============================================================

BeforeAll {
    # 导入 Mock 模块
    Import-Module (Join-Path $PSScriptRoot "helpers\Mocks.psm1") -Force
    
    # 脚本路径
    $script:ScriptPath = Join-Path $PSScriptRoot ".." ".." "docker-deploy.ps1"
}

# ============================================================
# 语法测试
# ============================================================

Describe "docker-deploy.ps1 语法验证" {
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
        $output | Should -Match "OpenClaw Docker 一键部署脚本"
        $output | Should -Match "-Token"
        $output | Should -Match "-Port"
    }
}

# ============================================================
# 参数解析测试
# ============================================================

Describe "参数解析" {
    It "接受 -Token 参数" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "\[string\]\`$Token"
    }
    
    It "接受 -Port 参数" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "\[string\]\`$Port"
    }
    
    It "接受 -Name 参数" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "\[string\]\`$Name"
    }
    
    It "接受 -LocalOnly 参数" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "\[switch\]\`$LocalOnly"
    }
    
    It "接受 -SkipInit 参数" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "\[switch\]\`$SkipInit"
    }
    
    It "接受 -Help 参数" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "\[switch\]\`$Help"
    }
}

# ============================================================
# Docker 检测测试 (使用 Mock)
# ============================================================

Describe "Test-Docker 函数" {
    BeforeEach {
        . $script:ScriptPath -Help 2>$null
    }
    
    It "检测已安装的 Docker" {
        Mock -CommandName docker -MockWith { 
            param($cmd)
            if ($cmd -eq "--version") {
                return "Docker version 24.0.0, build 123abc"
            }
            if ($cmd -eq "info") {
                return "Containers: 5"
            }
        }
        
        if (Get-Command Test-Docker -ErrorAction SilentlyContinue) {
            { Test-Docker } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "Test-Docker 函数不存在"
        }
    }
    
    It "检测缺失的 Docker" {
        Mock -CommandName docker -MockWith { throw "command not found" }
        
        if (Get-Command Test-Docker -ErrorAction SilentlyContinue) {
            { Test-Docker } | Should -Throw
        } else {
            Set-ItResult -Skipped -Because "Test-Docker 函数不存在"
        }
    }
    
    It "检测未运行的 Docker" {
        Mock -CommandName docker -MockWith { 
            param($cmd)
            if ($cmd -eq "--version") {
                return "Docker version 24.0.0"
            }
            if ($cmd -eq "info") {
                $global:LASTEXITCODE = 1
                throw "Cannot connect to Docker daemon"
            }
        }
        
        if (Get-Command Test-Docker -ErrorAction SilentlyContinue) {
            { Test-Docker } | Should -Throw
        } else {
            Set-ItResult -Skipped -Because "Test-Docker 函数不存在"
        }
    }
}

# ============================================================
# Token 生成测试
# ============================================================

Describe "New-RandomToken 函数" {
    BeforeEach {
        . $script:ScriptPath -Help 2>$null
    }
    
    It "生成非空 token" {
        if (Get-Command New-RandomToken -ErrorAction SilentlyContinue) {
            $token = New-RandomToken
            $token | Should -Not -BeNullOrEmpty
        } else {
            Set-ItResult -Skipped -Because "New-RandomToken 函数不存在"
        }
    }
    
    It "生成足够长度的 token" {
        if (Get-Command New-RandomToken -ErrorAction SilentlyContinue) {
            $token = New-RandomToken
            $token.Length | Should -BeGreaterThan 16
        } else {
            Set-ItResult -Skipped -Because "New-RandomToken 函数不存在"
        }
    }
    
    It "每次生成不同的 token" {
        if (Get-Command New-RandomToken -ErrorAction SilentlyContinue) {
            $token1 = New-RandomToken
            $token2 = New-RandomToken
            $token1 | Should -Not -Be $token2
        } else {
            Set-ItResult -Skipped -Because "New-RandomToken 函数不存在"
        }
    }
}

# ============================================================
# IP 检测测试
# ============================================================

Describe "Get-LocalIP 函数" {
    BeforeEach {
        . $script:ScriptPath -Help 2>$null
    }
    
    It "返回有效 IP 或 localhost" {
        if (Get-Command Get-LocalIP -ErrorAction SilentlyContinue) {
            $ip = Get-LocalIP
            $ip | Should -Not -BeNullOrEmpty
            # 应该是 IP 格式或 localhost
            $ip | Should -Match "^(\d{1,3}\.){3}\d{1,3}$|localhost"
        } else {
            Set-ItResult -Skipped -Because "Get-LocalIP 函数不存在"
        }
    }
}

# ============================================================
# 容器管理测试 (使用 Mock)
# ============================================================

Describe "容器管理函数" {
    BeforeEach {
        . $script:ScriptPath -Help 2>$null
    }
    
    It "Test-ContainerExists 检测已存在的容器" {
        Mock -CommandName docker -MockWith {
            param($cmd)
            if ($cmd -eq "ps") {
                return "openclaw"
            }
        }
        
        if (Get-Command Test-ContainerExists -ErrorAction SilentlyContinue) {
            $script:Name = "openclaw"
            $result = Test-ContainerExists
            $result | Should -Be $true
        } else {
            Set-ItResult -Skipped -Because "Test-ContainerExists 函数不存在"
        }
    }
}

# ============================================================
# 镜像拉取测试 (使用 Mock)
# ============================================================

Describe "镜像拉取" {
    BeforeEach {
        . $script:ScriptPath -Help 2>$null
    }
    
    It "Invoke-PullImage 调用 docker pull" {
        Mock -CommandName docker -MockWith { 
            param($args)
            return "Pulling $args"
        }
        
        if (Get-Command Invoke-PullImage -ErrorAction SilentlyContinue) {
            $script:Image = "ghcr.io/test/image:latest"
            { Invoke-PullImage } | Should -Not -Throw
        } else {
            Set-ItResult -Skipped -Because "Invoke-PullImage 函数不存在"
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
        $scriptContent | Should -Match "function Test-Docker"
    }
    
    It "脚本设置 ErrorActionPreference" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
    }
    
    It "脚本定义默认配置" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match '\$VolumeName'
        $scriptContent | Should -Match '\$Image'
    }
    
    It "脚本使用正确的镜像地址" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match "ghcr.io/1186258278/openclaw-zh"
    }
}

# ============================================================
# 安全测试
# ============================================================

Describe "安全性检查" {
    It "脚本不包含硬编码的敏感信息" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        
        # 不应该包含硬编码的密码或 API 密钥
        $scriptContent | Should -Not -Match "password\s*=\s*['\"][^'\"]+['\"]"
        $scriptContent | Should -Not -Match "api_key\s*=\s*['\"][^'\"]+['\"]"
    }
    
    It "Token 参数默认为空" {
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match '\[string\]\$Token\s*=\s*""'
    }
}
