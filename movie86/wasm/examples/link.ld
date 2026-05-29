/* Minimal static i386 link script for the demo fixtures.
 *
 * Goal: a single PT_LOAD covering just `.text`, vaddr = 0x08048000,
 * no section header table, no .symtab / .strtab / .comment / .note.
 * That's the same layout the originally-committed examples shipped
 * with — small enough that the whole file is dominated by the
 * Ehdr (0x34) + Phdr (0x20) and the program bytes themselves.
 *
 * `FILEHDR PHDRS` in the PT_LOAD tells ld to include the ELF header
 * and program header table inside the loaded segment, so the loader
 * maps from file offset 0 to the segment's virtual address. .text
 * follows right after the Phdr table, which means `_start` lives at
 * vaddr = 0x08048000 + 0x54 (= sizeof Ehdr + 1 * sizeof Phdr).
 * Movie86's loader follows whatever `p_vaddr` says, and turbo86's
 * stub maps RWX from 0x08048000 — both engines stay happy.
 *
 * /DISCARD/ drops everything the assembler emits incidentally
 * (.note.GNU-stack from `as`, etc.) so the link output stays tight.
 */
ENTRY(_start)

PHDRS {
    text PT_LOAD FILEHDR PHDRS FLAGS(5);  /* R + X */
}

SECTIONS {
    . = 0x08048000 + SIZEOF_HEADERS;
    .text : { *(.text) } :text

    /DISCARD/ : {
        *(.note*)
        *(.comment)
        *(.debug*)
        *(.eh_frame*)
    }
}
