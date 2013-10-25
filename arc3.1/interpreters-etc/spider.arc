;Spider solitaire.
;So there are 104 cards, eqv of two decks.

; Begin with 10 piles of cards, 4 having 6 cards, 6 having 5 cards.
; This leaves 50 cards in a deck, for 5 dealings.

; Each stack begins with the top card revealed.
; At all times, the legal moves are:
; - deal 10 more cards, if applicable
;   - requires cards left, and no pile can be empty
; - move a continuous stack of cards to another pile
;   - continuous stack: revealed, same suit, rank inc'ing by 1
;   - the destination pile must either be empty or its top card
;     has rank 1+[rank of bottom of moving stack]

(def spider-help ()
  (no:pr "
Spider solitaire.
Basic commands:
(new-game n):
  Begins a new game. n is the number of suits to play with;
  n can be 1, 2, or 4.
(mv src dest (o n)):
  Moves a stack of cards from column src to column dest.
  The third argument, n, is the number of cards to move; it
  can usually be left unspecified.
(moar):
  Deals a new card to each pile.
(undo):
  Undoes the last 'moar' or 'mv' command.

Options (defaults):
colored (t on mac/unix, nil on windows):
  Color output. Useful when it works.
unicode (t on mac/unix, nil on windows):
  Suits print as special Unicode characters. Nice when it works.
warn-on-mv-ambiguity (t):
  Whether to squawk when you go (mv src dest) when the number
  of cards you could move from src to dest is ambiguous.

More commands:
(game-repl):
  Lets you drop the parens from (mv src dest), (undo), and
  so on. Also stops printing arc> and nil.
(prp (o show-hidden t)):
  Prints all piles, and note the optional argument.
"))

; Printing should be easy.



; Cards are integers 0-51.
; Requires annoying shift.
; Spade, then heart, then club and diamond.
; (Game lets you use only spades, or only spades and hearts.)

(= colored (case ($.system-type)
             macosx t
             unix t
             windows nil)
   unicode (case ($.system-type)
             macosx t
             unix t
             windows nil))

(= card-sym (with (unc (obj spade '♠
                            club '♣
                            heart '♥
                            diamond '♦)
                   nunc (obj club "%"
                             heart "@"
                             spade "#"
                             diamond "^"))
              [if unicode
                  unc._
                  nunc._]))

(def card-str (n (o colored colored))
  (with (rank (inc:mod n 13)
         suit ('(club heart spade diamond)
               (div n 13)))
    ((if colored
         [str-colored _
                      (case suit
                        heart 'red
                        diamond 'red
                        'green)
                      t]
         idfn)
     (string (case rank
               1 'A
               11 'J
               12 'Q
               13 'K
               rank)
             card-sym.suit))))

(def prp ((o show-hidden t) (o colored colored) (o piles the-piles))
  (withs (piles (map rev piles)
          pr-cols (fn () (for i 0 dec:len.piles (pr "  " i " "))
		    (prn "   Deck: " len.the-deck)))
    (pr-cols)
    (if colored
        (for i 0 (dec:reduce max (map len piles))
          (each x piles
            (aif (car:nthcdr i x)
                 (pr (if (or show-hidden cadr.it)
                         (string (if (is (inc:mod car.it 13) 10)
                                     ""
                                     " ")
                                 card-str:car.it)
                         (str-colored " --"
                                      'white
                                      nil))
                     " ")
                 (pr "    ")))
          (prn))
        (grid (mapn [map (fn (pile) (aand (car:nthcdr _ pile)
                                          ([pad _ 3]
                                           (if (or show-hidden cadr.it)
                                               (card-str car.it colored)
                                               "--"))))
                         piles]
                    0 (dec:reduce max (map len piles)))
              t))
    (pr-cols)))

(def setup-game (difficulty)
  (= the-deck (map [mod _ (case difficulty
                            1 13 2 26 4 52)]
                   randperm:range.104)
     the-piles (join (n-of 4 (n-of 6 (list pop.the-deck nil)))
                     (n-of 6 (n-of 5 (list pop.the-deck nil)))))
  (state-based-effects))

(def new-game (difficulty (o options nil))
  (setup-game difficulty)
  (if (is options t)
      (= warn-on-mv-ambiguity nil colored t))
  prp.nil
  (if (is options t)
      (game-repl)))

;each stack contains a list of card-y things.
;top of stack = car.
;card-y things: car = actual card, cadr = revealed.

;state-based effects:
; - A-K --> drop 13 cards
; - top not flipped --> flip it
; - no cards left --> win
(def state-based-effects ()
  (aif (pos [is chain-length._ 13]
            the-piles)
       (do (repeat 13 pop:the-piles.it)
           (state-based-effects))
       (pos [and _ no:cadar._] the-piles)
       (do set:cadar:the-piles.it
           (state-based-effects))
       (and no.the-deck (all no the-piles))
       (win-game)))

(def chain-length (xs (o suited t))
  (if no.xs
      0
      (xloop (i 1 xs cdr.xs val caar.xs)
        (if (or no.xs
                no:cadar.xs ;not revealed
                (is 12 (mod val 13)) ;K
                (if suited
                    (isnt caar.xs inc.val)
                    (isnt 1 (mod (- caar.xs val) 13))))
            i
            (next inc.i cdr.xs inc.val)))))

(def make-move (n i j (o question-me nil))
  (if (and question-me (no:can-move n i j))
      (err "Bad move.")
      (let (a b) (split the-piles.i n)
        (= the-piles.i b
           the-piles.j (join a the-piles.j)))))

;this is game logic, making the game work.
;a program to analyze or play would generate
; all legal moves, not merely have a t/nil
; "is this move legal" procedure.
(def can-move (n i j)  
  (or (is n 0) ;why not
      (and n
           (<= n chain-length:the-piles.i)
           (>= len:the-piles.i n)
           (or no:the-piles.j ;dest is empty
               (and (isnt 12 (mod (car (the-piles.i dec.n)) 13))
                    (is 1 (mod (- (car the-piles.j.0)
                                  (car (the-piles.i dec.n))) 13)))))))

(def can-deal ()
  (and the-deck (all idfn the-piles)))

(def deal ((o question-me nil))
  (if (and question-me (no:can-deal))
      (err "To deal, the deck must be nonempty, and all piles must be nonempty.")
      (forlen i the-piles
        (push (list pop.the-deck t) the-piles.i))))

(= prev-states nil)

(= warn-on-mv-ambiguity t)

(def mv (i j (o n nil))
  (let n (if n
             n
             the-piles.j
             (find-int [can-move _ i j] 1 chain-length:the-piles.i)
             (let u chain-length:the-piles.i
               (when (and (isnt u 1) warn-on-mv-ambiguity)
                 (prn "To move less than a full chain to an empty pile, supply a third argument to mv. To kill this warning, set (= warn-on-mv-ambiguity nil)."))
               u))
    (with (old-state (deepcopy:list the-deck the-piles))
      (make-move n i j t)
      (state-based-effects)
      (push old-state prev-states)
      prp.nil)))

(def moar ()
  (let old-state (deepcopy:list the-deck the-piles)
    deal.t
    (state-based-effects)
    (push old-state prev-states)
    (prsn "Deck:" len.the-deck "cards")
    prp.nil))

(def undo ()
  (let (a b) pop.prev-states
    (= the-deck a
       the-piles b)
    prp.nil))

(def win-game ()
  (prn "TEH WINRARZ!")
  ;cake taken from the internet:
  ;http://www.chris.com/ascii/index.php?art=events/birthday
  (prn "
                               )\\
                              (__)
                               /\\
                              [[]]
                           @@@[[]]@@@
                     @@@@@@@@@[[]]@@@@@@@@@
                 @@@@@@@      [[]]      @@@@@@@
             @@@@@@@@@        [[]]        @@@@@@@@@
            @@@@@@@           [[]]           @@@@@@@
            !@@@@@@@@@                    @@@@@@@@@!
            !    @@@@@@@                @@@@@@@    !
            !        @@@@@@@@@@@@@@@@@@@@@@        !
            !              @@@@@@@@@@@             !
            !             ______________           !
            !             HAPPY BIRTHDAY           !
            !             --------------           !
            !!!!!!!                          !!!!!!!
                 !!!!!!!                !!!!!!!
                     !!!!!!!!!!!!!!!!!!!!!!!"))

(def game-repl ()
  (on-err (fn (ex) prn:details.ex
              (game-repl))
    (fn ()
      (let u (readline)
        (if (all (orf digit whitec) u)
            (case (count digit u)
              0 nil
              (withs (x (pos digit u) y (pos digit u inc.x))
                (apply mv
                       int:string:u.x
                       int:string:u.y
                       (aif (pos digit u inc.y)
                            (list:int:string:cut u it)))))
            eval:readall.u)
        (game-repl)))))



; Now for AI crap.

;Things I do.
;
;1. If there's a card x on card x+1, and I can move it to a same-suit x+1; or if there's a card x on a blank square, and I can move it to a card x+1; then I move it.
;
;This is a strictly-better thing.
;
;2. In this situation:
;--  --
; x  --
;     x
;     
;All else being equal, take the x from the smaller pile.  (Strictly follows from Principle 1.)
;
;3. In this situation:
;--  --  5♥
;4♣  4♥
;All else being equal, take the x of the same suit.  (Note that if you're close to completing a run of the different suit, and you're missing an x of that suit, then this may be bad advice.  It's generally good early game, though.)
;
;
;
;Principle 1.  It's better to have an empty pile and a pile with 2 hidden cards than two piles with 1 hidden card.

(def bflm () ;brute force legal moves
  (accum a
    (fors (i j) 0 9
      (for n 1 (reduce max (map len the-piles))
        (when (can-move n i j)
          (a:list i j n))))))

(def reversible-move-from (xs n)
  (or (is len.xs n)
      (< n (chain-length xs nil))))

(def reversible (i j n)
  (reversible-move-from the-piles.i n))

(def constructive (i j n)
  (and the-piles.j
       (is n chain-length:the-piles.i)
       (is (+ n chain-length:the-piles.j)
           (chain-length:join (take n the-piles.i) the-piles.j))))

(def revealing-move-from (xs n)
  (and (< n len.xs)
       (no:cadr xs.n))) ;not revealed

(def revealing (i j n)
  (revealing-move-from the-piles.i n))

(def digging-move-from (xs n)
  (and (nthcdr n xs)
       (is n chain-length.xs)))

(def digging (i j n) ;uncovers something and doesn't cover a new thing
  ;(digging-move-from the-piles.i n))
  (and (nthcdr n the-piles.i)
       (is n chain-length:the-piles.i)
       (or no:the-piles.j
           (is (+ n chain-length:the-piles.j)
               (chain-length:join (take n the-piles.i)
                                  the-piles.j)))))

(def gm ((o print t))
  ((if print prn id)
   (keep (fn ((i j n))
           (and ;(reversible-move-from the-piles.i n)
                (constructive i j n)))
         (bflm))))

(def u ()
  (aif (car:gm nil)
       (apply mv prn.it)
       prn.nil))

(def h ()
  (aif (car:keep (fn ((i j n))
                   (and (constructive i j n)
                        (reversible i j n)))
                 (bflm))
       (apply mv prn.it)
       prn.nil))

(def pick-mv (filter)
  (aif (car:keep filter (bflm))
       (apply mv prn.it)
       prn.nil))

(def g ()
  (pick-mv (fn ((i j n))
             (or (digging i j n)
                 (revealing i j n)
                 (constructive i j n)))))

(def b ()
  (aif (car:keep (fn ((i j n))
                   (no:reversible i j n)))
       (apply mv prn.it)
       prn.nil))

(def m args
  (if no.args
      (h)
      (apply mv args)))

;(fors (i j) 0 9
;  (with (i i j j) ;need this because 'for doesn't create a new lexical context with each iteration
;    (= (symbol-value (symb 'm i j))
;       ;(fn () (list i j)))))
;       (fn () (mv i j)))))

(mac for2 (var min max . body)
  (w/uniq (gf gmin gmax)
    `(with (,gmin ,min ,gmax ,max)
       ((rfn ,gf (,var)
          (unless (> ,var ,gmax)
            ,@body
            (,gf (+ ,var 1))))
        ,gmin))))
        
        

(def visibles ()
  (map [inc:mod dec:car._ 13] (keep cadr flat1.the-piles)))