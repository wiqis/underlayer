#!/usr/bin/env python3
"""Independent DWARF 5 decoder, written from the specification.

Exists so that the DWARF course's claims can be checked against something
other than readelf. Its output is compared field by field against both
`readelf --debug-dump` and `llvm-dwarfdump` by crosscheck.py.

Handles what the course teaches and no more: .debug_abbrev, the .debug_info
DIE tree, .debug_loclists, .debug_aranges, .debug_pubnames, and the .eh_frame
CFI program. Anything it cannot decode raises rather than guessing.

    python3 dwarf_decode.py <file.o> [--section NAME] [--dwo] [--limit N]
"""
import struct
import sys

import dwarf_sections as ds

# ---------------------------------------------------------------- constants

# Numeric values are the DWARF 5 standard's. They are NOT memorable and a
# first pass written from memory gets several of them wrong -- the mistake is
# silent, because the decoder still walks the whole tree and still finds every
# DIE, it just mislabels them. crosscheck.py compares the names this table
# produces against readelf's, so a wrong constant is caught rather than taught.
TAG = {
    0x01: 'DW_TAG_array_type', 0x02: 'DW_TAG_class_type',
    0x03: 'DW_TAG_entry_point', 0x04: 'DW_TAG_enumeration_type',
    0x05: 'DW_TAG_formal_parameter', 0x08: 'DW_TAG_imported_declaration',
    0x0a: 'DW_TAG_label', 0x0b: 'DW_TAG_lexical_block',
    0x0d: 'DW_TAG_member', 0x0f: 'DW_TAG_pointer_type',
    0x10: 'DW_TAG_reference_type', 0x11: 'DW_TAG_compile_unit',
    0x12: 'DW_TAG_string_type', 0x13: 'DW_TAG_structure_type',
    0x15: 'DW_TAG_subroutine_type', 0x16: 'DW_TAG_typedef',
    0x17: 'DW_TAG_union_type', 0x18: 'DW_TAG_unspecified_parameters',
    0x19: 'DW_TAG_variant', 0x1a: 'DW_TAG_common_block',
    0x1b: 'DW_TAG_common_inclusion', 0x1c: 'DW_TAG_inheritance',
    0x1d: 'DW_TAG_inlined_subroutine', 0x1e: 'DW_TAG_module',
    0x1f: 'DW_TAG_ptr_to_member_type', 0x20: 'DW_TAG_set_type',
    0x21: 'DW_TAG_subrange_type', 0x22: 'DW_TAG_with_stmt',
    0x23: 'DW_TAG_access_declaration', 0x24: 'DW_TAG_base_type',
    0x25: 'DW_TAG_catch_block', 0x26: 'DW_TAG_const_type',
    0x27: 'DW_TAG_constant', 0x28: 'DW_TAG_enumerator',
    0x29: 'DW_TAG_file_type', 0x2a: 'DW_TAG_friend',
    0x2b: 'DW_TAG_namelist', 0x2c: 'DW_TAG_namelist_item',
    0x2d: 'DW_TAG_packed_type', 0x2e: 'DW_TAG_subprogram',
    0x2f: 'DW_TAG_template_type_parameter',
    0x30: 'DW_TAG_template_value_parameter', 0x31: 'DW_TAG_thrown_type',
    0x32: 'DW_TAG_try_block', 0x33: 'DW_TAG_variant_part',
    0x34: 'DW_TAG_variable', 0x35: 'DW_TAG_volatile_type',
    0x36: 'DW_TAG_dwarf_procedure', 0x37: 'DW_TAG_restrict_type',
    0x38: 'DW_TAG_interface_type', 0x39: 'DW_TAG_namespace',
    0x3a: 'DW_TAG_imported_module', 0x3b: 'DW_TAG_unspecified_type',
    0x3c: 'DW_TAG_partial_unit', 0x3d: 'DW_TAG_imported_unit',
    0x3f: 'DW_TAG_condition', 0x40: 'DW_TAG_shared_type',
    0x41: 'DW_TAG_type_unit', 0x42: 'DW_TAG_rvalue_reference_type',
    0x43: 'DW_TAG_template_alias', 0x44: 'DW_TAG_coarray_type',
    0x45: 'DW_TAG_generic_subrange', 0x46: 'DW_TAG_dynamic_type',
    0x47: 'DW_TAG_atomic_type', 0x48: 'DW_TAG_call_site',
    0x49: 'DW_TAG_call_site_parameter', 0x4a: 'DW_TAG_skeleton_unit',
    0x4b: 'DW_TAG_immutable_type',
}

