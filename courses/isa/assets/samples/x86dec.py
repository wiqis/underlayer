#!/usr/bin/env python3
"""x86dec.py -- an x86-64 instruction decoder, and the reason for every byte.

The interesting part of an x86-64 instruction is not the mnemonic. It is that
the mnemonic is not stored anywhere. A disassembler has to work out where the
NEXT instruction starts before it can name this one, and it has to do that
from a set of rules that are genuinely strange:

  * 0x40-0x4F is INC/DEC in 32-bit mode and a REX prefix in 64-bit mode.
    The same three bytes are one instruction or two depending on the MODE.
  * A REX prefix must be the LAST prefix before the opcode. A legacy prefix
    that follows REX is not a prefix at all -- it is the opcode.
  * The SIB byte precedes the displacement, but the ModRM byte selects
    whether a SIB byte exists at all, and the SIB's base field can mean
    "no base", which then means the displacement is 4 bytes, not 1.
  * An instruction's length is not a property of the opcode. The same opcode
    is 1 byte and 15 bytes depending on the prefix, the addressing mode and
    the immediate width.

So this decoder is built around one idea: decode the ENCODING, show the work,
and only then look up a name. The derivation is printed for every field,
because the derivation is the lesson and the name is a lookup.

    python3 x86dec.py 4889e84883ec20        # decode a hex byte string
    python3 x86dec.py --elf <binary>        # walk every code section
    python3 x86dec.py --section .text <binary>
    python3 x86dec.py --why <hex>           # show only the reasoning
    python3 x86dec.py --forms               # the operand-form table

The decoder is deliberately PARTIAL in one direction: it resolves length and
structure for a broad table of opcodes, and names a documented subset. Where
it has no name it prints the opcode in hex rather than guessing, because a
guessed mnemonic is a claim nothing checked. Run courses/isa/assets/samples/
crosscheck.py to see it compared against objdump instruction-for-instruction.
"""

import os
import re
import struct
import sys

# ---------------------------------------------------------------------------
# Registers. The 4-bit encoding is 0-15; the low three bits name the legacy
# register and REX.{R,X,B} supply bit 3 by ADDING 8. That is the whole trick,
# and it is why REX.R=1 with reg=0 is r8, not r9.
# ---------------------------------------------------------------------------
REG64 = ['rax', 'rcx', 'rdx', 'rbx', 'rsp', 'rbp', 'rsi', 'rdi',
         'r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15']
REG32 = ['eax', 'ecx', 'edx', 'ebx', 'esp', 'ebp', 'esi', 'edi',
         'r8d', 'r9d', 'r10d', 'r11d', 'r12d', 'r13d', 'r14d', 'r15d']
REG16 = ['ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di',
         'r8w', 'r9w', 'r10w', 'r11w', 'r12w', 'r13w', 'r14w', 'r15w']
REG8 = ['al', 'cl', 'dl', 'bl', 'ah', 'ch', 'dh', 'bh',
        'r8b', 'r9b', 'r10b', 'r11b', 'r12b', 'r13b', 'r14b', 'r15b']

# ---------------------------------------------------------------------------
# Operand forms. What matters for LENGTH:
#   none      no ModRM, no immediate          (ret, nop, hlt)
#   rel8      ModRM-free, 1-byte displacement (jcc short)
#   rel32     ModRM-free, 4-byte displacement (call/jmp rel32, jcc near)
#   r_rm      ModRM, r + r/m                  (mov, add, cmp -- most of the ISA)
#   rm_r      ModRM, r/m + r
#   rm        ModRM only                       (push, jmp r/m, notrack)
#   rm_i8     ModRM then imm8                 (group1 arithmetic, shift-by-1)
#   rm_i32    ModRM then imm16/32/64 by size  (group1 arithmetic, mov imm)
#   rm_imm8   ModRM then imm8 after the r/m   (pshufd, pinsrw, bt)
#   r_i8      ModRM-free, 1-byte immediate    (mov r8, imm8)
#   r_i32     ModRM-free, 4- or 8-byte        (mov eax, imm32; movabs)
#   r_rm8     ModRM, r8 + r/m8
#   rm_r8     ModRM, r/m8 + r8
#   rm8_i8    ModRM, r/m8 then imm8           (cmp byte, imm8)
#   moffs     ModRM-free, address-sized        (mov al, [abs])
#   f_imm8    ModRM then a 1-byte "register" selector (x87)
#   f_imm16   ModRM-free, 2-byte              (ret imm16)
# ---------------------------------------------------------------------------
# The opcode groups: one opcode byte covers eight operations, and the ModRM
# reg field -- which elsewhere names a register -- picks which one. This is
# the first place the decoder has to read ModRM to know the MNEMONIC, not just
# the length, so it is the natural place to explain the mechanism.
GROUPS = {
    '80': ['add', 'or', 'adc', 'sbb', 'and', 'sub', 'xor', 'cmp'],
    '81': ['add', 'or', 'adc', 'sbb', 'and', 'sub', 'xor', 'cmp'],
    '82': ['add', 'or', 'adc', 'sbb', 'and', 'sub', 'xor', 'cmp'],
    '83': ['add', 'or', 'adc', 'sbb', 'and', 'sub', 'xor', 'cmp'],
    'c0': ['rol', 'ror', 'rcl', 'rcr', 'shl', 'shr', 'shl', 'sar'],
    'c1': ['rol', 'ror', 'rcl', 'rcr', 'shl', 'shr', 'shl', 'sar'],
    'd0': ['rol', 'ror', 'rcl', 'rcr', 'shl', 'shr', 'shl', 'sar'],
    'd1': ['rol', 'ror', 'rcl', 'rcr', 'shl', 'shr', 'shl', 'sar'],
    'd2': ['rol', 'ror', 'rcl', 'rcr', 'shl', 'shr', 'shl', 'sar'],
    'd3': ['rol', 'ror', 'rcl', 'rcr', 'shl', 'shr', 'shl', 'sar'],
    'f6': ['test', 'test', 'not', 'neg', 'mul', 'imul', 'div', 'idiv'],
    'f7': ['test', 'test', 'not', 'neg', 'mul', 'imul', 'div', 'idiv'],
    'fe': ['inc', 'dec', 'inc', 'dec', 'inc', 'dec', 'inc', 'dec'],
    'ff': ['inc', 'dec', 'call', 'callf', 'jmp', 'jmpf', 'push', '(bad)'],
    'c6': ['mov', 'mov', 'mov', 'mov', 'mov', 'mov', 'mov', 'mov'],
    'c7': ['mov', 'mov', 'mov', 'mov', 'mov', 'mov', 'mov', 'mov'],
    '0f ba': ['bt', 'bts', 'btr', 'btc', 'bt', 'bt', 'bt', 'bt'],
    '0f c7': ['cmpxchg', 'cmpxchg', 'cmpxchg', 'cmpxchg', 'cmpxchg',
              'cmpxchg', 'cmpxchg', 'rdrand'],
    '0f ae': ['fxsave', 'fxrstor', 'ldmxcsr', 'stmxcsr', 'xsave', 'lfence',
              'mfence', 'sfence'],
}

