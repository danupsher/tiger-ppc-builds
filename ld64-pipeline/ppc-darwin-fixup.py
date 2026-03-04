#!/usr/bin/env python3
"""
Post-process GCC 7 PPC assembly for Darwin/Tiger compatibility.

Five fixes:
1. Move weak definitions into coalesced sections (required by Tiger's ld).
2. Generate non-PIC symbol stubs for external function calls. FSF GCC 7 emits
   bare 'bl _func' but Tiger's ld requires calls to go through stubs.
3. Strip .subsections_via_symbols to prevent linker code reordering that causes
   branch displacement overflow in the large cc1plus binary.
4. Merge __text_cold into .text to prevent cross-section branch overflow.
   Tiger's old linker can't generate branch trampolines, so all code must stay
   in one text section to keep local branches within displacement limits.
5. Generate absolute-addressed trampolines for cross-section branches between
   .text and __textcoal_nt. Tiger's ld can't create branch trampolines, so
   branches between these sections overflow in large binaries like cc1/cc1plus.

Stubs/trampolines are placed inline at function boundaries (blr) AND before
section switches, keeping them close to call sites.
Each stub region gets its own copy of needed stubs.
"""
import sys
import re

COAL_TEXT = '\t.section __TEXT,__textcoal_nt,coalesced,pure_instructions\n\t.align 2\n'
COAL_DATA = '\t.section __DATA,__datacoal_nt,coalesced\n'
NL_PTR_SECTION = '\t.non_lazy_symbol_pointer\n'


def get_section_type(sec):
    """Classify a section as 'text' or 'data'."""
    s = sec.strip()
    if s in ('.text', '\t.text') or 'pure_instructions' in s:
        return 'text'
    return 'data'


def _section_kind(sec_str):
    """Return 'text', 'coal_text', 'coal_data', or 'other'."""
    s = sec_str.strip()
    if 'textcoal_nt' in s or 'coalesced' in s and 'pure_instructions' in s:
        return 'coal_text'
    if 'datacoal_nt' in s or 'coalesced' in s:
        return 'coal_data'
    if s in ('.text', '\t.text') or (s.startswith('.section') and 'pure_instructions' in s
                                      and 'coal' not in s):
        return 'text'
    return 'other'


def _is_text_cold(stripped):
    """Check if a section directive is __text_cold."""
    return 'text_cold' in stripped and ('.section' in stripped or '\t.section' in stripped)


def _is_section_directive(stripped):
    """Check if a line is a section-switching directive."""
    base = stripped.lstrip('\t')
    if base in ('.text', '.data', '.const', '.const_data',
                '.non_lazy_symbol_pointer', '.cstring',
                '.literal4', '.literal8', '.static_data'):
        return True
    if base.startswith('.section ') or base.startswith('.section\t'):
        return True
    # ObjC 1.0 section directives (each switches to a specific __OBJC section)
    if base.startswith('.objc_') and '=' not in stripped and not base.startswith('.objc_class_name'):
        return True
    return False


