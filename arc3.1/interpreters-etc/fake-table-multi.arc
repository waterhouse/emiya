
;A hash table that can be incrementally resized.
;The only potentially O(n) operation in it should be
;the new allocation of a vector of size n.
;Even then, that might not be a problem, depending on how
;things are handled.

;The hash operation shall have guaranteed constant bounds.
;Except maybe on strings?
;...
;Feh.
;Now...

;There are a few means of achieving this.
;Basically, the problem is conses and, worse, arrays that can
;recurse into giant objects, or even loop.
;Obvious solutions are to look only up to a certain depth, or look at
;only up to a certain number of objects.
;
;Looks like SXHASH in SBCL, CLISP, and CCL all go through every
;character in the string.  (Also, CLISP and CCL seem to be in the business
;of adding, so that changing a character by 1 seems to change the result
;by 1.)
;(That or I got lucky by screwing with index 2000002.)
;(Looks like CCL probably uses something eqv to ∑(s[i] * a^i mod m).)
;
;Meh, probably not a problem.
;
;I think I might enforce symbol-hashes, or even hashes in general,
;having the top three bits be 0, so that they can be passed around as
;fixnums.
;Not like there would be any use, at least when it comes to use in hash
;tables, for bits higher than log_2(table size), which will rarely exceed
;32 or so, and can't exceed 48 on most machines.
;
;Looking at only up to a certain number of objects is somewhat nicer
;in a sense, 'cause that's really what I'm looking for, but...
;It might actually be a worse strategy, in case of hashing
;(deep-list actually-distinguishable-stuff)
;, and also it's easier to not deal with what might be called "non-local
;returns" or something.  (Like, saying screw this, resetting the stack
;pointer, and jumping to the appropriate return point.)
;So that'll happen to be easier.

;Right.
;
;Create:
;user=[is-table table-mask primary-vec old-vec-or-zero table-count lock]
;
;Insert:
;(Will branch into "update existing" and "insert new".)
;Type-check.
;Get table-mask.
;Hash.
;AND.
;
;... Ok, with two vecs, of diff. sizes, that is a bad idea.
;I _guess_ table-mask can be computed from vec-len.
;...
;Fuck.
;This conflicts with the fact that I'd like the vec-len field to be
;used for somewhat dual purposes... hmm...
;
;Feh.
;It seems to lead to unfortunate things if I require that kind of
;synchronization... hmm...
;I guess it's possible that I could really give ... ... no, old ptrs,
;too terrible.
;Could really screw with how hash table things are traced, but...
;In the meantime...
;Must dumbly get actual vector length.
;Thus:

Create:
user=[is-table primary-vec old-vec-or-zero table-count lock]

Insert:
(Will branch into "update existing" and "insert new".)
Type-check.


Check if needs resizing.
If so, and if your thread doesn't think it needs absolute real-time
behavior/isn't lazy, then call resize and jump back to insert.
(It would be possible to add "resize this pls" to some work-list,
 and meanwhile just insert it and leave it to others to clean up.)

Now, regarding concurrent use:
- When reading the old and the enlarged versions of a table, you
  should check the old one, and then the new one.
  (If something has disappeared from the old one, then it must
   already be in the new one; on the other hand, if something is
   not yet in the new one, it may be gone and moved to the new one
   by the time you look in the old one.)
- If someone replaces the current vec with a new one... it's
  conceivable that all the moving could be done between when you
  get the vec-ptr and when you're done looking through it.
  So, look at the main-vec-ptr and see if it's changed.
Therefore...

Look in 



Resize:
Try to grab lock. (If fail, someone else is resizing; return
immediately. A nice thing is that technically you can wait
forever for the resize and the table will continue to produce
correct results, if slowly.)
Create vector of appropriate size.
... Fill it with nils.  (This is really terrible.)
(Zeros would also work if consistently used.)
(Also, "aristocratic" threads could ... see above.)



Geez....

Formal properties that must be obeyed...
- If someone inserts a key-value mapping into the table,
  and "later" someone else looks up that key in the table,
  and no one had inserted a new value or deleted the value
  for that key "later" than the first insertion but "earlier"
  than the 
- From the perspective of the table, there is a consistent sequence
  of events: lookups, assignments (and deletions). (May be multiple
  compatible sequences.)
- Relativity, in general.

Now...

Ok.
If someone has put x -> y in the new table,
and someone else was putting x -> z in the old table,
then the x -> y insert was certainly initiated later.
This leads to an interpretation that x -> y should become canon,
and 
Then some people who were looking up x in the table before the resize
might observe x -> z


OH GOD
OH GOD
NEUHUUHUHUHUHUHO
NEUEUEUHUHUHUHUHO
Welp.
Resizing the table can't be normal GC work.
The above principle implies you must do key-eq comparisons.
Which might take arbitrarily long and arbtirary consing, with 



FFFFFFFFFFFFFFFFUUUUUUUUUUUUUUUUUUUUUUU
Nope.
Can't have you inserting the new mapping into the new vec
while the old mapping still exists.
Otherwise, someone could delete it from the new vec, and then
commit the delete, and then someone would eventually move
the old mapping to the new vec and that would be terrible.