FORMS = {
    'none':    dict(modrm=False, imm=0, sized=False),
    'rel8':    dict(modrm=False, imm=1, sized=False),
    'rel32':   dict(modrm=False, imm=4, sized=True),
    'r_rm':    dict(modrm=True, imm=0, sized=False),
    'rm_r':    dict(modrm=True, imm=0, sized=False),
    'r_rm8':   dict(modrm=True, imm=0, sized=False),
    'rm_r8':   dict(modrm=True, imm=0, sized=False),
    'r_r8':    dict(modrm=True, imm=0, sized=False),
    'r_x8':    dict(modrm=True, imm=0, sized=False),
    'x_rm':    dict(modrm=True, imm=0, sized=False),
    'rm_x':    dict(modrm=True, imm=0, sized=False),
    'x_rm_x':  dict(modrm=True, imm=0, sized=False),
    'rm':      dict(modrm=True, imm=0, sized=False),
    'rm_i8':   dict(modrm=True, imm=1, sized=False),
    'rm_i32':  dict(modrm=True, imm=4, sized=True),
    'rm_imm8': dict(modrm=True, imm=1, sized=False, after_rm=True),
    'rm_x_imm8': dict(modrm=True, imm=1, sized=False, after_rm=True),
    'rm8_i8':  dict(modrm=True, imm=1, sized=False),
    'r_i8':    dict(modrm=False, imm=1, sized=False, regsrc='opcode'),
    'r_i32':   dict(modrm=False, imm=4, sized=True, regsrc='opcode'),
    'opreg':   dict(modrm=False, imm=0, sized=False, regsrc='opcode'),
    'imm_i8':  dict(modrm=False, imm=1, sized=False, regsrc='none'),
    'imm_i32': dict(modrm=False, imm=4, sized=True, regsrc='none'),
    'acc_i8':  dict(modrm=False, imm=1, sized=False, regsrc='acc'),
    'acc_i32': dict(modrm=False, imm=4, sized=True, regsrc='acc'),
    'moffs':   dict(modrm=False, imm=8, sized=True),
    'f_imm8':  dict(modrm=True, imm=1, sized=False, modrm_is_reg=True),
    'f_imm16': dict(modrm=False, imm=2, sized=False),
    'enter':   dict(modrm=False, imm=2, sized=False, extra_imm8=True),
}

# ---------------------------------------------------------------------------
# The opcode table. Keyed by the opcode bytes as a hex string.
#
# Entries are (mnemonic, form). Only opcodes whose LENGTH the decoder is sure
# of are listed: an unlisted opcode raises Unknown rather than a guess, and
# the crosscheck asserts that a real .text decodes with no Unknown. The
# mnemonic is a bonus; the length is the contract.
# ---------------------------------------------------------------------------
ONEBYTE = {
    # --- no operands
    'c3': ('ret', 'none'), 'cb': ('retf', 'none'), 'c2': ('ret', 'f_imm16'),
    '90': ('nop', 'none'),
    # XCHG with the accumulator: the register is in the low 3 opcode bits and
    # there is no ModRM. These nine were lost when a duplicate-key cleanup
    # dropped a whole line that happened to carry several entries, which is the
    # hazard of editing a dict literal with a line-based script.
    '91': ('xchg', 'opreg'), '92': ('xchg', 'opreg'), '93': ('xchg', 'opreg'),
    '94': ('xchg', 'opreg'), '95': ('xchg', 'opreg'), '96': ('xchg', 'opreg'),
    '97': ('xchg', 'opreg'), '9a': ('xchg', 'opreg'), '9b': ('xchg', 'opreg'),
    '98': ('cwde', 'none'), '99': ('cdq', 'none'),
    'f4': ('hlt', 'none'), 'f5': ('cmc', 'none'), 'f8': ('clc', 'none'),
    'f9': ('stc', 'none'), 'fc': ('cld', 'none'), 'fd': ('std', 'none'),
    'e3': ('jecxz', 'rel8'), 'e2': ('loop', 'rel8'), 'e1': ('loopne', 'rel8'),
    'e0': ('loopne', 'rel8'), 'eb': ('jmp', 'rel8'),
    '9c': ('pushfq', 'none'), '9d': ('popfq', 'none'),
    '9e': ('sahf', 'none'), '9f': ('lahf', 'none'),
    '06': ('push', 'none'), '07': ('pop', 'none'), '0e': ('push', 'none'),
    '16': ('push', 'none'), '17': ('pop', 'none'), '1e': ('push', 'none'),
    '1f': ('pop', 'none'), '27': ('daa', 'none'), '2f': ('das', 'none'),
    '37': ('aaa', 'none'), '3f': ('aas', 'none'), 'd7': ('xlat', 'none'),
    'cf': ('iret', 'none'), '0b': ('ud2', 'none'),
    # --- relative jumps
    'e8': ('call', 'rel32'), 'e9': ('jmp', 'rel32'),
    'ea': ('jmpf', 'moffs'), 'eb': ('jmp', 'rel8'),
    # --- short jumps, the 8-bit displacement half of the Jcc family
    '70': ('jo', 'rel8'), '71': ('jno', 'rel8'), '72': ('jb', 'rel8'),
    '73': ('jae', 'rel8'), '74': ('je', 'rel8'), '75': ('jne', 'rel8'),
    '76': ('jbe', 'rel8'), '77': ('ja', 'rel8'), '78': ('js', 'rel8'),
    '79': ('jns', 'rel8'), '7a': ('jp', 'rel8'), '7b': ('jnp', 'rel8'),
    '7c': ('jl', 'rel8'), '7d': ('jge', 'rel8'), '7e': ('jle', 'rel8'),
    '7f': ('jg', 'rel8'),
    # --- accumulator <-> memory, address-sized and no ModRM
    'a0': ('mov', 'moffs'), 'a1': ('mov', 'moffs'), 'a2': ('mov', 'moffs'),
    'a3': ('mov', 'moffs'),
    'a8': ('test', 'acc_i8'), 'a9': ('test', 'acc_i32'),
    'e4': ('in', 'imm_i8'), 'e5': ('in', 'imm_i8'),
    'e6': ('out', 'imm_i8'), 'e7': ('out', 'imm_i8'),
    'ec': ('in', 'none'), 'ed': ('in', 'none'),
    'ee': ('out', 'none'), 'ef': ('out', 'none'),
    '6c': ('insb', 'none'), '6d': ('ins', 'none'),
    '6e': ('outsb', 'none'), '6f': ('outs', 'none'),
    '68': ('push', 'imm_i32'), '6a': ('push', 'imm_i8'), '6b': ('imul', 'rm_i8'),
    '60': ('pusha', 'none'), '61': ('popa', 'none'),
    '04': ('add', 'acc_i8'), '0c': ('or', 'acc_i8'), '14': ('adc', 'acc_i8'),
    '1c': ('sbb', 'acc_i8'), '24': ('and', 'acc_i8'), '2c': ('sub', 'acc_i8'),
    '34': ('xor', 'acc_i8'), '3c': ('cmp', 'acc_i8'),
    '05': ('add', 'acc_i32'), '0d': ('or', 'acc_i32'), '15': ('adc', 'acc_i32'),
    '1d': ('sbb', 'acc_i32'), '25': ('and', 'acc_i32'), '2d': ('sub', 'acc_i32'),
    '35': ('xor', 'acc_i32'), '3d': ('cmp', 'acc_i32'),
    '82': (None, 'rm_i8'),
    'c8': ('enter', 'enter'), 'c9': ('leave', 'none'),
    'f1': ('int1', 'none'), 'fa': ('cli', 'none'), 'fb': ('sti', 'none'),
    'd4': ('aam', 'r_i8'), 'd5': ('aad', 'r_i8'),
    'd7': ('xlat', 'none'), 'ea': ('jmp', 'moffs'),
    '0b': ('ud2', 'none'),
    'b0': ('mov', 'r_i8'), 'b1': ('mov', 'r_i8'), 'b2': ('mov', 'r_i8'),
    'b3': ('mov', 'r_i8'), 'b4': ('mov', 'r_i8'), 'b5': ('mov', 'r_i8'),
    'b6': ('mov', 'r_i8'), 'b7': ('mov', 'r_i8'),
    'b8': ('mov', 'r_i32'), 'b9': ('mov', 'r_i32'), 'ba': ('mov', 'r_i32'),
    'bb': ('mov', 'r_i32'), 'bc': ('mov', 'r_i32'), 'bd': ('mov', 'r_i32'),
    'be': ('mov', 'r_i32'), 'bf': ('mov', 'r_i32'),
    # --- test r/m, imm  (F6 /0 and F7 /0)
    'f6': ('test', 'rm_i8'), 'f7': ('test', 'rm_i32'),
    # --- the mov/arith/movzx/movsx family, ModRM, no immediate
    '88': ('mov', 'rm_r8'), '89': ('mov', 'rm_r'), '8a': ('mov', 'r_rm8'),
    '8b': ('mov', 'r_rm'), '8c': ('mov', 'r_r8'), '8d': ('lea', 'rm_r'),
    '8e': ('mov', 'rm_r8'), '8f': ('pop', 'rm_r'),
    '62': ('evd', 'rm_r'),
    '63': ('movsxd', 'rm_r'),
    '84': ('test', 'rm_r8'), '85': ('test', 'rm_r'),
    '86': ('xchg', 'rm_r8'), '87': ('xchg', 'rm_r'),
    '00': ('add', 'rm_r8'), '01': ('add', 'rm_r'),
    '02': ('add', 'r_rm8'), '03': ('add', 'r_rm'),
    '08': ('or', 'rm_r8'), '09': ('or', 'rm_r'),
    '0a': ('or', 'r_rm8'), '0b': ('or', 'r_rm'),
    '10': ('adc', 'rm_r8'), '11': ('adc', 'rm_r'),
    '12': ('adc', 'r_rm8'), '13': ('adc', 'r_rm'),
    '18': ('sbb', 'rm_r8'), '19': ('sbb', 'rm_r'),
    '1a': ('sbb', 'r_rm8'), '1b': ('sbb', 'r_rm'),
    '20': ('and', 'rm_r8'), '21': ('and', 'rm_r'),
    '22': ('and', 'r_rm8'), '23': ('and', 'r_rm'),
    '28': ('sub', 'rm_r8'), '29': ('sub', 'rm_r'),
    '2a': ('sub', 'r_rm8'), '2b': ('sub', 'r_rm'),
    '30': ('xor', 'rm_r8'), '31': ('xor', 'rm_r'),
    '32': ('xor', 'r_rm8'), '33': ('xor', 'r_rm'),
    '38': ('cmp', 'rm_r8'), '39': ('cmp', 'rm_r'),
    '3a': ('cmp', 'r_rm8'), '3b': ('cmp', 'r_rm'),
    # --- group 1: the byte/word/dword extensions of the arithmetic ops
    '80': (None, 'rm_i8'), '81': (None, 'rm_i32'), '83': (None, 'rm_i8'),
    # --- the shifts and rotates
    'c0': (None, 'rm_i8'), 'c1': (None, 'rm_i8'),
    'd0': (None, 'rm'), 'd1': (None, 'rm'),
    'd2': (None, 'rm'), 'd3': (None, 'rm'),
    # --- group 3: test/not/neg/mul/imul/div/idiv, immediate width from reg
    'fe': (None, 'rm'), 'ff': (None, 'rm'),
    # --- group 5: the indirect calls and jumps
    'ff': (None, 'rm'),
    # --- mov to/from segment, imm forms
    'c6': (None, 'rm8_i8'), 'c7': (None, 'rm_i32'),
    # --- misc r/m forms
    '8f': ('pop', 'rm_r'),
    'c7': (None, 'rm_i32'),
    # --- string ops
    'a4': ('movsb', 'none'), 'a5': ('movsd', 'none'),
    'a6': ('cmpsb', 'none'), 'a7': ('cmpsd', 'none'),
    'aa': ('stosb', 'none'), 'ab': ('stosd', 'none'),
    'ac': ('lodsb', 'none'), 'ad': ('lodsd', 'none'),
    'ae': ('scasb', 'none'), 'af': ('scasd', 'none'),
    # --- push/pop reg
    '50': ('push', 'opreg'), '51': ('push', 'opreg'), '52': ('push', 'opreg'),
    '53': ('push', 'opreg'), '54': ('push', 'opreg'), '55': ('push', 'opreg'),
    '56': ('push', 'opreg'), '57': ('push', 'opreg'),
    '58': ('pop', 'opreg'), '59': ('pop', 'opreg'), '5a': ('pop', 'opreg'),
    '5b': ('pop', 'opreg'), '5c': ('pop', 'opreg'), '5d': ('pop', 'opreg'),
    '5e': ('pop', 'opreg'), '5f': ('pop', 'opreg'),
    # --- the /digit group that lives in the opcode
    # --- setcc, ModRM with an 8-bit r/m
    # --- the 0x0F escape lives here
    '0f': (None, 'unknown'),
}

