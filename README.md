# MikroTik 中国大陆直连 IP 列表

数据来源：[`appshubcc/bett-rules`](https://github.com/appshubcc/bett-rules) 的 `meta/geo/geoip/cn.list`。

## 文件

- `mikrotik-cn-direct-ipv4.rsc`：仅 IPv4，推荐用于大多数网络。
- `mikrotik-cn-direct-ipv6.rsc`：仅 IPv6。
- `mikrotik-cn-direct-all.rsc`：IPv4 + IPv6，合并为一个文件，推荐一次性导入。
- `mikrotik-cn-direct-ipv4-ipv6.rsc`：IPv4 + IPv6，兼容旧文件名。
- `cn-ipv4.txt` / `cn-ipv6.txt`：纯 CIDR 列表。
- `cn-source.list`：上游原始列表。
- `update.sh`：通过代理拉取最新数据并重新生成全部导入文件。

导入后创建的 address-list 名称为：`CN-DIRECT`。

> 注意：每次导入 `.rsc` 文件时，会先删除现有的同名 `CN-DIRECT` address-list，然后写入最新版列表。请勿把自己的条目混在这个列表中。

## 更新数据

运行脚本会从上游重新下载 CIDR 数据，并更新 `cn-source.list`、IPv4/IPv6 列表及所有 `.rsc` 文件。下载失败时不会覆盖现有文件。

使用 HTTP 代理：

```bash
./update.sh --proxy http://127.0.0.1:7890
```

使用 SOCKS5 代理：

```bash
./update.sh --proxy socks5h://127.0.0.1:7890
```

也可以通过环境变量传入代理，适合定时任务：

```bash
PROXY_URL=http://127.0.0.1:7890 ./update.sh
```

如需替换数据源，同时指定 `--source`：

```bash
./update.sh \
  --proxy http://127.0.0.1:7890 \
  --source https://cdn.jsdelivr.net/gh/appshubcc/bett-rules@meta/geo/geoip/cn.list
```

脚本依赖 `curl` 和 `python3`，支持 `http://`、`https://`、`socks5h://` 等 curl 代理协议。

## 导入方法

1. 在 WinBox/WebFig 的 **Files** 中上传所需 `.rsc` 文件。
2. 打开 Terminal，执行：

```routeros
/import file-name=mikrotik-cn-direct-ipv4.rsc
```

仅导入 IPv6：

```routeros
/import file-name=mikrotik-cn-direct-ipv6.rsc
```

一次性导入 IPv4 + IPv6：

```routeros
/import file-name=mikrotik-cn-direct-all.rsc
```

检查导入结果：

```routeros
/ip firewall address-list print count-only where list="CN-DIRECT"
/ipv6 firewall address-list print count-only where list="CN-DIRECT"
```

## 用于“大陆直连”

此文件只创建目标 IP 地址列表，不会擅自修改现有路由、防火墙或代理规则。

如果你通过 mangle 将流量标记到代理路由表，可在“代理 mark-routing 规则”之前增加一条放行规则：

```routeros
/ip firewall mangle
add chain=prerouting dst-address-list="CN-DIRECT" action=accept comment="China mainland direct"
```

规则顺序很重要：该规则应位于代理分流/`mark-routing` 规则之前。具体链、入口接口和路由方案仍需按你的现有配置调整。