AT = {
    0x01: 'DW_AT_sibling', 0x02: 'DW_AT_location', 0x03: 'DW_AT_name',
    0x09: 'DW_AT_ordering', 0x0a: 'DW_AT_subscr_data',
    0x0b: 'DW_AT_byte_size', 0x0c: 'DW_AT_bit_offset',
    0x0d: 'DW_AT_bit_size', 0x0f: 'DW_AT_element_list',
    0x10: 'DW_AT_stmt_list', 0x11: 'DW_AT_low_pc', 0x12: 'DW_AT_high_pc',
    0x13: 'DW_AT_language', 0x14: 'DW_AT_member', 0x15: 'DW_AT_discr',
    0x16: 'DW_AT_discr_value', 0x17: 'DW_AT_visibility', 0x18: 'DW_AT_import',
    0x19: 'DW_AT_string_length', 0x1a: 'DW_AT_common_reference',
    0x1b: 'DW_AT_comp_dir', 0x1c: 'DW_AT_const_value',
    0x1d: 'DW_AT_containing_type', 0x1e: 'DW_AT_default_value',
    0x20: 'DW_AT_inline', 0x21: 'DW_AT_is_optional', 0x22: 'DW_AT_lower_bound',
    0x25: 'DW_AT_producer', 0x27: 'DW_AT_prototyped',
    0x2a: 'DW_AT_return_addr', 0x2c: 'DW_AT_start_scope',
    0x2e: 'DW_AT_bit_stride', 0x2f: 'DW_AT_upper_bound',
    0x31: 'DW_AT_abstract_origin', 0x32: 'DW_AT_accessibility',
    0x33: 'DW_AT_address_class', 0x34: 'DW_AT_artificial',
    0x35: 'DW_AT_base_types', 0x36: 'DW_AT_calling_convention',
    0x37: 'DW_AT_count', 0x38: 'DW_AT_data_member_location',
    0x39: 'DW_AT_decl_column', 0x3a: 'DW_AT_decl_file', 0x3b: 'DW_AT_decl_line',
    0x3c: 'DW_AT_declaration', 0x3d: 'DW_AT_discr_list', 0x3e: 'DW_AT_encoding',
    0x3f: 'DW_AT_external', 0x40: 'DW_AT_frame_base', 0x41: 'DW_AT_friend',
    0x42: 'DW_AT_identifier_case', 0x43: 'DW_AT_macro_info',
    0x44: 'DW_AT_namelist_item', 0x45: 'DW_AT_priority', 0x46: 'DW_AT_segment',
    0x47: 'DW_AT_specification', 0x48: 'DW_AT_static_link',
    0x49: 'DW_AT_type', 0x4a: 'DW_AT_use_location',
    0x4b: 'DW_AT_variable_parameter', 0x4c: 'DW_AT_virtuality',
    0x4d: 'DW_AT_vtable_elem_location', 0x4f: 'DW_AT_allocated',
    0x50: 'DW_AT_associated', 0x51: 'DW_AT_data_location',
    0x52: 'DW_AT_byte_stride', 0x53: 'DW_AT_entry_pc', 0x54: 'DW_AT_use_UTF8',
    0x55: 'DW_AT_ranges', 0x56: 'DW_AT_extension', 0x57: 'DW_AT_trampoline',
    0x58: 'DW_AT_call_column', 0x59: 'DW_AT_call_file', 0x5a: 'DW_AT_call_line',
    0x5b: 'DW_AT_description', 0x5c: 'DW_AT_binary_scale',
    0x5d: 'DW_AT_decimal_scale', 0x5e: 'DW_AT_small',
    0x5f: 'DW_AT_decimal_sign', 0x60: 'DW_AT_digit_count',
    0x61: 'DW_AT_picture_string', 0x62: 'DW_AT_mutable',
    0x63: 'DW_AT_threads_scaled', 0x64: 'DW_AT_explicit',
    0x65: 'DW_AT_object_pointer', 0x66: 'DW_AT_endianity',
    0x67: 'DW_AT_elemental', 0x68: 'DW_AT_pure', 0x69: 'DW_AT_recursive',
    0x6a: 'DW_AT_signature', 0x6b: 'DW_AT_main_subprogram',
    0x6c: 'DW_AT_data_bit_offset', 0x6d: 'DW_AT_const_expr',
    0x6e: 'DW_AT_linkage_name', 0x6f: 'DW_AT_enum_class',
    0x70: 'DW_AT_string_length_bit_size', 0x71: 'DW_AT_string_length_byte_size',
    0x71: 'DW_AT_rank', 0x72: 'DW_AT_str_offsets_base',
    0x73: 'DW_AT_addr_base', 0x74: 'DW_AT_rnglists_base',
    0x76: 'DW_AT_dwo_name', 0x77: 'DW_AT_reference',
    0x78: 'DW_AT_rvalue_reference', 0x79: 'DW_AT_macros',
    0x7a: 'DW_AT_call_all_calls', 0x7b: 'DW_AT_call_all_source_calls',
    0x7c: 'DW_AT_call_all_tail_calls', 0x7d: 'DW_AT_call_return_pc',
    0x7e: 'DW_AT_call_value', 0x7f: 'DW_AT_call_origin',
    0x80: 'DW_AT_call_parameter', 0x81: 'DW_AT_call_pc',
    0x82: 'DW_AT_call_tail_call', 0x83: 'DW_AT_call_target',
    0x84: 'DW_AT_call_target_clobbered', 0x85: 'DW_AT_call_data_location',
    0x86: 'DW_AT_call_data_value', 0x87: 'DW_AT_noreturn',
    0x88: 'DW_AT_alignment', 0x89: 'DW_AT_export_symbols',
    0x8a: 'DW_AT_deleted', 0x8b: 'DW_AT_defaulted',
    0x8c: 'DW_AT_loclists_base',
    # GNU extensions gcc emits alongside DW_AT_language in DWARF 5 units
    0x90: 'DW_AT_language_name', 0x91: 'DW_AT_language_version',
    # vendor range 0x2000+, which is where the GNU extensions live
    0x2111: 'DW_AT_GNU_call_site_value',
    0x2116: 'DW_AT_GNU_all_tail_call_sites',
    0x2117: 'DW_AT_GNU_all_call_sites',
    0x2119: 'DW_AT_GNU_macros',
    0x2130: 'DW_AT_GNU_dwo_name',
    0x2131: 'DW_AT_GNU_dwo_id',
    0x2133: 'DW_AT_GNU_ranges_base',
    0x2134: 'DW_AT_GNU_pubnames',
    0x2135: 'DW_AT_GNU_pubtypes',
    0x2136: 'DW_AT_GNU_discriminator',
    0x2137: 'DW_AT_GNU_locviews',
    0x2138: 'DW_AT_GNU_entry_view',
}