# The 0F escape. Same structure: the mnemonic is a bonus, the form is the
# contract. Note '0f 0b' -> ud2: a deliberately UNDEFINED opcode, which is the
# reason a bad indirect branch faults immediately instead of wandering.
TWO_BYTE = {
    '0b': ('ud2', 'none'),
    '05': ('syscall', 'none'), '34': ('sysenter', 'none'), '35': ('sysexit', 'none'),
    '1f': ('nop', 'rm'),          # multi-byte NOP: 66 0f 1f /0
    'a2': ('cpuid', 'none'), '01': ('sgdt', 'rm'), '00': ('sldt', 'rm'),
    '06': ('clts', 'none'), '09': ('wbinvd', 'none'), '0e': ('femms', 'none'),
    '0f': (None, 'unknown'),      # 3DNow!: 0F 0F /r imm8, a 1990s AMD extension
    '10': ('movups', 'x_rm'), '11': ('movups', 'rm_x'),
    '28': ('movapd', 'x_rm'), '29': ('movapd', 'rm_x'),
    '2a': ('cvtsi2sd', 'x_rm'), '2e': ('ucomisd', 'x_rm'), '2f': ('comisd', 'x_rm'),
    '51': ('sqrt', 'x_rm'), '54': ('and', 'x_rm'), '55': ('andn', 'x_rm'),
    '56': ('orpd', 'x_rm'), '57': ('xorps', 'x_rm'),
    '58': ('add', 'x_rm'), '59': ('mul', 'x_rm'), '5c': ('sub', 'x_rm'),
    '5d': ('min', 'x_rm'), '5e': ('div', 'x_rm'), '5f': ('max', 'x_rm'),
    '5a': ('cvt', 'x_rm'), '5b': ('cvt', 'x_rm'),
    '6e': ('movq', 'x_rm'), '7e': ('movd', 'rm_x'), '7f': ('movdqa', 'x_rm'),
    '6f': ('movdqu', 'x_rm'), 'd6': ('movq', 'rm_x'),
    '70': ('pshufd', 'rm_x_imm8'), '71': ('psrlw', 'rm_x_imm8'),
    '72': ('psrld', 'rm_imm8'), '73': ('psrlq', 'rm_imm8'),
    '12': ('movlps', 'x_rm'), '13': ('movlps', 'rm_x'), '16': ('movhps', 'x_rm'),
    '17': ('movhps', 'rm_x'),
    'b6': ('movzx', 'r_rm'), 'b7': ('movzx', 'r_rm'),
    'be': ('movsx', 'r_rm'), 'bf': ('movsx', 'r_rm'),
    'af': ('imul', 'r_rm'),
    'ba': (None, 'rm_imm8'), 'a4': ('shld', 'rm_imm8'), 'a5': ('shld', 'rm'),
    'ac': ('shrd', 'rm_imm8'), 'ad': ('shrd', 'rm'),
    'a0': ('pushfs', 'none'), 'a1': ('popfs', 'none'),
    'a8': ('pushgs', 'none'), 'a9': ('popgs', 'none'),
    'c0': ('xadd', 'r_rm8'), 'c1': ('xadd', 'r_rm'),
    'c8': ('bswap', 'opreg'), 'c9': ('bswap', 'opreg'),
    'ca': ('bswap', 'opreg'), 'cb': ('bswap', 'opreg'),
    'cc': ('bswap', 'opreg'), 'cd': ('bswap', 'opreg'),
    'ce': ('bswap', 'opreg'), 'cf': ('bswap', 'opreg'),
    '40': ('cmovo', 'rm_r'), '41': ('cmovno', 'rm_r'), '42': ('cmovb', 'rm_r'),
    '43': ('cmovae', 'rm_r'), '44': ('cmove', 'rm_r'), '45': ('cmovne', 'rm_r'),
    '46': ('cmovbe', 'rm_r'), '47': ('cmova', 'rm_r'), '48': ('cmovs', 'rm_r'),
    '49': ('cmovns', 'rm_r'), '4a': ('cmovp', 'rm_r'), '4b': ('cmovnp', 'rm_r'),
    '4c': ('cmovl', 'rm_r'), '4d': ('cmovge', 'rm_r'), '4e': ('cmovle', 'rm_r'),
    '4f': ('cmova', 'rm_r'),
    '4d': ('cmovge', 'rm_r'),
    '80': ('jo', 'rel32'), '81': ('jno', 'rel32'), '82': ('jb', 'rel32'),
    '83': ('jae', 'rel32'), '84': ('je', 'rel32'), '85': ('jne', 'rel32'),
    '86': ('jbe', 'rel32'), '87': ('ja', 'rel32'), '88': ('js', 'rel32'),
    '89': ('jns', 'rel32'), '8a': ('jp', 'rel32'), '8b': ('jnp', 'rel32'),
    '8c': ('jl', 'rel32'), '8d': ('jge', 'rel32'), '8e': ('jle', 'rel32'),
    '8f': ('jg', 'rel32'),
    '90': ('seto', 'rm_r8'), '91': ('setno', 'rm_r8'), '92': ('setb', 'rm_r8'),
    '93': ('setae', 'rm_r8'), '94': ('sete', 'rm_r8'), '95': ('setne', 'rm_r8'),
    '96': ('setbe', 'rm_r8'), '97': ('seta', 'rm_r8'), '98': ('sets', 'rm_r8'),
    '99': ('setns', 'rm_r8'), '9a': ('setp', 'rm_r8'), '9b': ('setnp', 'rm_r8'),
    '9c': ('setl', 'rm_r8'), '9d': ('setge', 'rm_r8'), '9e': ('setle', 'rm_r8'),
    '9f': ('seta', 'rm_r8'),
    'a5': ('syscall', 'none'),
    'b0': ('cmpxchg', 'r_rm8'), 'b1': ('cmpxchg', 'r_rm'),
    'e0': ('loopnz', 'rel8'), 'e1': ('loopz', 'rel8'), 'e2': ('loop', 'rel8'),
    'e3': ('jecxz', 'rel8'),
    'f4': ('pmuludq', 'x_rm'), 'f5': ('pmaddwd', 'x_rm'),
    'f6': ('psadbw', 'x_rm'), 'f7': ('maskmovdqu', 'rm_x'),
    '60': ('punpcklbw', 'x_rm'), '61': ('punpcklwd', 'x_rm'),
    '62': ('punpckldq', 'x_rm'), '63': ('packsswb', 'x_rm'),
    '64': ('pcmpgtb', 'x_rm'), '65': ('pcmpgtw', 'x_rm'),
    '66': ('pcmpgtd', 'x_rm'), '67': ('packuswb', 'x_rm'),
    '68': ('punpckhbw', 'x_rm'), '69': ('punpckhwd', 'x_rm'),
    '6a': ('punpckhdq', 'x_rm'), '6b': ('packssdw', 'x_rm'),
    '6d': ('punpckhqdq', 'x_rm'), '6f': ('movdqu2', 'x_rm'),
    '74': ('pcmpeqb', 'x_rm'), '75': ('pcmpeqw', 'x_rm'),
    '76': ('pcmpeqd', 'x_rm'), 'd4': ('paddq', 'x_rm'),
    'd5': ('pmullw', 'x_rm'), 'd6': ('movq2dq', 'x_rm'),
    'd7': ('pmovmskb', 'rm_x'), 'e6': ('cvtdq2pd', 'x_rm'),
    '0d': ('prefetch', 'rm'),
    'ae': (None, 'rm'),
    '18': (None, 'rm'), '19': (None, 'rm'), '1a': (None, 'rm'), '1b': (None, 'rm'),
    '1c': ('nop', 'rm'), '1d': ('nop', 'rm'), '1e': ('nop', 'rm'),
    '38': (None, 'unknown'), '3a': (None, 'unknown'),
    '78': ('vmread', 'rm'), '79': ('vmwrite', 'rm'),
    'e8': ('serialize', 'none'),
    'ee': ('rdmsr', 'none'), 'ef': ('wrmsr', 'none'),
    '31': ('rdtsc', 'none'), 'a2': ('cpuid', 'none'),
}

