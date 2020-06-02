; Global variables
globals
[
  total-population
  diffidence-value
  fact-checkers-relationship-concordance
  non-fact-checkers-relationship-concordance
]
; Relationship concordance
links-own
[
  weight
]

; Player data
turtles-own
[
  fact-checking-attitude
  credibility
  people-convinced
  n-baited
  committed-debunks
  received-debunks
  has-shared-fake-news?
  fact-checking-change
  debunked?
  node-relationship-concordance
]

; Changes the look of the network in the view
to dispose-network
    repeat 10
  [
    layout-spring turtles links 0.6 (world-width / (sqrt total-population)) 0.05
  ]
end

; Set the color of a player depending on value
to-report setup-color [value]
  ifelse value > 0.5
  [report green]
  [report red]
end

; Creates a turtle with fact checking attitude equals to fc
to create-turtle [fc]
  create-turtles 1 [
    set fact-checking-attitude fc
    set credibility 0
    setxy (random-xcor * 0.95) (random-ycor * 0.95)
    set color setup-color fact-checking-attitude
    reset-turn-values
  ]
end

; Creation of all turtles according to population settings given by sliders
to setup-nodes
  set-default-shape turtles "person"
  set total-population (non-fact-checker-population + fact-checker-population)
  let current-debunkers 0
  let current-conspiracists 0
  while [current-debunkers < fact-checker-population]
  [
    create-turtle (0.5 + random-float 0.5)
    set current-debunkers (current-debunkers + 1)
  ]
  while [current-conspiracists < non-fact-checker-population]
  [
    create-turtle random-float 0.5
    set current-conspiracists (current-conspiracists + 1)
  ]
end

; Setup the network according to the average degree specified by the slider. This algorithm is inspired by the one present in Virus on a network model present in Netlogo model library.
to setup-spatially-clustered-network
  let num-links (average-degree * total-population) / 2
  while [count links < num-links]
  [
    ask one-of turtles
    [
      let choice (min-one-of (other turtles with [not link-neighbor? myself])
                   [distance myself])

      if choice != nobody [
        let dist 0
        ask choice [
          set dist distance myself
        ]
        create-link-with choice [
          ifelse relationship-feedback = true
          [
            set weight ((sqrt(max-pxcor * max-pycor) - dist) / 20)
            set label precision weight 3
          ]
          [
            set weight 0.5
            set label precision weight 3
          ]
        ]
      ]
    ]
  ]
  ; make the network look a little prettier
  dispose-network

end

; This function acts like a switch while asking for fact checkers or non fact checkers
to-report agent-requested? [name]
  if name = "fact-checkers"
  [report fact-checking-attitude > 0.5]

  if name = "non-fact-checkers"
  [report fact-checking-attitude <= 0.5]

end

; This function sets relationship concordance
to relationship-concordance-setter [type-of-relationship-concordance value]
  if type-of-relationship-concordance = "fact-checkers"
  [set fact-checkers-relationship-concordance value]
  if type-of-relationship-concordance = "non-fact-checkers"
  [set non-fact-checkers-relationship-concordance value]

end

; This procedure finds and sets relationship concordance of player type "type-of-relationship-concordance"
to find-single-relationship-concordance [type-of-relationship-concordance]
  ; relationship-concordance 0
  ifelse all? turtles [count link-neighbors with [agent-requested? type-of-relationship-concordance] < 1]
  [
    relationship-concordance-setter type-of-relationship-concordance 1
  ]
  [
    let total 0
    ask turtles with [ count link-neighbors with [agent-requested? type-of-relationship-concordance] < 1]
      [ set node-relationship-concordance 1
        set total total + 1
      ]
    ask turtles with [ count link-neighbors with [agent-requested? type-of-relationship-concordance] >= 1]
    [
      let numberof-neighbors count link-neighbors
      let hood count link-neighbors with [agent-requested? type-of-relationship-concordance]
      set node-relationship-concordance (hood / numberof-neighbors)
      ;; find the sum for the value at turtles
      set total total + node-relationship-concordance
    ]
    ;; take the average
    relationship-concordance-setter type-of-relationship-concordance total / count turtles
  ]
end

; Setup of the simulation
to Setup
  clear-all
  ifelse diffidence-in-debunker = true
  [
    set diffidence-value diffidence-in-debunker-value
  ]
  [
    set diffidence-value 1
  ]
  setup-nodes
  setup-spatially-clustered-network
  find-relationship-concordance
  ;setup-debug-nodes
  reset-ticks
