# OPPO A35 (PEFM00 / project 20091) — Linux 4.19 bring-up notes

Base: `oppo-source/android_kernel_oppo_mt6765`, branch `oppo/mt6765_r_11.1.4_a16` (Linux 4.19.127).

Stock device kernel is 4.14.141; this tree is the OPPO Android-11 (R) 4.19 vendor kernel.

## Companion tree

The kernel source has ~56 symlinks into `vendor/oplus` (and `vendor/mediatek`), e.g.
`drivers/power/oplus -> ../../../vendor/oplus/kernel/charger`.
Those resolve to `<this tree>/../vendor` (the Android layout has `kernel/` and `vendor/` as siblings).
Fetch them from `oppo-source/android_kernel_modules_oppo_mt6765`, same branch:

    git clone --depth 1 -b oppo/mt6765_r_11.1.4_a16 \
      https://github.com/oppo-source/android_kernel_modules_oppo_mt6765.git /tmp/oppo-modules
    mkdir -p ../vendor
    cp -a /tmp/oppo-modules/source/vendor/oplus  ../vendor/oplus
    cp -a /tmp/oppo-modules/source/vendor/mediatek ../vendor/mediatek

## Fixes applied for a standalone (non-Android) build

- `scripts/extract-cert.c`: drop `openssl/engine.h` + PKCS#11 branch (OpenSSL 3).
- `MODULE_SIG` disabled (host `scripts/sign-file.c` also needs the removed engine.h).
- `include/linux/uifirst/uifirst_sched_common.h`: `is_animator_ux_task()` gets a return type.
- `kernel/sched/extension/eas_plus.c`: declare `sysctl_slide_boost_enabled`.
- `mm/mmap.c`: bypass `vm_mmap_pgoff_with_check()` (no definition in this tree).
- `fs/exfat`, `fs/osdcardfs`: empty stubs (the OPPO copies are not in the modules repo).
- `fs/proc/resmap_account.h`, `mm/vm_anti_fragment1.c`: repointed to the real files.

## Build

    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=$PWD/out \
      oppo6765_20375_defconfig
    make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- O=$PWD/out \
      KCFLAGS="-Wno-error=strict-prototypes -Wno-error=return-type \
               -Wno-error=array-compare -Wno-error=format \
               -Wno-error=implicit-function-declaration" \
      -j$(nproc) Image dtbs

The A35 board DTS is NOT in the OPPO source; only 20271/20361/20379/206A1/20701/21251/21281 exist.
Use the stock PEFM00 DTB (`boot.img` dtb, 106865 bytes) for the first boot test.