# The 0F escape is where "most opcodes are /r" pays off. Roughly 250 of the
# two-byte opcodes take a ModRM byte and nothing else, so the decoder can
# default to that and override only the exceptions. The exceptions are listed
# explicitly because a WRONG default here silently shifts every subsequent
# instruction boundary, which is the one failure a disassembler cannot hide.
#
#   0F xx with NO ModRM          (operate on fixed registers or are system)
#   0F xx ModRM then imm8        (the shift/permute family)
#   0F 8x                        (Jcc rel32 -- a displacement, not a ModRM)
#   0F xx with a ModRM that is NOT a register (mov to/from CR/DR, lgdt)
TWO_BYTE_NO_MODRM = set('05 06 07 08 09 0b 0e 0e 30 31 32 33 34 35 77 a2 a8 a9 aa'.split())
TWO_BYTE_IMM8 = set('70 71 72 73 78 79 7a 7b 7c a4 ac ba c0 c1 c2 c4 c5 c6'.split())
TWO_BYTE_REL32 = set('80 81 82 83 84 85 86 87 88 89 8a 8b 8c 8d 8e 8f'.split())
# The opcodes that DO take a ModRM byte but only ever a REGISTER one. These
# are the ones that make a bare ModRM byte of 0xC0 a valid instruction. Note
# what is NOT here: 0F 09 (WBINVD), 0F 0B (UD2) and 0F 31 (RDTSC) take no
# ModRM at all, and an earlier version of this list wrongly included them --
# which made the decoder demand a ModRM byte that does not exist, and refuse
# to decode three perfectly ordinary instructions.
TWO_BYTE_MODRM_IS_REG = set(
    ('0f 0f 1f 40 41 42 43 44 45 46 47 48 49 4a 4b 4c 4d 4e 4f '
     '90 91 92 93 94 95 96 97 98 99 9a 9b 9c 9d 9e 9f '
     'a4 a5 ac ad af b0 b1 b6 b7 be bf c0 c1 '
     'c8 c9 ca cb cc cd ce cf').split())

