# BashToml

使用纯Bash解析简单的TOML配置

---

在Linux运维、DevOps和CLI工具开发中，配置管理是永恒的话题。**TOML**（Tom's Obvious Minimal Language）凭借其清晰的层级结构和极佳的可读性脱颖而出。然而在纯Shell环境中处理TOML一直是个难题——直到现在。

---

## 脚本功能亮点 ✨
### 1. 双模式智能运行
- **全局变量模式**  
  `parse_toml config.toml` 一键注入所有配置项为全局变量
  ```bash
  echo "数据库地址: ${database_server}"
  echo "首个端口: ${database_ports[0]}"
  ```

- **精准查询模式**  
  `parse_toml config.toml "servers.alpha.ip"` 直接输出目标值
  ```bash
  # 输出：10.0.0.1
  ```

### 2. 全数据类型支持
| 数据类型       | 示例                 | 转换结果                     |
|----------------|----------------------|------------------------------|
| 字符串         | `"localhost"`        | `localhost`                  |
| 数字           | `5000`               | 保持数值类型                 |
| 布尔值         | `true`/`false`       | 原生Bash布尔                 |
| 数组           | `[1, "two", true]`   | Bash索引数组                 |
| 嵌套配置       | `[servers.alpha]`    | 自动转换为`servers_alpha_`前缀 |

### 3. 企业级健壮性
- 自动跳过非法键名并告警
- 支持含空格和特殊字符的值
- 错误退出码机制
  ```bash
  if ! result=$(parse_toml config.toml "invalid.key"); then
    echo "配置项缺失，启用默认值"
  fi
  ```

---

## 核心实现解析 🔍
### 1. 语法解析引擎
```bash
while IFS= read -r line; do
  # 三阶清洗流水线
  line_clean=$(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$line")
  
  # 节识别器
  [[ "$line_clean" =~ ^\[(.*)\]$ ]] && current_section="${BASH_REMATCH[1]//./_}_"

  # 键值提取器
  [[ "$line_clean" =~ ^([^=]+)=[[:space:]]*(.*) ]] && handle_key_value "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
done < "$toml_file"
```

### 2. 安全赋值机制
采用`printf "%q"`进行Shell注入防护：
```bash
value_clean=$(sed -e 's/^"//' -e 's/"$//' <<< "$raw_value")
safe_value=$(printf "%q" "$value_clean")
declare -g "${var_name}=$safe_value"
```

### 3. 数组处理器
```bash
if [[ "$value" == "["*"]" ]]; then
  IFS=', ' read -ra temp_array <<< "${value//[][]/}"
  declare -ag "${var_name}=(${temp_array[@]})"
fi
```

---

## 使用示例 🚀
### 场景1：CI/CD环境配置
```bash
#!/bin/bash
source toml-parser.sh

parse_toml ci-config.toml

docker build \
  --tag "${image_repository}:${image_tag}" \
  --build-arg ENV="${deploy_environment}" \
  --file "${dockerfile_path}"
```

### 场景2：快速调试配置
```bash
# 查询嵌套配置
parse_toml config.toml "redis.cluster.nodes[1]"

# 对比开发/生产配置
diff <(parse_toml dev.toml) <(parse_toml prod.toml)
```

### 场景3：与jq协作处理
```bash
# 生成JSON格式配置
parse_toml config.toml | jq -n 'inputs' > config.json
```

---

## 获取与使用

1. 确保你的 Bash 版本为 4.0 或以上 (bash --version)

2. 在本项目的 Release 页面获取最新版本和测试用例

3. 进行测试、修改和复制粘贴即可

```bash
cd <工具所在目录>
chmod +x start-test.sh
bash start-test.sh
```
