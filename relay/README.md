# Hermes Relay

公网中转方案，让 App 在任何网络下都能连接内网 Hermes。

## 架构

```
App ──WebSocket──→ Relay (公网) ←──WebSocket── Bridge ──HTTP──→ Hermes Webhook
```

## 部署

### 1. Relay Server（公网 VPS）

```bash
pip install websockets
python3 relay.py --port 9920 --auth your-secret
```

### 2. Hermes 侧

**方式 A：Bridge 脚本（最简单）**

```bash
# 1. 在 Hermes 机器上启用 Webhook
hermes webhook subscribe hermes-bridge

# 2. 安装依赖
pip install aiohttp websockets

# 3. 启动 Bridge
python3 bridge.py ws://your-vps:9920 --name "我的Mac" --auth your-secret
```

**方式 B：Gateway Platform（深度集成）**

```bash
# 1. 复制 platform 文件
cp relay/hermes_relay.py ~/.hermes/hermes-agent/gateway/platforms/

# 2. 安装依赖
pip install websockets

# 3. 设环境变量并重启 gateway
export HERMES_RELAY_URL=ws://your-vps:9920
export HERMES_RELAY_NAME=我的Mac
export HERMES_RELAY_AUTH=your-secret
hermes gateway restart
```

### 3. App 侧

在 Hermes Mobile 的 Settings 里切换到 Relay 模式，输入 Relay 地址即可自动发现 Hermes 实例。

## 协议

```
Hermes → Relay:  {"type":"register","name":"My Mac"}
Relay → App:     {"type":"instances","list":[...]}
App → Relay:     {"type":"chat","target":"<id>","content":"hello"}
Hermes → Relay:  {"type":"chunk","to":"<app>","delta":"He"}
Hermes → Relay:  {"type":"done","to":"<app>"}
```