def process_asm(input_file, output_file):
    with open(input_file, 'r') as f:
        lines = f.readlines()

    # --- Pass 1: Collect defined labels and weak symbols ---
    defined_labels = set()
    weak_symbols = set()
    for line in lines:
        stripped = line.strip()
        m = re.match(r'^(_\w+):', stripped)
        if m:
            defined_labels.add(m.group(1))
        m = re.match(r'\s*\.weak_definition\s+(_\w+)', stripped)
        if m:
            weak_symbols.add(m.group(1))

    # --- Pass 1.5: Determine output section for each label ---
    # Weak symbols go to coal_text/coal_data; non-weak stay in their section.
    # __text_cold is merged into .text.
    label_output_kind = {}  # label -> 'text', 'coal_text', etc.
    cur_sec = '.text'
    for line in lines:
        stripped = line.strip()
        if _is_section_directive(stripped):
            if _is_text_cold(stripped):
                cur_sec = '.text'
            else:
                base = stripped.lstrip('\t')
                if base.startswith('.section ') or base.startswith('.section\t'):
                    cur_sec = stripped
                elif base == '.text':
                    cur_sec = '.text'
                elif base == '.data':
                    cur_sec = '.data'
                elif base == '.const':
                    cur_sec = '.const'
                elif base == '.const_data':
                    cur_sec = '.const_data'
                elif base == '.static_data':
                    cur_sec = '.static_data'
        m = re.match(r'^(_\w+):', stripped)
        if m:
            sym = m.group(1)
            if sym in weak_symbols:
                if get_section_type(cur_sec) == 'text':
                    label_output_kind[sym] = 'coal_text'
                else:
                    label_output_kind[sym] = 'coal_data'
            else:
                label_output_kind[sym] = _section_kind(cur_sec)

    # --- Pass 2: Find calls that need stubs/trampolines ---
    external_calls = set()      # Undefined symbols -> pointer-based stubs
    xsection_calls = set()      # Defined symbols needing cross-section trampolines
    # Match symbols with $ (e.g., _mmap$UNIX2003 from __DARWIN_UNIX03)
    branch_pattern = re.compile(r'^\s+b(?:l)?\s+(_[\w$]+)\s*$')

    # We need to know the caller's section to detect cross-section branches.
    # Do a pre-scan tracking sections and branches.
    cur_sec = '.text'
    for line in lines:
        stripped = line.strip()
        if _is_section_directive(stripped):
            if _is_text_cold(stripped):
                cur_sec = '.text'
            else:
                base = stripped.lstrip('\t')
                if base.startswith('.section ') or base.startswith('.section\t'):
                    cur_sec = stripped
                elif base == '.text':
                    cur_sec = '.text'
                elif base == '.data':
                    cur_sec = '.data'
                elif base == '.const':
                    cur_sec = '.const'
                elif base == '.const_data':
                    cur_sec = '.const_data'
                elif base == '.static_data':
                    cur_sec = '.static_data'
        # Track entering weak regions (these go to coal_text/coal_data)
        label_m = re.match(r'^(_\w+):', stripped)
        if label_m and label_m.group(1) in weak_symbols:
            if get_section_type(cur_sec) == 'text':
                caller_kind = 'coal_text'
            else:
                caller_kind = 'coal_data'
        else:
            caller_kind = _section_kind(cur_sec)

        m = branch_pattern.match(line)
        if m:
            sym = m.group(1)
            if sym not in defined_labels:
                external_calls.add(sym)
            else:
                # Check if cross-section branch
                target_kind = label_output_kind.get(sym, caller_kind)
                if target_kind != caller_kind:
                    # Cross-section: text <-> coal_text needs trampoline
                    if set([target_kind, caller_kind]) <= {'text', 'coal_text'}:
                        xsection_calls.add(sym)

    # All symbols that need stubs (for branch rewriting in Pass 3)
    all_stubbed = external_calls | xsection_calls

    # --- Pass 3: Rewrite assembly ---
    output_lines = []
    in_weak_region = False
    saved_section = '\t.text\n'
    current_section = '\t.text\n'
    in_text_section = True
    current_kind = 'text'

    stub_region = 0
    pending_ext_stubs = set()    # External symbols pending
    pending_x_stubs = set()      # Cross-section symbols pending
    cold_merged = 0
    emitted_labels = {}          # label -> section_kind when first emitted
    skip_until_label = False     # Skip duplicate label's associated code

    def flush_stubs():
        """Emit any pending stubs in the current section."""
        nonlocal stub_region, pending_ext_stubs, pending_x_stubs
        if not pending_ext_stubs and not pending_x_stubs:
            return
        _emit_inline_stubs(output_lines, pending_ext_stubs, pending_x_stubs,
                           stub_region)
        stub_region += 1
        pending_ext_stubs = set()
        pending_x_stubs = set()

    def update_section(stripped, line):
        """Update current section tracking from a section directive."""
        nonlocal current_section, in_text_section, current_kind
        base = stripped.lstrip('\t')
        if base == '.text':
            current_section = '\t.text\n'
            in_text_section = True
            current_kind = 'text'
        elif base == '.data':
            current_section = '\t.data\n'
            in_text_section = False
            current_kind = 'other'
        elif base == '.const':
            current_section = '\t.const\n'
            in_text_section = False
            current_kind = 'other'
        elif base == '.const_data':
            current_section = '\t.const_data\n'
            in_text_section = False
            current_kind = 'other'
        elif base == '.static_data':
            current_section = '\t.static_data\n'
            in_text_section = False
            current_kind = 'other'
        elif base.startswith('.section ') or base.startswith('.section\t'):
            current_section = line
            in_text_section = 'pure_instructions' in stripped
            current_kind = _section_kind(stripped)
        else:
            current_section = line
            in_text_section = False
            current_kind = 'other'

    for line in lines:
        stripped = line.strip()

        # --- Strip .subsections_via_symbols ---
        if '.subsections_via_symbols' in stripped:
            continue

        # --- Deduplicate GCC-generated $stub labels (unified build dupes) ---
        # Match local labels like L_sym$stub: or "L_sym$spb":
        # GCC 7 can emit the same $stub label in both .data (as a vtable
        # pointer) and __picsymbolstub1 (as executable code).  The bl
        # instruction needs the code version.  If a duplicate appears in a
        # code section while the first was in data, rename the data version
        # so the assembler sees no conflict and the bl resolves to code.
        local_label_m = re.match(r'^(L[\w.$"]+):', stripped)
        if local_label_m:
            llabel = local_label_m.group(1)
            if llabel in emitted_labels:
                prev_kind = emitted_labels[llabel]
                if prev_kind == current_kind:
                    # Same section kind → true duplicate, skip it.
                    skip_until_label = True
                    continue
                if prev_kind != 'text' and (current_kind == 'text' or
                        current_kind == 'coal_text'):
                    # Previous was data, current is code.  Rename the
                    # data-section label so the assembler doesn't see a
                    # duplicate and bl resolves to this code version.
                    renamed = llabel + '$dat'
                    for idx in range(len(output_lines) - 1, -1, -1):
                        if output_lines[idx].startswith(llabel + ':'):
                            output_lines[idx] = renamed + ':\n'
                            break
                    # Let this (code) label emit normally below.
                else:
                    # Previous was code, current is data.  Skip the
                    # data duplicate — bl already resolved to code.
                    skip_until_label = True
                    continue
            emitted_labels[llabel] = current_kind
            skip_until_label = False
        elif skip_until_label:
            # A section directive or global label ends the skip
            if _is_section_directive(stripped) or re.match(r'^[_L][\w.$"]*:', stripped):
                skip_until_label = False
            else:
                continue

        # --- Merge __text_cold into .text ---
        if _is_text_cold(stripped):
            cold_merged += 1
            flush_stubs()
            output_lines.append('\t.text\n')
            current_section = '\t.text\n'
            in_text_section = True
            current_kind = 'text'
            continue

        # --- Detect section switches and weak entries ---
        is_sec_dir = _is_section_directive(stripped)
        is_label = re.match(r'^(_\w+):', stripped)
        entering_weak = bool(is_label and is_label.group(1) in weak_symbols)

        # --- Flush stubs before any section change ---
        if is_sec_dir or entering_weak:
            flush_stubs()

        # Update section tracking
        if is_sec_dir:
            update_section(stripped, line)

        # --- Weak symbol coalesced section handling ---
        if entering_weak:
            sym = is_label.group(1)
            sec_str = label_output_kind.get(sym, 'coal_text')
            if not in_weak_region:
                saved_section = current_section
            if sec_str == 'coal_text':
                output_lines.append(COAL_TEXT)
                current_section = COAL_TEXT
                in_text_section = True
                current_kind = 'coal_text'
            else:
                output_lines.append(COAL_DATA)
                current_section = COAL_DATA
                in_text_section = False
                current_kind = 'coal_data'
            in_weak_region = True
            output_lines.append(line)
            continue

        if in_weak_region:
            is_new_globl = re.match(r'\s*\.globl\s+(_\w+)', stripped)
            new_label = re.match(r'^(_\w+):', stripped)
            exit_weak = False
            if is_new_globl:
                sym = is_new_globl.group(1)
                if sym not in weak_symbols:
                    exit_weak = True
            elif new_label:
                sym = new_label.group(1)
                if sym not in weak_symbols:
                    exit_weak = True
            elif is_sec_dir and 'coal' not in stripped:
                exit_weak = True

            if exit_weak:
                flush_stubs()
                in_weak_region = False
                if is_sec_dir:
                    # Exit triggered by an explicit section directive — use it
                    # for tracking instead of saved_section. The directive itself
                    # will be emitted at line output_lines.append(line) below.
                    update_section(stripped, line)
                else:
                    output_lines.append(saved_section)
                    current_section = saved_section
                    in_text_section = get_section_type(saved_section) == 'text'
                    current_kind = _section_kind(saved_section.strip())

        # At function boundaries (blr), emit stubs
        if stripped == 'blr' and (pending_ext_stubs or pending_x_stubs):
            output_lines.append(line)
            flush_stubs()
            continue

        # --- Rewrite branches to use stubs/trampolines ---
        m = branch_pattern.match(line)
        if m and m.group(1) in all_stubbed:
            sym = m.group(1)
            stub_label = 'L{}$stub_{}'.format(sym, stub_region)
            instr = line.split()[0]  # 'bl' or 'b'
            output_lines.append('\t{} {}\n'.format(instr, stub_label))
            if sym in external_calls:
                pending_ext_stubs.add(sym)
            else:
                pending_x_stubs.add(sym)
            continue

        output_lines.append(line)

    # Emit any remaining pending stubs at the end
    if pending_ext_stubs or pending_x_stubs:
        if not in_text_section:
            output_lines.append('\t.text\n')
        _emit_inline_stubs(output_lines, pending_ext_stubs, pending_x_stubs,
                           stub_region)

    # --- Append non-lazy symbol pointers for external symbols ---
    if external_calls:
        output_lines.append(NL_PTR_SECTION)
        for sym in sorted(external_calls):
            lazy_ptr = 'L{}$lazy_ptr'.format(sym)
            output_lines.append('{}:\n'.format(lazy_ptr))
            output_lines.append('\t.indirect_symbol {}\n'.format(sym))
            output_lines.append('\t.long\t0\n')

    with open(output_file, 'w') as f:
        f.writelines(output_lines)

    stats = []
    if weak_symbols:
        stats.append('{} weak->coalesced'.format(len(weak_symbols)))
    n_stubs = len(external_calls) + len(xsection_calls)
    if n_stubs:
        stats.append('{} stubs ({} regions)'.format(
            n_stubs, stub_region + (1 if not (pending_ext_stubs or pending_x_stubs) else 0)))
    if xsection_calls:
        stats.append('{} xsection'.format(len(xsection_calls)))
    if cold_merged:
        stats.append('{} text_cold->text'.format(cold_merged))
    if stats:
        print('ppc-darwin-fixup: {}'.format(', '.join(stats)), file=sys.stderr)