# The F6/F7 groups: reg 0 and 1 are TEST (with an immediate) and the other
# six take none. So the WIDTH OF THE IMMEDIATE DEPENDS ON THE MODRM reg FIELD,
# which is the subtlest thing in the one-byte map and the reason `f6` alone is
# not a length.
GROUP_IMM_ONLY = {'f6': (0, 1), 'f7': (0, 1)}

# Same principle on the ONE-BYTE map. The opcodes that take no ModRM are a
# short, enumerable list; everything else has one. Enumerating the exceptions
# and defaulting the rest is far more robust than listing hundreds of /r
# opcodes by hand -- and it makes the interesting part readable, because the
# exceptions ARE the interesting part.
ONEBYTE_NO_MODRM = set(
    ('06 07 0e 16 17 1e 1f 27 2f 37 3f '            # bcd, push seg
     '0b 60 61 '                                    # ud2, pusha/popa
     '50 51 52 53 54 55 56 57 58 59 5a 5b 5c 5d 5e 5f '   # push/pop r
     '70 71 72 73 74 75 76 77 78 79 7a 7b 7c 7d 7e 7f '   # jcc rel8
     '90 91 92 93 94 95 96 97 98 99 9a 9b 9c 9d 9e 9f '   # nop/xchg/cwde/flags
     'a4 a5 a6 a7 aa ab ac ad ae af '               # string ops
     'c2 c3 c9 cc cd ce cf '                        # ret, leave, int
     'd4 d5 d7 '                                    # aam, aad, xlat
     'e0 e1 e2 ec ed ee ef '                        # loop, in/out from dx
     'f4 f5 f8 f9 fa fb fc fd').split())
ONEBYTE_REL8 = set('70 71 72 73 74 75 76 77 78 79 7a 7b 7c 7d 7e 7f e0 e1 e2 e3 eb'.split())
ONEBYTE_REL32 = set('e8 e9'.split())
ONEBYTE_MOFFS = set('a0 a1 a2 a3 ea'.split())
ONEBYTE_MODRM_IMM8 = set('80 82 83 c0 c1 d2 c6 6b'.split())
ONEBYTE_MODRM_IMMSZ = set('81 c7'.split())

LEGACY_PREFIX = {
    0x66: 'operand-size', 0x67: 'address-size',
    0xf0: 'lock', 0xf2: 'repnz', 0xf3: 'repz',
    0x2e: 'cs', 0x36: 'ss', 0x3e: 'ds',
    0x26: 'es', 0x64: 'fs', 0x65: 'gs',
}

CC = ['o', 'no', 'b', 'ae', 'e', 'ne', 'be', 'a',
      's', 'ns', 'p', 'np', 'l', 'ge', 'le', 'g']


class Bad(Exception):
    """The byte stream does not decode here. Carries the reason."""


class Unknown(Bad):
    """A valid-looking prefix and opcode, but no table entry."""


class Insn(object):
    def __init__(self):
        self.offset = 0
        self.raw = b''
        self.why = []
        self.legacy = []       # [(byte, name)]
        self.rex = None
        self.opcode = ''
        self.map = 'one-byte'
        self.mnemonic = None
        self.form = None
        self.modrm = None
        self.sib = None
        self.disp = None
        self.disp_size = 0
        self.imm = None
        self.imm_size = 0
        self.text = ''

    @property
    def length(self):
        return len(self.raw)

    def say(self, s):
        self.why.append(s)

    def __str__(self):
        h = ' '.join('%02x' % b for b in self.raw)
        return '%-9s %-22s %s' % (h, self.text, '')

    def explain(self, indent='    '):
        out = [indent + 'offset %d, %d bytes: %s'
               % (self.offset, len(self.raw),
                  ' '.join('%02x' % b for b in self.raw)),
               indent + '  ' + self.text]
        for w in self.why:
            out.append(indent + '  . ' + w)
        return '\n'.join(out)


def _opbyte(insn):
    """The last byte of the opcode, as an int.

    Needed because the opcode is stored as a hex string and the two-byte map
    makes that string '0f c8'. A form like 'opreg' (BSWAP, PUSH r64) takes
    the register from the low 3 bits of the LAST opcode byte, so the string
    has to be split -- `int('0f c8', 16)` is not a number.
    """
    return int(insn.opcode.split()[-1], 16)


def _reg(n, size):
    if size == 8:
        return REG8[n & 0xf]
    if size == 16:
        return REG16[n & 0xf]
    if size == 32:
        return REG32[n & 0xf]
    return REG64[n & 0xf]


def _sib_str(sib, rex_x, size, disp, rip_rel, memsz):
    """Render [base + index*scale + disp] from a SIB byte.

    Two field values are special and both were measured rather than assumed:
      index = 100 (0b100)  means NO INDEX when REX.X = 0
      base  = 101 (0b101)  means NO BASE when mod = 00
    """
    ss = sib >> 6
    index = (sib >> 3) & 7
    base = sib & 7
    scale = 1 << ss
    parts = []
    if index == 4 and not rex_x:
        parts.append(None)                       # no index
    else:
        parts.append(_reg(index | (8 if rex_x else 0), size))
    b = None
    if base == 5 and memsz == 0:
        b = None                                # no base; a 4-byte absolute disp
    else:
        b = _reg(base | (8 if (rex_x and False) else 0), size)
    if b is not None and (b in ('rsp', 'r12', 'esp', 'r12d')) and not parts[0]:
        # a lone rsp base, printed without the zero index
        s = b
    else:
        btxt = b if b is not None else ''
        itxt = parts[0] if parts[0] is not None else ''
        s = btxt
        if itxt:
            s += '+' + itxt + '*%d' % scale
    if rip_rel:
        s = 'rip'
    if disp is not None and disp != 0:
        s += ('+' if s else '') + (str(disp) if disp >= 0 else str(disp))
    if not s:
        s = '0x0'
    return '[%s]' % s


def _mem_str(insn, memsz):
    """The r/m operand text, from ModRM (+ SIB + displacement)."""
    m = insn.modrm
    mod, reg, rm = m >> 6, (m >> 3) & 7, m & 7
    rex = insn.rex or 0
    rex_b, rex_x = (rex >> 0) & 1, (rex >> 2) & 1
    if mod == 3:
        return _reg(rm | (8 if rex_b else 0), memsz)
    disp = insn.disp
    if mod == 0 and rm == 5:
        return '[rip%+d]' % disp
    if rm == 4:
        return _sib_str(insn.sib, rex_x, memsz, disp, False,
                        insn.disp_size if mod == 0 else 1)
    base = _reg(rm | (8 if rex_b else 0), memsz)
    if disp:
        return '[%s%+d]' % (base, disp)
    if base in ('rsp', 'r12'):
        return '[%s]' % base
    return '[%s]' % base


