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
