# pve-cluster — Port Analysis and Modification Document

| Field | Value |
|---|---|
| pxvirt version | 9.0.6 (`pxvirt/packages/pve-cluster/pve-cluster`) |
| Upstream proxmox version | 9.1.6 (`/mnt/remoteshare/Projects/pve-cluster`) |
| Recommended base | **Upstream 9.1.6** (better code; see §2) |
| Portage atoms | 3 packages (see §1) |
| Priority | **CRITICAL** — most other packages are blocked on this |
| Status | 🔴 Not started |

---

## §1 — Package Split

Debian produces 4 binary packages from one source. For Gentoo we consolidate to **3**
(libpve-notify-perl merged into libpve-cluster-perl — same source, trivial extra dep):

### 1.1 `sys-cluster/pve-cluster` (C daemon + Perl XS)

| Item | Details |
|---|---|
| Key binary | `/usr/bin/pmxcfs` — FUSE daemon, cluster filesystem over corosync |
| Also installs | `/usr/bin/create_pmxcfs_db` — initialize SQLite DB offline |
| Perl XS | `IPCC.so` — IPC to pmxcfs via libqb; built from `IPCC.xs` |
| Perl modules | `PVE::Cluster`, `PVE::IPCC`, `PVE::Cluster::IPCConst` |
| C build deps | corosync libs (libcpg, libcmap, libquorum, libcorosync_common), libqb, libfuse, libglib2, libsqlite3, librrd, check |

### 1.2 `dev-perl/libpve-cluster-perl` (Pure Perl library + notify)

| Modules | Notes |
|---|---|
| `PVE::Corosync` | Parse/write corosync.conf |
| `PVE::DataCenterConfig` | Datacenter-level config schema |
| `PVE::RRD` | RRD metrics interface (requires `net-analyzer/rrdtool[perl,graph]`) |
| `PVE::SSHInfo` | SSH key/fingerprint helpers |
| `PVE::Notify` | Notification dispatcher (uses `Proxmox::RS::Notify` from libproxmox-rs-perl) |
| Perl deps | `RRDs` (from `net-analyzer/rrdtool[perl,graph]`), `Net::SSLeay`, `libpve-apiclient-perl`, `libproxmox-rs-perl` |
| Runtime service | `rrdcached` |

### 1.3 `dev-perl/libpve-cluster-api-perl` (API + pvecm CLI)

| Modules | Notes |
|---|---|
| `PVE::API2::*` | REST endpoints under `/cluster/` |
| `PVE::CLI::pvecm` | `pvecm` command (cluster management CLI) |
| `PVE::Cluster::Setup` | Node join/leave, SSL cert generation |
| Runtime tools | `faketime` (`sys-libs/libfaketime`), `rsync`, `openssl`, `ssh-keygen` |
| Perl deps | `Digest::HMAC`, `UUID`, `libpve-access-control`, `libpve-apiclient-perl` |

---

## §2 — pxvirt 9.0.6 vs Upstream 9.1.6 Differences

**Recommendation**: Use **upstream 9.1.6** as the ebuild source. Apply pxvirt-specific
features as numbered patches. Do NOT use pxvirt 9.0.6 as the base — upstream has critical
bug fixes that pxvirt is missing.

### 2.1 `PVE/API2/ClusterConfig.pm` — vmlist endpoint ✅ APPLY AS PATCH

pxvirt adds `/cluster/vmlist` API endpoint returning UUID-annotated VM list (pxvirt-specific
UUID-based VM discovery feature).

**Patch**: `0001-pxvirt-cluster-vmlist-uuid-endpoint.patch`

### 2.2 `PVE/Cluster/Setup.pm` — SSL cert generation ⛔ USE UPSTREAM

pxvirt uses legacy approach: writes full OpenSSL config to `/tmp/pvesslconf-$$.tmp` and
passes it via `-config`. Upstream uses modern `-addext keyUsage=critical,...` flag (OpenSSL
≥ 1.1.1) and writes the CSR to `/run/pve-cluster/` (no /tmp race condition).

**Action**: Use upstream code as-is.

### 2.3 `PVE/Cluster.pm` — lock timeout + path whitelist ⚡ MIXED

