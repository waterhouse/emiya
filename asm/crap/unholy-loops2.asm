

        ;; It would appear that dealing with interrupts is simply *too hard*,
        ;; at least for the moment.
        ;; (Intended for multiprocessing.)
        ;; Basically, to deal with them in compiled code, I would have to do one of:
        ;; - Have a convention where only certain registers ever contain pointers.
        ;; - Have a convention within each chunk of compiled code where only certain
        ;;   registers ever contain pointers.
        ;; - Compute, between every instruction in compiled code, which registers
        ;;   contain maybe-pointers, and annotate compiled code sufficiently to do this.
        ;; (This is the problem that, I suppose, Shivers and Appel have faced.
        ;;  Though I believe my constraints are bigger: I want real-time guarantees,
        ;;  and I'd like to have threads tell each other about GC flips with signals.)
        ;; Furthermore:
        ;; To run user-supplied code (e.g. C graphics libraries)...
        ;; I could:
        ;; - turn off interrupts at every C call, and turn them back on afterward
        ;;   (this sucks performance-wise for every C call, and also, if the C code
        ;;    was doing a serious autistic loop, the rest of the threads would be sitting
        ;;    around doing almost nothing until the C code finally returned, which
        ;;    could be problematic)
        ;; - maybe figure out a way for an interrupt handler, triggered during C, to
        ;;   write to
        ;;   (this seems like it'll complicate the handler... eh, maybe not too much.
        ;;    still, I am not sure how you can figure out which thread you are within
        ;;    a handler. at any rate, this still has the "stuck in an autistic loop"
        ;;    problem)
        ;; - instruct the user to use C libraries that know where they keep their
        ;;   pointers (HAHAHAHAHAHAHAHAHAHAHAHA HAHA HAH HA HA HA HA oh man)

        ;; So... an alternative is to replace interrupts with polling.
        ;; I was struck by Appel's terrible example.
        ;; p. 176 of Compiling with Continuations, with description on p. 177.
;; h0:     # n=r2, h1=r4, k2'=r5, k3'=r6
;;         r0 = r12+r13    # will overflow on heap exhaustion
;;         r3 = M[r4+0]    # k0'=r3
;;         r4 = M[r4+4]    # k1'=r4
;;         r2 = r2+2       # n'=r2
;;         jump r3
        ;; In this case, r4 is a chain of closure things that look like [continuation <whatever>].
        ;; Most of the continuations are h0.
        ;; So this will be a tight loop of 4 instructions.
        ;; However, there is a fifth instruction, the heap check.
        ;; He says it right there:
        ;;   Since the function h0 does not allocate any records, we could eliminate its heap-
        ;;   limit check and still be guaranteed that the heap would not overflow. However,
        ;;   this could make the asynchronous signal handler wait long periods between safe
        ;;   points (see Section 16.6).
        ;; Welp.

        ;; I've seen and considered such ideas before, but I didn't take them seriously.
        ;; Now I am.
        ;; ... This seems to be an unusual example.
        ;; Anyway.
        ;; I have rejected such polling ideas in the past, because I want an autistic
        ;; integer manipulation loop, or something like that (a thing that does no allocation
        ;; and perhaps no memory touching at all), to be as efficient as it can possibly be.
        ;; So no fucking polling at every iteration of the loop.
        ;; But now I am thinking of doing exactly that.
        ;; This is because a) I was butting heads yet again with the problem of doing anything else,
        ;; b) I've seen beta-expansion as loop unrolling and realized you could maybe unroll
        ;; such a loop a step or two, amortizing the cost as +X/2Y instead of +X/Y,
        ;; and c) all discussion of safe-points and stuff.
        ;; Safe-points are where you do a convenient amount of work, then look at whether
        ;; some box has been checked.
        ;; This could involve signal handlers anyway (ones that would check the box and return immediately),
        ;; or could not.

        ;; The idea:
        ;; Every thread shall have a little "mailbox".
        ;; A thread-specific field [each thread should keep a register pointing to
        ;; a vector of thread-specific values] that is usually 0. When you want to register
        ;; some kind of interrupt to a thread, write to its mailbox.  It'll see it soonish.
        ;; (Lolz.)
        ;; Threads could have their own interrupt handlers that they'd actually execute,
        ;; which would store dicks in their mailbox.
        ;; Or we could intend to not have our system handle interrupts at all,
        ;; and implement "there was a GC flip" and "we want you to yield to another thread"
        ;; by writing to a thread's mailbox and just waiting for it to notice.
        ;; They both have their attractions...

        ;; Anyway.
        ;; This would still provide no defense against C code that did a lot of autistic looping.
        ;; You might ensure it could follow fwd'ing ptrs, and ensure it saved all its Arc pointer
        ;; values on the stack, and move the contents of its stack while it was doing whatever the fuck.
        ;; The "ensure it could follow fwd'ing ptrs" part is unrealistic for any off-the-shelf C library.
        ;; So, whatever.
        ;; Programmer beware for that.
        ;; At least that is pretty appropriate to the task at hand.
        ;; (Like, if _you're_ doing autistic things with C code, that's something you should
        ;;  know about.)

        ;; So I came here to measure the effect on good code.
        ;; I am thinking I may do this.
        ;; Konoyo subete no aku.
        ;; Guhhhhhhhhhhhhhhh.
        ;; That's what you get for wanting "real time"!
        ;; 'Hem.

        mov rax, 0xfffefafd

        
        ;; rdi = method
        ;; rsi = n

        ;; ok, my reflexes disagreed with that
        xchg rdi, rsi           ;lolololololol

        push qword 0
        xor edx, edx

        cmp rdi, 0
        je base
        cmp rdi, 1
        je base_unrolled
        cmp rdi, 2
        je checking
        cmp rdi, 3
        je checking_unrolled
        cmp rdi, 4
        je checking_unrolled_4

        ;; I'll test... I suppose...
        ;; There's counting, then triangle,
        ;; then PRNG (ax+b), then PRNG2 (ax+b mod m).
        ;; Those are the obvious things...