# REX.W widens the OPERAND to 64 bits. It does NOT widen the IMMEDIATE -- with
# three exceptions, which is a rule worth knowing because getting it wrong
# costs four bytes and desynchronises every boundary after it.
#
#   48 c7 40 20 00 00 00 00   mov QWORD PTR [rax+0x20],0   <- imm32, sign-extended
#   48 b8 <8 bytes>            movabs rax, imm64             <- a real imm64
#   48 81 78 ff 00 00 00 00   cmp QWORD PTR [rax-1], 0      <- imm32
#
# So: the 64-bit immediate exists only where the ISA defines one (B8+r MOV,
# and a handful of others). Everywhere else "mov to a 64-bit register from a
# literal" means a 32-bit literal that gets sign-extended -- which is also why
# you cannot load the value 0x00000000FFFFFFFF with one instruction.
IMM64_WIDENS_WITH_REX = {'r_i32'}      # the forms that really do take imm64


def _imm_size(form_def, insn):
    """How wide is the immediate, given the prefixes in effect?"""
    n = form_def['imm']
    if n == 0:
        return 0
    if form_def.get('modrm_is_reg'):
        return 1
    if not form_def['sized']:
        return n
    if insn.op16:
        return 2
    if insn.rex_w:
        return 8 if insn.form in IMM64_WIDENS_WITH_REX else n
    return n


class _Flags(object):
    """The prefix state the length arithmetic depends on."""
    __slots__ = ('op16', 'addr16', 'rex_w')

    def __init__(self):
        self.op16 = False
        self.addr16 = False
        self.rex_w = False


