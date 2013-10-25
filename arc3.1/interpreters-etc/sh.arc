;(load "a")
;(let orig rand;covered already I think
;  (def rand (a (o b nil))
;    (if (no b)
;        (orig a)
;        (+ a (orig (- b a))))))






(= equal iso)


(def mac->term (mac)
  (string "osascript -e 'tell application \"Keyboard Maestro Engine\" to do script \""
          mac
          "\"'"))
(def join-cmds args
  (tostring
   (each x args
     (pr x ";"))))

(def wait-for-me ()
  (if (file-exists (home "breakbreakbreak"))
      (do (system:string "rm " (home "breakbreakbreak"))
          (err "BREAK"))
      (file-exists (home "stopstopstop"))
      (do (prn "Waiting to proceed")
          (sleep (rand 3 7))
          (wait-for-me))))
(def run-macro macs
  (wait-for-me)
  (system (apply join-cmds
                 (map mac->term
                      (keep id
                            (flatten macs))))))

;SUPPLANTED BY NON-KEYBOARD-MAESTRO CLICK
;(def click ()
;  (run-macro "click"))
(def tclick ()
  (repeat 3 (click)))
(def wakey ()
  (run-macro "wakey"))
(def chrome ()
  (run-macro "chrome"))

(def click-sleeps args;by minutes
  ;(sleep 30);give me time to put mouse, etc. in position
  ;(click)
  (each x args
    (sleep (* x 60))
    (wakey)
    (sleep 2)
    (click)
    (prs x "click")))
;upgrading quarry
(def current ()
  (click-sleeps 4 8 16 32 64 128 256))

(def click-secs args
  (each x args
    (sleep x)
    (wakey)
    (sleep 2)
    (click)
    (prs x "click")))




