# OpenClaw 汉化版 - 脚本测试

本目录包含部署脚本的自动化测试。

## 测试框架

| 语言 | 框架 | 说明 |
|------|------|------|
| Bash | [Bats](https://github.com/bats-core/bats-core) | Bash 自动化测试系统 |
| PowerShell | [Pester](https://pester.dev/) | PowerShell 官方测试框架 |

## 目录结构

```
tests/
├── bash/
│   ├── install.bats           # install.sh 测试
│   ├── docker-deploy.bats     # docker-deploy.sh 测试
│   └── helpers/
│       └── mocks.bash         # Docker/npm 模拟函数
├── powershell/
│   ├── install.Tests.ps1      # install.ps1 测试
│   ├── docker-deploy.Tests.ps1 # docker-deploy.ps1 测试
│   └── helpers/
│       └── Mocks.psm1         # 模拟模块
└── README.md                  # 本文件
```

## 本地运行测试

### Bash 测试 (Linux / macOS)

```bash
# 安装 Bats
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt-get install bats

# 或从源码安装
git clone https://github.com/bats-core/bats-core.git
cd bats-core && sudo ./install.sh /usr/local

# 运行测试
bats tests/bash/install.bats
bats tests/bash/docker-deploy.bats

# 运行所有 Bash 测试
bats tests/bash/*.bats
```

### PowerShell 测试 (Windows)

```powershell
# 安装 Pester (通常已预装)
Install-Module -Name Pester -Force -SkipPublisherCheck

# 运行测试
Invoke-Pester tests/powershell/install.Tests.ps1
Invoke-Pester tests/powershell/docker-deploy.Tests.ps1

# 运行所有 PowerShell 测试
Invoke-Pester tests/powershell/*.Tests.ps1
```

### 静态分析

```bash
# Bash: ShellCheck
shellcheck install.sh docker-deploy.sh

# Bash: 语法检查
bash -n install.sh
bash -n docker-deploy.sh
```

```powershell
# PowerShell: PSScriptAnalyzer
Install-Module -Name PSScriptAnalyzer -Force
Invoke-ScriptAnalyzer -Path install.ps1
Invoke-ScriptAnalyzer -Path docker-deploy.ps1
```

## 测试覆盖范围

### install.sh / install.ps1

- [x] 语法验证
- [x] 参数解析 (`--nightly`, `--help`)
- [x] Node.js 版本检查
- [x] npm 可用性检查
- [x] 原版卸载逻辑
- [x] 安装命令构建
- [x] 错误处理

### docker-deploy.sh / docker-deploy.ps1

- [x] 语法验证
- [x] 参数解析 (`--token`, `--port`, `--name`, `--local-only`, `--skip-init`)
- [x] Docker 可用性检查
- [x] Docker 运行状态检查
- [x] 容器生命周期管理
- [x] Token 生成
- [x] IP 地址检测
- [x] 配置初始化
- [x] 错误处理

## Mock 策略

测试中使用 Mock 来模拟外部依赖（Docker、npm、node 等），避免真实执行。

### Bash Mock 示例

```bash
# 覆盖 docker 命令
docker() {
  case "$1" in
    "info") echo "Docker version 20.10.0" ;;
    "pull") echo "Pulling image..." ;;
    *) return 0 ;;
  esac
}
export -f docker
```

### PowerShell Mock 示例

```powershell
Mock -CommandName docker -MockWith {
    param($cmd)
    switch ($cmd) {
        "info" { "Docker version 20.10.0" }
        "pull" { "Pulling image..." }
    }
}
```

## CI/CD 集成

测试通过 GitHub Actions 自动运行：

- **触发条件**: 推送或 PR 修改 `*.sh`、`*.ps1` 或 `tests/**`
- **工作流**: `.github/workflows/test-scripts.yml`
- **运行环境**:
  - Bash 测试: `ubuntu-latest`
  - PowerShell 测试: `windows-latest`

## 添加新测试

1. 在对应目录创建测试文件
2. 遵循命名规范: `*.bats` (Bash) 或 `*.Tests.ps1` (PowerShell)
3. 使用 helpers 目录中的 mock 函数
4. 提交前本地运行测试验证

## 相关链接

- [Bats 文档](https://bats-core.readthedocs.io/)
- [Pester 文档](https://pester.dev/docs/quick-start)
- [ShellCheck](https://www.shellcheck.net/)
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
