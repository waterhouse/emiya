#!/bin/sh

if which -s racket
then
    if which -s rlwrap
    then rlwrap -cr -q "\"" -C arc racket -if arc3.1/as.scm
    else
        if (($# == 0))
            then echo "Installing rlwrap is optional but will make your life easier."
                 echo "(Turn this warning off by supplying any arguments to this script.)"
        fi
        racket -if arc3.1/as.scm
    fi
else echo "Install Racket, ensuring that the command-line executable \"racket\""
     echo "is accessible by that name."
fi