Fortunately, I think this was sort of already solved.
When making a new mapping, first you must search both tables
(in the right order) for an old mapping. If find, modify.
Only if it doesn't exist in either table can you create a new
mapping.

So, there's still a potential issue with (a) multiple resizes
and (b) long thread delays.
If a thread is inserting cock, and then it finds that other
threads appear to have moved everything out of that table,
then it seems like either the insertion could be lost, if it
is indeed abandoned, or it could be made twice, if (a) actually
another thread is still copying things into the new table,
and (b) 

Now, this seems solvable by the simple and actually apparently
cost-free mechanism of leaving a different kind of "abandoned"
value in old dead tables once you've dicked.
Then ............
Then sheeeeit works, it would seem.
Threads doing insertions will notice, via cmpxchg, that the value
has changed from "nil" to "abandoned".

Ok, that's 10/10 bretty good.
Now..........



Deletion.
Make the same effort as lookup does, to find a key-val pair.
Then assign val to DELETED.
Then eradicate.


Lookup:
Usual case should go like this:
Look in old-vec slot.
Find nothing. (Either nil/abandoned or no vec.)
Look in new-vec slot.
Find vec.
Look for pair.
Found -> return.
Not found -> Look in new-vec slot, see if has changed, if so, jump
             back to Lookup.

Now, in actuality, 

Should factor out "find-pair".
So.
(Just like in the IBM paper, though they call it "find".)


;find-pair(table, key, hash):
;old = table.old-vec
;mask = old-vec.len - 1
;ind = mask AND hash
;addr = old + ind*8 - vector_tag
;xs = [addr]
;loop:
;if xs = "nil" or "abandoned", jmp look-in-new [could be impl'd as type test]
;x = car(xs) ;(key . val)
;k = car(x)
;if equal(key, k), jump find-pair-found
;addr = x + 8 - cons_tag
;xs = [addr]
;jump loop
;
;look-in-new:
;new = table.new-vec
;mask = new-vec.len - 1
;ind = mask AND hash
;addr = new + ind*8 - vector_tag
;xs = [addr]
;loop:
;if xs = "nil" or "abandoned", jmp apparent-failure
;x = car(xs) ;(key . val)
;k = car(x)
;if equal(key, k), jump find-pair-found
;addr = x + 8 - cons_tag
;xs = [addr]
;jump loop
;
;apparent-failure:
;if table.new-vec ≠ new, jump find-pair
;return nil/0, nil/0
;
;find-pair-found:
;return x, addr
;
;
;lookup(table, key, hash):
;x, addr = find-pair(table, key, hash)
;return x


ok, now, let's try that with DELETED shit

find-pair(table, key, hash):
old = table.old-vec
mask = old-vec.len - 1
ind = mask AND hash
addr = old + ind*8 - vector_tag
xs = [addr]
loop:
if xs = "nil" or "abandoned", jmp look-in-new [could be impl'd as type test]
x = car(xs) ;(key . val)
k = car(x)
if equal(key, k):
   ;if DELETED, we just ignore it
   if 
addr = x + 8 - cons_tag
xs = [addr]
jump loop

look-in-new:
new = table.new-vec
mask = new-vec.len - 1
ind = mask AND hash
addr = new + ind*8 - vector_tag
xs = [addr]
loop:
if xs = "nil" or "abandoned", jmp apparent-failure
x = car(xs) ;(key . val)
k = car(x)
if equal(key, k), jump find-pair-found
addr = x + 8 - cons_tag
xs = [addr]
jump loop

apparent-failure:
if table.new-vec ≠ new, jump find-pair
return nil/0, nil/0

find-pair-found:
return x, addr


lookup(table, key, hash):
x, addr = find-pair(table, key, hash)
return x




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
mask = old-vec.len - 1
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
mask = new-vec.len - 1
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
   mask = old.len - 1
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
mask = new.len - 1
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
jump cleanup-vec(new, kv, hash)

cleanup-vec(vec, kv, hash):
mask = vec.len - 1
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

;wow.
;is that it?
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

;ok, let's put this all together or something.

;regarding the possibility of moving with scdr:
;first, you must link before you unlink, else someone
;may lookup and miss in the meantime.
;[and if you somehow indicate that shit is bein'
; moved in the meantime, then that still means
; any lookups will have to wait until you're done
; before they can be sure the key is missing,
; because they don't have any other way of reaching
; your key.]
;second, if you link in the moved thing at the end
;of the destination, that's probably bad, 'cause you'll
;have no way of knowing if someone has inserted and ...
;wait...
;nah, they'll ...
;however.
;moves, and then ...
;change the nil...
;must change the nil (use ints * 16) (dist. from "abandoned",
; probably)
;and how about deletions...

;Under this proposal,
;a "p" cons (which holds a kv and another "p" or nil)
;will have its cdr modified if either:
;- the thing ahead of it gets deleted and rm'd from the list
;- the thing ahead of it gets moved into a resized vec,
;  and we nil-ify the cdr (maybe?)
;- it is in a resized vec, and something gets moved in behind it

;Now...
;There could be what is known as an ABA problem.
;
;Just fuck it, my brain has become fairly convinced that you
;can't do anything good without this allocation business.
;[By the way... in this case, performance will actually
; decrease with large heap sizes for a particular use case:
; a weak-hash-table in which most entries become garbage.
; Probably.]






