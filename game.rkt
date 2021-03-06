#lang racket

#|

Racket Arcade (r-cade) - a simple game engine

Copyright (c) 2020 by Jeffrey Massung
All rights reserved.

|#

(require csfml)
(require ffi/unsafe/custodian)
(require racket/match)

;; ----------------------------------------------------

(require "video.rkt")
(require "shader.rkt")
(require "input.rkt")
(require "draw.rkt")
(require "palette.rkt")
(require "font.rkt")
(require "audio.rkt")
(require "sound.rkt")

;; ----------------------------------------------------

(provide (all-defined-out))

;; ----------------------------------------------------

(define (quit)
  (when (and (window) (sfRenderWindow_isOpen (window)))
    (sfRenderWindow_close (window))))

;; ----------------------------------------------------

(define framerate (make-parameter #f))
(define frame (make-parameter #f))
(define frameclock (make-parameter #f))

;; ----------------------------------------------------

(define frametime (make-parameter #f))
(define gametime (make-parameter #f))

;; ----------------------------------------------------

(define-syntax define-action
  (syntax-rules ()
    [(_ name btn)
     (define (name) (btn))]
    [(_ name btn #t)
     (define (name) (eq? (btn) 1))]
    [(_ name btn rep)
     (define (name)
       (let ([rate (floor (/ (framerate) rep))])
         (and (btn) (= (remainder (btn) rate) 1))))]))

;; ----------------------------------------------------

(define (process-events)
  (update-buttons)

  ; handle every event in the queue
  (do ([event (sfRenderWindow_pollEvent (window))
              (sfRenderWindow_pollEvent (window))])
    ((not event))

    ; every once in a while SFML returns an invalid event
    (with-handlers ([exn:fail? (const (void))])
      (case (sfEvent-type event)
        ; window events
        ('sfEvtClosed (sfRenderWindow_close (window)))
        ('sfEvtResized (resize (sfEvent-size event)))
        
        ; key events
        ('sfEvtKeyPressed
         (on-key-pressed (sfEvent-key event)))
        ('sfEvtKeyReleased
         (on-key-released (sfEvent-key event)))
        
        ; mouse events
        ('sfEvtMouseMoved
         (on-mouse-moved (sfEvent-mouseMove event)))
        ('sfEvtMouseButtonPressed
         (on-mouse-clicked (sfEvent-mouseButton event)))
        ('sfEvtMouseButtonReleased
         (on-mouse-released (sfEvent-mouseButton event)))))))
  
;; ----------------------------------------------------

(define (sync)
  (process-events)
  (play-queued-sounds)

  ; render vram
  (flip (frame) (gametime))
  
  ; wait for the next frame
  (let* ([elapsed (sfClock_getElapsedTime (frameclock))]
         [delta (- (/ (framerate)) (sfTime_asSeconds elapsed))])
    (unless (< delta 0.0)
      (sleep delta)))

  ; update frametime, gametime, frame, and reset the frame clock
  (frametime (sfTime_asSeconds (sfClock_getElapsedTime (frameclock))))
  (gametime (+ (gametime) (frametime)))
  (frame (+ (frame) 1))
  (sfClock_restart (frameclock)))

;; ----------------------------------------------------

(define (wait [until btn-any])
  (do () [(or (until) (not (sfRenderWindow_isOpen (window)))) #f]
    (sync)))

;; ----------------------------------------------------

(define (discover-good-scale w h)
  (let* ([mode (sfVideoMode_getDesktopMode)]

         ; size of the display the window will be on
         [screen-w (sfVideoMode-width mode)]
         [screen-h (sfVideoMode-height mode)]

         ; scale to fit ~60% of the screen
         [scale-x (quotient (* screen-w 0.6) w)]
         [scale-y (quotient (* screen-h 0.6) h)])
    (inexact->exact (max (min scale-x scale-y) 1))))

;; ----------------------------------------------------

(define (run game-loop
             pixels-wide
             pixels-high
             #:init [init #f]
             #:scale [scale #f]
             #:fps [fps 60]
             #:shader [effect #t]
             #:title [title "R-cade"])
  (unless scale
    (set! scale (discover-good-scale pixels-wide pixels-high)))

  ; set the video mode for the window
  (let ([mode (make-sfVideoMode (* pixels-wide scale) (* pixels-high scale) 32)])

    ; initialize global state
    (parameterize
        ([window (sfRenderWindow_create mode title '(sfDefaultStyle) #f)]

         ; video memory
         [texture (sfRenderTexture_create pixels-wide pixels-high #f)]
         [sprite (sfSprite_create)]

         ; create a fragment shader for fullscreen rendering
         [shader (and effect (sfShader_createFromMemory vertex-shader
                                                        #f
                                                        fragment-shader))]

         ; default render state
         [render-state (make-sfRenderStates sfBlendAlpha
                                            sfTransform_Identity
                                            #f
                                            #f)]

         ; default palette and font
         [palette (for/vector ([c basic-palette]) c)]
         [font (for/vector ([g basic-font]) g)]

         ; sound mixer
         [sounds (create-sound-channels 8)]
         [sound-queue null]

         ; music channel and riff pointer
         [music-channel #f]
         [music-riff #f]

         ; playfield size
         [width pixels-wide]
         [height pixels-high]

         ; input buttons
         [buttons (make-hash)]

         ; mouse position
         [mouse-x 0]
         [mouse-y 0]

         ; frame
         [framerate fps]
         [frame 0]

         ; delta frame time, total game time, and framerate clock
         [frametime 0.0]
         [gametime 0.0]
         [frameclock (sfClock_create)])

      ; attempt to close the windw on shutdown (or re-run)
      (let ([v (register-custodian-shutdown (window)
                                            (λ (w)
                                              (when w
                                                (sfRenderWindow_close w)))
                                            #:at-exit? #t)])
        
        ; optionally allow for an init function
        (when init
          (init))
        
        ; defaults
        (cls)
        (color 7)
        
        ; set shader uniforms
        (when (shader)
          (let ([size (make-sfGlslVec2 (exact->inexact (width))
                                       (exact->inexact (height)))])
            (sfShader_setVec2Uniform (shader) "textureSize" size)))
        
        ; main game loop
        (do () [(not (sfRenderWindow_isOpen (window)))]
          (with-handlers ([exn? (λ (e)
                                  (displayln e)
                                  (quit))])
            (sync)
            (game-loop)))

        ; clean-up shutdown registration
        (unregister-custodian-shutdown (window) v))

      ; stop playing sounds and music
      (stop-music)
      (stop-sound))))
