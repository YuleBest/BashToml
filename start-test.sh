#!/bin/bash
shopt -s extglob

parse_toml() {
  local toml_file="$1"
  local key_path="$2"
  local current_section="" target_var="" found_value=""

  # 解析键路径（支持数组索引）
  if [[ -n "$key_path" ]]; then
    local section="${key_path%.*}" key_part="${key_path##*.}"
    local array_index=""

    # 分离数组键和索引（如 ports[1] -> key=ports, index=1）
    if [[ "$key_part" =~ ^([^[]+)\[([0-9]+)\]$ ]]; then
      key="${BASH_REMATCH[1]}"
      array_index="${BASH_REMATCH[2]}"
    else
      key="$key_part"
    fi

    section="${section//./_}_"
    target_var="${section}${key}"
  fi

  while IFS= read -r line; do
    line_clean=$(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$line")
    [[ -z "$line_clean" ]] && continue

    if [[ "$line_clean" =~ ^\[(.*)\]$ ]]; then
      current_section="${BASH_REMATCH[1]//./_}_"
      continue
    fi

    if [[ "$line_clean" =~ ^([^=]+)=[[:space:]]*(.*) ]]; then
      key_raw=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "${BASH_REMATCH[1]}")
      value_raw="${BASH_REMATCH[2]}"

      if [[ ! "$key_raw" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        # echo "Warning: Invalid key '$key_raw'" >&2
        continue
      fi

      value_clean=$(sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" <<< "$value_raw")
      current_var="${current_section}${key_raw}"

      # 精准查询模式
      if [[ -n "$target_var" ]]; then
        if [[ "$current_var" == "$target_var" ]]; then
          if [[ "$value_clean" == "["*"]" ]]; then
            value_clean=${value_clean#\[}; value_clean=${value_clean%\]}
            IFS=', ' read -ra temp_array <<< "$value_clean"
            array_elements=()
            for elem in "${temp_array[@]}"; do
              elem_clean=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$elem")
              array_elements+=("$elem_clean")
            done

            # 处理数组索引
            if [[ -n "$array_index" ]]; then
              if (( array_index >= 0 && array_index < ${#array_elements[@]} )); then
                found_value="${array_elements[$array_index]}"
              else
                echo "ERROR: Index $array_index out of bounds" >&2
                return 1
              fi
            else
              found_value="${array_elements[*]}"
            fi
          else
            found_value="$value_clean"
          fi
        fi
      else
        # 全局变量声明模式
        if [[ "$value_clean" == "["*"]" ]]; then
          value_clean=${value_clean#\[}; value_clean=${value_clean%\]}
          IFS=', ' read -ra temp_array <<< "$value_clean"
          declare -ag "${current_var}=($(printf "%q " "${temp_array[@]}"))"
        else
          declare -g "${current_var}=${value_clean}"
        fi
      fi
    fi
  done < "$toml_file"

  if [[ -n "$key_path" ]]; then
    if [[ -n "$found_value" ]]; then
      echo "$found_value"
    else
      echo "ERROR: Key '$key_path' not found" >&2
      return 1
    fi
  fi
}

# 测试1：基础标量值
echo "测试1：基础标量值"
app_name=$(parse_toml complex-config.toml "app.name")
echo "[app_name] $app_name"
[[ "$app_name" == "Super Server" ]] && echo "通过" || echo "失败"

# 测试2：浮点数处理
echo "测试2：浮点数处理"
timeout=$(parse_toml complex-config.toml "app.startup_timeout")
echo "[timeout] $timeout"
[[ "$timeout" == "30.5" ]] && echo "通过" || echo "失败"

# 测试3：布尔值处理
echo "测试3：布尔值处理"
ssl_status=$(parse_toml complex-config.toml "app.enable_ssl")
echo "[ssl_status] $ssl_status"
[[ "$ssl_status" == "true" ]] && echo "通过" || echo "失败"

# 测试4：简单数组访问
echo "测试4：简单数组访问"
tag=$(parse_toml complex-config.toml "app.tags[2]")
echo "[tag] $tag"
[[ "$tag" == "\"auto-scaling\"" ]] && echo "通过" || echo "失败"

# 测试5：嵌套配置访问
echo "测试5：嵌套配置访问"
db_port=$(parse_toml complex-config.toml "database.primary.port")
echo "[db_port] $db_port"
[[ "$db_port" == "5432" ]] && echo "通过" || echo "失败"

# 测试6：对象类型处理（需全局变量模式）
echo "测试6：对象类型处理（需全局变量模式）"
parse_toml complex-config.toml
echo "[services_gateway_endpoint] $services_gateway_endpoint"
[[ "$services_gateway_endpoint" == "https://api.example.com" ]] && echo "通过" || echo "失败"

# 测试7：混合类型数组
echo "测试7：混合类型数组"
retry_policies=($(parse_toml complex-config.toml "services.gateway.retry_policy"))
echo "[retry_policies[2]] ${retry_policies[2]}"
[[ "${retry_policies[2]}" == "1000" ]] && echo "通过" || echo "失败"

# 测试8：越界索引处理
echo "测试8：越界索引处理"
parse_toml complex-config.toml "database.primary.replica_hosts[3]"
[[ $? -eq 1 ]] && echo "通过" || echo "失败"

# 测试9：路径不存在处理
echo "测试9：路径不存在处理"
parse_toml complex-config.toml "monitoring.nonexistent.key"
[[ $? -eq 1 ]] && echo "通过" || echo "失败"

echo "====== 测试完成 ======"