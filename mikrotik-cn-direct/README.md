# MikroTik 中国大陆直连 IP 列表

数据来源：[`appshubcc/bett-rules`](https://github.com/appshubcc/bett-rules) 的 `meta/geo/geoip/cn.list`。

## 文件

- `mikrotik-cn-direct-ipv4.rsc`：仅 IPv4，推荐用于大多数网络。
- `mikrotik-cn-direct-ipv4-ipv6.rsc`：IPv4 + IPv6，适合已启用 IPv6 的 RouterOS。
- `cn-ipv4.txt` / `cn-ipv6.txt`：纯 CIDR 列表。
- `cn-source.list`：上游原始列表。

导入后创建的 address-list 名称为：`CN-DIRECT`。

> 注意：每次导入 `.rsc` 文件时，会先删除现有的同名 `CN-DIRECT` address-list，然后写入最新版列表。请勿把自己的条目混在这个列表中。

## 导入方法

1. 在 WinBox/WebFig 的 **Files** 中上传所需 `.rsc` 文件。
2. 打开 Terminal，执行：

```routeros
/import file-name=mikrotik-cn-direct-ipv4.rsc
```

如需 IPv6：

```routeros
/import file-name=mikrotik-cn-direct-ipv4-ipv6.rsc
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
