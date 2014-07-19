FOR-EACH
OH GOD

Also getting a list of keys.
And maybe values.
And both.
These are important and should not be neglected.
......
Options...
The only problem is with resizing and copying.
Basically, it seems like iterating through the dick
should not miss any items and not duplicate any items,
although it is forgivable if it uses old values of
things that were modified during, gets some newly
created entries and not others, gets some deleted
entries and not others, etc.

Options to deal with that:
- Lock table to prevent resizing while doing this
  crap.  Hate locks.
- Look through old table, then new table, and disambig.
  Disambig. using ... a table you newly allocate.
  Bunch of work and garbage allocated.  Hate that too.
- If half-resized, help finish resizing work; then try
  to grab all kv's from the table, and check if a resize
  occurred in the meantime, and if so, fail and retry
  again.
  Potentially a lot of work, although still O(n) total,
  although O(1) latency -> O(n) for iteration.
  (Thing about iteration is, it is done for side effect,
  and unless the side effect is idempotent, you can't
  abort and retry from the beginning without changing
  program semantics.)
  You can at least just collect the "p" conses (and not
  collect any nils), so that's a bit of space-saving.

I think I'm in favor of the last option.
It does mean consing for an operation that shouldn't
require consing: iterating and adding up integers or
whatever.
But it works ok, and if you want non-consing, you can
lock the fucking table.  I could provide that as a
primitive too.



...
I think I really don't need the address.
Rediscoverable. Caching it is an optimization.
...
Although, actually, I do need v for lookups.
(Otherwise no way to get v.)
Really this could return a shitload of values.
(Which it effectively does, through global variables,
 in the IBM example.)
...
Never mind, you're an idiot.
If you find dick, it just might be out of date or something.
Ok, let's be strict.




