# Dedicated local Redis setup

## Chapter 1. Sources and baseline
https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/
https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/
https://redis.io/docs/latest/develop/data-types/streams/
Proposed instance: loopback port 6380, dedicated private data/config directories, namespace ts:dev:*. These are Thunderstone choices. Check port conflicts and existing services first. Redis 6.2+ is required for XAUTOCLAIM; verify maintenance and package version.

## Chapter 2. Inspect and install
```bash
command -v redis-server || true
command -v redis-cli || true
redis-server --version 2>/dev/null || true
command -v ss >/dev/null && ss -ltn || true
```
Use the observed distro's supported package method only when permitted. Debian/Ubuntu example:
```bash
sudo apt-get update
sudo apt-get install -y redis-server redis-tools
```
Package installation may start system Redis on 6379. Report this side effect; never stop an existing service blindly.

## Chapter 3. Configuration specification
Create private user-owned config/data directories with mode 0700 and secret/config files with mode 0600. Generate a random password locally, never in a chat or committed file. Use a hashed ACL password. Refuse existing configuration overwrite.
```conf
bind 127.0.0.1
protected-mode yes
port 6380
daemonize no
appendonly yes
appendfsync everysec
maxmemory 256mb
maxmemory-policy noeviction
# Add dir and aclfile using resolved private runtime paths.
```
ACL template, substitute a generated SHA256 password digest privately:
```text
user default off
user thunderstone on #GENERATED_SHA256 ~ts:dev:* -@all +ping +get +set +del +exists +expire +ttl +hget +hset +hgetall +hdel +xadd +xread +xrange +xrevrange +xlen +xgroup|create +xreadgroup +xack +xpending +xautoclaim
```
Do not grant +@all to resolve a denied management tool. Index provisioning needs a separate authorised identity.
256 MB is a proposed initial cap. AOF rewrite uses extra memory. Noeviction can reject writes; retain collector spool and surface errors. everysec may lose approximately one second of recent writes in a disaster. AOF is not backup or protection against VM disk loss.

## Chapter 4. Start and test
```bash
redis-server "$HOME/.config/thunderstone-redis/redis.conf"
```
Validate foreground, then use a dedicated supervisor supported by the host. tmux alone is not reboot persistence. Load REDISCLI_AUTH from a private password file without shell tracing:
```bash
set +x
export REDISCLI_AUTH="$(cat "$HOME/.config/thunderstone-redis/password")"
redis-cli -h 127.0.0.1 -p 6380 --user thunderstone ping
redis-cli -h 127.0.0.1 -p 6380 --user thunderstone set ts:dev:smoke ok EX 120
redis-cli -h 127.0.0.1 -p 6380 --user thunderstone get ts:dev:smoke
redis-cli -h 127.0.0.1 -p 6380 --user thunderstone get other:project
unset REDISCLI_AUTH
```
Require PONG, ok and namespace denial. Never test FLUSHALL. Restart only this dedicated instance and verify a retained test record. Test VM recreation/backup restore separately. Do not expose 6380 publicly.