| Change | Direction | Action |
|--------|-----------|--------|
| `List::Util::max/min` for alarm timeout precision | upstream improvement pxvirt lacks | Use upstream |
| `Time::HiRes::usleep` for fine-grained lock retry | upstream improvement | Use upstream |
| `priv/wg-keys.cfg` in cfs_file_db whitelist | pxvirt (WireGuard support) | Patch with 0002 |
| `sdn/route-maps.cfg`, `sdn/prefix-lists.cfg` | pxvirt (SDN feature) | Patch with 0002 |
| `mkdir $dbbackupdir or $!{EEXIST}` + `chmod 0700` | upstream improvement | Use upstream |

**Patch**: `0002-pxvirt-add-wg-sdn-paths.patch` (covers Cluster.pm + status.c paths)

### 2.4 `PVE/Corosync.pm` — token-coefficient ✅ APPLY AS PATCH

pxvirt adds `token-coefficient` totem parameter for tuning corosync timing on
high-latency/lossy networks.

**Patch**: `0003-pxvirt-corosync-token-coefficient.patch`

### 2.5 `PVE/DataCenterConfig.pm` — HA auto-rebalance ✅ APPLY AS PATCH

pxvirt adds:
- `dynamic` CRS scheduling mode (alongside `basic`/`static`)
- `ha-auto-rebalance` (boolean)
- `ha-auto-rebalance-threshold` (0–100%)
- `ha-auto-rebalance-method` (`bruteforce`/`topsis`)
- `ha-auto-rebalance-hold-duration` (rounds)

**Patch**: `0004-pxvirt-ha-auto-rebalance.patch`

### 2.6 `PVE/RRD.pm` — pxvirt MISSING upstream improvements ⛔ USE UPSTREAM

Upstream 9.1.6 added:
- `get_rrd_data` closure (deduplicates RRD fetch logic)
- `get_old_rrd_path_if_exist` (handles `.old` suffix for renamed RRD files during
  the `memavailable→memfree` field rename migration)

pxvirt 9.0.6 lacks both — **RRD data reads for migrated datasets will fail silently**.
This is a pxvirt bug, not intentional.

**Action**: Use upstream code as-is.

### 2.7 `pmxcfs/database.c` — prepared statement cache ✅ APPLY AS PATCH

pxvirt adds pre-prepared `sql_update_entry` statement, avoiding repeated `sqlite3_prepare`
on every tree UPDATE write (performance improvement for high-frequency cluster writes).

**Patch**: `0005-pxvirt-database-prepared-stmt-cache.patch`

### 2.8 `pmxcfs/pmxcfs.c` — directory permissions ⛔ USE UPSTREAM

| Path | pxvirt | Upstream |
|------|--------|----------|
| `/var/lib/pve-cluster` | `0755` | `0750` |
| `/run/pve-cluster` | `0755` | `0750` |
| `/etc/pve` | `0755` | `0750` |

Upstream's `0750` is more secure. **Action**: Use upstream permissions.

### 2.9 `pmxcfs/status.c` — private path list + RRD defs ⚡ MIXED + ⚠️ RISK

| Change | Direction | Action |
|--------|-----------|--------|
| `priv/wg-keys.cfg` added to private_files[] | pxvirt (WireGuard) | Patch with 0002 |
| `sdn/route-maps.cfg`, `sdn/prefix-lists.cfg` added | pxvirt (SDN) | Patch with 0002 |
| Static `rrd_def_node[]` and `rrd_def_vm[]` **removed** | pxvirt architecture change | ⚠️ INVESTIGATE |

**⚠️ HIGH RISK**: pxvirt removes the static RRD database creation definitions from
status.c. These arrays tell pmxcfs how to initialize RRD round-robin databases for new
nodes and VMs. If pxvirt moved this logic elsewhere (e.g., into a Perl layer or a different
C file), removing them is safe. If not, pmxcfs will silently fail to create RRD databases
for new nodes — metrics will never appear.

**Required before patching**: Verify whether RRD DB creation still works in the pxvirt
9.0.6 build without these definitions. Check pve-manager or other packages for replacement
logic.

---

## §3 — Gentoo-Specific Build Changes

### 3.1 IPCC.xs Compilation ⚙️

The `IPCC.xs` Perl XS binding (IPC bridge to pmxcfs via libqb) must be compiled at emerge:

```bash
# Step 1: Generate C from XS
xsubpp -noversioncheck IPCC.xs > IPCC.c

# Step 2: Compile shared library
gcc -fPIC -Wall -O2 \
    $(perl -MExtUtils::Embed -e perl_inc) \
    $(pkg-config --cflags libqb) \
    -shared -o IPCC.so IPCC.c \
    $(pkg-config --libs libqb)
```

