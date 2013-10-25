(def all-diff (a b c)
  (is 0 (mod (+ a b c) 3)))

(def is-set (a b c)
  (if (is a b)
      (is b c)
      (and (all-diff (mod a 3) (mod b 3) (mod c 3))
           (is-set (div a 3) (div b 3) (div c 3)))))

(def layout ()
  (take 12 (randperm:range 0 80)))

(def show (xs (o local nil))
  (between a (range 1 3) (prn "<br/>")
    (for b 1 4
      (prn:string " <img src=\""
                  (if local "./set/" "http://setgame.com/images/setcards/small/")
                  (string:num->digs inc:pop.xs 10 2)
                  ".gif\">"))))

(def show-set (ns xs)
  (no:map [apply prsn _] (tuples 4 (map [if (mem _ ns) #\X #\.] xs))))

(def num-sets (xs)
  ;brute force
  (count t (map-chooses is-set 3 xs)))

(def sets (xs)
  (map cadr (keep [is car._ t] (map-chooses (fn args (list (apply is-set args) args)) 3 xs))))

(def show-sets ((o xs set-puzzle))
  (between s sets.xs (prn:newstring 10 #\-)
    (show-set s xs)))

(def set-game ((o n 6))
  (xloop ()
    (= set-puzzle (layout))
    (unless (is n num-sets.set-puzzle)
      (next)))
  (tofile "bob.html" show.set-puzzle)
  (system "open bob.html"))

(def uset-game ((o n 6) (o filename "bob.html") (o local nil))
  (xloop ()
    (= set-puzzle (layout))
    (unless (is n num-sets.set-puzzle)
      (next)))
  (tofile filename
          (show set-puzzle local)
          (prn "<br/><font color=\"white\" face=\"courier\" size=\"4\">"
               "<h1>" num-sets.set-puzzle "</h1><br/>"
               (subst "<br/>\n" "\n"
                      (tostring:show-sets))
               "</font>"))
  (system:string "open " filename))