find-pair(table, key, hash):
old = table.old-vec
mask = old-vec.len - 2
ind = mask AND hash
xs = old[addr]
loop:
if xs = "nil" or "abandoned", jmp look-in-new [could be impl'd as type test]
x = car(xs) ;(key . val)
k = car(x)
if equal(key, k)
   v = cdr(x)
   if v ≠ "DELETED"
      jump find-pair-found
xs = cdr(xs)
jump loop

look-in-new:
new = table.new-vec
mask = new-vec.len - 2
ind = mask AND hash
xs = new[addr]
loop:
if xs = "nil" or "abandoned", jmp apparent-failure
x = car(xs) ;(key . val)
k = car(x)
if equal(key, k)
   v = cdr(x)
   if v ≠ "DELETED"
      jump find-pair-found
xs = cdr(xs)
jump loop

apparent-failure:
if table.new-vec ≠ new, jump find-pair
return nil/0

find-pair-found:
return x


lookup(table, key, hash):
x = find-pair(table, key, hash)
if x = nil/0
   return nil
v = cdr(x)
if v = "DELETED", jump lookup
return v

lookup-with-fail(table, key, hash, failv):
x = find-pair(table, key, hash)
if x = nil/0
   v = failv
   return v
v = cdr(x)
if v = "DELETED", jump lookup-with-fail
return v
   
lookup-succ-fail(table, key, hash, ksucc, kfail):
x = find-pair(table, key, hash)
if x = nil/0
   call-cont(kfail, nil)
v = cdr(x)
if v = "DELETED", jump lookup-succ-fail
call-cont(ksucc, v)
;(probably have to pass ... well, I dunno)

hash-set(table, key, hash, val):
x = find-pair(table, key, hash)
if x ≠ nil/0
   ;modify directly
   v = cdr(x)
   if v = "DELETED", jump hash-set
   retry_modify:
   cmpxchg(v, cdr(x), val):
     if succ, return
     if fail
        if v = "DELETED", jump hash-set
        jump retry_modify
;otherwise we must install a new cons
;let's reuse a cons...
kv = cons(key, val)
p = cons(kv, 0)
;..... ok, this is inappropriate.
;I need something better.
;--welp, whatever.
;I guess we try to be optimistic at first.
;after that... we make a cons cell and do shit.
;now this part will involve duplicating finding work.
;first we must check le old dick if exists.
;............................
;ok, um...
;conceivable: load table.old, then stall, someone screws around,
; load table.new, it's after 2 resizings, and installing shit
; there will confuse people.
; (Because someone could delete it, then someone else could copy
;  a mapping of the same key from the new "old" into the new new,
;  and then the effects of that delete would be erased.)
;therefore.
;must do some shit.
;[btw, one might write a non-optimistic version too]
grab-both:
new = table.new
old = table.old
if table.new ≠ new, jump grab-both
;just verify it ain't in old
if old ≠ 0
   mask = old.len - 2
   ind = hash AND mask
   xs = old[ind]
   loop:
   if xs = "nil" or "abandoned", jump look-in-new
   x = car(xs)
   k = car(x)
   if equal(k, key)
      retry-modify:
      v = cdr(x)
      if v ≠ "DELETED"
         cmpxchg(v, cdr(x), val):
           if succ, return
           if fail, jump retry-modify
   xs = cdr(xs)
   jump loop
;now, here, the loop will not be identical,
;because we need to keep track of the original xs.
;we will need it for a CMPXCHG.
look-in-new:
mask = new.len - 2
ind = hash AND mask
the-xs = new[ind]
if the-xs = "abandoned", jump grab-both
xs = the-xs
loop:
if xs = "nil" (or "abandoned"), jump insert-now
x = car(xs)
k = car(x)
if equal(k, key)
   retry-modify:
   v = cdr(x)
   if v ≠ "DELETED"
      cmpxchg(v, cdr(x), val):
        if succ, return
        if fail, jump retry-modify
xs = cdr(xs)
jump loop

insert-now:
cdr(p) = the-xs
cmpxchg(the-xs, new[ind], p):
  if succ, jump do-copying-work
  if fail, jump look-in-new

do-copying-work:
... oh boy, fuck, whatever
(oh yeah, also resizing shit. feh.)
jump copying-work(table) ;that will spec. units of work


;Oh boy.
;Well, there we go.
;Now, deletion.
;Significantly better.

delete(table, key, hash):
x = find-pair(table, key, hash)
if x = "nil" or "abandoned"
   return
tmp = "DELETED"
xchg(cdr(x), tmp)
if tmp = "DELETED"
   return
;jump cleanup(table, key, hash)
jump cleanup(table, x, hash)

;Actually...
;For cleanup...
;Can we be sure that dicks won't propagate to the other
;table?  Probably, yes.
;That ...
;At least means if shit gets moved under our feet, it
;won't be a problem.

;cleanup(table, key, hash):
;;..........
;;since the above doesn't save the information of which
;;vector now has a DELETED dick in it, I guess I have to
;;do both tables.
;;but at least I don't have to worry about replacements.
;old = table.old
;if old ≠ 0
;   call cleanup-vec(old, hash) ;wtvr atm
;new = table.new
;jump cleanup-vec(new, hash)
;;this shit would be signif. diff. with more sophist.
;;(in particular it would probably just eliminate the one
;; pair, rather than cleaning up ....
;; --well, ok, I should rewrite this)

cleanup(table, kv, hash):
old = table.old
if old ≠ 0
   call cleanup-vec(old, kv, hash)
new = table.new
jump cleanup-vec(new, kv, hash)

cleanup-vec(vec, kv, hash):
mask = vec.len - 2
ind = hash AND mask
;ok, so...
;cdrs only get modified by other cleanups,
;or possibly copiers that see DELETED at the head.
retry:
xs = vec[ind]
if xs = "nil" or "abandoned", return
x = car(xs)
next = cdr(xs)
if x = kv
   cmpxchg(xs, vec[ind], next):
     if succ, return ;complete victory
     if fail, jump retry
;now here
;we need to rm our thing by cmpxchg-ing,
;and then check that the xs whose cdr we modified
;is not a DELETED thing.
;if we do that, we win.
loop:
if next = "nil" or "abandoned", return ;rm'd somehow
next-x = car(next)
further = cdr(next) ;order here?
if next-x = kv
   cmpxchg(next, cdr(xs), further):
     if succ
        if cdr(x) = "DELETED", jump retry
        return ;victory
     if fail
        ;would that necessarily mean someone else had
        ;successfully cleaned up? yes, it would.
        return
xs = next
x = next-x
next = further
jump loop





do-copying-work(table, work):
;so, I think vectors have to have an extra entry.
;(meaning must subtract 2 in all the above shit)
old = table.old
new = table.new
;..............
;ok
if old = new, return ;just in case...?
if old = 0, return ;this makes sense
;now...
;do I maintain a counter?
;do I try to "cleverly" work at a randomized place
;or smthg?
;for the moment let's just start at the start
size = old.len - 1 ;like 256
start = old[size]
;now...
;...
;geez, I guess, given the way a lock can mean arbitrarily
;many dicks piling up... I can't make too many ass'ns
;about number of steps to make.
;However, regular case, n -> 2n => n movings, n abandonings.
;[By the way, it might be possible to do the moving
; destructively, although I am not sure. --It would certainly
; have to go from the end, rather than the beginning.]
;[... That's a bit of a fascinating little problem.
; But, for now... consing.]
workloop:
if work = 0, return
if start = size, return
xs = old[start]
if xs = "abandoned" ;(probably is 8)
   start += 1
   ;someone else will update the workn
   jump workloop
if xs = "nil" ;(probably is 0)
   tmp = "abandoned"
   cmpxchg(xs, old[start], tmp):
     if succ
        work -= 1
        update:
        new-start = start + 1
        if new-start = size
           old[size] = size ;no need for cmpxchg
           ;also must announce done
           tmp = 0
           cmpxchg(old, table.old, tmp):
             either way, return
        if old[new-start] = "abandoned", jump update
        actual-update:
        cmpxchg(start, old[size], new-start):
          if succ, jump workloop
          if fail
             if start < new-start
                jump actual-update
;otherwise xs is not nil, and so...
x = car(xs)
next = cdr(xs)
;first we insert x into the new place
;which means... oh god
;basically an insert, except we back off if exists
key = car(x)
;...............
;yeah, we do need to hash (oh fuck me)
;[I recall, I had thought of the possibility of storing the
; hash with the key and the value, and was like, neh, screw
; that. Could be changed, but feh.]
hash = hash(key)
mask = new.len - 2 ;the right thing ;this could be gotten earlier
ind = mask AND hash

p = cons(x, 0)

blarg:
the-ys = new[ind]
;we will cmpxchg a replacement, if it is appropriate
ys = the-ys
mem:
if ys = nil/0, jump try-insert ;no "abandoned"
y = car(ys)
if x = y, jump done-moving
k = car(y)
if equal(key, k), jump done-moving
ys = cdr(ys)
jump mem

try-insert:
cdr(p) = the-ys
cmpxchg(the-ys, new[ind], p):
  if succ
     ;must also check if it got deleted by now
     if cdr(x) = "DELETED"
        ;must clean that up
        call cleanup-vec(old, x, hash)
        jump done-moving
  if fail, jump blarg


done-moving:
;now we need to remove the old thing from the list
;...
;if ninnies have added to it in the meantime...
;is it possible to fix that shit without possibly
;repeatedly consing a bunch?
;I guess I probably can just start from the start
;of *this* list and do work from there.
;have that count as le work.
;that actually works...
;so eet eez not eh problem to do this
;[this is exactly what Mr. Cliff Click was saying,
; of it being partially counterproductive but being
; rare and happening at most O(# threads) times]
;--ok, either I can be lazy here, or I can figure
;out about modifying cdrs.
;either should be ok.
;so I'll do the former for now.
;--could pessimistically check old[start] for changes
;right here first. but neh.
next = cdr(xs)
cmpxchg(xs, old[start], next):
  if succ
     work -= 1
     jump workloop
  if fail, jump workloop

;resize, motherfuckers.

resize(table, n):
tmp = 1
xchg(tmp, table.lock)
if tmp = 1, return ;S. E. P.
;ok, now...
;might check out the table count, but that should be
;done beforehand too, so prob. unnec.
;(really that n should be computed here, not by the
; caller, but oh well.)
;................
;it's conceivable someone will dick around.
;therefore, must do dicks here.

vec = make-vector(n, nil/0) ;must be nil'd, yes
new = table.new
table.old = new
table.new = vec
table.lock = 0
return