IPCC.so must be installed to `$(perl -MConfig -e 'print $Config{vendorarch}')/auto/PVE/IPCC/IPCC.so`
so Perl's auto-loader finds it when `use PVE::IPCC` is called.

**BDEPEND**: `dev-perl/ExtUtils-MakeMaker` (provides `xsubpp`), `sys-cluster/libqb`

### 3.2 IPCConst.pm Code Generation ⚙️

`PVE::Cluster::IPCConst` is generated at build time from `pmxcfs/cfs-ipc-ops.h` via awk:
```bash
awk -f src/PVE/Cluster/IPCConst.pm.awk src/pmxcfs/cfs-ipc-ops.h > IPCConst.pm
```
This generates Perl constants for all `CFS_IPC_*` opcodes. Must run AFTER the pmxcfs
build so the header is in place.

### 3.3 RRDs Perl Bindings (USE flag required) 📋

`PVE::RRD` requires the `RRDs` Perl module from rrdtool. In Gentoo:
```
net-analyzer/rrdtool[perl,graph]
```
Note: `graph` USE is **required** when enabling `perl` — rrdtool-1.10.3.ebuild enforces this.

**RDEPEND** for `libpve-cluster-perl`: `net-analyzer/rrdtool[perl,graph]`

### 3.4 faketime Binary 📋

Used by `PVE::Cluster::Setup` for certificate date manipulation during cluster join/renew.
Gentoo provides this as `sys-libs/libfaketime` (installs `/usr/bin/faketime`).

**RDEPEND** for `libpve-cluster-api-perl`: `sys-libs/libfaketime`

### 3.5 systemd Service + OpenRC Init Script 📋

The existing `debian/pve-cluster.service` can be installed as-is for systemd users.
An OpenRC init script is also needed for non-systemd Gentoo:

```sh
# /etc/init.d/pve-cluster — key requirements:
# - depend on: net corosync rrdcached
# - require: sys-fs/fuse kernel module loaded (br_netfilter too)
# - start-stop-daemon --exec /usr/bin/pmxcfs
# - pidfile: /run/pve-cluster.pid
```

### 3.6 sysctl Settings 📋

`debian/sysctl.d/10-pve.conf` must be installed — these are required for VM/CT networking:
```
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
net.bridge.bridge-nf-filter-vlan-tagged = 0
net.ipv4.igmp_link_local_mcast_reports = 0
fs.aio-max-nr = 1048576
```
Install to: `/usr/lib/sysctl.d/10-pve-cluster.conf`

### 3.7 Directory Creation 📋

| Directory | Mode | Notes |
|-----------|------|-------|
| `/var/lib/pve-cluster` | `0750` | SQLite DB; created by pmxcfs at startup if absent |
| `/etc/pve` | `0750` | FUSE mount point; pmxcfs mounts here |
| `/etc/pve/priv` | `0700` | Private credentials; created by pmxcfs |
| `/run/pve-cluster` | `0750` | Runtime socket/temp; created by pmxcfs |

pmxcfs creates most dirs itself on first run. `keepdir` for `/var/lib/pve-cluster`
in ebuild; let pmxcfs handle the rest.

### 3.8 rrdcached Socket Path ⚠️

Verify the rrdcached socket path on Gentoo. Debian uses `/run/rrdcached.sock`.
Gentoo's rrdtool init script configures rrdcached differently.

**Action required**: Check `/etc/conf.d/rrdcached` or `rrdcached.service` socket
path after rrdtool install, then verify `PVE::RRD` uses the right path.

### 3.9 postinst Migration Logic 📋

Debian's `postinst` removes the legacy `/etc/pve/sdn/fabrics/` directory when upgrading
from < 9.0.1. For Gentoo (fresh install only), this is not needed. However, for the
upgrade case, add to `pkg_postinst()`:
```bash
rmdir --ignore-fail-on-non-empty /etc/pve/sdn/fabrics/ 2>/dev/null || true
```

---

## §4 — Dependency Matrix

