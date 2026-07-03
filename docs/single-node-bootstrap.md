# Single-Node Bootstrap (Without pve-cluster)

On Debian, `/etc/pve/` is always a `pmxcfs` FUSE filesystem mounted by `pve-cluster`.
On a standalone Gentoo node (Phase 1, no cluster), `pve-cluster` is not installed and
`/etc/pve/` must be a plain directory pre-seeded with the configuration pvedaemon expects.

Without this bootstrap, `pvedaemon` will fail to start.

---

## What pve-manager Expects in `/etc/pve/`

At startup, `pvedaemon` reads:

| File | Purpose | Required |
|------|---------|---------|
| `datacenter.cfg` | Global datacenter settings | Yes (can be empty-ish) |
| `storage.cfg` | Storage pool definitions | Yes (needs at least one pool) |
| `user.cfg` | User accounts | Yes (needs root@pam) |
| `token.cfg` | API tokens | No (can be empty) |
| `nodes/<hostname>/config` | Per-node config | Yes (can be empty) |
| `local/` → `nodes/<hostname>/` | Symlink (optional) | No |

---

## Bootstrap Procedure

Run this **once** after installing `pve-manager`, before starting any services:

```bash
#!/bin/bash
# /usr/local/sbin/pve-standalone-bootstrap.sh
# Run once on a fresh single-node Gentoo pxvirt install

set -e
HOSTNAME=$(hostname -s)

# Create directory structure
mkdir -p /etc/pve/nodes/${HOSTNAME}
mkdir -p /var/lib/pve-manager
mkdir -p /var/lib/vz/{images,template/{cache,iso,vztmpl},dump,snippets}
mkdir -p /var/log/pve

# datacenter.cfg - minimal global config
cat > /etc/pve/datacenter.cfg << 'EOF'
keyboard: en-us
EOF

# storage.cfg - local directory storage (minimum viable)
cat > /etc/pve/storage.cfg << EOF
dir: local
	path /var/lib/vz
	content iso,vztmpl,backup

dir: local-lvm
	path /var/lib/vz/images
	content images,rootdir
EOF

# user.cfg - root@pam user (PAM-authenticated, no stored password)
cat > /etc/pve/user.cfg << 'EOF'
user:root@pam:1:0:::root@pam:::

role:Administrator:Datastore.Allocate,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Datastore.Download,Mapping.Audit,Mapping.Modify,Mapping.Use,Pool.Allocate,Pool.Audit,Realm.AllocateUser,SDN.Allocate,SDN.Audit,SDN.Use,Sys.Audit,Sys.Console,Sys.Incoming,Sys.Modify,Sys.PowerMgmt,Sys.Syslog,VM.Allocate,VM.Audit,VM.Backup,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.Monitor,VM.PowerMgmt,VM.Snapshot,VM.Snapshot.Rollback:

acl:1:/:root@pam:Administrator:
EOF

# token.cfg - empty (no API tokens initially)
touch /etc/pve/token.cfg

# Per-node config (can be empty)
touch /etc/pve/nodes/${HOSTNAME}/config

# Permissions (pvedaemon runs as root but some files need specific perms)
chmod 0640 /etc/pve/user.cfg
chmod 0640 /etc/pve/token.cfg
chmod 0644 /etc/pve/datacenter.cfg
chmod 0644 /etc/pve/storage.cfg

echo "Bootstrap complete. /etc/pve/ is ready for standalone pve-manager."
echo "Start services with:"
echo "  systemctl start pvedaemon.service"
echo "  systemctl start pveproxy.service"
echo "  systemctl start pvestatd.service"
```

Make it executable and run it:

```bash
chmod +x /usr/local/sbin/pve-standalone-bootstrap.sh
/usr/local/sbin/pve-standalone-bootstrap.sh
```

---

## Systemd One-Shot Service (Optional)

To automate bootstrap on first boot, install a one-shot systemd service:

`/etc/systemd/system/pve-standalone-bootstrap.service`

```ini
[Unit]
Description=pxvirt Standalone Node Bootstrap
Before=pvedaemon.service
ConditionPathExists=!/etc/pve/datacenter.cfg

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/pve-standalone-bootstrap.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable pve-standalone-bootstrap.service
```

The `ConditionPathExists=!` ensures it only runs if `/etc/pve/datacenter.cfg` doesn't
already exist (i.e., first boot only).

---

## Starting Services

After bootstrap:

```bash
systemctl enable --now pvedaemon.service
systemctl enable --now pveproxy.service
systemctl enable --now pvestatd.service
```

Verify:

```bash
systemctl status pvedaemon pveproxy pvestatd
journalctl -u pvedaemon -n 50
```

Access the web UI at `https://<host-ip>:8006`. Log in as `root` with the system's PAM
password (same as your root shell password).

---

## What Doesn't Work Without pve-cluster

On a standalone node (no cluster), the following web UI features are unavailable or broken:

| Feature | Status | Reason |
|---------|--------|--------|
| Cluster view | ❌ Unavailable | Requires corosync + pve-cluster |
| Config sync between nodes | ❌ Unavailable | Requires pmxcfs |
| HA groups / HA resources | ❌ Unavailable | Requires pve-ha-manager |
| Cross-node migration | ❌ Unavailable | Requires cluster |
| Distributed firewall rules | ❌ Unavailable | Requires cluster config sync |
| VM/CT management (local) | ✅ Works | Full local management |
| Storage management | ✅ Works | All storage types |
| VM creation, start/stop/migrate (local) | ✅ Works | Single-node only |
| Web UI | ✅ Works | Full UI, cluster panels empty |
| Backups (local/PBS) | ✅ Works | |
| ACME/Let's Encrypt | ✅ Works | |
| User/permission management | ✅ Works | Local users only |

---

## Upgrading to Cluster Later (Phase 3)

When you're ready to add cluster support:

1. Install Phase 3 packages: `emerge sys-cluster/pve-cluster`
2. Stop pvedaemon: `systemctl stop pvedaemon pveproxy pvestatd`
3. Back up `/etc/pve/`: `cp -a /etc/pve /etc/pve.standalone.bak`
4. Start pve-cluster: `systemctl start pve-cluster`
   - This mounts pmxcfs over `/etc/pve/`
   - Existing config files are imported into pmxcfs automatically
5. Restart management services: `systemctl start pvedaemon pveproxy pvestatd`
6. Disable the standalone bootstrap service: `systemctl disable pve-standalone-bootstrap`