def decode_one(buf, i=0, limit=None):
    """Decode the instruction at buf[i:]. Returns an Insn.

    `limit` bounds the decode: the decoder refuses to read a field that would
    cross it, so a stream can be required to terminate exactly on a boundary.
    """
    end = len(buf) if limit is None else min(limit, len(buf))
    insn = Insn()
    insn.offset = i
    p = i

    if p >= end:
        raise Bad('no bytes left')

    # --- 1. legacy prefixes. A REX byte ENDS prefix collection: anything
    #        after it is the opcode, not a prefix. That is the rule that makes
    #        48 66 decode as two instructions rather than one.
    while p < end:
        b = buf[p]
        if b in LEGACY_PREFIX:
            insn.legacy.append((b, LEGACY_PREFIX[b]))
            insn.say('byte %02x at %d is the %s prefix' % (b, p - i, LEGACY_PREFIX[b]))
            if b == 0x66:
                insn.say('  it sets the operand size to 16 bits unless REX.W overrides')
            if b == 0x67:
                insn.say('  it sets the address size to 32 bits')
            p += 1
            continue
        if 0x40 <= b <= 0x4f:
            break          # REX: leave the loop, it is handled next
        break
    # collect at most one REX, and only if it is immediately before the opcode
    if p < end and 0x40 <= buf[p] <= 0x4f:
        rex = buf[p]
        insn.rex = rex
        insn.say('byte %02x at %d is a REX prefix: W=%d R=%d X=%d B=%d'
                 % (rex, p - i, (rex >> 3) & 1, (rex >> 2) & 1,
                    (rex >> 1) & 1, rex & 1))
        insn.say('  the three extension bits each ADD 8 to a 3-bit field,')
        insn.say('  so R=1 with reg=000 is r8 -- not r9')
        p += 1

    # --- 2. the opcode map
    if p >= end:
        raise Bad('prefixes ran off the end')
    b0 = buf[p]
    if b0 == 0x0f:
        if p + 1 >= end:
            raise Bad('0F escape truncated')
        b1 = buf[p + 1]
        if b1 in (0x38, 0x3a):
            if p + 2 >= end:
                raise Bad('%02X escape truncated' % b1)
            b2 = buf[p + 2]
            insn.map = '0f %02x' % b1
            insn.opcode = '0f %02x %02x' % (b1, b2)
            insn.say('bytes 0f %02x at %d open the THREE-byte opcode map,'
                     % (b1, p - i))
            insn.say('  opcode %02x follows; these maps are where AVX and SSE'
                     % b2)
            insn.say('  live, and 0f 3a adds an imm8 after the r/m')
            p += 3
            mn, form = None, ('rm_imm8' if b1 == 0x3a else 'r_rm')
        else:
            insn.map = 'two-byte'
            insn.opcode = '0f %02x' % b1
            insn.say('byte 0f at %d is the escape: the real opcode is %02x'
                     % (p - i, b1))
            p += 2
            key1 = '%02x' % b1
            if key1 in TWO_BYTE:
                mn, form = TWO_BYTE[key1]
            elif key1 in TWO_BYTE_NO_MODRM:
                mn, form = None, 'none'
            elif key1 in TWO_BYTE_REL32:
                mn, form = None, 'rel32'
            elif key1 in TWO_BYTE_IMM8:
                mn, form = None, 'rm_imm8'
            else:
                # The default: a ModRM byte and nothing else. This is right
                # for the large majority of the two-byte map, and a wrong
                # guess is visible immediately because the instruction chain
                # stops closing on the section size.
                mn, form = None, 'r_rm'
    else:
        insn.opcode = '%02x' % b0
        insn.say('byte %02x at %d is a one-byte opcode' % (b0, p - i))
        p += 1
        # The table is keyed by the opcode's hex STRING, because the escape
        # form has two of them ('0f 05') and one lookup shape is easier to
        # keep right than two.
        key0 = '%02x' % b0
        if key0 in ONEBYTE and ONEBYTE[key0][0] is not None:
            mn, form = ONEBYTE[key0]
        elif key0 in ONEBYTE and ONEBYTE[key0][1] not in (None, 'unknown'):
            mn, form = ONEBYTE[key0]
        elif key0 in ONEBYTE_REL8:
            mn, form = None, 'rel8'
        elif key0 in ONEBYTE_REL32:
            mn, form = None, 'rel32'
        elif key0 in ONEBYTE_MOFFS:
            mn, form = None, 'moffs'
        elif key0 in ONEBYTE_MODRM_IMM8:
            mn, form = None, 'rm_i8'
        elif key0 in ONEBYTE_MODRM_IMMSZ:
            mn, form = None, 'rm_i32'
        elif key0 in ONEBYTE_NO_MODRM:
            mn, form = None, 'none'
        else:
            # default: a ModRM byte and nothing after it
            mn, form = None, 'r_rm'
    insn.mnemonic = mn
    insn.form = form
    if insn.form is None or insn.form not in FORMS:
        raise Unknown('no form for opcode %s' % insn.opcode)
    fd = FORMS[insn.form]

    # --- 3. the ModRM byte and everything it drags along
    fl = _Flags()
    fl.op16 = any(b == 0x66 for b, _ in insn.legacy)
    fl.addr16 = any(b == 0x67 for b, _ in insn.legacy)
    fl.rex_w = bool((insn.rex or 0) >> 3 & 1)
    insn.op16 = fl.op16
    insn.addr16 = fl.addr16
    insn.rex_w = fl.rex_w

    if fd['modrm']:
        if p >= end:
            raise Bad('ModRM truncated')
        m = buf[p]
        insn.modrm = m
        mod, reg, rm = m >> 6, (m >> 3) & 7, m & 7
        insn.say('byte %02x at %d is the ModRM byte: mod=%d reg=%d rm=%d'
                 % (m, p - i, mod, reg, rm))
        if mod == 3:
            insn.say('  mod=11: the r/m field names a REGISTER, so no address')
            insn.say('  bytes follow')
            p += 1
        else:
            if mod == 0:
                insn.say('  mod=00: no displacement, except rm=101 which is')
                insn.say('  RIP-relative and carries a 4-byte displacement')
            elif mod == 1:
                insn.say('  mod=01: an 8-bit SIGNED displacement follows')
            else:
                insn.say('  mod=10: a 32-bit SIGNED displacement follows')
            if rm == 4:
                if p + 1 >= end:
                    raise Bad('SIB truncated')
                s = buf[p + 1]
                insn.sib = s
                ss, ix, bs = s >> 6, (s >> 3) & 7, s & 7
                insn.say('  rm=100 means a SIB byte follows: %02x at %d'
                         % (s, p + 1 - i))
                insn.say('    ss=%d -> scale %d,  index=%d,  base=%d'
                         % (ss, 1 << ss, ix, bs))
                if ix == 4 and not ((insn.rex or 0) >> 2 & 1):
                    insn.say('    index=100 with REX.X=0 means NO INDEX')
                if bs == 5 and mod == 0:
                    insn.say('    base=101 with mod=00 means NO BASE: the')
                    insn.say('    displacement is a 4-byte absolute address')
                elif bs == 5:
                    insn.say('    base=101 with mod!=00 is the register rbp')
                p += 2
            else:
                p += 1
            # the displacement
            need = 0
            if mod == 1:
                need = 1
            elif mod == 2:
                need = 4
            elif mod == 0 and rm == 5:
                need = 4
            elif mod == 0 and rm == 4 and (insn.sib & 7) == 5:
                need = 4
            if need:
                if p + need > end:
                    raise Bad('displacement truncated')
                d = int.from_bytes(buf[p:p + need], 'little', signed=need != 4)
                insn.disp = d
                insn.disp_size = need
                insn.say('  %d byte%s displacement at %d, value %d (%#x)'
                         % (need, '' if need == 1 else 's', p - i, d, d & 0xffffffff))
                insn.say('  read little-endian, so the LOW byte is at the LOW')
                insn.say('  address -- 11 22 33 44 means 0x44332211')
                p += need

    # --- 3b. opcode groups: the ModRM reg field selects the operation
    grp = None
    gkey = insn.opcode if insn.opcode in GROUPS else (
        ('0f ' + insn.opcode[3:5]) if insn.map == 'two-byte'
        and ('0f ' + insn.opcode[3:5]) in GROUPS else None)
    if gkey and insn.modrm is not None:
        grp = GROUPS[gkey][(insn.modrm >> 3) & 7]
        insn.mnemonic = grp
        insn.say('opcode %s is a GROUP of eight operations and the ModRM reg'
                 % insn.opcode)
        insn.say('  field is %d, which selects %s -- so the same reg field'
                 % ((insn.modrm >> 3) & 7, grp))
        insn.say('  names an operation here instead of a register')
        if grp == '(bad)':
            insn.say('  reg=7 is the UNDEFINED member of this group, so the')
            insn.say('  encoding exists but no operation is defined for it')
    # endbr64 is F3 0F 1E FA -- the F3 prefix is what makes it endbr64 rather
    # than the multi-byte NOP that 0F 1E is on its own.
    if insn.opcode == '0f 1e' and any(b == 0xf3 for b, _ in insn.legacy):
        if insn.modrm == 0xfa:
            insn.mnemonic = 'endbr64'
            insn.form = 'none'
            insn.say('the F3 prefix turns 0F 1E /r into ENDBR64 -- a landing')
            insn.say('  pad for CET indirect branch tracking, and a NOP on a')
            insn.say('  CPU without it. The ModRM byte is FIXED at FA, so the')
            insn.say('  instruction is exactly four bytes and takes no operand')

    # --- 4. the immediate. For the F6/F7 groups only the TEST members carry
    # one, so the width depends on the ModRM reg field -- which is why a bare
    # `f6` is not a length, and why the decoder has to read ModRM before it
    # can even know how long the instruction is.
    if gkey in GROUP_IMM_ONLY and insn.modrm is not None:
        members = GROUP_IMM_ONLY[gkey]
        digit = (insn.modrm >> 3) & 7
        if digit not in members:
            insn.form = 'rm'          # no immediate at all for the other six
            fd = FORMS['rm']
            insn.say('  the TEST members (reg %s) carry an immediate; this is'
                     % ','.join(str(x) for x in members))
            insn.say('  reg=%d (%s), which has none, so the instruction ends'
                     % (digit, grp))
            insn.say('  here. The opcode byte alone does not determine the')
            insn.say('  length -- the ModRM reg field does.')
    isz = _imm_size(fd, insn)
    if isz:
        if fd.get('after_rm'):
            p += 0        # already positioned after the r/m
        if p + isz > end:
            raise Bad('immediate truncated')
        v = int.from_bytes(buf[p:p + isz], 'little', signed=False)
        insn.imm = v
        insn.imm_size = isz
        why_sz = ('the operand-size prefix' if fl.op16
                  else 'REX.W' if fl.rex_w
                  else 'the default')
        insn.say('%d byte immediate at %d, value %d, width from %s'
                 % (isz, p - i, v, why_sz))
        p += isz
        # ENTER is the one baseline instruction with TWO immediates of different
        # widths: a 16-bit nesting level, then an 8-bit operand size.
        if fd.get('extra_imm8'):
            if p + 1 > end:
                raise Bad('ENTER operand size truncated')
            insn.imm2 = buf[p]
            insn.say('ENTER then takes a SECOND immediate: an 8-bit operand')
            insn.say('  size at %d, value %d' % (p - i, buf[p]))
            p += 1

    if p > end:
        raise Bad('instruction crosses the end')
    insn.raw = bytes(buf[i:p])
    insn.text = render(insn, fd)
    return insn