| Dep | Type | Gentoo Atom | Status |
|-----|------|-------------|--------|
| libcpg, libcmap, libquorum, libcorosync_common | C BUILD | `sys-cluster/corosync` | ✅ In ::gentoo |
| libqb | C BUILD+LINK | `sys-cluster/libqb` | ✅ In ::gentoo |
| libfuse | C BUILD+LINK | `sys-fs/fuse` | ✅ In ::gentoo |
| libglib-2.0 | C BUILD+LINK | `dev-libs/glib` | ✅ In ::gentoo |
| libsqlite3 | C BUILD+LINK | `dev-db/sqlite` | ✅ In ::gentoo |
| librrd | C BUILD+LINK | `net-analyzer/rrdtool` | ✅ In ::gentoo |
| check | C BUILD TEST | `dev-libs/check` | ✅ In ::gentoo |
| xsubpp | XS BUILD | `dev-perl/ExtUtils-MakeMaker` | ✅ In ::gentoo |
| RRDs (Perl) | PERL RDEP | `net-analyzer/rrdtool[perl,graph]` | ✅ In ::gentoo (USE flag needed) |
| Net::SSLeay | PERL RDEP | `dev-perl/Net-SSLeay` | ✅ In ::gentoo |
| Digest::HMAC | PERL RDEP | `dev-perl/Digest-HMAC` | ✅ In ::gentoo |
| UUID | PERL RDEP | `dev-perl/UUID` | ✅ In ::gentoo |
| faketime | RUNTIME | `sys-libs/libfaketime` | ✅ In ::gentoo |
| rrdcached | RUNTIME SERVICE | `net-analyzer/rrdtool` | ✅ In ::gentoo |
| rsync | RUNTIME | `net-misc/rsync` | ✅ In ::gentoo |
| openssl | RUNTIME | `dev-libs/openssl` | ✅ In ::gentoo |

**All dependencies available** — no new overlay ebuilds needed for deps.

---

## §5 — Implementation Task List

| # | Task | Owner | Status |
|---|------|-------|--------|
| 5.1 | Investigate pxvirt RRD def removal (§2.9) | — | 🔴 Todo |
| 5.2 | Generate 5 pxvirt patches against upstream 9.1.6 | — | 🔴 Todo |
| 5.3 | Write `sys-cluster/pve-cluster` ebuild (C daemon + XS) | — | 🔴 Todo |
| 5.4 | Write OpenRC init script for pmxcfs | — | 🔴 Todo |
| 5.5 | Write `dev-perl/libpve-cluster-perl` ebuild | — | 🔴 Todo |
| 5.6 | Write `dev-perl/libpve-cluster-api-perl` ebuild | — | 🔴 Todo |
| 5.7 | Verify rrdcached socket path on Gentoo | — | 🔴 Todo |
| 5.8 | Test single-node bootstrap with create_pmxcfs_db | — | 🔴 Todo |

---

## §6 — Single-Node Operation Without Full Cluster

pmxcfs supports running without an active corosync cluster ("local mode"). When corosync
is not running or quorum is not achieved, pmxcfs operates locally — serving `/etc/pve/`
from its SQLite database without replication.

**Single-node bootstrap sequence**:
```bash
# 1. Initialize the database (one-time)
create_pmxcfs_db /var/lib/pve-cluster/config.db

# 2. Start pmxcfs (will run in local mode without corosync)
pmxcfs &

# 3. Seed minimal config through the mounted filesystem
echo 'user:root@pam:1:0:::root@localhost::' > /etc/pve/user.cfg
touch /etc/pve/priv/shadow.cfg

# 4. Start pvedaemon (now has /etc/pve/ access)
pvedaemon start
```

This is sufficient for a single-node hypervisor without clustering.

---

## §7 — Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| pxvirt RRD def removal may break RRD DB creation for new nodes | HIGH | Use upstream code; don't apply pxvirt RRD removal until verified |
| IPCC.so ABI tied to specific libqb version | MEDIUM | Pin `sys-cluster/libqb:=` in RDEPEND/DEPEND |
| FUSE mount fails without kernel module loaded | MEDIUM | Add modprobe/kernel check in init script |
| rrdcached socket path mismatch | LOW | Document and verify after install |
| xsubpp version sensitivity | LOW | BDEPEND on `dev-perl/ExtUtils-MakeMaker` |
| pmxcfs local mode behavior differences vs clustered mode | MEDIUM | Test and document |

---

## §8 — Contested pxvirt Changes: Full Analysis and Recommendations

This section documents every pxvirt change the Gentoo port disagrees with,
explains the rationale, and specifies what we use instead.

---

### 8.1 `pmxcfs/database.c` — `stmt_update_entry` is DEAD CODE

**pxvirt adds:**
```c
sqlite3_stmt *stmt_update_entry;             // struct field
static char *sql_update_entry = "UPDATE tree SET ...";  // SQL string
sqlite3_prepare_v3(..., sql_update_entry, ..., &bdb->stmt_update_entry, ...); // init
sqlite3_finalize(bdb->stmt_update_entry);    // cleanup
```