end

; Fake news propagation algorithm explained deeper in the report
to share-fake-news
  ask turtles
  [
    let r-debunks 0
    let will-do-fact-checking random-float 1
    let p-convinced 0
    let deb? false
    let myself-fact-checking-change 0
    ifelse will-do-fact-checking > fact-checking-attitude or has-shared-fake-news? = true
    [
      if has-shared-fake-news? = false
      [
        ; self confirmation bias
        set has-shared-fake-news? true
        set fact-checking-change (fact-checking-change - fact-checking-attitude * confirmation-bias)
      ]
      let actual-fact-checking fact-checking-attitude
      ;Reazione sociale di coloro che possono vedere la fake news
      ask link-neighbors
      [
        let fact-check random-float 1
        let relationship-strength 0
        let my-link link-with myself
        ask my-link
        [
          set relationship-strength weight
        ]
        ifelse fact-check > fact-checking-attitude
        [
          ; Relationship strength increases with people convinced
          set p-convinced p-convinced + 1
          set has-shared-fake-news? true
          ; Fact checking attitude decreases because other people that share the same news give an implicit feedback to news truthfulness
          set fact-checking-change (fact-checking-change - fact-checking-attitude * confirmation-bias * relationship-strength)
          set relationship-strength (relationship-strength + relationship-strength * relationship-modifier)
          set n-baited (n-baited + 1)
        ]
        [
          ; Notizia debunkata da chi l'ha vista
          set deb? true
          set myself-fact-checking-change (myself-fact-checking-change + [fact-checking-attitude] of myself * (debunk-effectiveness) * relationship-strength / diffidence-value)
          set relationship-strength (relationship-strength - relationship-strength * relationship-modifier)
          set r-debunks (r-debunks + 1)
          set committed-debunks committed-debunks + 1
        ]
        if relationship-feedback
        [
          ask my-link
          [set weight relationship-strength]
        ]
      ]
    ]
    [
      if self-debunk = true
      [
        ; The player fact checks the news.
        set deb? true
        set fact-checking-change (fact-checking-change + fact-checking-attitude * debunk-effectiveness)
        ; Confidence with other fact checkers increases
        ask link-neighbors with [fact-checking-attitude > 0.5]
        [
          if relationship-feedback
          [
            ask link-with myself
            [
              set weight weight + weight * relationship-modifier
            ]
          ]
        ]
      ]
    ]
      set has-shared-fake-news? false
      set debunked? deb?
      set fact-checking-change fact-checking-change + myself-fact-checking-change
      set people-convinced p-convinced
      set received-debunks r-debunks
    ]
end

; Values reset at beginning of each turn
to reset-turn-values
  set n-baited 0
  set people-convinced 0
  set committed-debunks 0
  set received-debunks 0
  set fact-checking-change 0
  set has-shared-fake-news? false
  set debunked? false
end

; Normalization of out of bounds values
to normalize-values
  ask links
  [
    if weight > 1
    [set weight 1]
    if weight < 0.001 and link-removal
    [die]
    set label precision weight 3
  ]
    if fact-checking-attitude > 1
    [set fact-checking-attitude 1]
    if fact-checking-attitude < 0
    [set fact-checking-attitude 0]
end

; Operations to be done at the beginning of each turn
to start-turn
  ask turtles
  [
    reset-turn-values
    set color setup-color fact-checking-attitude
  ]
end

; Strategy changes
to change-strategy
  set fact-checking-attitude (fact-checking-attitude + fact-checking-change)
  normalize-values
end

; Credibility comparison, change of strategy and credibility update
to update-behaviour
  ask turtles
  [
    let new-credibility credibility
    set new-credibility (new-credibility + (people-convinced))
    set new-credibility (new-credibility + (committed-debunks))
    set new-credibility (new-credibility - (received-debunks * 3))
    if has-shared-fake-news? = false
    [set new-credibility new-credibility + 1]
    if new-credibility < credibility
    [
      change-strategy
    ]
    set credibility new-credibility
  ]
end

; This procedure finds the relationship concordance of both types of players
to find-relationship-concordance
  find-single-relationship-concordance "fact-checkers"
  find-single-relationship-concordance "non-fact-checkers"
end