FORM = {
    0x01: 'DW_FORM_addr', 0x03: 'DW_FORM_block2', 0x04: 'DW_FORM_block4',
    0x05: 'DW_FORM_data2', 0x06: 'DW_FORM_data4', 0x07: 'DW_FORM_data8',
    0x08: 'DW_FORM_string', 0x09: 'DW_FORM_block', 0x0a: 'DW_FORM_block1',
    0x0b: 'DW_FORM_data1', 0x0c: 'DW_FORM_flag', 0x0d: 'DW_FORM_sdata',
    0x0e: 'DW_FORM_strp', 0x0f: 'DW_FORM_udata', 0x10: 'DW_FORM_ref_addr',
    0x11: 'DW_FORM_ref1', 0x12: 'DW_FORM_ref2', 0x13: 'DW_FORM_ref4',
    0x14: 'DW_FORM_ref8', 0x15: 'DW_FORM_ref_udata', 0x16: 'DW_FORM_indirect',
    0x17: 'DW_FORM_sec_offset', 0x18: 'DW_FORM_exprloc',
    0x19: 'DW_FORM_flag_present', 0x1a: 'DW_FORM_strx',
    0x1b: 'DW_FORM_addrx', 0x1c: 'DW_FORM_ref_sup4', 0x1d: 'DW_FORM_strp_sup',
    0x1e: 'DW_FORM_data16', 0x1f: 'DW_FORM_line_strp',
    0x20: 'DW_FORM_ref_sig8', 0x21: 'DW_FORM_implicit_const',
    0x22: 'DW_FORM_loclistx', 0x23: 'DW_FORM_rnglistx',
    0x25: 'DW_FORM_strx1', 0x26: 'DW_FORM_strx2', 0x27: 'DW_FORM_strx3',
    0x28: 'DW_FORM_strx4', 0x29: 'DW_FORM_addrx1', 0x2a: 'DW_FORM_addrx2',
    0x2b: 'DW_FORM_addrx3', 0x2c: 'DW_FORM_addrx4',
}

CHILDREN = {0: 'no', 1: 'yes'}

UT = {0x01: 'DW_UT_compile', 0x02: 'DW_UT_type',
      0x03: 'DW_UT_partial', 0x04: 'DW_UT_skeleton',
      0x05: 'DW_UT_split_compile', 0x06: 'DW_UT_split_type'}

LLE = {0x00: 'DW_LLE_end_of_list', 0x01: 'DW_LLE_base_addressx',
       0x02: 'DW_LLE_startx_endx', 0x03: 'DW_LLE_startx_length',
       0x04: 'DW_LLE_offset_pair', 0x05: 'DW_LLE_default_location',
       0x06: 'DW_LLE_base_address', 0x07: 'DW_LLE_start_end',
       0x08: 'DW_LLE_start_length'}

# ---------------------------------------------------------------- primitives


class Cursor:
    def __init__(self, buf, pos=0, unit_end=None, addr_size=8, unit_base=0):
        self.b = buf
        self.p = pos
        self.end = len(buf) if unit_end is None else unit_end
        self.addr_size = addr_size
        self.base = unit_base

    def eof(self):
        return self.p >= self.end

    def u8(self):
        v, = struct.unpack_from('<B', self.b, self.p)
        self.p += 1
        return v

    def s8(self):
        v, = struct.unpack_from('<b', self.b, self.p)
        self.p += 1
        return v

    def u16(self):
        v, = struct.unpack_from('<H', self.b, self.p)
        self.p += 2
        return v

    def u32(self):
        v, = struct.unpack_from('<I', self.b, self.p)
        self.p += 4
        return v

    def u64(self):
        v, = struct.unpack_from('<Q', self.b, self.p)
        self.p += 8
        return v

    def uleb(self):
        r = 0
        s = 0
        while True:
            byte = self.u8()
            r |= (byte & 0x7F) << s
            if not byte & 0x80:
                return r
            s += 7

    def sleb(self):
        r = 0
        s = 0
        while True:
            byte = self.u8()
            r |= (byte & 0x7F) << s
            s += 7
            if not byte & 0x80:
                if byte & 0x40:
                    r -= 1 << s
                return r

    def bytes(self, n):
        v = self.b[self.p:self.p + n]
        self.p += n
        return v

    def cstr(self):
        end = self.b.index(b'\x00', self.p)
        v = self.b[self.p:end].decode('utf-8', 'replace')
        self.p = end + 1
        return v

    def block(self):
        n = self.uleb()
        return self.bytes(n)


# ---------------------------------------------------------------- abbrev


def read_abbrev(data, offset=0):
    """Return {code: (tag, has_children, [(at, form, implicit_const)])}.

    A `.debug_abbrev` section may hold several tables, each terminated by a
    lone code 0, and a unit names the one it wants by offset. Reading past the
    terminator is not merely untidy: a later table reusing the same codes
    silently replaces the earlier one, and the decoder then walks the DIE tree
    using the wrong attribute lists. It still finds every DIE, because the
    byte walk stays in step -- it just reports nonsense. So stop at the 0.
    """
    table = {}
    c = Cursor(data, offset)
    while not c.eof():
        code = c.uleb()
        if code == 0:
            break                         # end of THIS table
        tag = c.uleb()
        has_children = c.u8()
        attrs = []
        while True:
            at = c.uleb()
            form = c.uleb()
            const = None
            if form == 0x21:              # DW_FORM_implicit_const
                const = c.sleb()
            if at == 0 and form == 0:
                break
            attrs.append((at, form, const))
        table[code] = (tag, has_children, attrs)
    return table


def count_abbrev_tables(data):
    """How many tables the section holds, and where each starts."""
    starts = []
    p = 0
    c = Cursor(data, 0)
    while c.p < len(data):
        starts.append(c.p)
        while c.p < len(data):
            code = c.uleb()
            if code == 0:
                break
            c.uleb()                      # tag
            c.u8()                        # children
            while True:
                at = c.uleb()
                form = c.uleb()
                if form == 0x21:
                    c.sleb()
                if at == 0 and form == 0:
                    break
        c.p += 1                          # the terminating 0
        if c.p <= starts[-1]:
            break                         # trailing zero, no more tables
    return starts


# ---------------------------------------------------------------- forms


