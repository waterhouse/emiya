

;it is time to parse "instruction signature -> opcode" crap.

;we have a line of (name):, followed by lines of "(arg )*.( opcode)+".

;some instruction names have spaces ("push fs", "jmp far"). might delete spaces or hyphenate or whatever.
;however, for args and opcodes, spaces are separators.

'(or (join (or "rm" "r" "m" "i")
           (or "8" "16" "32" "64"))
     (or "al" "ax" "eax" "rax"))

'(or (with (a (or "rm" "r" "m" "i")
            b (or "8" "16" "32" "64"))))

; [n is 8/16/32/64]
;rn
;rmn
;mn
;in
; [for now just do that; later do below]
;
;al ax eax rax
;

(= opcode (table))


;(add (reg64 0) (imm32 5))

;Things like "0F" or "13" --> 0-255.
(def byteify (x)
  (read:string "#x" x))

;sig: (add reg64 imm32) --> '(<byte>+ (or /r /0-7))
;;Separation of concerns... for now just opcode info.


;Ok fuck me.
;How should the order of the args in "add rdx, rcx" go in the ModRM byte?
;The ModRM byte should have "11" in the top two bits, and then RCX = 001
;and RDX = 010.
;ModRM: [mod=2|reg=3|r/m=3]
;If we use the opcode for "rm64 r64", then we go 48 01 [11|010|001].
;If we use the opcode for "r64 rm64", then we go 48 03 [11|001|010].
;Because the "rm" thing goes in the r/m field.
;This means I can't just say "(reg64 reg64) -> 01 /r or 03 /r, doesn't matter".
;Fuck.  Need to be more detailed.  I'll probably compute a separate table of
;(add reg64 reg64) --> 01, the (reg/mem64 reg64) opcode.
;the REX prefix crap needs to know too, so just make an 'operands-reversed table.


(= operands-reversed (table))

(= valid-arg (table))
(each x '(rm r m i)
  (each n '(8 16 32 64)
    (set:valid-arg:symb x n)))