**The problem:** `stmt_update_entry` is **never called**. The actual write path in
both pxvirt and upstream uses:
```c
sqlite3_stmt *stmt = (inode > version) ? bdb->stmt_insert_entry : bdb->stmt_replace_entry;
rc = backend_write_inode(bdb->db, stmt, ...);
```
`stmt_update_entry` is initialized and finalized but never bound or stepped.
It is dead code.

**Additional harm**: pxvirt's init has a `goto fail` on `sqlite3_prepare_v3` for this
statement. If the prepare fails for any reason, database initialization fails entirely —
for a statement that is never used.

**pxvirt also misses** an upstream bugfix present in the same file:
```c
// upstream adds sqlite3_close(db) in error path (line 107):
if (rc != SQLITE_OK) {
    sqlite3_close(db);   // ← pxvirt MISSING this — connection leak on init failure
    return NULL;
}
```

**Decision:** Use upstream `database.c` as-is.
- Dead code removed
- Connection leak on init failure fixed (upstream bugfix)
- No `goto fail` for an unused prepared statement

**Patch status:** Patch 0005 from §2.7 is **cancelled**. Not applied.

---

### 8.2 `pmxcfs/status.c` — RRD Definition Removal is Safe (but permissions are wrong)

**What pxvirt removes:**
- `rrd_def_node[]` — PVE2-era RRD schema for nodes
- `rrd_def_vm[]` — PVE2-era RRD schema for VMs
- `rrd_def_storage[]` — PVE2-era RRD schema for storage
- The migration logic that checks for `pve2-node/`, `pve2-vm/`, `pve2-storage/` dirs
- `filename_pve2` pointer tracking for all three entity types
- `use_pve2_file` flag logic

**Why pxvirt did this:** pxvirt targets ARM64/LoongArch as a fresh platform. There are
no PVE2.x installations to migrate from. The `rrd_def_*` legacy arrays are ONLY used
when a `pve2-*` directory already exists in the RRD data dir — which only happens on
systems upgrading from Proxmox VE 2.x (2013 era). On a fresh install, code path never
reaches these arrays.

**Assessment:** The RRD removal is correct and intentional. It is NOT a bug.
Fresh Gentoo installs will never have `pve2-*` directories.

**However — permissions are wrong in pxvirt:**

pxvirt's simplified code uses `0755` for `checked_mkdir` calls in the RRD creation path:
```c
checked_mkdir(RRDDIR "/pve-node-9.0", 0755);  // pxvirt — too permissive
checked_mkdir(dir, 0755);                      // pxvirt
```

Upstream correctly uses `0750`:
```c
checked_mkdir(RRDDIR "/pve-node-9.0", 0750);  // upstream — correct
checked_mkdir(dir, 0750);                      // upstream
```

**Decision:** Use upstream `status.c` as the base. Apply pxvirt's WireGuard and SDN
path additions as patch 0002, but do NOT apply pxvirt's simplified RRD creation path.

**Why upstream is better here:**
- Upstream has the same net result for fresh installs (no pve2 dirs = same code path)
- Upstream uses `0750` (restricts RRD dir to owner only)
- Upstream code is better documented and tested
- If an admin has PVE2 data they want to preserve, upstream handles it gracefully

**Patch 0002** applies only the private file additions:
```diff
+    {.path = "priv/wg-keys.cfg"},
...
+    {.path = "sdn/route-maps.cfg"},
+    {.path = "sdn/prefix-lists.cfg"},
```

---

### 8.3 `pmxcfs/pmxcfs.c` — Directory Permissions Too Permissive

**pxvirt:**
```c
mkdir(VARLIBDIR, 0755);  // /var/lib/pve-cluster
mkdir(RUNDIR,    0755);  // /run/pve-cluster
mkdir(CFSDIR,    0755);  // /etc/pve
```

**Upstream:**
```c
mkdir(VARLIBDIR, 0750);
mkdir(RUNDIR,    0750);
mkdir(CFSDIR,    0750);
```

**The problem:** `/etc/pve/priv/` contains private SSL keys, shadow credentials, and
auth tokens. World-readable (`0755`) parent directories mean any local user can attempt
to enumerate and access sensitive cluster config. `0750` (owner + group readable only)
is correct.

**Decision:** Use upstream `pmxcfs.c` as-is. The permission tightening is the right call.
No patch needed — upstream is correct.

---

### 8.4 `PVE/Cluster/Setup.pm` — Legacy SSL Config File in /tmp

