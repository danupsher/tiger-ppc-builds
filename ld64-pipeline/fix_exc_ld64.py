"""Post-process GCC 15 assembly for ld64 linking on Linux.

Handles TWO different eh_frame formats:
1. iMac cc1plus format: "zPLR" augmentation, 0x9b/0x10/0x10 encodings, direct pcrel FDEs
2. Linux cc1plus format: "zPL" augmentation, 0x0/0x0 encodings, indirect non_lazy_ptr FDEs

For ld64 compatibility, we need:
- Personality pointer as absptr (ld64 can relocate this)
- FDE initial locations as direct pcrel (no linker relocation needed)
- LSDA pointers as direct pcrel (no linker relocation needed)
- PIC stubs for external function calls
"""
import sys, re

def fix_assembly(lines):
    out = []
    fixes = 0
    in_cie = False
    in_fde = False
    past_personality = False

    # Collect local non_lazy_ptr names that reference local labels (FDE targets)
    # These are like lLFB5$non_lazy_ptr -> LFB5
    local_nlp = {}  # 'lLFB5$non_lazy_ptr' -> 'LFB5'
    lsda_nlp = {}   # 'LLLSDA7$non_lazy_ptr' -> 'LLSDA7'
    nlp_to_remove = set()

    for line in lines:
        s = line.strip()
        # Match local FDE non_lazy_ptr definitions: lLFB5$non_lazy_ptr:
        m = re.match(r'(l(?:LFB|LFE)\d+)\$non_lazy_ptr:', s)
        if m:
            local_nlp[m.group(1) + '$non_lazy_ptr'] = m.group(1)[1:]  # lLFB5 -> LFB5
            nlp_to_remove.add(m.group(1) + '$non_lazy_ptr')
        # Match LSDA non_lazy_ptr definitions: LLLSDA7$non_lazy_ptr:
        m = re.match(r'(L+LSDA\d+)\$non_lazy_ptr:', s)
        if m:
            # LLLSDA7$non_lazy_ptr -> LLSDA7 (strip one L prefix)
            target = m.group(1)[1:]  # strip leading L
            lsda_nlp[m.group(1) + '$non_lazy_ptr'] = target
            nlp_to_remove.add(m.group(1) + '$non_lazy_ptr')

    # Detect CIE format and collect external call targets in pre-pass
    ext_calls = set()
    local_defs = set()
    has_stub = set()
    cie_format = None
    for line in lines:
        s = line.strip()
        # Detect CIE format
        if '"zPLR' in s and '.ascii' in s:
            cie_format = 'zPLR'
        if '.ascii' in s and 'zPL' in s and 'zPLR' not in s:
            cie_format = 'zPL'
        # Collect external call targets for PIC stubs
        m = re.match(r'b[l]?\s+(_[\w$.]+)', s)
        if m and not s.startswith('.'):
            ext_calls.add(m.group(1))
        m2 = re.match(r'L(_[\w$.]+)\$stub:', s)
        if m2:
            has_stub.add(m2.group(1))
    need_stubs = ext_calls - has_stub

    had_lecie = False
    skip_nlp_block = False
    skip_until_align = False
    in_lsda = False
    lsda_byte_count = 0
    ttype_data_syms = []  # symbols needing .data typeref entries

    for i, line in enumerate(lines):
        s = line.strip()

        # Skip local non_lazy_ptr entries in .data/.non_lazy_symbol_pointer
        # Format: label$non_lazy_ptr: / .indirect_symbol ... / .long ... / .align ...
        if skip_nlp_block:
            if s.startswith('.align') or s.startswith('.long') or s.startswith('.indirect_symbol') or s == '':
                continue
            skip_nlp_block = False

        for nlp_name in nlp_to_remove:
            if nlp_name + ':' == s:
                skip_nlp_block = True
                fixes += 1
                break
        if skip_nlp_block:
            continue

        # Track CIE
        if re.match(r'LSCIE\d+:', s):
            in_cie = True
            in_fde = False
            past_personality = False

        if re.match(r'LECIE\d+:', s):
            in_cie = False

        if in_cie:
            # Handle "zPLR" format (iMac cc1plus)
            if cie_format == 'zPLR':
                # Change personality encoding 0x9b -> 0x0
                if not past_personality and '0x9b' in s and re.match(r'\s*\.byte\s+', s):
                    out.append(line.replace('0x9b', '0x0'))
                    past_personality = True
                    fixes += 1
                    continue
                # Change personality pointer from pcrel indirect to absolute
                if '$non_lazy_ptr-.' in s:
                    newline = re.sub(r'L(_\w+)\$non_lazy_ptr-\.', r'\1', line)
                    out.append(newline)
                    past_personality = True
                    fixes += 1
                    continue

            # Handle "zPL" format (Linux cross cc1plus)
            elif cie_format == 'zPL':
                # Personality pointer: P encoding=0x0 (absptr)
                # But pointer is pcrel indirect: L___gxx_personality_v0$non_lazy_ptr-.
                # Convert to direct absolute: ___gxx_personality_v0
                if '$non_lazy_ptr-.' in s and not past_personality:
                    newline = re.sub(r'L(_\w+)\$non_lazy_ptr-\.', r'\1', line)
                    out.append(newline)
                    past_personality = True
                    fixes += 1
                    continue
                # L encoding: already 0x0 (absptr) - but we want pcrel for LSDA
                # Add R encoding byte after L encoding to make it "zPLR"
                # The augmentation data length also needs updating (6 -> 7)

        # Track FDE
        if re.match(r'LSFDE\d+:', s) or re.match(r'L[A-Z]*SFDE\d+:', s):
            in_fde = True
            in_cie = False
        if re.match(r'LEFDE\d+:', s) or re.match(r'L[A-Z]*EFDE\d+:', s):
            in_fde = False

        if in_fde:
            # Convert FDE indirect non_lazy_ptr refs to direct pcrel
            # lLFB5$non_lazy_ptr-. -> LFB5-.
            for nlp_name, target in local_nlp.items():
                if nlp_name + '-.' in s:
                    newline = line.replace(nlp_name + '-.', target + '-.')
                    out.append(newline)
                    fixes += 1
                    break
            else:
                # Convert LSDA indirect non_lazy_ptr refs to direct pcrel
                for nlp_name, target in lsda_nlp.items():
                    if nlp_name + '-.' in s:
                        newline = line.replace(nlp_name + '-.', target + '-.')
                        out.append(newline)
                        fixes += 1
                        break
                else:
                    out.append(line)
                    continue
            continue

        # Add _main.eh global after CIE end
        if re.match(r'LECIE\d+:', s) and not had_lecie:
            had_lecie = True
            out.append(line)
            next_lines = ''.join(lines[i+1:i+3]) if i+1 < len(lines) else ''
            if '_main.eh' not in next_lines:
                out.append('\t.globl _main.eh\n')
                out.append('_main.eh:\n')
                fixes += 1
            continue

        # Strip any remaining corrupt .indirect_symbol entries
        if s.startswith('.indirect_symbol') and ('"_"' in s or s.endswith('"_"')):
            fixes += 1
            continue

        # Strip .weak_definition for typeinfo symbols (__ZTI*, __ZTS*)
        # ld64 doesn't resolve data references to coalesced/weak symbols
        if False:  # DISABLED: __ZTI must stay coalesced to avoid duplicate symbol errors
            fixes += 1
            continue

        # Fix LSDA TType for "zPL" format
        # Change TType encoding from absptr (0x0) to indirect pcrel (0x9b)
        # and TType entries from direct .long __ZTI* to .long L__ZTI*$non_lazy_ptr-.
        if cie_format == 'zPL':
            if re.match(r'LLSDA\d+:', s):
                in_lsda = True
                lsda_byte_count = 0
            if in_lsda and (s.startswith('.section') or s.startswith('.text')):
                in_lsda = False
            if in_lsda:
                if re.match(r'\s*\.byte\s+', s):
                    lsda_byte_count += 1
                    if lsda_byte_count == 2:
                        if re.match(r'\s*\.byte\s+(0x0+|0)\s*$', s):
                            out.append('\t.byte\t0x9b\n')
                            fixes += 1
                            continue
                m_tt = re.match(r'(\s*\.long\s+)(__Z\w+)\s*$', line.rstrip('\n'))
                if m_tt:
                    prefix = m_tt.group(1)
                    ttype_sym = m_tt.group(2)
                    # Use a .data typeref instead of non_lazy_ptr
                    # ld64 resolves .data relocations but not non_lazy_ptrs
                    # for coalesced symbols
                    typeref = 'L%s$typeref' % ttype_sym
                    out.append('%s%s-.\n' % (prefix, typeref))
                    if ttype_sym not in ttype_data_syms:
                        ttype_data_syms.append(ttype_sym)
                    fixes += 1
                    continue

        # Replace bl/b to external with stub call
        m = re.match(r'(\s*b[l]?\s+)(_[\w$.]+)\s*$', line.rstrip('\n'))
        if m and m.group(2) in need_stubs:
            out.append(m.group(1) + 'L' + m.group(2) + '$stub\n')
            fixes += 1
            continue

        out.append(line)

    # For "zPL" format, we need to fix the CIE augmentation
    # Change "zPL" to "zPLR" and add R encoding byte, update aug data length
    if cie_format == 'zPL':
        new_out = []
        in_cie_pass2 = False
        found_aug = False
        found_aug_len = False
        found_l_enc = False
        saw_personality_long = False
        for line in out:
            s = line.strip()
            if re.match(r'LSCIE\d+:', s):
                in_cie_pass2 = True
                found_aug = False
                found_aug_len = False
                found_l_enc = False
                saw_personality_long = False
            if re.match(r'LECIE\d+:', s):
                in_cie_pass2 = False

            if in_cie_pass2:
                # Change "zPL\0" to "zPLR\0"
                if '.ascii' in s and 'zPL' in s and 'zPLR' not in s:
                    new_out.append(line.replace('zPL\\0', 'zPLR\\0').replace('zPL\x00', 'zPLR\x00'))
                    found_aug = True
                    fixes += 1
                    continue
                # Update augmentation data length: 6 -> 7
                if found_aug and not found_aug_len:
                    m_aug = re.match(r'(\s*\.byte\s+)(0x6|6)\s*$', line.rstrip('\n'))
                    if m_aug:
                        val = '0x7' if '0x' in m_aug.group(2) else '7'
                        new_out.append(m_aug.group(1) + val + '\n')
                        found_aug_len = True
                        fixes += 1
                        continue
                # After aug data length, track: .long (personality) then .byte (L enc)
                if found_aug_len and not found_l_enc:
                    if '.long' in s:
                        saw_personality_long = True
                    elif saw_personality_long and '.byte' in s:
                        # This is the L encoding byte - change to 0x10 (pcrel)
                        # and add R encoding byte (0x10) after it
                        new_out.append('\t.byte\t0x10\n')  # L encoding = pcrel
                        new_out.append('\t.byte\t0x10\n')  # R encoding = pcrel
                        found_l_enc = True
                        fixes += 1
                        continue

            new_out.append(line)

        out = new_out

    # Add .data typeref entries for LSDA TType symbols
    # These are regular data relocations that ld64 resolves at link time
    # (unlike non_lazy_symbol_pointers which may not be resolved for coalesced syms)
    if ttype_data_syms:
        typeref_lines = ['\t.data\n', '\t.align\t2\n']
        for sym in ttype_data_syms:
            typeref_lines.append('L%s$typeref:\n' % sym)
            typeref_lines.append('\t.long\t%s\n' % sym)
            fixes += 1
        # Insert before .non_lazy_symbol_pointer or at end
        insert_idx = len(out)
        for j in range(len(out) - 1, -1, -1):
            if '.non_lazy_symbol_pointer' in out[j]:
                insert_idx = j
                break
        out[insert_idx:insert_idx] = typeref_lines

    # Add PIC stubs
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
