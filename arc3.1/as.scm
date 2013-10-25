; mzscheme -m -f as.scm
; (tl)
; (asv)
; http://localhost:8080

(require mzscheme) ; promise we won't redefine mzscheme bindings

;(compile-enforce-module-constants #f) ;HAHAHAHAHAHAHAHAHA ya rt ;guh

(require "ac.scm") 
(require "brackets.scm")
(use-bracket-readtable)

(parameterize ((current-directory (or (current-load-relative-directory)
                                      (current-directory))))
  (aload "arc.arc")
  (aload "libs.arc") 
  
  (aload "a")
  (aload "sh.arc") ;my stuff
  
  (aload "spider.arc") ;temporary
  )

(tl)

