#!/usr/bin/env bats
# ============================================================
# install.sh 测试
# 使用 Bats (Bash Automated Testing System)
# ============================================================

# 加载测试辅助函数
load 'helpers/mocks'

# 测试脚本路径
SCRIPT_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/install.sh"

# ============================================================
# 语法测试
# ============================================================

@test "install.sh 语法正确" {
    run bash -n "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# ============================================================
# 帮助信息测试
# ============================================================

@test "--help 显示帮助信息并退出" {
    run bash "$SCRIPT_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"OpenClaw 汉化版安装脚本"* ]]
    [[ "$output" == *"--nightly"* ]]
}

@test "-h 显示帮助信息并退出" {
    run bash "$SCRIPT_PATH" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"OpenClaw 汉化版安装脚本"* ]]
}

# ============================================================
# 参数解析测试
# ============================================================

@test "无参数默认安装稳定版" {
    # 跳过实际安装，只测试参数解析
    # 这个测试需要 mock node 和 npm
    skip "需要完整 mock 环境"
}

@test "未知参数报错" {
    run bash "$SCRIPT_PATH" --unknown-param
    [ "$status" -ne 0 ]
    [[ "$output" == *"未知参数"* ]]
}

# ============================================================
# 函数单元测试
# ============================================================

@test "check_command 检测已存在的命令" {
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_command bash
    [ "$status" -eq 0 ]
}

@test "check_command 检测不存在的命令" {
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_command nonexistent_command_12345
    [ "$status" -ne 0 ]
}

# ============================================================
# Node.js 版本检查测试 (使用 mock)
# ============================================================

@test "check_node_version 接受 Node.js 22+" {
    # Mock node 命令返回 v22.12.0
    mock_node "v22.12.0"
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_node_version
    [ "$status" -eq 0 ]
    [[ "$output" == *"Node.js 版本"* ]]
}

@test "check_node_version 拒绝 Node.js 21" {
    # Mock node 命令返回 v21.0.0
    mock_node "v21.0.0"
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_node_version
    [ "$status" -ne 0 ]
    [[ "$output" == *"版本过低"* ]]
}

@test "check_node_version 检测缺失的 Node.js" {
    # Mock node 命令不存在
    mock_node_not_found
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_node_version
    [ "$status" -ne 0 ]
    [[ "$output" == *"未检测到 Node.js"* ]]
}

# ============================================================
# npm 检查测试 (使用 mock)
# ============================================================

@test "check_npm 检测已安装的 npm" {
    mock_npm "10.2.0"
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_npm
    [ "$status" -eq 0 ]
    [[ "$output" == *"npm 版本"* ]]
}

@test "check_npm 检测缺失的 npm" {
    mock_npm_not_found
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_npm
    [ "$status" -ne 0 ]
}

# ============================================================
# 安装流程测试 (使用 mock)
# ============================================================

@test "install_chinese 调用正确的 npm 命令 (稳定版)" {
    mock_npm "10.2.0"
    NPM_TAG="latest"
    
    # 捕获 npm install 命令
    npm() {
        echo "npm $*"
    }
    export -f npm
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run install_chinese
    [[ "$output" == *"@qingchencloud/openclaw-zh@latest"* ]]
}

@test "install_chinese 调用正确的 npm 命令 (nightly)" {
    mock_npm "10.2.0"
    NPM_TAG="nightly"
    
    npm() {
        echo "npm $*"
    }
    export -f npm
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run install_chinese
    [[ "$output" == *"@qingchencloud/openclaw-zh@nightly"* ]]
}

# ============================================================
# 卸载原版测试 (使用 mock)
# ============================================================

@test "uninstall_original 检测并卸载原版" {
    # Mock npm list 返回成功（原版已安装）
    npm() {
        case "$1" in
            "list")
                echo "openclaw@1.0.0"
                return 0
                ;;
            "uninstall")
                echo "uninstalling $*"
                return 0
                ;;
        esac
    }
    export -f npm
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run uninstall_original
    [[ "$output" == *"检测到原版"* ]] || [[ "$output" == *"原版已卸载"* ]]
}

@test "uninstall_original 原版不存在时跳过" {
    # Mock npm list 返回失败（原版未安装）
    npm() {
        case "$1" in
            "list")
                return 1
                ;;
        esac
    }
    export -f npm
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run uninstall_original
    [ "$status" -eq 0 ]
}