; Execute the game for #v turns, 50 by default
to go [v]
  let value 0
  while [value < v] [
    start-turn
    share-fake-news
    update-behaviour
    find-relationship-concordance
    tick
    set value value + 1
  dispose-network
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
956
18
1497
560
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
16
111
79
144
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
44
197
77
non-fact-checker-population
non-fact-checker-population
10
150
100.0
1
1
NIL
HORIZONTAL

SLIDER
16
10
196
43
average-degree
average-degree
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
16
77
197
110
fact-checker-population
fact-checker-population
10
150
100.0
1
1
NIL
HORIZONTAL

BUTTON
127
112
197
145
NIL
go 50
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
650
269
949
459
Mean Credibility
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Fact checkers" 1.0 0 -13840069 true "" "plot mean [credibility] of turtles with [fact-checking-attitude > 0.5]"
"Non fact checkers" 1.0 0 -2674135 true "" "plot mean [credibility] of turtles with [fact-checking-attitude <= 0.5]"

PLOT
30
469
351
606
Mean attitude
Time
Value
0.0
10.0
0.0
10.0
true
true
"set-plot-y-range 0 1" ""
PENS
"Fact checkers" 1.0 0 -13840069 true "" "plot mean [fact-checking-attitude] of turtles  with [fact-checking-attitude > 0.5]"
"Not fact-checkers" 1.0 0 -2674135 true "" "plot mean [fact-checking-attitude] of turtles with [fact-checking-attitude <= 0.5]"

SLIDER
247
10
419
43
confirmation-bias
confirmation-bias
0
0.5
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
246
81
418
114
debunk-effectiveness
debunk-effectiveness
0
0.5
0.3
0.1
1
NIL
HORIZONTAL

PLOT
248
118
637
258
Number of debunks
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-y-range 0 5" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [debunked? = true]"

SWITCH
17
148
195
181
self-debunk
self-debunk
1
1
-1000

SWITCH
16
187
196
220
diffidence-in-debunker
diffidence-in-debunker
1
1
-1000

SLIDER
15
222
195
255
diffidence-in-debunker-value
diffidence-in-debunker-value
1
5
2.0
1
1
NIL
HORIZONTAL

PLOT
352
467
658
604
fake-news shared
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [has-shared-fake-news? = true]"

PLOT
353
269
637
459
Relationship concordance 
time
clustering
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"Non fact-checkers" 1.0 0 -2674135 true "" "plot non-fact-checkers-relationship-concordance"
"Fact-checkers " 1.0 0 -13840069 true "" "plot fact-checkers-relationship-concordance"

SWITCH
423
47
597
80
relationship-feedback
relationship-feedback
0
1
-1000

SLIDER
247
46
419
79
relationship-modifier
relationship-modifier
0
0.1
0.1
0.01
1
NIL
HORIZONTAL

PLOT
30
316
350
459
Population
Time
Number of agents
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Fact-checkers" 1.0 0 -13840069 true "" "plot count turtles with [fact-checking-attitude > 0.5]"
"Not fact-checkers" 1.0 0 -2674135 true "" "plot count turtles with [fact-checking-attitude <= 0.5]"

SWITCH
423
10
544
43
link-removal
link-removal
0
1
-1000

MONITOR
30
268
182
313
Fact-checker percentage
count turtles with [fact-checking-attitude > 0.5] / total-population * 100
3
1
11

MONITOR
198
269
350
314
Non fact-checker percentage
count turtles with [fact-checking-attitude <= 0.5] / total-population * 100
3
1
11

@#$#@#$#@
## WHAT IS IT?

This model tries to simulate behavioral interactions between fact checkers and non fact checkers in a realistically clustered social network 

## HOW IT WORKS

Each player receives a fake news at each turn, according to his fact-checking attitude he has a certain probability of sharing that news. If the player shares or debunk the fake news, his credibility changes according to rules described in the report.
Each player tries to maximize his credibility, so if the new credibility is less than the previous one his strategy will change.

## HOW TO USE IT

Setup button prepares the world according to the number of people specified and the average degree for links. Go 50 button makes the simulation run for 50 turns. 

## THINGS TO NOTICE

Population evolution, attitude polarization, distribution of people and relationships in the view, relationship concordance and mean credibility. Number of debunks and number of fake news shared at each turn are 

## THINGS TO TRY

Try modifying sliders to simulate situations not present in report. 


## RELATED MODELS

The initial distribution of relationships and people is inspired by virus on a network model already existing in netlogo library.

## CREDITS AND REFERENCES

This model is made by Gianluca Principini for Complex Systems and Network Science exam, for University of Bologna.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
