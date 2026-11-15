#!/usr/bin/env bash
# PEFM00 fixup: patches that live in the external vendor/oplus tree
# (android_kernel_modules_oppo_mt6765) or adjust the defconfig.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
V="$ROOT/../vendor"

echo "== vendor tree: $V"
if [ ! -d "$V/oplus" ]; then
	echo "!! $V/oplus missing; copy android_kernel_modules_oppo_mt6765/source/vendor first" >&2
	exit 1
fi

echo "== [1/3] project node fallback (oppo_project -> oplus_project)"
for f in "$V/oplus/kernel/system/oplus_project/mtk/oplus_project.c" \
         "$V/oplus/kernel/system/oplus_project/mtk/oplus_project_oldcdt.c"; do
	[ -f "$f" ] || { echo "   skip $f"; continue; }
	python3 - "$f" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
old='np = of_find_node_by_name(NULL, "oplus_project");'
new='''np = of_find_node_by_name(NULL, "oplus_project");
	if (!np)
		np = of_find_node_by_name(NULL, "oppo_project");'''
if 'oppo_project");' in s:
    print('   already patched:', p)
else:
    s=s.replace(old,new)
    open(p,'w').write(s)
    print('   patched:', p)
PY
done

echo "== [2/3] drop -Werror from vendor Makefiles (GCC 13+)"
find "$V" \( -name Makefile -o -name Kbuild -o -name "*.mk" \) -type f 2>/dev/null \
	| xargs -r grep -l -- "-Werror" 2>/dev/null \
	| while read -r f; do sed -i 's/-Werror/-Wno-error/g' "$f"; done
echo "   done"

echo "== [3/3] defconfig: USB gadget serial (ttyGS0 console)"
CONF="$ROOT/arch/arm64/configs/oppo6765_20375_defconfig"
if ! grep -q "^CONFIG_USB_G_SERIAL=y" "$CONF" 2>/dev/null; then
	echo "CONFIG_USB_G_SERIAL=y" >> "$CONF"
	echo "   added"
else
	echo "   already there"
fi

echo "== fixup complete"
