

        ;; So, the user wants to write a program.
        ;; A program that uses operations like cons, car, cdr, and closure.
        ;; This is some shit the user can include to make a program like that work.

        ;; The user will "%include "gc-system.asm" at the top.
        ;; This will define a bunch of macros that may be used in the user's main program.
        ;; Then the user shall call "gc_footer" at the bottom.
        ;; This will define the "startup_sequence" label, all the startup code,
        ;;  and all the stub functions that are needed.
        ;; Now, there's a bunch of crap that I could choose to put in various places.
        ;; There are the variables like "fromspace_mask", and the jump tables I'll
        ;; define, and the saved_regs table.
        ;; (Closures and the fields before them will necessarily be in the main code.)
        ;; nasm seems to think I should put some of the above in a "data" section, different
        ;; from a "code" or "text" section.
        ;; (It prints a warning with "resq" in a non-data section, it seems.)
        ;; ("bss" section is for resq shit.)
        ;; (..............................
        ;;  Goddammit, according to section 7.9.2 nasm has various default section things,
        ;;  and none of them provides both "exec" and "write".
        ;;  So there's value in my writing shit.
        ;;  However, I could probably tell it to have it be writable and whatnot.
        ;;  Then I could actually run Racket shit.
        ;;  Which might obviate ... much of the startup_sequence I have to write.
        ;;  Possibly all the stuff that's not specific to Arc.)
        
        ;; Now, the info table at least must be defined, and basically therefore must appear,
        ;; after the main user code, because its size comes from the number of times the
        ;; user's code increments "alloc_count".
        ;; Can you have a data section after a code section?
        ;; If you have it after lexically, will nasm reorder them?
        ;; Would that be a problem?
        ;; Could be tested.
        ;; --Looks like: lexical permutations are legal, multiple bss sections and probably
        ;;  any sections are legal, and nasm does reorder them.
        ;; Well... 

        ;; Anyway, meanwhile, I haven't tested and chosen which of a few different
        ;; alloc. and other methods to use, so this will wait a bit...
        












        