class Resolver:
    """Resolves the string and address indirections a DWARF unit relies on."""

    def __init__(self, path, dwo=False, addr_base=0, str_offsets_base=0):
        suffix = '.dwo' if dwo else ''
        self.dwo = dwo
        try:
            self.dstr = ds.section(path, '.debug_str' + suffix)['data']
        except KeyError:
            self.dstr = b''
        try:
            self.dlstr = ds.section(path, '.debug_line_str' + suffix)['data']
        except KeyError:
            self.dlstr = b''
        self.addr_base = addr_base
        try:
            self.daddr = ds.section(path, '.debug_addr' + suffix)['data']
        except KeyError:
            self.daddr = b''
        self.str_offsets_base = str_offsets_base
        try:
            self.dso = ds.section(path, '.debug_str_offsets' + suffix)['data']
        except KeyError:
            self.dso = b''

    def dstr_at(self, off):
        return ds.cstr(self.dstr, off)

    def dlstr_at(self, off):
        return ds.cstr(self.dlstr, off)

    def strx(self, index):
        if not self.dso:
            return '<strx %d: no .debug_str_offsets>' % index
        off = self.str_offsets_base + 4 * index
        sec_off, = struct.unpack_from('<I', self.dso, off)
        return self.dstr_at(sec_off)

    def addrx(self, index):
        if not self.daddr:
            return '<addrx %d: no .debug_addr>' % index
        off = self.addr_base + self.addr_size_bytes * index
        fmt = {4: '<I', 8: '<Q'}[self.addr_size_bytes]
        v, = struct.unpack_from(fmt, self.daddr, off)
        return v


def read_form(cur, form, const, res, unit, out):
    """Read one form's value. Appends a (name, raw, value) triple to `out`."""
    if form == 0x01:                                   # addr
        v = cur.u64() if cur.addr_size == 8 else cur.u32()
        return 'DW_FORM_addr', v
    if form == 0x0b:                                   # data1
        return 'DW_FORM_data1', cur.u8()
    if form == 0x05:                                   # data2
        return 'DW_FORM_data2', cur.u16()
    if form == 0x06:                                   # data4
        return 'DW_FORM_data4', cur.u32()
    if form == 0x07:                                   # data8
        return 'DW_FORM_data8', cur.u64()
    if form == 0x1e:                                   # data16
        return 'DW_FORM_data16', cur.bytes(16).hex()
    if form == 0x0d:                                   # sdata
        return 'DW_FORM_sdata', cur.sleb()
    if form == 0x0f:                                   # udata
        return 'DW_FORM_udata', cur.uleb()
    if form == 0x08:                                   # string
        return 'DW_FORM_string', cur.cstr()
    if form == 0x0e:                                   # strp
        o = cur.u32()
        return 'DW_FORM_strp', '%s  (str+0x%x)' % (res.dstr_at(o), o)
    if form == 0x1f:                                   # line_strp
        o = cur.u32()
        return 'DW_FORM_line_strp', '%s  (line_str+0x%x)' % (res.dlstr_at(o), o)
    if form == 0x17:                                   # sec_offset
        o = cur.u32()
        return 'DW_FORM_sec_offset', '0x%x' % o
    if form == 0x11:                                   # ref1
        return 'DW_FORM_ref1', '<0x%x>' % (unit['cu'] + cur.u8())
    if form == 0x12:                                   # ref2
        return 'DW_FORM_ref2', '<0x%x>' % (unit['cu'] + cur.u16())
    if form == 0x13:                                   # ref4
        return 'DW_FORM_ref4', '<0x%x>' % (unit['cu'] + cur.u32())
    if form == 0x14:                                   # ref8
        return 'DW_FORM_ref8', '<0x%x>' % (unit['cu'] + cur.u64())
    if form == 0x15:                                   # ref_udata
        return 'DW_FORM_ref_udata', '<0x%x>' % (unit['cu'] + cur.uleb())
    if form == 0x10:                                   # ref_addr (unit-relative)
        v = cur.u32() if unit['version'] < 5 else cur.u32()
        return 'DW_FORM_ref_addr', '<0x%x>' % v
    if form == 0x19:                                   # flag_present
        return 'DW_FORM_flag_present', 1
    if form == 0x0c:                                   # flag
        return 'DW_FORM_flag', cur.u8()
    if form == 0x18:                                   # exprloc
        b = cur.block()
        return 'DW_FORM_exprloc', '%d byte block: %s' % (len(b), b.hex(' '))
    if form == 0x09:                                   # block
        b = cur.block()
        return 'DW_FORM_block', '%d bytes' % len(b)
    if form == 0x0a:                                   # block1
        n = cur.u8()
        b = cur.bytes(n)
        return 'DW_FORM_block1', '%d bytes' % n
    if form == 0x03:                                   # block2
        n = cur.u16()
        cur.bytes(n)
        return 'DW_FORM_block2', '%d bytes' % n
    if form == 0x04:                                   # block4
        n = cur.u32()
        cur.bytes(n)
        return 'DW_FORM_block4', '%d bytes' % n
    if form == 0x21:                                   # implicit_const
        return 'DW_FORM_implicit_const', const
    if form == 0x22:                                   # loclistx
        return 'DW_FORM_loclistx', 'loclist[0x%x]' % cur.uleb()
    if form == 0x23:                                   # rnglistx
        return 'DW_FORM_rnglistx', 'rnglist[0x%x]' % cur.uleb()
    if form in (0x1a, 0x25, 0x26, 0x27, 0x28):         # strx family
        idx = {0x1a: cur.uleb, 0x25: cur.u8, 0x26: cur.u16,
               0x27: lambda: int.from_bytes(cur.bytes(3), 'little'),
               0x28: cur.u32}[form]()
        return FORM[form], '%s  (str_offsets[%d])' % (res.strx(idx), idx)
    if form in (0x1b, 0x29, 0x2a, 0x2b, 0x2c):         # addrx family
        idx = {0x1b: cur.uleb, 0x29: cur.u8, 0x2a: cur.u16,
               0x2b: lambda: int.from_bytes(cur.bytes(3), 'little'),
               0x2c: cur.u32}[form]()
        return FORM[form], 'addr_index[%d]' % idx
    if form == 0x16:                                   # indirect
        real = cur.uleb()
        name, value = read_form(cur, real, None, res, unit, out)
        return 'DW_FORM_indirect -> ' + name, value
    raise ValueError('unhandled form 0x%x at 0x%x' % (form, cur.p))


