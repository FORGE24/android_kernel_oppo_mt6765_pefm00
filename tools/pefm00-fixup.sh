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

echo "== [1b/3] hardcode project 20091 when lookup fails (PEFM00)"
python3 - "$V/oplus/kernel/system/oplus_project/mtk/oplus_project.c" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
old='''unsigned int get_project(void)
{
    init_project_version();

    if(!is_new_cdt()){
        return get_project_oldcdt();
    }

    return g_project? g_project->nDataBCDT.ProjectNo : 0;
}'''
new='''unsigned int get_project(void)
{
    unsigned int r;

    init_project_version();

    if(!is_new_cdt()){
        r = get_project_oldcdt();
    } else {
        r = g_project ? g_project->nDataBCDT.ProjectNo : 0;
    }

    /* PEFM00: force the A35 id if the DTB lookup failed */
    if (r == 0)
        r = 20091;

    return r;
}'''
if 'PEFM00: force the A35 id' in s:
    print('   already patched')
else:
    s=s.replace(old,new,1)
    open(p,'w').write(s)
    print('   patched get_project')
PY

python3 - "$V/oplus/kernel/system/oplus_project/mtk/oplus_project_oldcdt.c" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
old='''	if(format)
		return format->nProject;
	else
		return 0;'''
new='''	if(format)
		return format->nProject;
	else
		return 20091; /* PEFM00 fallback */'''
if 'PEFM00 fallback' in s:
    print('   already patched')
else:
    s=s.replace(old,new,1)
    open(p,'w').write(s)
    print('   patched oldcdt')
PY

echo "== [2/3] drop -Werror from vendor Makefiles (GCC 13+)"
find "$V" \( -name Makefile -o -name Kbuild -o -name "*.mk" \) -type f 2>/dev/null \
	| xargs -r grep -l -- "-Werror" 2>/dev/null \
	| while read -r f; do sed -i 's/-Werror/-Wno-error/g' "$f"; done
echo "   done"

echo "== [3/3] defconfig: USB gadget serial + MT6370 TCPC"
for opt in CONFIG_USB_G_SERIAL CONFIG_TCPC_MT6370; do
	if ! grep -q "^$opt=y" "$ROOT/arch/arm64/configs/oppo6765_20375_defconfig" 2>/dev/null; then
		echo "$opt=y" >> "$ROOT/arch/arm64/configs/oppo6765_20375_defconfig"
		echo "   added $opt"
	fi
done
CONF="$ROOT/arch/arm64/configs/oppo6765_20375_defconfig"
if ! grep -q "^CONFIG_USB_G_SERIAL=y" "$CONF" 2>/dev/null; then
	echo "CONFIG_USB_G_SERIAL=y" >> "$CONF"
	echo "   added"
else
	echo "   already there"
fi

echo "== fixup complete"
