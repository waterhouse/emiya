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
  
  (aload "ssx9.arc") ;hah, above is not temporary, oh well
  (aload "dppr14.arc") ;is useful
  )

(unless (namespace-variable-value 'norepl #t (lambda () #f))
  (tl))

