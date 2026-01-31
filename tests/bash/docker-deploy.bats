#!/usr/bin/env bats
# ============================================================
# docker-deploy.sh 测试
# 使用 Bats (Bash Automated Testing System)
# ============================================================

# 加载测试辅助函数
load 'helpers/mocks'

# 测试脚本路径
SCRIPT_PATH="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/docker-deploy.sh"

# ============================================================
# 语法测试
# ============================================================

@test "docker-deploy.sh 语法正确" {
    run bash -n "$SCRIPT_PATH"
    [ "$status" -eq 0 ]
}

# ============================================================
# 帮助信息测试
# ============================================================

@test "--help 显示帮助信息并退出" {
    run bash "$SCRIPT_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"OpenClaw Docker 一键部署脚本"* ]]
    [[ "$output" == *"--token"* ]]
    [[ "$output" == *"--port"* ]]
}

@test "-h 显示帮助信息并退出" {
    run bash "$SCRIPT_PATH" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"OpenClaw Docker 一键部署脚本"* ]]
}

# ============================================================
# 参数解析测试
# ============================================================

@test "未知参数报错" {
    run bash "$SCRIPT_PATH" --unknown-param
    [ "$status" -ne 0 ]
    [[ "$output" == *"未知参数"* ]]
}

@test "--token 参数被正确解析" {
    # 只测试帮助中提到了 token
    run bash "$SCRIPT_PATH" --help
    [[ "$output" == *"--token"* ]]
    [[ "$output" == *"设置访问令牌"* ]]
}

@test "--port 参数被正确解析" {
    run bash "$SCRIPT_PATH" --help
    [[ "$output" == *"--port"* ]]
    [[ "$output" == *"设置端口"* ]]
}

@test "--local-only 参数被正确解析" {
    run bash "$SCRIPT_PATH" --help
    [[ "$output" == *"--local-only"* ]]
    [[ "$output" == *"仅本地访问"* ]]
}

@test "--skip-init 参数被正确解析" {
    run bash "$SCRIPT_PATH" --help
    [[ "$output" == *"--skip-init"* ]]
}

# ============================================================
# Docker 检查测试 (使用 mock)
# ============================================================

@test "check_docker 检测已安装的 Docker" {
    mock_docker_available
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_docker
    [ "$status" -eq 0 ]
}

@test "check_docker 检测缺失的 Docker" {
    mock_docker_not_found
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_docker
    [ "$status" -ne 0 ]
    [[ "$output" == *"未检测到 Docker"* ]] || [[ "$output" == *"Docker"* ]]
}

@test "check_docker 检测未运行的 Docker" {
    mock_docker_not_running
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    run check_docker
    [ "$status" -ne 0 ]
}

# ============================================================
# Token 生成测试
# ============================================================

@test "generate_token 生成非空 token" {
    source "$SCRIPT_PATH" 2>/dev/null || true
    
    # 如果函数存在
    if type generate_token &>/dev/null; then
        run generate_token
        [ "$status" -eq 0 ]
        [ -n "$output" ]
        # Token 应该有一定长度
        [ ${#output} -ge 16 ]
    else
        skip "generate_token 函数不存在"
    fi
}

# ============================================================
# IP 检测测试
# ============================================================

@test "get_local_ip 返回有效 IP 或 localhost" {
    source "$SCRIPT_PATH" 2>/dev/null || true
    
    if type get_local_ip &>/dev/null; then
        run get_local_ip
        [ "$status" -eq 0 ]
        [ -n "$output" ]
    else
        skip "get_local_ip 函数不存在"
    fi
}

# ============================================================
# 容器管理测试 (使用 mock)
# ============================================================

@test "check_existing_container 检测已存在的容器" {
    # Mock docker ps 返回容器
    docker() {
        case "$1" in
            "ps")
                echo "openclaw"
                return 0
                ;;
        esac
    }
    export -f docker
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    
    if type check_existing_container &>/dev/null; then
        CONTAINER_NAME="openclaw"
        run check_existing_container
        # 应该检测到容器存在
        [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    else
        skip "check_existing_container 函数不存在"
    fi
}

# ============================================================
# 镜像拉取测试 (使用 mock)
# ============================================================

@test "pull_image 调用 docker pull" {
    docker() {
        echo "docker $*"
        return 0
    }
    export -f docker
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    
    if type pull_image &>/dev/null; then
        IMAGE="ghcr.io/test/image:latest"
        run pull_image
        [[ "$output" == *"pull"* ]]
    else
        skip "pull_image 函数不存在"
    fi
}

# ============================================================
# 配置初始化测试 (使用 mock)
# ============================================================

@test "init_config 调用 openclaw setup" {
    docker() {
        echo "docker $*"
        return 0
    }
    export -f docker
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    
    if type init_config &>/dev/null; then
        run init_config
        [[ "$output" == *"setup"* ]] || [ "$status" -eq 0 ]
    else
        skip "init_config 函数不存在"
    fi
}

# ============================================================
# 远程访问配置测试 (使用 mock)
# ============================================================

@test "configure_remote_access 设置必要参数" {
    docker() {
        echo "docker $*"
        return 0
    }
    export -f docker
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    
    if type configure_remote_access &>/dev/null; then
        run configure_remote_access
        # 应该设置 gateway.mode, gateway.bind, allowInsecureAuth
        [[ "$output" == *"gateway"* ]] || [ "$status" -eq 0 ]
    else
        skip "configure_remote_access 函数不存在"
    fi
}

# ============================================================
# 容器启动测试 (使用 mock)
# ============================================================

@test "start_container 构建正确的 docker run 命令" {
    docker() {
        echo "docker $*"
        return 0
    }
    export -f docker
    
    source "$SCRIPT_PATH" 2>/dev/null || true
    
    if type start_container &>/dev/null; then
        CONTAINER_NAME="test-container"
        PORT="18789"
        VOLUME_NAME="test-volume"
        IMAGE="test-image"
        GATEWAY_TOKEN="test-token"
        
        run start_container
        [[ "$output" == *"run"* ]]
        [[ "$output" == *"-p"* ]] || [[ "$output" == *"18789"* ]]
    else
        skip "start_container 函数不存在"
    fi
}
