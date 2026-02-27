"""Post-process GCC 15 assembly for Tiger PPC exception handling.

Fixes:
1. eh_frame CIE: personality encoding 0x9b -> 0x0 (absptr)
2. eh_frame CIE: personality ptr from pcrel indirect to absolute
3. eh_frame CIE: LSDA encoding 0x10 -> 0x0 (absptr)
4. eh_frame CIE: FDE encoding 0x10 -> 0x0 (absptr)
5. eh_frame FDE: pcrel pointers (remove -.)
6. LSDA: TType encoding 0x9b -> 0x0
7. LSDA: type table entries from pcrel indirect to absolute
8. LSDA: section __TEXT -> __DATA
9. Add PIC stubs for external function calls
10. Add _main.eh global if missing
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
    
    # Collect external bl targets for stub generation
    ext_calls = set()
    has_stub = set()
    
    # First pass: find all bl targets and existing stubs
    for line in lines:
        s = line.strip()
        m = re.match(r'bl\s+(_[\w$]+)', s)
        if m and not s.startswith('.'):
            target = m.group(1)
            ext_calls.add(target)
        if '$stub:' in s:
            # Extract stub target name
            m2 = re.match(r'L(_[\w$]+)\$stub:', s)
            if m2:
                has_stub.add(m2.group(1))
    
    # Determine which calls need stubs (external functions from dylibs)
    # All calls that aren't to local labels need stubs
    # But calls to functions from static libs don't need stubs at link time
    # We'll add stubs for ALL external calls to be safe
    need_stubs = ext_calls - has_stub
    
    had_lecie = False
    
    for i, line in enumerate(lines):
        s = line.strip()
        
        # Fix LSDA section placement
        if '__TEXT,__gcc_except_tab' in s:
            out.append(line.replace('__TEXT,__gcc_except_tab', '__DATA,__gcc_except_tab'))
            fixes += 1
            continue
        
        # Track LSDA regions
        if re.match(r'LLSDA\d+:', s):
            in_lsda = True
            lsda_byte_count = 0
        if in_lsda and (s.startswith('.text') or 
                         (s.startswith('.section') and 'gcc_except' not in s)):
            in_lsda = False
        
        if in_lsda:
            if re.match(r'\s*\.byte\s+', s):
                lsda_byte_count += 1
                if lsda_byte_count == 2 and '0x9b' in s:
                    out.append(line.replace('0x9b', '0x0'))
                    fixes += 1
                    continue
            if '$non_lazy_ptr-.' in s:
                newline = re.sub(r'L(_\w+)\$non_lazy_ptr-\.', r'\1', line)
                out.append(newline)
                fixes += 1
                continue
        
        # Track eh_frame CIE
        if re.match(r'LSCIE\d+:', s):
            in_cie = True
            in_fde = False
            past_personality = False
            cie_byte_count = 0
        if re.match(r'LECIE\d+:', s):
            in_cie = False
        
        # Track FDE
        if re.match(r'LSFDE\d+:', s) or re.match(r'L[A-Z]*SFDE\d+:', s):
            in_fde = True
            in_cie = False
        if re.match(r'LEFDE\d+:', s) or re.match(r'L[A-Z]*EFDE\d+:', s):
            in_fde = False
        
        if in_cie:
            if re.match(r'\s*\.byte\s+', s):
                cie_byte_count += 1
                # After augmentation string "zPLR\0" (5 bytes), code_align, data_align, 
                # return_reg, aug_data_len, the next byte is personality encoding
                if not past_personality and '0x9b' in s:
                    out.append(line.replace('0x9b', '0x0'))
                    past_personality = True
                    fixes += 1
                    continue
                # After personality, LSDA encoding and FDE encoding
                if past_personality and '0x10' in s:
                    out.append(line.replace('0x10', '0x0'))
                    fixes += 1
                    continue
            # Fix personality pointer: pcrel indirect -> absolute
            if in_cie and '$non_lazy_ptr-.' in s:
                newline = re.sub(r'L(_\w+)\$non_lazy_ptr-\.', r'\1', line)
                out.append(newline)
                past_personality = True
                fixes += 1
                continue
        
        if in_fde:
            # Fix FDE pcrel pointers (remove -.)
            if re.match(r'\s*\.long\s+\w+-\.', s) or '-.' in s:
                if '-.':
                    newline = line.replace('-.', '')
                    if newline != line:
                        out.append(newline)
                        fixes += 1
                        continue
        
        # Add _main.eh global after CIE end
        if re.match(r'LECIE\d+:', s) and not had_lecie:
            had_lecie = True
            out.append(line)
            # Check if next line already has .globl _main.eh
            if i+1 < len(lines):
                next_lines = ''.join(lines[i+1:i+3])
            else:
                next_lines = ''
            if '_main.eh' not in next_lines:
                out.append('\t.globl _main.eh\n')
                out.append('_main.eh:\n')
                fixes += 1
            continue
        
        # Replace direct bl to external with stub call
        m = re.match(r'(\s*bl\s+)(_[\w$]+)\s*$', line.rstrip('\n'))
        if m and m.group(2) in need_stubs:
            out.append(m.group(1) + 'L' + m.group(2) + '$stub\n')
            fixes += 1
            continue
        
        out.append(line)
    
    # Add PIC stubs at the end (before non_lazy_symbol_pointer if present)
    if need_stubs:
        # Find insertion point (before .non_lazy_symbol_pointer)
        insert_idx = len(out)
        for j in range(len(out) - 1, -1, -1):
            if '.non_lazy_symbol_pointer' in out[j]:
                insert_idx = j
                break
        
        stub_lines = []
        for target in sorted(need_stubs):
            safe_name = target.replace('$', '_')
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
    
    # Remove trailing garbage
    idx = data.find(b'\t.set\t\x00\x00')
    if idx > 0:
        data = data[:idx]
    if not data.endswith(b'\n'):
        data += b'\n'
    
    lines = data.decode('utf-8', errors='replace').split('\n')
    lines = [l + '\n' for l in lines if l]
    
    out, fixes = fix_assembly(lines)
    
    with open(sys.argv[2], 'w') as f:
        f.writelines(out)
    sys.stdout.write("Applied %d fixes\n" % fixes)