# ---------------------------------------------------------------- info


def decode_info(path, limit=None, dwo=False, verbose=True,
                str_offsets_base=None, addr_base=None):
    """Decode every unit in .debug_info.

    A section holds one unit per compilation, back to back, each with its own
    length and its own abbreviation table. A linked binary from two .c files has
    two, so a decoder that reads only the first reports a short tree rather
    than failing -- which is the dangerous kind of wrong.
    """
    name = '.debug_info.dwo' if dwo else '.debug_info'
    sec = ds.section(path, name)
    data = sec['data']
    abbrev_name = '.debug_abbrev.dwo' if dwo else '.debug_abbrev'
    abbrev_data = ds.section(path, abbrev_name)['data']

    res = Resolver(path, dwo=dwo)
    res.addr_size_bytes = 8
    # In split DWARF the string indirection is relative to a base that lives
    # in the *skeleton* unit, not here, so the caller supplies it. Getting it
    # wrong shifts every string by base/4 entries and yields confident nonsense:
    # DW_AT_producer comes back as "unsigned int".
    if str_offsets_base is not None:
        res.str_offsets_base = str_offsets_base
    elif dwo:
        res.str_offsets_base = 8
    if addr_base is not None:
        res.addr_base = addr_base

    all_units = []
    all_abbrevs = []
    all_dies = []
    pos = 0
    while pos + 4 <= len(data):
        c = Cursor(data, pos)
        unit_length = c.u32()
        if unit_length == 0:
            break
        unit_start = c.p
        dwarf64 = unit_length == 0xFFFFFFFF
        if dwarf64:
            unit_length = c.u64()
        cu = unit_start - (12 if dwarf64 else 4)
        version = c.u16()
        unit_type = None
        if version >= 5:
            unit_type = c.u8()
        addr_size = c.u8()
        abbrev_off = c.u32()
        if dwarf64:
            abbrev_off = c.u64()
        type_sig = type_off = dwo_id = None
        if version >= 5 and unit_type in (0x02, 0x06):
            # DW_UT_type / DW_UT_split_type: signature then offset
            type_sig = c.bytes(8)
            type_off = c.u64()
        elif version >= 5 and unit_type in (0x04, 0x05):
            # DW_UT_skeleton / DW_UT_split_compile: a single 8-byte dwo_id and
            # nothing else. The DIE tree is not here at all -- it lives in the
            # separate .dwo file, and this unit only says where.
            dwo_id = c.bytes(8)
        unit = dict(cu=cu, version=version, unit_type=unit_type,
                    addr_size=addr_size, abbrev_off=abbrev_off,
                    dwarf64=dwarf64, unit_length=unit_length,
                    type_sig=type_sig, type_off=type_off, dwo_id=dwo_id)
        if verbose:
            extra = ''
            if unit_type is not None:
                extra = ' unit_type=0x%02x(%s)' % (
                    unit_type, UT.get(unit_type, '?'))
            if type_sig is not None:
                extra += ' type_signature=%s type_offset=0x%x' % (
                    type_sig.hex(), type_off)
            if dwo_id is not None:
                extra += ' dwo_id=0x%s' % dwo_id.hex()
            print('--- unit at 0x%x: unit_length=0x%x version=%d%s '
                  'address_size=%d abbrev_offset=0x%x ---'
                  % (cu, unit_length, version, extra, addr_size, abbrev_off))
            print('    header ends at 0x%x, so the first DIE is at <%d><%x>'
                  % (c.p, 0, c.p))

        abbrevs = read_abbrev(abbrev_data, abbrev_off)
        if verbose:
            print('    %d abbreviations: %s'
                  % (len(abbrevs),
                     ' '.join('%d=%s' % (k, TAG.get(v[0], '0x%x' % v[0]))
                              for k, v in sorted(abbrevs.items()))))

        unit_end = unit_start + unit_length
        cur = Cursor(data, c.p, unit_end, addr_size=addr_size)
        res.addr_size_bytes = addr_size

        dies = []
        stack = []
        while not cur.eof():
            die_off = cur.p
            code = cur.uleb()
            if code == 0:
                if stack:
                    stack.pop()
                continue
            if code not in abbrevs:
                raise ValueError(
                    'unit 0x%x: abbrev code %d at 0x%x is not in the table at '
                    '0x%x (%d entries)'
                    % (cu, code, die_off, abbrev_off, len(abbrevs)))
            tag, has_children, attrs = abbrevs[code]
            values = []
            for at, form, const in attrs:
                attr_off = cur.p
                fname, value = read_form(cur, form, const, res, unit, values)
                values.append((AT.get(at, 'DW_AT_0x%x' % at), at, form, fname,
                               value, attr_off))
            die = dict(offset=die_off, code=code, tag=tag,
                       tag_name=TAG.get(tag, 'DW_TAG_0x%x' % tag),
                       children=bool(has_children), attrs=values,
                       depth=len(stack), unit=cu)
            dies.append(die)
            if has_children:
                stack.append(die)
            if limit and len(all_dies) + len(dies) >= limit:
                break
        if verbose:
            for die in dies:
                print('%s<%d><%x>: Abbrev Number: %d (%s)'
                      % ('  ' * die['depth'], die['depth'], die['offset'],
                         die['code'], die['tag_name']))
                for name_, at, form, fname, value, aoff in die['attrs']:
                    print('%s    <%x>   %-22s : %s'
                          % ('  ' * die['depth'], aoff, name_, value))
                    print('%s        %-22s   [%s]'
                          % ('  ' * die['depth'], '', fname))
        all_units.append(unit)
        all_abbrevs.append(abbrevs)
        all_dies.extend(dies)
        if limit and len(all_dies) >= limit:
            break
        pos = unit_end
    return all_units, all_abbrevs, all_dies


