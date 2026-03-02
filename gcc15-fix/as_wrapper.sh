#!/bin/sh
# GCC 15 assembler wrapper for Tiger
# 1. Strips corrupted tail bytes from cc1 output
# 2. Fixes exception handling (eh_frame, LSDA, PIC stubs)
REAL_AS=/usr/bin/as
FIX_EXC=/usr/local/lib/gcc/powerpc-apple-darwin8/15.2.0/fix_exc.py

# Find the last argument (the .s input file)
last=""
for arg in "$@"; do
    last="$arg"
done

# If last arg is a .s file, clean and fix it
case "$last" in
    *.s)
        if [ -f "$last" ]; then
            cleaned="/tmp/as_clean_$$.s"
            fixed="/tmp/as_fixed_$$.s"
            # Step 1: Strip corrupted tail bytes
            tr -d '\000' < "$last" | sed -e '/\.set.*%qd/d' -e '/ms_str/d' -e 's/^flags:.*/.text/' > "$cleaned"
            # Step 2: Apply PIC stub + exception handling fixes
            if [ -f "$FIX_EXC" ]; then
                /usr/local/bin/python3 "$FIX_EXC" "$cleaned" "$fixed" 2>/dev/null
                if [ $? -eq 0 ] && [ -f "$fixed" ]; then
                    mv "$fixed" "$cleaned"
                fi
            fi
            # Get all args except the last, then add cleaned file
            count=$#
            i=1
            all_but_last=""
            while [ $i -lt $count ]; do
                all_but_last="$all_but_last $1"
                shift
                i=`expr $i + 1`
            done
            $REAL_AS $all_but_last "$cleaned"
            ret=$?
            rm -f "$cleaned" "$fixed"
            exit $ret
        fi
        ;;
esac

exec $REAL_AS "$@"