def _emit_inline_stubs(output_lines, ext_stubs, x_stubs, region):
    """Emit stubs inline for a specific region.

    ext_stubs: external symbols using pointer-based stubs (lis/lwz).
    x_stubs: cross-section internal symbols using direct addr stubs (lis/addi).
    """
    all_stubs = ext_stubs | x_stubs
    if not all_stubs:
        return

    skip_label = 'L_stub_skip_{}'.format(region)
    output_lines.append('\tb {}\n'.format(skip_label))

    for sym in sorted(all_stubs):
        stub_label = 'L{}$stub_{}'.format(sym, region)
        output_lines.append('\t.align 2\n')
        output_lines.append('{}:\n'.format(stub_label))

        if sym in ext_stubs:
            # External: load address through non_lazy_symbol_pointer
            lazy_ptr = 'L{}$lazy_ptr'.format(sym)
            output_lines.append('\tlis r11,ha16({})\n'.format(lazy_ptr))
            output_lines.append('\tlwz r12,lo16({})(r11)\n'.format(lazy_ptr))
        else:
            # Cross-section internal: direct absolute address
            output_lines.append('\tlis r12,ha16({})\n'.format(sym))
            output_lines.append('\tla r12,lo16({})(r12)\n'.format(sym))

        output_lines.append('\tmtctr r12\n')
        output_lines.append('\tbctr\n')

    output_lines.append('{}:\n'.format(skip_label))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: {} input.s output.s'.format(sys.argv[0]), file=sys.stderr)
        sys.exit(1)
    process_asm(sys.argv[1], sys.argv[2])
