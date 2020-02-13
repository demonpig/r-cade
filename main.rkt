#lang racket

#|

Racket Arcade (r-cade) - a simple game engine

Copyright (c) 2020 by Jeffrey Massung
All rights reserved.

|#

(require ffi/unsafe)
(require csfml)

;; ----------------------------------------------------

(require "video.rkt")
(require "game.rkt")
(require "input.rkt")
(require "palette.rkt")
(require "draw.rkt")
(require "voice.rkt")
(require "sound.rkt")
(require "music.rkt")
(require "audio.rkt")

;; ----------------------------------------------------

(provide

 ; game
 define-action
 run
 quit
 wait
 sync
 frame
 frametime
 gametime
 width
 height

 ; input
 btn-any
 btn-start
 btn-select
 btn-quit
 btn-z
 btn-x
 btn-up
 btn-down
 btn-right
 btn-left
 btn-mouse
 mouse-x
 mouse-y
 hide-mouse
 show-mouse

 ; draw
 cls
 color
 set-color!
 draw
 text
 line
 rect
 circle

 ; voice
 sine-wave
 sawtooth-wave
 square-wave
 triangle-wave
 noise-wave
 envelope
 fade-in-envelope
 fade-out-envelope
 z-envelope
 s-envelope
 peak-envelope
 trough-envelope

 ; sound
 sound
 sound?
 tone
 sweep

 ; music
 music
 music?

 ; audio
 channel?
 play-sound
 stop-sound
 play-music
 stop-music
 pause-music
 )