**pxvirt uses:**
```perl
my $cfgfn = "/tmp/pvesslconf-$$.tmp";    # temp file in world-writable /tmp
my $fh = IO::File->new($cfgfn, "w");
print $fh $sslconf;
close($fh);
# ... then:
'-config', $cfgfn,                        # passes to openssl
```

**Upstream uses:**
```perl
my $reqfn = "/run/pve-cluster/pvecertreq-$$.tmp";  # temp in service-owned dir
# Uses -addext directly:
'-addext', 'keyUsage=critical,keyCertSign,cRLSign',
```

**Problems with pxvirt's approach:**

1. **`/tmp` race condition (TOCTOU)**: Writing a config file to world-writable `/tmp`
   is a classic symlink attack vector. A local user could pre-create a symlink at
   `/tmp/pvesslconf-$$.tmp` before root runs `pvecm` and cause the config to be written
   to an attacker-controlled location.

2. **`/run/pve-cluster/` is safer**: This directory is created as `0750` by pmxcfs and
   owned by root. Only root can write there — no symlink race.

3. **pxvirt's SAN construction is different:**
   pxvirt (correct order): resolve IP → append to names → then read DNS config  
   Upstream (cleaner): build `names` string inline  
   No functional difference but pxvirt reads `resolvconf` after setting `$names` —
   slightly confusing order.

4. **`-addext` requires OpenSSL ≥ 1.1.1** (2018): All modern Gentoo systems have
   OpenSSL ≥ 3.x. This is not a compatibility concern.

**Decision:** Use upstream `Setup.pm`. The `/run/pve-cluster/` temp path and `-addext`
approach are safer and cleaner.

---

### 8.5 `PVE/RRD.pm` — pxvirt Misses Critical Upstream Bug Fix

**What upstream adds that pxvirt lacks:**
```perl
my $get_rrd_data = sub {
    my ($rrd, $cf, $is_node, $reso, $args, $res) = @_;
    ...
    # Handles the memavailable/memfree rename:
    $entry->{memavailable} = $val
        if $is_node && $name eq 'memfree' && !exists($entry->{memavailable});
```

**The `memfree`/`memavailable` issue:** Proxmox VE 8.x renamed the RRD data source
`memfree` to `memavailable` to more accurately reflect the Linux `MemAvailable` field
(which accounts for reclaimable caches). Existing RRD databases have `memfree`.

Without the upstream fix, nodes with pre-existing RRD data will:
- Show `memavailable = undefined` for old time ranges
- Charts will have gaps where the old field name was used
- The `get_old_rrd_path_if_exist` helper also handles the `.old` suffix migration

**Decision:** Use upstream `RRD.pm`. This is not a pxvirt feature, it is a pxvirt bug.
No patch — upstream code is used directly.

---

### Summary: Revised Patch Set

| Patch | Status | Reason |
|-------|--------|--------|
| 0001 — `/cluster/vmlist` UUID endpoint | ✅ APPLY | Legitimate pxvirt feature |
| 0002 — WireGuard + SDN path whitelist | ✅ APPLY (trimmed) | Private file additions only; no permission changes |
| 0003 — `token-coefficient` in Corosync.pm | ✅ APPLY | Legitimate pxvirt feature |
| 0004 — HA auto-rebalance in DataCenterConfig.pm | ✅ APPLY | Legitimate pxvirt feature |
| 0005 — `stmt_update_entry` prepared stmt | ❌ CANCELLED | Dead code; adds pointless failure mode |

| File | Decision | Reason |
|------|----------|--------|
| `pmxcfs/database.c` | Use upstream | Dead code removed; has connection leak fix |
| `pmxcfs/pmxcfs.c` | Use upstream | `0750` permissions are more secure |
| `pmxcfs/status.c` | Use upstream + patch 0002 | `0750` RRD dirs; preserves PVE2 migration path for safety |
| `PVE/Cluster/Setup.pm` | Use upstream | No `/tmp` race; `-addext` is modern and safe |
| `PVE/RRD.pm` | Use upstream | Critical memfree/memavailable fix pxvirt is missing |
| `PVE/Cluster.pm` | Use upstream + patch 0002 path additions | Better lock precision; upstream bug fixes |
| `PVE/Corosync.pm` | Use upstream + patch 0003 | token-coefficient is useful feature |
| `PVE/DataCenterConfig.pm` | Use upstream + patch 0004 | HA auto-rebalance is useful feature |
| `PVE/API2/ClusterConfig.pm` | Use upstream + patch 0001 | vmlist UUID endpoint is useful feature |
