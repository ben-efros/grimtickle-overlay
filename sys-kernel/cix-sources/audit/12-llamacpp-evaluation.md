# 12 — llama.cpp on the MS-R1

Tested 2026-11-01 on the `7.3.1-cix-ssp` boot of the reference MS-R1
(12-core ARM: 8× Cortex-A720 + 4× Cortex-A520, 63 GiB RAM, 97 GiB swap).

## Installed stack

- `/usr/bin/llama-cli`, `llama-server`, `llama-bench` etc., build
  `221f0f635 (10235)`, built for aarch64.
- CPU backend: `libggml-cpu.so`.
- Vulkan backend: `libggml-vulkan.so`; `--list-devices` reports:
  `Vulkan0: Mali-G720 MC10 (48621 MiB)` via panvk/Mesa.
- No NPU backend is available (NPU driver/UMD absent).

## CPU result — works

TinyLlama-1.1B-Chat Q4_K_M (`/root/models/...`, 638 MiB), 8 threads,
CPU only:

```sh
GGML_VK_VISIBLE_DEVICES=-1 llama-bench \
  -m tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  -p 64 -n 16 -t 8 -ngl 0 -r 3
```

| Test | Throughput |
|---|---|
| Prompt processing pp64 | **109.8 ± 1.0 t/s** |
| Generation tg16 | **48.6 ± 1.5 t/s** |

End-to-end `llama-completion` confirms normal token generation
(`load 193 ms`, `prompt eval 93 t/s`, `eval 48.8 t/s`).

## Vulkan result — not practical yet

The Vulkan backend detects the Mali GPU, but full offload with the
default build crashes:

```
vk::DeviceLostError: vk::Queue::submit: ErrorDeviceLost
panthor: CS_FAULT / CS_FATAL (CS_BUS_FAULT), comm=llama-bench
```

With the Vulkan feature workarounds:

```sh
GGML_VK_DISABLE_INTEGER_DOT_PRODUCT=1 \
GGML_VK_DISABLE_COOPMAT=1 \
GGML_VK_DISABLE_FUSION=1 \
llama-bench -m ... -p 16 -n 8 -ngl 99
```

it completes, but performance is far below CPU:

| Test | Throughput |
|---|---|
| pp16 | 1.11 t/s |
| tg8 | 4.61 t/s |

PanVK is explicitly non-conformant and this workload hits a bus fault
with the default shader set.  Until the PanVK/llama.cpp combination is
fixed, GPU inference is not useful on this board.

## Recommendation

Use llama.cpp's CPU backend:

```sh
GGML_VK_VISIBLE_DEVICES=-1 llama-cli -m /root/models/<model>.gguf \
  -ngl 0 -t 12 -p "..." -n 128
```

The 63 GiB RAM and 97 GiB swap are enough for 7B–13B quantized models;
the limit is CPU throughput, not memory.  A 7B Q4 model should be
benchmarked before promising interactive use, but 1.1B Q4 is already
usable at ~49 t/s generation.

## What others report on the same SoC

The picture is not hopeless; other CIX/Sky1 users have working GPU
inference with different userspace versions:

- The NCZ CIX installer AI/ML stack documents a working **panvk +
  llama.cpp** setup on Sky1 with Mesa 26.1.3: GPU offload is useful for
  prompt/prefill, while CPU wins token decode.  It also notes that very
  large single dispatches (e.g. `pp512`) can still crash panvk, and that
  the NPU cannot run LLMs (Compass NN only supports static graphs, no
  KV-cache/variable-length decode):
  <https://gitlab.com/ncz-os/cix-installer/-/blob/398578648a0bfa573b17a6c1e884dab76199b74e/docs/AI-ML-STACK.zh-CN.md>
- llama.cpp issue **#23057** is the same MS-R1/CIX CP8180 hardware.  It
  was root-caused to a 32-bit `CEIL_DIV` overflow when
  `maxComputeWorkGroupCount` is `UINT32_MAX` (typical of Mali), and was
  closed in July 2026 after the fix was validated on Mali-G68; reports in
  the thread show the open-source panvk stack working with constrained
  batches (`-b 64 -ub 64`) on the CIX Ubuntu concept image:
  <https://github.com/ggml-org/llama.cpp/issues/23057>
- A Mali-G720-specific Vulkan tuning PR (warptile/FP32 tuning, Termux)
  exists but was closed unmerged:
  <https://github.com/ggml-org/llama.cpp/pull/18493>

Our current Gentoo userspace is **Mesa 26.3.0-devel (panvk)**.  Even with
`-b 64 -ub 64` it hits a panthor `CS_BUS_FAULT` / `vk::DeviceLostError`
on the default shader path; disabling integer-dot/coopmat/fusion makes
it run but at only ~1.1/4.6 t/s.  This looks like a Mesa 26.3 panvk
regression or a stack-specific issue rather than an inherent G720
limitation.  Possible next steps are to test the ncz Mesa 26.1.3 build
(or a Mesa version that includes the #23057 fix) and retry constrained
batches, then compare with CPU decode.

## Comparison: Xeon Gold 6136

Same model (`TinyLlama-1.1B-Chat Q4_K_M`), CPU backend, `llama-bench
-p 64 -n 16`, using a local dual-socket Xeon Gold 6136 (Skylake-SP,
12 cores/24 threads per socket, 3.0/3.7 GHz, 6-channel DDR4-2666,
AVX-512) with single-socket CPU pinning:

| CPU | Threads | pp64 (t/s) | tg16 (t/s) |
|---|---:|---:|---:|
| MS-R1 (Cortex-A720/A520) | 8 | 109.8 | **48.6** |
| MS-R1 (all cores) | 12 | 95.7 | 16.4 |
| Xeon Gold 6136, 1 socket | 8 | 304.0 | 48.2 |
| Xeon Gold 6136, 1 socket | 12 | **400.5** | **58.4** |
| Xeon Gold 6136, 2 sockets | 44 | 20.3 | 6.9 |

Key points:

- **Token generation is essentially tied at 8 threads** (48.2 vs 48.6
  t/s).  For a 1.1B Q4 model, decode is dominated by memory bandwidth
  and per-token overhead, not raw FLOPs.
- The Xeon is **~2.8× faster at prompt processing at 8 threads** and
  **~3.6× faster at its best (12 threads)**.  Prefill is compute-bound,
  so Skylake-SP's AVX-512 and larger caches win.
- The MS-R1's 8-thread sweet spot matters: using all 12 cores drops
  decode to 16.4 t/s because of A520/big.LITTLE scheduling.  llama.cpp
  should be run with `-t 8` on this box, not `-t 12`.
- The dual-socket 44-thread result is not representative — cross-NUMA
  scheduling destroys performance; the single-socket numbers are the
  relevant ones for "a Xeon 6136".
- The test kernels/llama.cpp builds differ slightly (target build
  `221f0f635`, local build `785322d`), so treat differences under a few
  percent as noise.  Power is not comparable: the Xeon platform is
  ~150 W TDP for the CPU alone, versus the whole MS-R1 box idling around
  ~30 W.

So for a small 1.1B model the MS-R1 is surprisingly competitive on
decode, while the Xeon remains much faster for long-prompt/批处理
prefill.  For 7B+ models the Xeon's bandwidth advantage should widen,
but the same qualitative split (Xeon wins prefill, similar/somewhat
better decode) is expected.