# ---------------------------------------------------------------- loclists


def decode_loclists(path):
    sec = ds.section(path, '.debug_loclists')
    data = sec['data']
    print('--- .debug_loclists: %d bytes ---' % len(data))
    c = Cursor(data)
    while c.p < len(data):
        list_off = c.p
        length = c.u32()
        if length == 0:
            print('  unit at 0x%x: length 0 -> terminator' % list_off)
            continue
        end = c.p + length
        version = c.u16()
        addr_size = c.u8()
        seg_sel = c.u8()
        off_entry_count = c.u32()
        print('  list at 0x%x: version=%d addr_size=%d segment_selector=%d '
              'offset_entry_count=%d' % (list_off, version, addr_size,
                                         seg_sel, off_entry_count))
        while c.p < end:
            kind = c.u8()
            if kind == 0x00:
                print('      DW_LLE_end_of_list')
                break
            if kind == 0x05:
                print('      DW_LLE_default_location  expr %d bytes: %s'
                      % (1, c.block().hex(' ')))
                continue
            if kind == 0x06:
                v = c.u64() if addr_size == 8 else c.u32()
                print('      DW_LLE_base_address  0x%x' % v)
                continue
            if kind == 0x04:
                s, e = c.u32(), c.u32()
                print('      DW_LLE_offset_pair  start=0x%x end=0x%x' % (s, e))
                continue
            if kind == 0x07:
                s = c.u64() if addr_size == 8 else c.u32()
                e = c.u64() if addr_size == 8 else c.u32()
                print('      DW_LLE_start_end  0x%x..0x%x' % (s, e))
                continue
            if kind == 0x08:
                s = c.u64() if addr_size == 8 else c.u32()
                n = c.uleb()
                print('      DW_LLE_start_length  0x%x +%d' % (s, n))
                continue
            raise ValueError('unhandled DW_LLE 0x%02x' % kind)
        c.p = end


# ---------------------------------------------------------------- aranges


def decode_aranges(path, addr_size=None):
    """Decode .debug_aranges.

    The trap, and it is an alignment one rather than a version one: the header
    is 8 bytes after `unit_length` -- version(2), a 4-byte info offset,
    address_size(1), segment_selector_size(1) -- but the tuple table starts
    **16** bytes in, not 12, because the table is padded up to the tuple size.
    A reader that trusts the field list and starts reading tuples at 12 decodes
    the first address as 0x114900000000 instead of 0x1149: a plausible value
    that points nowhere, and that no consistency check will catch.

    Verified on both units of the reference binary, whose tables begin at 0x10
    and 0x40. Only address_size 8 could be tested here (no -m32 on this
    machine), and for a 4-byte address the 12-byte header is already
    tuple-aligned so the padding would be zero -- that is a prediction, not a
    measurement.
    """
    sec = ds.section(path, '.debug_aranges')
    data = sec['data']
    print('--- .debug_aranges: %d bytes ---' % len(data))
    c = Cursor(data)
    while c.p < len(data):
        unit_off = c.p
        length = c.u32()
        if length == 0:
            break
        end = c.p + length
        version = c.u16()
        info_off = c.u32()
        a_size = c.u8()
        seg_size = c.u8()
        tuple_size = a_size + seg_size
        if tuple_size:
            c.p = (c.p + tuple_size - 1) // tuple_size * tuple_size
        pairs = []
        while c.p + tuple_size * 2 <= end:
            a = int.from_bytes(c.bytes(tuple_size), 'little')
            l = int.from_bytes(c.bytes(a_size), 'little')
            pairs.append((a, l))
            if a == 0 and l == 0:
                break
        print('  unit at 0x%x: version=%d debug_info_offset=0x%x '
              'address_size=%d segment_selector_size=%d'
              % (unit_off, version, info_off, a_size, seg_size))
        for a, l in pairs:
            print('      address 0x%012x  length 0x%x' % (a, l))
        c.p = end


# ---------------------------------------------------------------- eh_frame


