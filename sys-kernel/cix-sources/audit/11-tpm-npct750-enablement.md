# 11 — TPM (Nuvoton NPCT750) enablement on the MS-R1

## Goal

Make the discrete Nuvoton NPCT750 TPM visible as `/dev/tpm0` on the
MS-R1 (`7.3.1-cix-ssp` test kernel).

## Firmware already describes the TPMs

The board SSDT already contains two SPI TPM children:

```
Scope (\_SB.SPI0) { Device (TP0) { _HID "SPT0001"; SpiSerialBusV2(... CS0, 500kHz) } }
Scope (\_SB.SPI1) { Device (TP1) { _HID "SPT0002"; SpiSerialBusV2(... CS0, 500kHz) } }
```

so no TPM SSDT is needed.  What was missing was the kernel side:

- `spi-cadence` had no ACPI match for the CIX SPI controllers
  (`CIXH2001`), so `spi0`/`spi1` never registered.
- `CONFIG_PINCTRL_SKY1` was unset in the captured MS-R1 config, so the
  ACPI pin groups (`\_SB.MUX0`/`MUX1`) were never applied.
- `tpm_tis_spi` had no ACPI ID for `SPT0001`/`SPT0002`.

## Changes

| Patch | Purpose |
|---|---|
| `0191-spi-cadence-add-cix-sky1-acpi-support.patch` | Port of srcshelton's audited `50130` 7.2.x patch: `CIXH2001` match data, `spi_reset` handling, device-property conversion, 8/16/32-bit word mask |
| `0193-tpm-tis-spi-match-cix-sky1-acpi-ids.patch` | Add `SPT0001`/`SPT0002` ACPI IDs to `tpm_tis_spi` |

Required kernel config (see `docs/config-notes.md`):

```
CONFIG_PINCTRL_SKY1=y
CONFIG_PINCTRL_SKY1_BASE=y
CONFIG_TCG_TPM=y
CONFIG_TCG_TIS_CORE=m
CONFIG_TCG_TIS_SPI=m
```

## Result on hardware (2026-11-01)

After enabling pinctrl and rebuilding:

- `CIXH2001:00` and `CIXH2001:01` bind to `cdns-spi`.
- `/sys/class/spi_master/spi0` and `spi1` exist.
- `spi-SPT0001:00` and `spi-SPT0002:00` enumerate from the SSDT.
- Pin mux is applied: `pinctrl_fch_spi0` claims the SPI1 pins and
  `pinctrl_fch_spi1` claims the GMAC1 pins used for the second
  controller.
- `tpm_tis_spi` automatically binds both devices, but both fail:

```
tpm_tis_spi spi-SPT0001:00: TPM vid 0xFFFF, did 0xFFFF init failed with error -19
tpm_tis_spi spi-SPT0002:00: TPM vid 0xFFFF, did 0xFFFF init failed with error -19
```

`0xFFFF` means no response on MISO / no TPM answering at the firmware
chip-select.  The software path is therefore complete; the remaining
issue is in the physical layer:

1. NPCT750 module not fully seated / wrong header / wrong orientation.
2. TPM not powered (header VCC or board jumper).
3. Board header wired to a different SPI bus/CS than the SSDT describes.
4. Wrong module variant (SPI vs I2C) or a defective module.

Next step: re-seat the 14-pin SPI TPM module, verify 3.3 V on the
header, and retry.  If it still returns 0xFFFF, probe SPI CLK/MOSI/MISO/CS
with a logic analyser and check which header the module is actually in.

## Notes

- Enabling `PINCTRL_SKY1` is independently useful: it removes most of
  the `pctldev with ACPI name '\_SB.MUX0/MUX1' not found` failures and
  applies the intended pin configuration.  Tested boot remained
  operational, including the 10Gbps USB link.
- `tpm_tis_spi` has no userspace dependency for the kernel probe; once
  the hardware responds, `/dev/tpm0` and `/dev/tpmrm0` will appear and
  `tpm2_getcap properties-fixed` can be used.
