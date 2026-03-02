"""Post-process GCC 15 assembly for Tiger PPC exception handling.

Handles TWO different eh_frame formats:
1. "zPLR" format (GCC 7-compiled cc1plus): 0x9b/0x10/0x10 encodings, direct pcrel FDEs
2. "zPL" format (GCC 15-compiled cc1plus): 0x0/0x0 encodings, indirect non_lazy_ptr FDEs

For cctools ld on Tiger, we convert everything to absolute encoding:
- Personality pointer: absolute (direct symbol reference)
- FDE locations: absolute (no -. suffix)
- LSDA pointers: absolute (no -. suffix)
- TType entries: absolute (direct symbol reference)
- LSDA section moved to __DATA (cctools ld doesn't relocate absptr in __TEXT)
- PIC stubs for external function calls
"""
import sys, re

def fix_assembly(lines):
    out = []
    fixes = 0
    in_cie = False
    in_fde = False
    in_lsda = False
    past_personality = False
    cie_byte_count = 0
    lsda_byte_count = 0
    skip_next_long = False

    # === Pre-pass: detect CIE format ===
    cie_format = None
    for line in lines:
        s = line.strip()
        if '.ascii' in s:
            if '"zPLR' in s:
                cie_format = 'zPLR'
                break
            if 'zPL' in s and 'zPLR' not in s:
                cie_format = 'zPL'
                break

    # === Pre-pass: collect local non_lazy_ptr mappings (for "zPL" format) ===
    local_nlp = {}   # 'lLFB5$non_lazy_ptr' -> 'LFB5'
    lsda_nlp = {}    # 'LLLSDA7$non_lazy_ptr' -> 'LLSDA7'
    nlp_to_remove = set()

    if cie_format == 'zPL':
        for line in lines:
            s = line.strip()
            # FDE target non_lazy_ptrs: lLFB5$non_lazy_ptr: -> LFB5
            m = re.match(r'(l(?:LFB|LFE)\d+)\$non_lazy_ptr:', s)
            if m:
                local_nlp[m.group(1) + '$non_lazy_ptr'] = m.group(1)[1:]
                nlp_to_remove.add(m.group(1) + '$non_lazy_ptr')
            # LSDA non_lazy_ptrs: LLLSDA7$non_lazy_ptr: -> LLSDA7
            m = re.match(r'(L+LSDA\d+)\$non_lazy_ptr:', s)
            if m:
                lsda_nlp[m.group(1) + '$non_lazy_ptr'] = m.group(1)[1:]
                nlp_to_remove.add(m.group(1) + '$non_lazy_ptr')

    # === Pre-pass: collect external call targets for PIC stubs ===
    ext_calls = set()
    has_stub = set()
    local_defs = set()
    for line in lines:
        s = line.strip()
        # bl/b targets (include dots for .isra.0, .constprop.0 etc)
        m = re.match(r'b[l]?\s+(_[\w$.]+)', s)
        if m and not s.startswith('.'):
            ext_calls.add(m.group(1))
        m2 = re.match(r'L(_[\w$.]+)\$stub:', s)
        if m2:
            has_stub.add(m2.group(1))
        # Locally defined labels (function definitions)
        m3 = re.match(r'(_[\w$.]+):', s)
        if m3:
            local_defs.add(m3.group(1))
    need_stubs = ext_calls - has_stub - local_defs

    had_lecie = False
    skip_nlp_block = False

    for i, line in enumerate(lines):
        s = line.strip()

        # === Skip local non_lazy_ptr definition blocks (for "zPL" format) ===
        if skip_nlp_block:
            if s.startswith('.align') or s.startswith('.long') or \
               s.startswith('.indirect_symbol') or s == '':
                continue
            skip_nlp_block = False

        for nlp_name in nlp_to_remove:
            if nlp_name + ':' == s:
                skip_nlp_block = True
                fixes += 1
                break
        if skip_nlp_block:
            continue

        # === Fix LSDA section placement (__TEXT -> __DATA) ===
        if '__TEXT,__gcc_except_tab' in s:
            out.append(line.replace('__TEXT,__gcc_except_tab',
                                    '__DATA,__gcc_except_tab'))
            fixes += 1
            continue

        # === Track LSDA regions ===
        if re.match(r'LLSDA\d+:', s):
            in_lsda = True
            lsda_byte_count = 0
        if in_lsda and (s.startswith('.text') or
                        (s.startswith('.section') and 'gcc_except' not in s)):
            in_lsda = False

        # === LSDA fixes (only for "zPLR" format) ===
        if in_lsda and cie_format == 'zPLR':
            if re.match(r'\s*\.byte\s+', s):
                lsda_byte_count += 1
                # TType encoding: 0x9b -> 0x0
                if lsda_byte_count == 2 and '0x9b' in s:
                    out.append(line.replace('0x9b', '0x0'))
                    fixes += 1
                    continue
            # TType entries: indirect pcrel -> absolute
            if '$non_lazy_ptr-.' in s:
                newline = re.sub(r'L(_\w+)\$non_lazy_ptr-\.', r'\1', line)
                out.append(newline)
                fixes += 1
                continue

        # === Track CIE ===
        if re.match(r'LSCIE\d+:', s):
            in_cie = True
            in_fde = False
            past_personality = False
            cie_byte_count = 0
        if re.match(r'LECIE\d+:', s):
            in_cie = False

        # === Track FDE ===
        if re.match(r'LSFDE\d+:', s) or re.match(r'L[A-Z]*SFDE\d+:', s):
            in_fde = True
            in_cie = False
        if re.match(r'LEFDE\d+:', s) or re.match(r'L[A-Z]*EFDE\d+:', s):
            in_fde = False

        # === CIE fixes ===
        if in_cie:
            if cie_format == 'zPLR':
                # Personality encoding 0x9b -> 0x0 (absptr)
                if re.match(r'\s*\.byte\s+', s):
                    cie_byte_count += 1
                    if not past_personality and '0x9b' in s:
                        out.append(line.replace('0x9b', '0x0'))
                        past_personality = True
                        fixes += 1
                        continue
                    # L and R encodings: 0x10 -> 0x0 (absptr)
                    if past_personality and '0x10' in s:
                        out.append(line.replace('0x10', '0x0'))
                        fixes += 1
                        continue
                # Personality pointer: pcrel indirect -> absolute
                if '$non_lazy_ptr-.' in s:
                    newline = re.sub(r'L(_\w+)\$non_lazy_ptr-\.', r'\1', line)
                    out.append(newline)
                    past_personality = True
                    fixes += 1
                    continue

            elif cie_format == 'zPL':
                # Personality encoding already 0x0, L encoding already 0x0
                # Just convert personality pointer to absolute
                if '$non_lazy_ptr-.' in s and not past_personality:
                    newline = re.sub(r'L(_\w+)\$non_lazy_ptr-\.', r'\1', line)
                    out.append(newline)
                    past_personality = True
                    fixes += 1
                    continue

        # === FDE fixes ===
        if in_fde:
            if cie_format == 'zPLR':
                # Remove -. to make references absolute
                if '-.' in s:
                    newline = line.replace('-.', '')
                    if newline != line:
                        out.append(newline)
                        fixes += 1
                        continue

            elif cie_format == 'zPL':
                # Convert indirect non_lazy_ptr refs to direct absolute
                converted = False
                for nlp_name, target in local_nlp.items():
                    if nlp_name + '-.' in s:
                        out.append(line.replace(nlp_name + '-.', target))
                        fixes += 1
                        converted = True
                        break
                if not converted:
                    for nlp_name, target in lsda_nlp.items():
                        if nlp_name + '-.' in s:
                            out.append(line.replace(nlp_name + '-.', target))
                            fixes += 1
                            converted = True
                            break
                if converted:
                    continue
                # Other -. references: just remove -.
                if '-.' in s:
                    newline = line.replace('-.', '')
                    if newline != line:
                        out.append(newline)
                        fixes += 1
                        continue

        # === Add _main.eh global after CIE end ===
        if re.match(r'LECIE\d+:', s) and not had_lecie:
            had_lecie = True
            out.append(line)
            next_lines = ''.join(lines[i+1:i+3]) if i+1 < len(lines) else ''
            if '_main.eh' not in next_lines:
                out.append('\t.globl _main.eh\n')
                out.append('_main.eh:\n')
                fixes += 1
            continue

        # === Strip corrupt .indirect_symbol entries ===
        if s.startswith('.indirect_symbol') and ('"_"' in s or s.endswith('"_"')):
            fixes += 1
            if out and out[-1].strip().endswith('$non_lazy_ptr:'):
                out.pop()
            skip_next_long = True
            continue
        if skip_next_long and s.startswith('.long'):
            skip_next_long = False
            continue
        skip_next_long = False

        # === Replace bl/b to external with stub call ===
        m = re.match(r'(\s*b[l]?\s+)(_[\w$.]+)\s*$', line.rstrip('\n'))
        if m and m.group(2) in need_stubs:
            out.append(m.group(1) + 'L' + m.group(2) + '$stub\n')
            fixes += 1
            continue

        out.append(line)

    # === Add PIC stubs ===
    if need_stubs:
        insert_idx = len(out)
        for j in range(len(out) - 1, -1, -1):
            if '.non_lazy_symbol_pointer' in out[j]:
                insert_idx = j
                break

        stub_lines = []
        for target in sorted(need_stubs):
            stub_lines.append('\t.section __TEXT,__picsymbolstub1,symbol_stubs,pure_instructions,32\n')
            stub_lines.append('\t.align 5\n')
            stub_lines.append('L%s$stub:\n' % target)
            stub_lines.append('\t.indirect_symbol %s\n' % target)
            stub_lines.append('\tmflr r0\n')
            stub_lines.append('\tbcl 20,31,L%s$spb\n' % target)
            stub_lines.append('L%s$spb:\n' % target)
            stub_lines.append('\tmflr r11\n')
            stub_lines.append('\taddis r11,r11,ha16(L%s$lazy_ptr-L%s$spb)\n' % (target, target))
            stub_lines.append('\tmtlr r0\n')
            stub_lines.append('\tlwzu r12,lo16(L%s$lazy_ptr-L%s$spb)(r11)\n' % (target, target))
            stub_lines.append('\tmtctr r12\n')
            stub_lines.append('\tbctr\n')
            stub_lines.append('\t.lazy_symbol_pointer\n')
            stub_lines.append('L%s$lazy_ptr:\n' % target)
            stub_lines.append('\t.indirect_symbol %s\n' % target)
            stub_lines.append('\t.long\tdyld_stub_binding_helper\n')
            fixes += 1

        out[insert_idx:insert_idx] = stub_lines

    return out, fixes

if __name__ == '__main__':
    with open(sys.argv[1], 'rb') as f:
        data = f.read()

    # Remove trailing garbage (.set with null bytes)
    idx = data.find(b'\t.set\t\x00\x00')
    if idx > 0:
        data = data[:idx]
    if not data.endswith(b'\n'):
        data += b'\n'

    lines = data.decode('utf-8', errors='replace').split('\n')
    # Strip lines with non-ASCII garbage (cc1plus memory corruption artifacts)
    lines = [l + '\n' for l in lines if l and '\ufffd' not in l]

    out, fixes = fix_assembly(lines)

    with open(sys.argv[2], 'w') as f:
        f.writelines(out)
    sys.stdout.write('Applied %d fixes\n' % fixes)