def decode_eh_frame(path):
    """Decode .eh_frame: a CIE of initial rules followed by FDEs.

    Layout of each record:
        length (4)          0xffffffff would mean 64-bit DWARF
        CIE_id (4)          0 => this record IS a CIE; otherwise it is the
                            file offset of the CIE whose rules apply
        version (1)
        augmentation (nul-terminated string)
        [version 1 only]    code_alignment_factor  ULEB
                            data_alignment_factor  SLEB
                            return_address_register ULEB
        [if augmentation starts with 'z']
                            augmentation_data_length ULEB
                            augmentation_data, whose meaning each letter fixes
        initial instructions, filling to the end of `length`
    """
    sec = ds.section(path, '.eh_frame')
    data = sec['data']
    # A pcrel encoded pointer is relative to the *runtime address* of its own
    # field, which is the section's virtual address plus the field's offset in
    # the section. Using the file offset instead produces values like
    # 0x26fffff010 where the real answer is 0x1060.
    sec_addr = sec['addr']
    print('--- .eh_frame: %d bytes, section address 0x%x ---'
          % (len(data), sec_addr))
    c = Cursor(data)
    cies = {}
    while c.p + 4 <= len(data):
        rec_off = c.p
        length = c.u32()
        if length == 0:
            print('  zero-length terminator at 0x%x' % rec_off)
            break
        end = c.p + length
        cie_field = c.p
        cie_id = c.u32()
        is_cie = cie_id == 0
        if not is_cie:
            # In .eh_frame the CIE pointer is RELATIVE to the position of the
            # pointer field itself, so the CIE's offset is field_pos - value.
            # In .debug_frame the same field is an absolute offset. Both files
            # in this course store a value equal to the field's own offset,
            # which is why reading it as absolute lands 0x1c / 0x34 bytes past
            # the start of a section that has no CIE there.
            cie_id = cie_field - cie_id
        version = aug = None
        code_align, data_align, ra_reg, fde_enc = 1, -1, 0, None
        if is_cie:
            version = c.u8()
            aug = c.cstr()
            if version == 1:
                code_align = c.uleb()
                data_align = c.sleb()
                ra_reg = c.uleb()
            if aug.startswith('z'):
                aug_len = c.uleb()
                aug_end = c.p + aug_len
                for ch in aug[1:]:
                    if ch == 'R':
                        fde_enc = c.u8()
                    elif ch == 'L':
                        c.u8()
                    elif ch == 'P':
                        penc = c.u8()
                        read_encoded_pointer(c, penc, sec_addr)
                    elif ch == 'S':
                        pass
                    else:
                        print('    unknown augmentation letter %r' % ch)
                c.p = aug_end
            cies[rec_off] = dict(code_align=code_align, data_align=data_align,
                                 ra_reg=ra_reg, fde_enc=fde_enc)
        print('  %s at 0x%x: length=%d'
              % ('CIE' if is_cie else 'FDE', rec_off, length))
        if is_cie:
            print('    version=%d augmentation=%r' % (version, aug))
            print('    code_alignment_factor=%d data_alignment_factor=%d '
                  'return_address_register=%d%s'
                  % (code_align, data_align, ra_reg,
                     (' fde_encoding=0x%02x' % fde_enc)
                     if fde_enc is not None else ''))
            cie = cies[rec_off]
        else:
            # An FDE has no version and no augmentation string. After the CIE
            # pointer come exactly two encoded values -- the initial location
            # and the address range -- whose encoding the CIE's 'R' letter set.
            # Reading a version byte here is the classic mistake: it eats the
            # first byte of the initial location and every later field shifts.
            cie = cies.get(cie_id)
            enc = cie['fde_enc'] if cie else 0x00
            start = read_encoded_pointer(c, enc, sec_addr)
            # address_range uses the same *format* nibble but the application
            # bits do not apply: it is a length, not an address, so applying
            # pcrel to it adds the section base a second time and yields
            # 0x209a where the real end of the range is 0x1086.
            stop = start + read_encoded_pointer(c, enc & 0x0F)
            print('    CIE_pointer=0x%x  pc=0x%x..0x%x  (encoding 0x%02x%s)'
                  % (cie_id, start, stop, enc,
                     '' if cie else ' -- CIE NOT FOUND, assuming absptr'))
        rows = decode_cfi_instructions(c, end, cie['code_align'],
                                       cie['data_align'])
        for r in rows:
            print('      %s' % r)
        c.p = end
    return


def read_encoded_pointer(c, enc, sec_addr=0):
    """Read one DW_EH_PE-encoded pointer and return its value.

    The low nibble is the format -- width and signedness -- and the high
    nibble is how to apply the raw value:

        0x00 absptr   0x01 uleb128   0x02 udata2   0x03 udata4
        0x04 udata8   0x09 sleb128   0x0a sdata2   0x0b sdata4
        0x0c sdata8   0xff omit

    and the application nibble is 0x10 pcrel, 0x30 datarel, 0x40 funcrel,
    0x50 aligned, 0x80 indirect. gcc's default here is 0x1b = pcrel|sdata4,
    so the stored value is a 4-byte signed displacement from the address of
    the field itself. Getting the width wrong is not a small error: reading
    sdata4 as 8 bytes swallows the following four bytes, so the FDE's address
    range comes out as 0x10076478 instead of 0x1086 and every instruction
    after it decodes as noise.
    """
    fmt = enc & 0x0F
    app = enc & 0x70
    at = sec_addr + c.p
    if fmt == 0xFF:
        return 0                       # DW_EH_PE_omit: no bytes present
    if fmt == 0x00:
        raw = int.from_bytes(c.bytes(c.addr_size), 'little')
    elif fmt == 0x01:
        raw = c.uleb()
    elif fmt == 0x09:
        raw = c.sleb()
    elif fmt == 0x02:
        raw = int.from_bytes(c.bytes(2), 'little')
    elif fmt == 0x0A:
        raw = int.from_bytes(c.bytes(2), 'little', signed=True)
    elif fmt == 0x03:
        raw = int.from_bytes(c.bytes(4), 'little')
    elif fmt == 0x0B:
        raw = int.from_bytes(c.bytes(4), 'little', signed=True)
    elif fmt == 0x04:
        raw = int.from_bytes(c.bytes(8), 'little')
    elif fmt == 0x0C:
        raw = int.from_bytes(c.bytes(8), 'little', signed=True)
    else:
        raise ValueError('unhandled DW_EH_PE format nibble 0x%x' % fmt)
    if app == 0x10:                    # DW_EH_PE_pcrel
        return (raw + at) & 0xFFFFFFFFFFFFFFFF
    if app == 0x40:                    # DW_EH_PE_funcrel
        return (raw + at) & 0xFFFFFFFFFFFFFFFF
    return raw                         # absptr, or datarel we cannot resolve


def size_of_encoded_pointer(enc, addr_size):
    fmt = enc & 0x0F
    return {0x00: addr_size, 0x01: 2, 0x02: 4, 0x03: 8,
            0x04: 0, 0x09: 0, 0x0a: 2, 0x0b: 4, 0x0c: 8}.get(fmt, addr_size)


