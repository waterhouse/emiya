

        mov rax, 0xfffefafd

        ;; http://www.youtube.com/watch?v=xe821OoYPUY
        ;; We are going to test the speed of call chains and so forth.

        ;; Next task: giant circle (actual call chains).
        ;; --Again, putting dq 69's between "jmp place2" and "place2:" makes no difference.
        ;; Can do 100 of these, 1m rounds, in 65 msec.
        ;; --Derf, the runtime varies weirdly.
        ;; Ok, it's actually slightly faster with "dq 69" in the middle.
        ;; That is,
        ;; arc> (pbcopy:tostring:for i 2 100 (prn "        jmp place" i "\n        dq 69\nplace" i ":"))
        ;; versus
        ;; arc> (pbcopy:tostring:for i 2 100 (prn "        jmp place" i "\nplace" i ":"))
        ;; is like 63-69 msec vs 65-93 msec.
        ;; Fuck, jesus, whatever.
        ;; As for 1000, with the dq in between, it's the same--62-66 msec--but
        ;; with no dq, it's 74-115 msec. (For some weird reason, the _first_ one is fastest. See:
;; arc> (repeat 8 (time:call-chaining2-thing call-chaining2 100000))
;; time: 74 cpu: 74 gc: 0 mem: 0
;; time: 90 cpu: 89 gc: 0 mem: 0
;; time: 92 cpu: 91 gc: 0 mem: 0
;; time: 104 cpu: 104 gc: 0 mem: 0
;; time: 109 cpu: 109 gc: 0 mem: 0
;; time: 115 cpu: 115 gc: 0 mem: 0
;; time: 98 cpu: 98 gc: 0 mem: 0
;; time: 95 cpu: 96 gc: 0 mem: 0
        ;; Feh, jesus.
        ;; Time to try something new.
        ;; arc> (pbcopy:tostring:for i 2 1000 (prn "        add rax, " i "\n        jmp place" i "\nplace" i ":"))
        ;; With adds:
        ;; 70-74 msec for 100k rounds, chain of 1000.
        ;; And 77-83 with adds and the dq back in:
        ;; arc> (pbcopy:tostring:for i 2 1000 (prn "        add rax, " i "\n        jmp place" i "\n        dq 69\nplace" i ":"))

        ;; Now for true terror.
        ;; Ha! At 10k, with adds, with 10k rounds, it is 337-348 msec.
        ;; With no adds, 317-360.
        ;; Oh god I should randomly permute the jumps...
        ;; As well as make this bigger.
        ;; 100k.
        ;; 373-380 with no adds.
        ;; I think I'm overflowing the instruction cache by now...
        ;; Next shall be the permutation.
        ;; (One source says that Intel Nehalem processors may have 32KB inst. caches.
        ;; And same for Core i7, four years later. Mmm.)

        ;; All right...
        ;; 10k dicks, random permutation. Cycle length 3493.
        ;; Code like this:
        ;; arc> (time:pbcopy:tostring:withs (n 10000 u (randperm:range 0 n) b "        ") (= dick u) (on i u (prn:string "place" index ":\n" (if (is index 0) (string b "dec rdi\n" b "jz return\n")) b "jmp place" i)))
        ;; time: 583 cpu: 167 gc: 22 mem: 6594416
        ;; arc> (time:xloop (x dick.0 n 1) (if (is x 0) n (next dick.x inc.n)))
        ;; time: 2 cpu: 2 gc: 0 mem: 752
        ;; 101
        ;; arc> (pbcopy:tostring:withs (n 10000 u (randperm:range 0 n) b "        ") (on i u (prn:string "place" index ":\n" (if (is index 0) (string b "dec rdi\n" b "jz return\n")) b "jmp place" i)))
        ;; Results:
        ;; arc> (time:call-chaining3-thing call-chaining3 (div (expt 10 8) 3493))
        ;; time: 452 cpu: 451 gc: 0 mem: 0 ;with 3493
        ;; With cycle length 419, time is 80-85 msec.
        ;; cycle length 101 => 68-71 msec.
        ;; cycle length 8636 => 539-544 msec.
        ;; Next for actual calls rather than jmps.

        ;; With calling, it's a little amusing...
        ;; If, at the first place, I say "dec rdi; jz return; call dick; ret",
        ;; then when rdi hits 0, there will be a large return stack, and the code at "return"
        ;; will get executed with such a stack.
        ;; So... nerf, better.
        ;; I think I'll need to pass a giant stack to do this crap. (100m words on stack.)
        ;; That, or have a kind of "driving" loop. (Probably best.)

        ;; All right, 2472 cycle.
        ;; Whoa my god.
        ;; arc> (time:call-chaining4-thing call-chaining4 (div (expt 10 8) 2472))
        ;; time: 3440 cpu: 3441 gc: 0 mem: 20456
        ;; 4422516744

        ;; 2840 cycle => 1374 msec
        ;; 2593 cycle => 1356 msec
        ;; 7113 cycle => 1504 msec
        ;; Hmm, maybe dick was a fluke.
        ;; 9829 cycle => 1541 msec
        ;; Seeming consistent.
        ;; 140 cycle => 683-692 msec.
        ;; Note code being used:
        ;; arc> (time:do (pbcopy:tostring:withs (n 10000 u (randperm:range 0 n) b "        ") (= dick u) (on i u (prn:string "place" index ":\n" b (and (isnt i 0) (string "call place" i "\n")) b "ret"))) (xloop (x dick.0 n 1) (if (is x 0) n (next dick.x inc.n))))

        ;; Now back to non-permuted.
        ;; arc> (time:do (pbcopy:tostring:withs (n 10000 u (randperm:range 0 n) b "        ") (= dick u) (on i u (let i (mod inc.index inc.n) (prn:string "place" index ":\n" b (and (isnt i 0) (string "call place" i "\n")) b "ret"))) (xloop (x dick.0 n 1) (if (is x 0) n (next dick.x inc.n)))))
        ;; 1136-1141 msec.
        ;; For 1000 places, 832-834 msec.
        ;; For 100 places, 734-748 msec.
        ;; For 500, 814-819 msec.
        ;; For 40, 563-570 msec.
        ;; (There is a bit of fuzziness with loop overhead and n being n+1 here, so I don't want to go too low.)
        ;; Next it will be time to prepare for inlined dicks...

        
top:
        call place0
        dec rdi
        jnz top
        jmp return

        place0:
        call place1
        ret
place1:
        call place2
        ret
place2:
        call place3
        ret
place3:
        call place4
        ret
place4:
        call place5
        ret
place5:
        call place6
        ret
place6:
        call place7
        ret
place7:
        call place8
        ret
place8:
        call place9
        ret
place9:
        call place10
        ret
place10:
        call place11
        ret
place11:
        call place12
        ret
place12:
        call place13
        ret
place13:
        call place14
        ret
place14:
        call place15
        ret
place15:
        call place16
        ret
place16:
        call place17
        ret
place17:
        call place18
        ret
place18:
        call place19
        ret
place19:
        call place20
        ret
place20:
        call place21
        ret
place21:
        call place22
        ret
place22:
        call place23
        ret
place23:
        call place24
        ret
place24:
        call place25
        ret
place25:
        call place26
        ret
place26:
        call place27
        ret
place27:
        call place28
        ret
place28:
        call place29
        ret
place29:
        call place30
        ret
place30:
        call place31
        ret
place31:
        call place32
        ret
place32:
        call place33
        ret
place33:
        call place34
        ret
place34:
        call place35
        ret
place35:
        call place36
        ret
place36:
        call place37
        ret
place37:
        call place38
        ret
place38:
        call place39
        ret
place39:
        call place40
        ret
place40:
                ret


return:
        ret


        