base:
        inc rdx
        dec rsi
        jnz base
        pop rax
        ret

base_unrolled:
        inc rdx
        dec rsi
        jz base_unrolled_done
        inc rdx
        dec rsi
        jnz base_unrolled
base_unrolled_done:     
        pop rax
        ret

fake_handler:
        pop rax
        mov rax, 23
        ret
        

checking:
        cmp qword [rsp], 0
        jne fake_handler
        inc rdx
        dec rsi
        jnz checking
        pop rax
        ret

checking_unrolled:
        cmp qword [rsp], 0
        jne fake_handler
        inc rdx
        dec rsi
        jz checking_unrolled_done
        inc rdx
        dec rsi
        jnz checking_unrolled
checking_unrolled_done:
        pop rax
        ret

checking_unrolled_4:
        cmp qword [rsp], 0
        jne fake_handler
        inc rdx
        dec rsi
        jz checking_unrolled_done
        inc rdx
        dec rsi
        jz checking_unrolled_done
        inc rdx
        dec rsi
        jz checking_unrolled_done
        inc rdx
        dec rsi
        jnz checking_unrolled_4
        pop rax
        ret

        ;; Ok,
        ;; "checking" is 2.0x as slow,
        ;; "checking_unrolled" is 1.5x as slow,
        ;; and "checking_unrolled_4" is 1.25x as slow.
        ;; That's kind of extremely accurate.
        ;; Well... can I inflict this?
        ;; I guess I can probably afford it at the start.
        ;; Uniprocessors are so much better...
        ;; (Shit should fucking automatically detect whether
        ;; you're using threads.  Or should assume uniprocessor
        ;; and recompile everything when you create a thread.)


        ;; OH MY GOOOOOOOOOOOOOOOOOOOOOOOD
        ;; Two revelations.
        ;; 1. I could have _most_ functions, or, like, the _default_
        ;;    be "check your fucking mailbox; the signal handler will
        ;;    put dick in your mailbox"; however, you could register
        ;;    any number of individual functions as "self-sufficient",
        ;;    so the signal handler 
        ;; 2. Maybe that BS crap of the stack size limit being in the billions
        ;;    was actually accurate, because it was happening during a
        ;;    call to sleep--a system call, and therefore in the context
        ;;    of the kernel, which plausibly has a giant stack.
        ;;    I 
        ;;
        ;; Unfortunately, the combination of these sucks.
        ;; If the stack you see is a kernel stack, then how can
        ;; you use that to figure out which thread you are?
        ;; That seems like a hard thing to do, _period._


        ;; Aw my gawd.
        ;; http://stackoverflow.com/questions/7296923/different-signal-handler-for-thread-and-process-is-it-possible
        ;;   If you know the signal did not interrupt an async-signal-unsafe function,
        ;;   you could call pthread_self to get the current thread id. Otherwise, one ugly
        ;;   but safe method is to take the address of errno and look up which thread you're
        ;;   in based on that (you'll have to keep a mapping table yourself and ensure that
        ;;   access to this table is async-signal-safe).

        ;; Errno?  Hmm.
        ;; Apparently errno is #defined to be a function, __error.
        ;; I guess I can believe that it might be capable of finding a thread-specific errno.
        ;; That sounds like one thing that would work...

        ;; Btw.
        ;; A more terrible idea is to just use most of the different Unix signals,
        ;; so that SIGINT means you're thread #1, SIGALRM means you're thread #2, and so on.
        ;; This is amazing and terrible.
        ;; It would work, though. For a small number of threads.
        ;; Also I wonder if you could use fucking binary or something.
        ;; Yeeeess... something like it.
        ;; Hey, actually.
        ;; So earlier I thought you could maybe, like,
        ;; have a single global variable, and signal only one thread at a time.
        ;; The signaler should write n to that variable, then signal thread n.
        ;; As a matter of fact, we could use k different signals and k global variables.
        ;; ... That does not sound too bad, to someone who has never used a computer
        ;; with more than 8 virtual CPU cores.
        ;; It's still terrible, though.


        ;; So.
        ;; Two things to do.
        ;; A. See if that "spurious" stack is actually a kernel stack,
        ;;    and if I can get it to be a normal user stack by interrupting it
        ;;    while it's executing a normal loop (as opposed to a system call).
        ;;    This is purely academic: if I want my program to sleep or to do
        ;;    any I/O whatsoever, I will need to use system calls, and therefore
        ;;    it is possible that those will be interrupted, and therefore I can't
        ;;    rely on a method that fails when it interrupts a system call.
        ;; B. Test out this errno approach.
        ;;    (Address of errno.)
        ;;    Make four threads, doing different things.
        ;;    (Mostly sleeping, to avoid working the CPU and pissing me off.)
        ;;    One of them counting, another triangle-ing,
        ;;    maybe some other shit.
        ;;    Prescheduled (this might be done with user input, or scheduled),
        ;;    a controlling thread will announce it'll signal thread n,
        ;;    then it will do so,
        ;;    and we'd better see a "Thread n reporting in" message.
        ;;    Also it'll probably announce the k that it's gotten to,
        ;;    and write to the controlling thread's mailbox the f(k) that it's
        ;;    computing.
        ;;    It may signal the controlling thread, or just wait for it to wake up.
        ;;    I suppose the former is better, and more impressive.
        ;;    Then we'd better see "Thread n reports that k -> f(k)."
        ;;    Continue this for a while.
        ;;    Once it clearly works, it should get boring.

        ;; ... Jesus christ.  It is _no_ more useful to signal a thread and have it
        ;; write to some location that it'll later check _anyway_, than to write
        ;; to that location yourself.  The only difference is maybe some insurance
        ;; that the thread will start executing.
        ;; However, you'd be better off doing something like what Appel describes,
        ;; having each "thread" be some data structure: [lock, register-list, thread-specific dick]
        ;; and then attempting to yield to that thread (grab the lock, store your own
        ;; registers in your own dick, unlock yourself, load its registers, and jump to
        ;; what it was doing).
        ;; I'm going to now be contemptuous of pthreads and whatever.
        ;; (I know of only one thing they provide: thread-local signal masking,
        ;; and even that could be achieved yourself)
        ;; ... I see, there could conceivably be problems down the road with locking.
        ;; E.g. interrupt a thread while it's trying to yield; now both threads are locked.
        ;; Fortunately, at the moment, my design does not have any requirements for
        ;; dealing with interrupts, and that can be dealt with later.
        ;; (E.g. make interrupt handler stfu if the PC is in the yield code.)

        
        