def decode_cfi_instructions(c, end, code_align, data_align):
    rows = []
    while c.p < end:
        op = c.u8()
        high = op >> 6
        low = op & 0x3F
        if high == 1:
            rows.append('DW_CFA_advance_loc  delta=%d (x code_align = %d)'
                        % (low, low * code_align))
        elif high == 2:
            rows.append('DW_CFA_offset  reg=%d  factored=%d bytes'
                        % (low, c.uleb() * data_align))
        elif high == 3:
            rows.append('DW_CFA_restore  reg=%d' % low)
        elif op == 0x00:
            rows.append('DW_CFA_nop')
        elif op == 0x01:
            rows.append('DW_CFA_set_loc')
        elif op == 0x02:
            rows.append('DW_CFA_advance_loc1  delta=%d' % c.u8())
        elif op == 0x03:
            rows.append('DW_CFA_advance_loc2  delta=%d' % c.u16())
        elif op == 0x04:
            rows.append('DW_CFA_advance_loc4  delta=%d' % c.u32())
        elif op == 0x05:
            r, o = c.uleb(), c.uleb()
            rows.append('DW_CFA_offset_extended  reg=%d offset=%d bytes'
                        % (r, o * data_align))
        elif op == 0x06:
            rows.append('DW_CFA_restore_extended  reg=%d' % c.uleb())
        elif op == 0x07:
            rows.append('DW_CFA_undefined  reg=%d' % c.uleb())
        elif op == 0x08:
            rows.append('DW_CFA_same_value  reg=%d' % c.uleb())
        elif op == 0x09:
            r, o = c.uleb(), c.uleb()
            rows.append('DW_CFA_register  reg=%d -> reg=%d' % (r, o))
        elif op == 0x0a:
            rows.append('DW_CFA_remember_state')
        elif op == 0x0b:
            rows.append('DW_CFA_restore_state')
        elif op == 0x0c:
            r, o = c.uleb(), c.uleb()
            rows.append('DW_CFA_def_cfa  reg=%d, offset=%d' % (r, o))
        elif op == 0x0d:
            rows.append('DW_CFA_def_cfa_register  reg=%d' % c.uleb())
        elif op == 0x0e:
            rows.append('DW_CFA_def_cfa_offset  offset=%d' % c.uleb())
        elif op == 0x0f:
            rows.append('DW_CFA_def_cfa_expression  block=%s'
                        % ' '.join('%02x' % b for b in c.block()))
        elif op == 0x10:
            r = c.uleb()
            rows.append('DW_CFA_expression  reg=%d, block=%s'
                        % (r, ' '.join('%02x' % b for b in c.block())))
        elif op == 0x11:
            r, o = c.uleb(), c.sleb()
            rows.append('DW_CFA_offset_extended_sf  reg=%d, %d'
                        % (r, o * data_align))
        elif op == 0x12:
            r, o = c.uleb(), c.sleb()
            rows.append('DW_CFA_def_cfa_sf  reg=%d, %d' % (r, o))
        elif op == 0x13:
            rows.append('DW_CFA_def_cfa_offset_sf  %d'
                        % c.sleb() * data_align)
        elif op == 0x14:
            r, o = c.uleb(), c.uleb()
            rows.append('DW_CFA_val_offset  reg=%d, %d' % (r, o * data_align))
        elif op == 0x15:
            r, o = c.uleb(), c.sleb()
            rows.append('DW_CFA_val_offset_sf  reg=%d, %d' % (r, o))
        elif op == 0x16:
            r = c.uleb()
            rows.append('DW_CFA_val_expression  reg=%d, block=%s'
                        % (r, ' '.join('%02x' % b for b in c.block())))
        elif op == 0x2d:
            rows.append('DW_CFA_GNU_window_save')
        elif op == 0x2e:
            v = c.u8()
            if v == 0x02:
                rows.append('DW_CFA_GNU_args_size  %d' % c.uleb())
            else:
                rows.append('DW_CFA_GNU_window_save')
        elif op == 0x2f:
            r, o = c.uleb(), c.uleb()
            rows.append('DW_CFA_GNU_negative_offset_extended  reg=%d, %d'
                        % (r, o * data_align))
        else:
            rows.append('!! unknown primary opcode 0x%02x at 0x%x'
                        % (op, c.p - 1))
            break
    return rows


# ---------------------------------------------------------------- pubnames


def decode_pubnames(path, name='.debug_pubnames'):
    sec = ds.section(path, name)
    data = sec['data']
    print('--- %s: %d bytes ---' % (name, len(data)))
    c = Cursor(data)
    while c.p + 4 <= len(data):
        unit_off = c.p
        length = c.u32()
        if length == 0:
            break
        end = c.p + length
        version = c.u16()
        info_off = c.u32()
        info_len = c.u32()
        print('  set at 0x%x: version=%d debug_info_offset=0x%x length=0x%x'
              % (unit_off, version, info_off, info_len))
        while c.p < end:
            die_off = c.u32()
            if die_off == 0:
                break
            print('      DIE <0x%x>  %s' % (die_off, c.cstr()))
        c.p = end


# ---------------------------------------------------------------- main


def main():
    argv = sys.argv[1:]
    what = 'all'
    limit = None
    path = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == '--dwo':
            what = 'dwo'
        elif a == '--limit':
            limit = int(argv[i + 1])
            i += 1
        elif not a.startswith('--'):
            path = a
        i += 1
    if path is None:
        print(__doc__)
        return 2
    if what == 'dwo':
        base = 8
        if '--str-offsets-base' in argv:
            base = int(argv[argv.index('--str-offsets-base') + 1])
        decode_info(path, limit=limit, dwo=True, str_offsets_base=base)
        return
    sections = {s['name'] for s in ds.read_elf_sections(path)[0]}
    if '.debug_info' in sections:
        decode_info(path, limit=limit)
    if '.debug_loclists' in sections:
        print()
        decode_loclists(path)
    if '.debug_aranges' in sections:
        print()
        decode_aranges(path)
    if '.eh_frame' in sections:
        print()
        decode_eh_frame(path)
    for n in ('.debug_pubnames', '.debug_gnu_pubnames'):
        if n in sections:
            print()
            decode_pubnames(path, n)


if __name__ == '__main__':
    main()