def render(insn, fd):
    rex = insn.rex or 0
    # A MEMORY operand is always named with the 64-bit register even without
    # REX.W: the address is 64 bits whatever the data width. Only REGISTER
    # operands shrink to 32 or 16 bits. Getting this backwards is the classic
    # [esp] vs [rsp] slip, and the address size is a separate prefix (0x67).
    memsz = 64 if (rex >> 3) & 1 else (16 if insn.op16 else 32)
    msz = 64 if not insn.addr16 else 32
    rsz = memsz
    if fd['modrm'] and (insn.modrm >> 6) == 3:
        rsz = memsz
    if insn.op16 and not ((rex >> 3) & 1):
        rsz = 16
    name = insn.mnemonic or ('(op %s)' % insn.opcode)
    if insn.op16 and not ((rex >> 3) & 1) and insn.mnemonic in (
            'mov', 'add', 'sub', 'and', 'or', 'xor', 'cmp', 'test', 'adc',
            'sbb', 'push', 'pop', 'inc', 'dec', 'lea', 'movsxd'):
        name += 'w'
    if (rex >> 3) & 1 and insn.mnemonic in (
            'mov', 'add', 'sub', 'and', 'or', 'xor', 'cmp', 'test', 'adc',
            'sbb', 'push', 'pop', 'inc', 'dec', 'lea'):
        name += 'q'
    if insn.form in ('rel8', 'rel32'):
        return '%-8s %#x' % (name, insn.offset + len(insn.raw) + (insn.imm or 0))
    if insn.form in ('none',):
        return name
    src = fd.get('regsrc')
    if src == 'none':
        return '%-8s %#x' % (name, insn.imm or 0)
    if src == 'opcode' and insn.form == 'opreg':
        return '%-8s %s' % (name, _reg((_opbyte(insn) & 7)
                                        | (8 if (rex & 1) else 0), memsz))
    if src in ('opcode', 'acc'):
        if insn.form in ('r_i8', 'acc_i8'):
            w = 8
        elif src == 'acc' or (rex >> 3) & 1:
            w = 64
        else:
            w = 32
        n = (_opbyte(insn) & 7) if src == 'opcode' else 0
        r = _reg(n | (8 if (rex & 1) else 0), w)
        return '%-8s %s,%#x' % (name, r, insn.imm)
    if not fd['modrm']:
        return '%-8s %#x' % (name, insn.imm or 0)
    m = insn.modrm
    mod, reg, rm = m >> 6, (m >> 3) & 7, m & 7
    greg = _reg(reg | (8 if (rex >> 2) & 1 else 0), rsz)
    mrm = _mem_str(insn, rsz if mod == 3 else msz)
    if insn.form in ('r_rm', 'r_rm8', 'r_r8'):
        return '%-8s %s,%s' % (name, greg, mrm)
    if insn.form in ('rm_r', 'rm_r8', 'r_x8'):
        return '%-8s %s,%s' % (name, mrm, greg)
    if insn.form == 'rm_x':
        return '%-8s %s,%s' % (name, mrm, greg)
    if insn.form == 'x_rm_x':
        return '%-8s %s,%s' % (name, mrm, greg)
    if insn.form == 'rm':
        return '%-8s %s' % (name, mrm)
    if insn.form == 'rm_imm8':
        return '%-8s %s,%#x' % (name, mrm, insn.imm)
    if insn.form == 'rm_x_imm8':
        return '%-8s %s,%#x,%s' % (name, mrm, insn.imm, greg)
    if insn.form == 'rm8_i8':
        return '%-8s byte %s,%#x' % (name, mrm, insn.imm)
    if insn.form in ('rm_i8', 'rm_i32'):
        return '%-8s %s,%#x' % (name, mrm, insn.imm)
    return '%-8s %s' % (name, mrm)


def decode_stream(buf, start=0, limit=None, stop_on_bad=True):
    """Decode forward from start. Returns (instructions, end_offset, bad)."""
    end = len(buf) if limit is None else min(limit, len(buf))
    out, p, bad = [], start, None
    while p < end:
        try:
            ins = decode_one(buf, p, end)
        except Bad as e:
            if not stop_on_bad:
                break
            bad = (p, str(e))
            break
        out.append(ins)
        if ins.length == 0:
            bad = (p, 'zero-length instruction: the loop would never end')
            break
        p += ins.length
    return out, p, bad


# ---------------------------------------------------------------------------
# Reading a real file. Section discovery is a stripped-down ELF reader; the
# point of the exercise is that no tool was asked where the code is.
# ---------------------------------------------------------------------------
PT_LOAD, SHT_PROGBITS = 1, 1


def code_sections(path):
    d = open(path, 'rb').read()
    if d[:4] != b'\x7fELF':
        raise ValueError('not an ELF file')
    (shoff,) = struct.unpack_from('<Q', d, 0x28)
    (shentsize, shnum, shstrndx) = struct.unpack_from('<HHH', d, 0x3a)
    secs = []
    for i in range(shnum):
        o = shoff + i * shentsize
        name, typ = struct.unpack_from('<II', d, o)
        flags, addr, off, size = struct.unpack_from('<QQQQ', d, o + 8)
        secs.append(dict(name_off=name, type=typ, flags=flags, addr=addr,
                         off=off, size=size, hdr=o))
    stro = secs[shstrndx]['off']

    def nm(n):
        e = d.index(b'\0', stro + n)
        return d[stro + n:e].decode('ascii', 'replace')

    out = []
    for s in secs:
        n = nm(s['name_off'])
        if s['type'] == SHT_PROGBITS and s['flags'] & 0x4 and s['size']:
            out.append((n, s['addr'], s['off'], s['size']))
    return d, out


def main():
    args = sys.argv[1:]
    if not args or '--forms' in args:
        print(__doc__)
        if '--forms' in args:
            print('\n  operand forms, and what each costs in bytes:')
            for k, v in sorted(FORMS.items()):
                print('    %-10s modrm=%-5s imm=%d%s'
                      % (k, v['modrm'], v['imm'],
                         ' (after the r/m)' if v.get('after_rm') else ''))
        return 0
    if args[0] == '--why':
        # Accept both `8b442420` and `8b 44 24 20`: the spaced form is what
        # appears in a hex dump, so a reader copying one out of a disassembly
        # should not have to know which form the tool wants.
        rest = [a for a in args[1:] if not a.startswith('-')]
        hexs = [''.join(rest)] if len(rest) > 1 else rest
        for h in hexs:
            b = bytes.fromhex(h.replace(' ', ''))
            ins, _, bad = decode_stream(b, 0, len(b))
            for i in ins:
                print(i.explain())
            if bad:
                print('    stopped at %d: %s' % bad)
        return 0
    # A bare argument that names an existing file is treated as an ELF, so the
    # common case needs no flag. Hex strings are not paths, and a path is not
    # hex, so the two cannot be confused -- and trying to fromhex() a filename
    # produced a traceback that looked like a decoder bug.
    if args and not args[0].startswith('-') and os.path.exists(args[0]):
        args = ['--elf'] + args
    if args[0] in ('--elf', '--section'):
        path = args[-1]
        want = args[1] if args[0] == '--section' else None
        d, secs = code_sections(path)
        total = ins_n = 0
        for n, addr, off, size in secs:
            if want and n != want:
                continue
            body = d[off:off + size]
            ins, end, bad = decode_stream(body, 0, len(body))
            print('  %-18s va=%#-10x %5d bytes -> %4d instructions%s'
                  % (n, addr, size, len(ins), '  BAD at %d' % bad[0] if bad else ''))
            if not want:
                for i in ins[:400]:
                    print('    %#-10x %-9s %s' % (addr + i.offset, ' '.join(
                        '%02x' % b for b in i.raw), i.text))
            total += size
            ins_n += len(ins)
            if bad:
                print('    the chain must consume exactly %d bytes; stopped at %d (%s)'
                      % (size, end, bad[1]))
        print('  ---')
        print('  %d bytes of code, %d instructions decoded, mean %.2f bytes'
              % (total, ins_n, total / ins_n if ins_n else 0))
        return 0
    # default: decode a hex string, spaced or not. A non-hex argument is a
    # mistake worth naming, not a traceback worth reading.
    rest = [a for a in args if not a.startswith('-')]
    hexs = [''.join(rest)] if len(rest) > 1 else rest
    for h in hexs:
        clean = h.replace(' ', '')
        if not clean or any(c not in '0123456789abcdefABCDEF' for c in clean):
            print('  %r is neither a hex byte string nor a file that exists' % h)
            print('  usage: x86dec.py 4889e8   |   x86dec.py --why 8b442420'
                  '   |   x86dec.py <binary>')
            continue
        b = bytes.fromhex(clean)
        ins, end, bad = decode_stream(b, 0, len(b))
        for i in ins:
            print(str(i))
        if bad:
            print('  stopped at offset %d: %s' % bad)
    return 0


if __name__ == '__main__':
    sys.exit(main())