;Writing macros
(def write-macfile (name macs)
  (w/outfile meh name
    (disp 
     (tostring
      (pr "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<array>
")
      (map pr macs)
      (pr "
</array>
</plist>
"))
     meh)))

(def poses (things xs (o start 0))
  (if (or (no things) (no start))
      nil
      (let u (pos (car things) xs :start start)
        (cons u (poses (cdr things) xs u)))))
(def str-poses (strs txt (o start 0) &key (return-end nil))
  (if (no strs)
      nil
      (aif (str-pos (car strs) txt start :return-end return-end)
           (cons it (str-poses (cdr strs) txt it :return-end return-end)))))
(def lines->txt (lines)
  (tostring (map prn lines)))
(def write-macthing (oldmacthing hrpos verpos name)
  (with* (u (tuples 2
                    (str-poses
                     '("<key>HorizontalPosition</key>
						<integer>"
                       "</integer>"
                       "<key>VerticalPosition</key>
						<integer>"
                       "</integer>"
                       "<key>Name</key>
				<string>"
                       "</string>")
                     oldmacthing))
            d (map (fn (x y) (cut oldmacthing x y))
                   (cons 0 (map car u))
                   (join (map cadr u) (list (len oldmacthing)))))
    (tostring (map pr
                   d
                   (list hrpos verpos name "")))))
;(with* (oldmacthing (setf oldmacthing* (lines->txt (readfile "Desktop/two macs.kmmacros")))
;                    u '("<key>HorizontalPosition</key>
;						<integer>"
;                        "</integer>"
;                        "<key>VerticalPosition</key>
;						<integer>"
;                        "</integer>"
;                        "<key>Name</key>
;				<string>"
;                        "</string>")
;                    ;ulen (map length u)
;                    uu (tuples 2 (str-poses u oldmacthing))
;                    us (map +
;                               (map car uu)
;                               (map length (map car (tuples 2 u))))
;                    ue (map cadr uu)
;                    ;        us (str-poses (map car uu)
;                    ;                      oldmacthing
;                    ;                      0
;                    ;                      :return-end t)
;                    ;        ue (str-poses (map cadr uu)
;                    ;                      oldmacthing)
;                    h (setf won (list us ue))
;                    d (map (fn (x y) (cut oldmacthing x y))
;                              (cons 0 ue)
;                              (join us (list (str-pos "<string>3A6D0CA5-B783-4B62-82EF-36D839C6CAF6</string>
;	</dict>"
;                                                        oldmacthing
;                                                        0
;                                                        :return-end t))))
;                    )
;  (defvar macthings*)
;  (setf macthings* d)
;  )













(def macthing (hrpos verpos name stringa stringb)
  (string
   (map string (list
                "   	<dict>
		<key>Activate</key>
		<string>Normal</string>
		<key>AddToMacroPalette</key>
		<false/>
		<key>AddToStatusMenu</key>
		<false/>
		<key>IsActive</key>
		<true/>
		<key>IsBrowserContainerOpen</key>
		<true/>
		<key>KeyCode</key>
		<integer>32767</integer>
		<key>Macros</key>
		<array>
			<dict>
				<key>Actions</key>
				<array>
					<dict>
						<key>Action</key>
						<string>Move</string>
						<key>HorizontalPosition</key>
						<integer>" hrpos "</integer>
						<key>IsActive</key>
						<true/>
						<key>MacroActionType</key>
						<string>MouseMoveAndClick</string>
						<key>Modifiers</key>
						<integer>0</integer>
						<key>Relative</key>
						<string>Mouse</string>
						<key>RelativeCorner</key>
						<string>TopLeft</string>
						<key>VerticalPosition</key>
						<integer>" verpos "</integer>
					</dict>
				</array>
				<key>IsActive</key>
				<true/>
				<key>Name</key>
				<string>" name "</string>
				<key>Triggers</key>
				<array/>
				<key>UID</key>
				<string>" stringa "</string>
			</dict>
		</array>
		<key>Modifiers</key>
		<integer>0</integer>
		<key>Name</key>
		<string>Global Macro Group</string>
		<key>Targeting</key>
		<dict>
			<key>Targeting</key>
			<string>All</string>
			<key>TargetingApps</key>
			<array/>
		</dict>
		<key>UID</key>
		<string>" stringb "</string>
	</dict>"))))

(def test (name)
  (write-macfile name
    (let u (all-choices (fn (n pos? swap?)
                          (with (a (expt 2 n) b 0)
                            (if (not pos?) (negate a))
                            (if swap? (rotatef a b))
                            (list a b)))
                        (range 0 10)
                        (list t nil)
                        (list t nil))
      (map (fn ((hr vr))
             (macthing hr
                       vr
                       (string (if (> hr 0)
                                   "r"
                                   (< hr 0)
                                   "l"
                                   (> vr 0)
                                   "d"
                                   "u")
                               (max (abs hr) (abs vr)))
                       "96FCA63F-2EDD-4618-8C2A-D5E92EE09453"
                       "96FCA63F-2EDD-4618-8C2A-D5E92EE09453"))
           u))))

(def get-digs (n a b (o base 10))
  (* (expt base a)
     (mod (trunc n (expt base a))
          (expt base (- b a)))))

(def num->nums (n (o b 10))
  (afnwith (m 1 u (rev (num->digs n b)))
    (if (no u)
        nil
        (is 0 (car u))
        (self (* m b) (cdr u))
        (cons (* m (car u))
              (self (* m b) (cdr u))))))


(def old-man-move (x y (o start nil))
  (run-macro
   (join
    (and start
         (list
          (downcase (string start))));ulc, llc, ulw, llw
    (map [string (if (> x 0)
                     "r"
                     "l")
                 _]
         (num->nums (abs x) 2))
    (map [string (if (> y 0)
                     "u"
                     "d")
                 _]
         (num->nums (abs y) 2)))))
(def mkst args
  (string (map string args)))

;SUPPLANTED BY NON-KEYBOARD-MAESTRO CRAP
;(def move (x y (o start 'llm));note that direc. is just starting point
;  (sleep .2)
;  (run-macro 
;   (mkst "<dict><key>Action</key><string>Move</string><key>HorizontalPosition</key><integer>"
;         (round x)
;         "</integer><key>IsActive</key><true/><key>MacroActionType</key><string>MouseMoveAndClick</string><key>Modifiers</key><integer>"
;         0;what are modifiers?
;         "</integer><key>Relative</key><string>"
;         (case (cut totext.start 2)
;           "c" "Screen"
;           "w" "Window"
;           "Mouse")
;         "</string><key>RelativeCorner</key><string>"
;         (case (cut totext.start 0 2)
;           "ul" "TopLeft"
;           "ll" "BottomLeft"
;           "ur" "TopRight"
;           "lr" "BottomRight"
;           "TopLeft")
;         "</string><key>VerticalPosition</key><integer>" (round y) "</integer></dict>")))



(def xml-clean (xt);replaces newlines with &#xA;
  (tostring
   (for i 0 (1- (len xt))
     (let u (xt i)
       (disp (case u
               #\newline "&#xA;"
               #\' "&#39;"
               #\" "&#34;"
               #\< "&#60;"
               #\> "&#62;"
               u))))))
(def text-macro (txt (o fast nil))
  (run-macro
   (string "<dict><key>IsActive</key><true/><key>JustDisplay</key><false/><key>MacroActionType</key><string>InsertText</string><key>Paste</key>" (if fast "<true/>" "<false/>") "<key>Text</key><string>"
           (xml-clean (string txt))
           "</string></dict>")))
(def run-key-macro (n mods)
  (run-macro
   (mkst
    "<dict><key>IsActive</key><true/><key>KeyCode</key><integer>"
    n
    "</integer><key>MacroActionType</key><string>SimulateKeystroke</string><key>Modifiers</key><integer>"
    
    mods
    
    "</integer></dict>")))

(def key-macro (k (o mods nil))
  (run-key-macro
   (or (pos (totext k)
            '("a" "o" "e" "u" "d" "i" ";" "q" "j" "k" "§" "x" "'" "," "." "p" "f" "y" "1" "2" "3" "4" "6" "5"
                  "]" "9" "7" "[" "8" "0" "=" "r" "g" "/" "c" "l" "ret" "n" "h" "-" "t" "s" "\\" "w" "z" "b" "m" "v" "tab" "spc" "`" "del" "ent"))
       (case (totext k)
         "up" 126
         "dn" 125
         "lf" 123
         "rt" 124)
       (err "What the hell key is this?" k 0))
   (sumlist [case _
              cmd 256
              opt 2048
              ctr 4096
              shf 512
              (err "Not cmd, opt, ctr, shf:" _ 0)]
            (if (alist mods)
                mods
                (list mods)))))
(def adium ()
  (key-macro 'a '(cmd shf)))

(def dvorak->qwerty-keypos (x)
  (elt 
   '(\` 1 2 3 4 5 6 7 8 9 0 - = q w e r t y u i o p \[ \] \\ a s d f g h j k l \; \' z x c v b n m \, \. \/)
   (pos x '(\` 1 2 3 4 5 6 7 8 9 0 \[ \] \' \, \. p y f g c r l \/ = \\ a o e u i d h t n s - \; q j k x b m w v z))))
(def grep (str xs)
  (keep [str-pos str _]
        (if (consp xs)
            xs
            (sep-str xs #\newline))))

(def numberpad (n)
  (run-key-macro (+ 82 n)
                 65536));wtf?  I suspect 0 works too as a mod.

(def click-drag ();mousekeys must be on
  (numberpad 0))
(def unclick ()
  (numberpad 5))

(def screenshot (x y);start from curpos
  (key-macro 4 '(cmd shf))
  (move 0 -1)
  (numberpad 2)
  (click-drag)
  (move x (-:1- y))
  (numberpad 8)
  (unclick))





(def make-unique-filename ()
  (let u 0
    (while (file-exists (string u))
      (++ u))
    (string u)))
(def pipe-to-string (cmd)
  (let u (pipe-from cmd)
    (do1 (tostring (drain (aif (readc u) (pr it))))
         (close u))))

;(def pipe-to-string (cmd)
;  (let u (make-unique-filename)
;    (ext:shell (string cmd " > " u))
;    (prog1 (read-textfile u)
;           (ext:shell (string "rm " u)))))

;Note that one can ($:require racket/gui)
; and ($:send the-clipboard get-clipboard-string 0)
; to get the clipboard.
(def clipboard ()
  (tostring:system pbpaste-string*))
(def get-selected-text ()
  (key-macro 'c 'cmd)
  (clipboard))

(def to-tokens (xt)
  (sep-str xt
           ~[or (alphanumericp _) (is _ #\')]))
(def tokens->sentence (tks)
  (tostring
   (pr (string-capitalize (car tks)) " ")
   (each x (butlast (cdr tks))
     (pr x " "))
   (pr (last1 tks) ".")))

(def print-to-adium (txt (o which))
  (adium)
  (if which (key-macro which 'cmd))
  (key-macro 'tab)
  (key-macro 'a 'cmd)
  (key-macro 'del)
  (text-macro txt t)
  (key-macro 'ret)
  txt)

(def make-wtfspeak ()
  (let u (get-selected-text)
    (adium)
    (key-macro 'tab)
    (key-macro 'del)
    (text-macro (tokens->sentence (sort (to-tokens u) (fn (x y) (is 1 (rand 2))))) t)
    (key-macro 'ret)))


(def can-read (thing)
  (w/uniq fail
    (isnt fail (read thing fail))))

;(def find-current-adium-chat ()



(def adium-repl ((o which 0))
  (adium)
  (key-macro which 'cmd)
  (move -80 -80 'lrw)
  (print-to-adium t)
  (with (last-in "" last-out "t")
    (while t
      (sleep 1)
      (tclick)
      (let u (get-selected-text)
        (when (and (not (in u "" last-in last-out (rem [is _ #\newline] last-out)))
                   (can-read u))
          (= last-in u)
          (= last-out (print-to-adium (tostring (prn (eval (readstring1 u))))
                                      which)))))))
(def forever-repl ((o which 0))
  (let u (thread (on-err (fn (ex) (print-to-adium (details ex) which))
                   (fn nil (adium-repl which))))
    (until (dead u) (sleep 1)))
  (forever-repl which))


;
;(def adium-repl ((o which 1))
;  (adium)
;  (key-macro which 'cmd)
;  (move 100 409 'ulw)
;  (print-to-adium t)
;  (with (last-str "" last-result "t")
;    (while t
;      (sleep 1)
;      (tclick)
;      (let u (get-selected-text)
;        (when (and (not (in u "" last-str last-result (rem [is _ #\newline] last-result)))
;                   (with-input-from-string (s u)
;                     (can-read s)))
;          (setf last-str u)
;          (setf last-result (print-to-adium (tostring (prn (eval (read-from-string u)))))))))))

(def get-pixel ();returns list of rgb's: 0-255
  (run-macro "colormeter")
  (key-macro 'c '(cmd shf))
  (key-macro 'tab 'cmd)
  (w/instr (clipboard)
    (list (read) (read) (read))))





(def new-lisp-window ()
  (run-macro "terminal")
  (key-macro 'n 'cmd)
  (text-macro "clisp
")
  (text-macro "(load \"sh\")
")
  )


(= system-type* ;(errsafe:read:tostring:system "uname"))
   ($.system-type))
(= pbpaste-string*
   (case system-type*
     ;Darwin "pbpaste"
     ;Linux "xclip -o")
     macosx "pbpaste"
     unix "xclip -o"
     windows "getclip") ;assuming cygwin
   pbcopy-string*
   (case system-type*
     ;Darwin "pbcopy"
     ;Linux "xclip"))
     macosx "pbcopy"
     unix "xclip"
     windows "putclip")) ;assuming cygwin

(def pbcopy (s)
  (let f (tmpfile)
    (w/outfile gf f (disp s gf))
    (system:string pbcopy-string* " < " f)
    rmfile.f))

(= pbpaste clipboard)

(def paste args
  (when args (pbcopy:string args))
  (run-macro "paste"))