(def reg-arg (x)
  (mem x '(r8 r16 r32 r64)))
(def r/m-arg (x)
  (mem x '(rm8 rm16 rm32 rm64
           m8 m16 m32 m64)))
(= fullsiggy (table))
(each n '(8 16 32 64)
  (each (x y) '((r reg) (m mem) (i imm))
    (= (fullsiggy:symb x n) (list:symb y n)))
  (= (fullsiggy:symb 'rm n) (map [symb _ n] '(reg mem))))

(def handle-line (s name)
  (let (sig opc) (map tokens (tokens s #\.))
    (withs (sig (map sym sig)
            opc opc ;more later
            modrm-args (keep (orf reg-arg r/m-arg) sig)
            modrm-argc len.modrm-args)
      (awhen (find no:valid-arg sig)
        (err "Not handled yet:" it))
      (each full-sig (map [cons sym.name _]
                          (all-choices list
                                       (map fullsiggy sig)))
        (unless opcode.full-sig
          (when (and (is modrm-argc 2)
                     r/m-arg:car.modrm-args)
            set:operands-reversed.full-sig)
          (= opcode.full-sig opc))))))


(def is-reg (x)
  (mem x '(reg8 reg16 reg32 reg64)))
(def is-mem (x)
  (mem x '(mem8 mem16 mem32 mem64)))
(def is-modrm (x)
  (or is-reg.x is-mem.x))

(def is-imm (x)
  (mem x '(imm8 imm16 imm32 imm64)))

(def modrm-count (arglist)
  (count is-modrm:car arglist))

;now there will probably be a place for instruction overrides

(= inst-override (table))


(each (x y) (tuples 2 '(clc f8
                        cld fc
                        cmc f5
                        stc f9
                        std fd
                        pause (f3 90)
                        cpuid (0f a2)
                        lahf 9f
                        lfence (0f ae e8)))
  (= inst-override.x (fn (xs) (map byteify (if acons.y y list.y)))))
(each (x y) (tuples 2 '(lods ac
                        movs a4
                        outs 6e
                        ins  6c
                        )))


;expected: left arg is left arg, right arg is right arg.
;so (rm r) is reversed, (r rm) is normal.
;... crap will have to be synchronized. like if I reserve "(add reg64 reg64)"
;for the "rm64 r64: 01 /r" opcode, and set operands-reversed = t for (add reg64 reg64),
;then I'd better not then make (add reg64 reg64) -> "r64 rm64: 03 /r" without
;also updating "operands-reversed" for that.

(def asm-inst ((name . arglist))
  (aif inst-override.name
       it.arglist
       (normal-asm-inst:cons name arglist)))

(def is-byte (x)
  (and (is 2 len.x)
       (all [or digit._ (<= #\a downcase._ #\f)] x)))

(def normal-asm-inst (xs)
  (let (name . arglist) xs
    (withs (fsig (if (all alist arglist)
                     (cons name (map car arglist))
                     (err "Arglist?" arglist))
            opc opcode.fsig
            type (list-find modrm-type opc))
      (awhen (find (complement:orf is-byte modrm-type) opc)
        (err "Don't understand opcode piece" it))
      ;(prsn name arglist fsig opc type)
      (join
       (aif (66-prefix fsig) list.it)
       (aif (rex-prefix fsig arglist type) list.it)
       ;now I want some kind of "interpreter" type crap with the opcode business
       (map byteify (keep is-byte opc))
       (let u modrm-count.arglist
         ;prn.u
         (if (is u 0)
             (err "No args for ModRM: override that shit" xs)
             (> u 2)
             (err "More than 2 args?" xs)
             (if (or (and (is u 1) (isa type 'int))
                       (and (is u 2) (is type 'r)))
                 (list:modrm fsig arglist type)
                 (err "Opcode-prescribed ModRM thing disagrees with arglist:"
                      type u xs))))))))

;(each x '(i r m rm)
;  (eval:prn `(def ,(symb 'is- x) (x)
;               (in x ,@(map (fn (n) `',(symb x n)) '(8 16 32 64))))))

(= modrm-type (table)
   (modrm-type "/r") 'r)
(for i 0 7
  (= (modrm-type:string "/" i) i))

(def list-find (f xs)
  (and xs (or f:car.xs (list-find f cdr.xs))))

(mac assert (condition)
  `(unless ,condition
     (err "Assertion failed:" ',condition)))

;there's just a single function, movs, that claims to have "mem mem" operands.
;I'll just assume there is 0 or 1 dick, and maybe override movs specifically.
;and oh jesus the thing that handles REX prefix will need to know too.

(def modrm (fsig arglist type)
  ;at the moment, don't understand mem.
  ;maybe weird crap will be (reg-special es) or smthg?
  (let xs (keep is-reg:car arglist)
    (when (isnt type 'r)
      (push `(fake-reg ,type) xs))
    (let (reg r/m) (map [num->digs (mod cadr._ 8) 2 3] xs) ;xs = ((reg64 n) (reg64 n))
      (when operands-reversed.fsig
        (swap reg r/m))
      (read:string "#b"
                   "11"
                   reg
                   r/m))))

;now some things have default operand size 64b.

(= 64b-default-operand-size (table)) ;indexed on name

(def rex-prefix (fsig arglist mrtype)
  ;again, only handle regs for now
  ;assume modrm-type isn't nil; that would imply no operands and this couldn't tell op size.
  (let xs (keep is-reg:car arglist)
    (when (isnt mrtype 'r)
      (push `(fake-reg ,mrtype) xs))
    (with (rex-w (and (mem [in _ 'reg64 'mem64] cdr.fsig)
                      no:64b-default-operand-size:car.fsig)
           rex-r (is 1 (div cadr:xs.0 8))
           rex-x nil
           rex-b (is 1 (div cadr:xs.1 8)))
      (when operands-reversed.fsig
        (swap rex-r rex-b))
      (let u (+ (if rex-w 8 0)
                (if rex-r 4 0)
                (if rex-x 2 0)
                (if rex-b 1 0))
        (if (is u 0)
            nil
            (+ u 64))))))

(def 66-prefix (fsig)
  (if (find [in _ 'reg16 'mem16 'imm16] fsig)
      102
      nil))



;to access things like AH, use 16-bit addressing (address size override).
;seems that crap is incompatible with a REX prefix, prob'ly because that
;enables access to the big things... I dunno.

;an instruction with an opcode indicating 8-bit operands
;when called with a 16-bit address size override thing
;will treat references to sp-di as ah-bh.

;as for 


(= reg-order
   '(rax rcx rdx rbx rsp rbp rsi rdi
     r8 r9 r10 r11 r12 r13 r14 r15)
   name-reg (table))

(on rname '(ax cx dx bx sp bp si di)
  (= (name-reg:symb 'r rname) `(reg64 ,index)
     (name-reg:symb 'e rname) `(reg32 ,index)
     (name-reg rname) `(reg16 ,index)))
(on rname '(a c d b)
  (= (name-reg:symb rname 'l) `(reg8 ,index)
     ;(name-reg:symb rname 'h) `(reg8 ,(+ index 4)))) ;psyduck; needing 16b addressing must be handled elsewhere
     ))
(on rname '(sp bp si di)
  (= (name-reg rname 'l) `(reg8 ,(+ index 4))))
(for i 8 15
  (each (x y) (tuples 2 '(b 8 w 16 d 32 "" 64))
    (= (name-reg:symb 'r i x) `(,(symb 'reg y) ,i))))

;(on r reg-order
;  (= name-reg.index `(reg64 ,r)))

(def asm-1 (xs)
  (asm-inst (map [aif name-reg._ it _] xs)))

(mac asi xs
  `(no:apply prsn (map [hexify _ 2] (asm-1 ',xs))))


(def strip-comment (xt)
  (aif (pos #\; xt)
       (cut xt it)
       xt))

(= opcode (table))
(let inst nil
  (each l (lines:filechars:home "Dropbox/asm/opcodes.txt")
    (zap strip-comment l)
    (aif (pos #\: l)
         (= inst (cut l 0 it))
         (errsafe:handle-line l inst))))