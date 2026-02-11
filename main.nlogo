globals [
  gini-index-reserve
  lorenz-points
  prices
  world-size  ;; to store the world dimensions for vision calculation
  global-avg-AK  ;; Global average AK for A_hat calculation

]

turtles-own [
  sugar           ;; the amount of sugar this turtle has
  spice
  potsugar
  potspice
  sugar-metabolism      ;; the amount of sugar that each turtles loses each tick
  spice-metabolism      ;;
  vision          ;; the distance that this turtle can see in the horizontal and vertical directions
  vision-points   ;; the points that this turtle can see in relative to it's current position (based on vision)
  wealth
  speed
  exploitation-events

  MRS
  exploited-count


  ;; Looting system variables
  lambda      ;; time allocation to looting
  omega       ;; defensive technology
  theta       ;; looting technology
  delta       ;; efficiency parameter for equilibrium condition
  role        ;; "producer" or "looter"
  AK
  A_hat       ;; productivity relative to global average
]

patches-own [
  psugar           ;; the amount of sugar on this patch
  max-psugar       ;; the maximum amount of sugar that can be on this patch
  pspice
  max-pspice
  expected-wealth
]

;;
;; Setup Procedures
;;

to setup
  ca
  if maximum-sugar-endowment <= minimum-sugar-endowment [
    user-message "Oops: the maximum-sugar-endowment must be larger than the minimum-sugar-endowment"
    stop
  ]
  clear-all



  ;; Calculate world size for vision distribution
  set world-size max (list world-width world-height)
  set global-avg-AK 1  ;; Initialize global average

  create-turtles initial-population [ turtle-setup ifelse k? or Ai? or theta? [setxy random-xcor random-ycor][setxy 25 random-ycor]]
  setup-patches
  update-lorenz-and-gini
  reset-ticks
end

to turtle-setup ;; turtle procedure
  set color green
  set shape "circle"
  set role "producer"

  set exploited-count 0

  set exploitation-events 0

  ;; Initialize looting system parameters

  ;; Initialize role and parameters
  set lambda 0.1 + random-float 0.9
  set delta random-float 0.6
  set omega random-float 0.4
  set role "producer"


  ;; theta as a function of naivety - when theta switch is on naivety is randomly distributed amongst people
  ifelse theta? [
    let naivety random-float 0.9
    set theta naivety
  ] [

    set theta 0.1
  ]

  move-to one-of patches with [not any? other turtles-here]
  set sugar random-in-range minimum-sugar-endowment maximum-sugar-endowment
  set spice random-in-range minimum-spice-endowment maximum-spice-endowment

  ifelse Ai? [
    set sugar-metabolism random-in-range 1 4
    set spice-metabolism random-in-range 1 4
    set A_hat calculate-A_hat
     ;; Production technology differences - mean 2, std dev 1
    set speed max list 1 (round (random-normal 3 1))
    set vision max list 1 (round (random-normal 3 1))
    calculate-vision-points

  ] [
    set sugar-metabolism 1
    set spice-metabolism 1
    set A_hat 1
     ;; Everyone identical - same production tech
    set speed 4
    set vision 4
    calculate-vision-points
  ]
  ;; Ensure bounds
  if vision > world-size [set vision world-size]
  if vision < 1 [set vision 1]
  if sugar-metabolism < 1 [set sugar-metabolism 1]
  if spice-metabolism < 1 [set spice-metabolism 1]
  if speed < 1 [set speed 1]

  ;; Calculate vision points based on vision range

  set wealth wealth-func sugar spice sugar-metabolism spice-metabolism
end

to calculate-vision-points ;; turtle procedure
  ;; turtles can look horizontally and vertically up to vision patches
  ;; but cannot look diagonally at all
  set vision-points []
  foreach (range 1 (vision + 1)) [ n ->
    set vision-points sentence vision-points (list (list 0 n) (list n 0) (list 0 (- n)) (list (- n) 0))
  ]
end

to setup-patches
  ;; Initialize all patches to 0
  ask patches [
    set max-psugar 0
    set max-pspice 0
  ]

  ifelse k? [
    ;; Mountains ON - Original sugarscape distribution
    ask patch 38 38 [set max-psugar 4 ask patches in-radius 4 [set max-psugar 4 ]
      ask patches in-radius 8 with [max-psugar = 0][set max-psugar 3]
      ask patches in-radius 12 with [max-psugar = 0][set max-psugar 2]
      ask patches in-radius 16 with [max-psugar = 0][set max-psugar 1]]
    ask patch 12 12 [set max-psugar 4 ask patches in-radius 4 [set max-psugar 4 ]
      ask patches in-radius 8 with [max-psugar = 0][set max-psugar 3]
      ask patches in-radius 12 with [max-psugar = 0][set max-psugar 2]
      ask patches in-radius 16 with [max-psugar = 0][set max-psugar 1]]
    ask patch 12 38 [set max-pspice 4 ask patches in-radius 4 [set max-pspice 4 ]
      ask patches in-radius 8 with [max-pspice = 0][set max-pspice 3]
      ask patches in-radius 12 with [max-pspice = 0][set max-pspice 2]
      ask patches in-radius 16 with [max-pspice = 0][set max-pspice 1]]
    ask patch 38 12 [set max-pspice 4 ask patches in-radius 4 [set max-pspice 4 ]
      ask patches in-radius 8 with [max-pspice = 0][set max-pspice 3]
      ask patches in-radius 12 with [max-pspice = 0][set max-pspice 2]
      ask patches in-radius 16 with [max-pspice = 0][set max-pspice 1]]
  ] [
    ;; Mountains OFF - Flatlands with evenly distributed resources
    ;; Left half: sugar plains (evenly distributed)
    ask patches with [pxcor <= 24] [
      set max-psugar 2  ;; Even distribution
    ]
    ;; Right half: spice plains (evenly distributed)
    ask patches with [pxcor > 24] [
      set max-pspice 2  ;; Even distribution
    ]
  ]

  ask patches [set psugar max-psugar set pspice max-pspice patch-recolor]
end

;;
;; A_hat Calculation
;;
to-report calculate-A_hat
  let Ai (vision + speed)

  ;;to get ki
  let visible-patches patches in-radius vision
  let best-patch max-one-of visible-patches [psugar + pspice]
  let Ki 0
  if best-patch != nobody [
    set Ki ([psugar + pspice] of best-patch)
  ]

  set AK Ai * Ki
  set A_hat AK / global-avg-AK
  report A_hat
end

;;
;; Looting System Implementation
;;

to update-role

  let best-victim find-best-victim
  let production-payoff A_hat
  let looting-payoff 0

  if best-victim != nobody [
    set looting-payoff calculate-loot-payoff best-victim
  ]

  let payoff-difference (looting-payoff - production-payoff)
  let threshold-payoff delta


    ifelse (payoff-difference < threshold-payoff) or MRS = 1 [
    set role "producer"
      set color green
      execute-production-strategy
    ] [
    set role "looter"
      set color red
      execute-looting-strategy best-victim
    ]

end

;; Find the best victim to loot from entire map
to-report find-best-victim
  let potential-victims other turtles with [wealth > 0]


  ;; Find the victim with maximum expected loot
  let best-victim one-of potential-victims with-max [wealth * (1 - omega)]


  report best-victim
end

;; Calculate loot payoff based on your specified formula
to-report calculate-loot-payoff [victim]
  if victim = nobody [report 0]
  let wealth-list [wealth] of turtles
 let wealth-cv (standard-deviation wealth-list) / (mean wealth-list)

 ;; Inequality multiplier - more inequality = more attractive looting
  let inequality-multiplier (1 + wealth-cv)
  let victim-omega [omega] of victim
  let victim-wealth [wealth] of victim

  let self-production-component (1 - lambda) * A_hat * ( delta)
let max-wealth max [wealth] of turtles
let loot-component (lambda ^ theta) * (1 - victim-omega) * (1 - delta) * inequality-multiplier

  report self-production-component + loot-component
end

;; Execute production strategy
to execute-production-strategy
  ;; Harvest the patch they're currently on (full harvest since not splitting time)
  let sugar-gained psugar
  let spice-gained pspice

  set sugar sugar + sugar-gained
  set spice spice + spice-gained
  set psugar 0
  set pspice 0
end

;; Execute looting strategy
to execute-looting-strategy [victim]
  if victim = nobody [
    execute-production-strategy  ;; Fallback to production if no victim
    stop
  ]

  ;; Loot from victim
  execute-loot-attempt victim

  ;; Harvest remaining time (1 - lambda) from current patch
  let partial-sugar-gained psugar * (1 - lambda)
  let partial-spice-gained pspice * (1 - lambda)

  set sugar sugar + partial-sugar-gained
  set spice spice + partial-spice-gained
  set psugar psugar - partial-sugar-gained
  set pspice pspice - partial-spice-gained
end

to execute-loot-attempt [victim]
  let victim-sugar [sugar] of victim
  let victim-spice [spice] of victim
  let victim-omega [omega] of victim
  let who-victim [who] of victim


;; if MRS>1 sugar > spice, loot spice; else loot sugar

  ;; Calculate what's available to loot (1-omega times original)
  let available-sugar victim-sugar * (1 - victim-omega)
  let available-spice victim-spice * (1 - victim-omega)
  let sugar-looted 0
  let spice-looted 0
  ;; Calculate actual loot amounts
  if MRS > 1 [
  set sugar-looted 0
  set spice-looted available-spice * lambda
  ]
  if MRS < 1 [
  set sugar-looted available-sugar * lambda
  set spice-looted 0
  ]


   ;; Calculate what victim keeps (omega times original)
 let victim-keeps-sugar victim-sugar * (1 - ((1 - victim-omega) * lambda))
 let victim-keeps-spice victim-spice * (1 - ((1 - victim-omega) * lambda))


  ;; Transfer resources - victim left with exactly omega times original
  ask victim [
    set sugar victim-keeps-sugar
    set spice victim-keeps-spice
    set wealth wealth-func sugar spice sugar-metabolism spice-metabolism
  ]

  ;; Gain the looted resources
  set sugar sugar + sugar-looted
  set spice spice + spice-looted



  ;  print (word "turtle " who "looted turtle " [who] of victim) ;;uncomment to check looting is actually working
end

;;
;; Runtime Procedures
;;

to go

  if not any? turtles [
    stop
  ]
  ask patches [
    patch-growback
    patch-recolor
  ]
  ask turtles [
    turtle-move
    turtle-eat


    if sugar <= 0 or spice <= 0 [
      hatch 1 [ turtle-setup ifelse k? or Ai? [setxy random-xcor random-ycor][setxy 25 random-ycor] ]
      die
    ]
  ]



  ask turtles [
    set wealth wealth-func sugar spice sugar-metabolism spice-metabolism
  ]

  update-lorenz-and-gini


  tick
end

;; Modified go procedure to use new looting system
to go-with-looting

if not any? turtles [
    stop
  ]
  ask patches [
    patch-growback
    patch-recolor
  ]
  ask turtles [
    turtle-move
    turtle-eat

    if sugar <= 0 or spice <= 0 [
      hatch 1 [ turtle-setup ifelse k? or Ai? or theta? [setxy random-xcor random-ycor][setxy 25 random-ycor] ]
      die
    ]

  ]



  ;; Agent strategy selection and actions
  ask turtles [
    set wealth wealth-func sugar spice sugar-metabolism spice-metabolism

  ;; Only flexible agents do payoff calculations
 set MRS (sugar / sugar-metabolism) / (spice / spice-metabolism)

    update-role ; This will set color based on decision

    ;; Death and reproduction
    if sugar <= 0 or spice <= 0 [
      hatch 1 [ turtle-setup ifelse k? [setxy random-xcor random-ycor][setxy 25 random-ycor] ]
      die
    ]
  ]



  ;; Final wealth update
  ask turtles [
    set wealth wealth-func sugar spice sugar-metabolism spice-metabolism
  ]

  update-lorenz-and-gini
  tick
end

to turtle-move
  ;; 1) build the set of visible, unoccupied patches
  let visible-patches
    (patch-set patch-here
      (patches at-points vision-points))
    with [ not any? turtles-here ]

  ;; 2) compute expected-wealth on those patches
  let ac-sugar sugar
  let ac-spice spice
  let m-sugar sugar-metabolism
  let m-spice spice-metabolism
  ask visible-patches [
    set expected-wealth
      wealth-func
        (ac-sugar + psugar)
        (ac-spice + pspice)
        m-sugar
        m-spice
  ]

  ;; 3) pick the single best in vision
  let best-patch max-one-of visible-patches [expected-wealth]

  ifelse best-patch != nobody [
    ;; — there IS a best patch, so move toward it —
    face best-patch
    let dist-to-target distance best-patch
    let step-size min (list speed dist-to-target)
    let dest patch-ahead step-size

    ifelse dest != nobody and not any? turtles-on dest [
      move-to dest
    ] [
      let alt
        min-one-of
          (patches in-radius step-size
             with [ not any? turtles-here and distance myself > 0 ])
          [distance myself]
      if alt != nobody [ move-to alt ]
    ]
  ] [
    ;; — no best patch in vision, so do a blind overshoot —
    rt random-float 360
    let dest-blind patch-ahead speed
    ifelse dest-blind != nobody and not any? turtles-on dest-blind [
      move-to dest-blind
    ] [
      let alt
        min-one-of
          (patches in-radius speed
             with [ not any? turtles-here and distance myself > 0 ])
          [distance myself]
      if alt != nobody [ move-to alt ]
    ]
  ]
end

to turtle-eat ;; turtle procedure
  set sugar (sugar - sugar-metabolism + psugar)
  set psugar 0
  set spice (spice - spice-metabolism + pspice)
  set pspice 0
end


to patch-recolor ;; patch procedure
  ;; color patches based on the amount of sugar and spice they have
  ifelse k? [
    ;; Mountains ON - Original quadrant coloring
    if pxcor > 24 and pycor > 24 [set pcolor (yellow + 4.9 - psugar)]
    if pxcor <= 24 and pycor <= 24 [set pcolor (yellow + 4.9 - psugar)]
    if pxcor > 24 and pycor <= 24 [set pcolor (red + 4.9 - pspice)]
    if pxcor <= 24 and pycor > 24 [set pcolor (red + 4.9 - pspice)]
  ] [
    ;; Mountains OFF - Flatlands coloring
    if pxcor <= 24 [
      ;; Left half - sugar plains
      set pcolor (yellow + 4.9 - psugar)
    ]
    if pxcor > 24 [
      ;; Right half - spice plains
      set pcolor (red + 4.9 - pspice)
    ]
  ]
end

to patch-growback ;; patch procedure
  set psugar min (list max-psugar (psugar + 1))
  set pspice min (list max-pspice (pspice + 1))
end

to update-lorenz-and-gini
  let num-people count turtles
  let sorted-wealths sort [wealth] of turtles
  let total-wealth sum sorted-wealths
  let wealth-sum-so-far 0
  let index 0
  set gini-index-reserve 0
  set lorenz-points []
  repeat num-people [
    set wealth-sum-so-far (wealth-sum-so-far + item index sorted-wealths)
    set lorenz-points lput ((wealth-sum-so-far / total-wealth) * 100) lorenz-points
    set index (index + 1)
    set gini-index-reserve
      gini-index-reserve +
      (index / num-people) -
      (wealth-sum-so-far / total-wealth)
  ]
end

;; Monitoring function for new looting system
to monitor-looting-activity
  let total-agents count turtles
  let looters count turtles with [role = "looter"]
  let producers count turtles with [role = "producer"]

  print (word "=== LOOTING ACTIVITY REPORT ===")
  print (word "Total Agents: " total-agents)
  print (word "Active Looters: " looters " (" precision (looters / total-agents * 100) 1 "%)")
  print (word "Active Producers: " producers " (" precision (producers / total-agents * 100) 1 "%)")

  let total-exploitation-events sum [exploitation-events] of turtles
  print (word "Total Exploitation Events: " total-exploitation-events)

  if looters > 0 [
    let avg-lambda-looters mean [lambda] of turtles with [role = "looter"]
    let avg-theta-looters mean [theta] of turtles with [role = "looter"]
    print (word "Average Lambda (Looters): " precision avg-lambda-looters 3)
    print (word "Average Theta (Looters): " precision avg-theta-looters 3)
  ]

  if producers > 0 [
    let avg-omega-producers mean [omega] of turtles with [role = "producer"]
    print (word "Average Omega (Producers): " precision avg-omega-producers 3)
  ]
end


;;
;; Utilities and Reporters
;;

to-report random-in-range [low high]
  ;; Handle both integer and float ranges
  ifelse (low = floor low) and (high = floor high) [
    ;; Integer range
    report low + random (high - low + 1)
  ] [
    ;; Float range
    report low + random-float (high - low)
  ]
end

to-report wealth-func [ac-sugar ac-spice m-sugar m-spice]
  let wealth-report 0
  if ac-sugar > 0 and ac-spice > 0 [set wealth-report (ac-sugar ^ (m-sugar /(m-sugar + m-spice)) ) * (ac-spice ^ (m-spice / (m-sugar + m-spice)))]
  report wealth-report
end

to-report mean-speed
  report mean [speed] of turtles
end

to-report mean-vision
  report mean [vision] of turtles
end

to-report mean-sugar-metabolism
  report mean [sugar-metabolism] of turtles
end

to-report mean-spice-metabolism
  report mean [spice-metabolism] of turtles
end

;; New monitoring reporters for looter dynamics
to-report count-looters
  report count turtles with [role = "looter"]
end

to-report mean-lambda
  report mean [lambda] of turtles
end

to-report inequality-measure
  let wealths [wealth] of turtles
  if length wealths = 0 [report 0]
  let mean-wealth mean wealths
  if mean-wealth = 0 [report 0]
  report standard-deviation wealths / mean-wealth
end

to-report mean-A-hat
  report mean [A_hat] of turtles
end

;;
;; Visualization Procedures
;;

to color-agents-by-vision ;; turtle procedure
  ifelse role = "looter" [
    set color red - (vision - 3.5)
  ] [
    set color blue - (vision - 3.5)
  ]
end

to color-agents-by-metabolism ;; turtle procedure
  ifelse role = "looter" [
    set color red + ((sugar-metabolism + spice-metabolism) / 2 - 2.5)
  ] [
    set color blue + ((sugar-metabolism + spice-metabolism) / 2 - 2.5)
  ]
end

to color-agents-by-speed ;; turtle procedure
  ifelse role = "looter" [
    set color red + (speed - 2.5)
  ] [
    set color blue + (speed - 2.5)
  ]
end

to-report percent-looters
  report (count turtles with [role = "looter"] / count turtles) * 100
end
@#$#@#$#@
GRAPHICS-WINDOW
295
10
703
419
-1
-1
8.0
1
10
1
1
1
0
0
0
1
0
49
0
49
1
1
1
ticks
30.0

BUTTON
5
190
85
230
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

BUTTON
90
190
180
230
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
185
190
275
230
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
10
10
290
43
initial-population
initial-population
0
1000
200.0
10
1
NIL
HORIZONTAL

SLIDER
10
45
290
78
minimum-sugar-endowment
minimum-sugar-endowment
0
200
20.0
1
1
NIL
HORIZONTAL

PLOT
710
220
970
420
Gini index vs. time
Time
Gini
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -13345367 true "" "plot (gini-index-reserve / count turtles) * 2"

SLIDER
10
80
290
113
maximum-sugar-endowment
maximum-sugar-endowment
0
200
21.0
1
1
NIL
HORIZONTAL

SLIDER
10
115
290
148
minimum-spice-endowment
minimum-spice-endowment
5
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
10
150
290
183
maximum-spice-endowment
maximum-spice-endowment
5
100
21.0
1
1
NIL
HORIZONTAL

PLOT
710
10
970
220
Population
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
"default" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
970
220
1245
420
Turtle attributes
NIL
NIL
0.0
10.0
0.0
5.0
true
true
"" ""
PENS
"sugar" 1.0 0 -16777216 true "" "plot mean [sugar-metabolism] of turtles"
"spice" 1.0 0 -2674135 true "" "plot mean [spice-metabolism] of turtles"
"vision" 1.0 0 -14439633 true "" "plot mean [vision] of turtles"
"speed" 1.0 0 -7500403 true "" "plot mean [speed] of turtles"

PLOT
970
10
1245
220
resources
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
"sugar" 1.0 0 -16777216 true "" "plot sum [psugar] of patches"
"spice" 1.0 0 -2674135 true "" "plot sum [pspice] of patches"

PLOT
1250
10
1450
160
lorenz plot
NIL
NIL
0.0
100.0
0.0
100.0
false
false
"" ""
PENS
"equal" 100.0 0 -16777216 true ";; draw a straight line from lower left to upper right\nset-current-plot-pen \"equal\"\nplot 0\nplot 100" ""
"pen-1" 1.0 0 -5298144 true "" "plot-pen-reset\nset-plot-pen-interval 100 / count turtles\nplot 0\nforeach lorenz-points plot"

SWITCH
25
290
128
323
k?
k?
0
1
-1000

SWITCH
84
331
187
364
Ai?
Ai?
1
1
-1000

SWITCH
131
290
234
323
theta?
theta?
1
1
-1000

MONITOR
85
385
182
430
looter % 
count turtles with [role = \"looter\"] * 100 / count turtles
17
1
11

BUTTON
5
245
122
278
NIL
go-with-looting
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
135
245
282
278
go-with-looting once
go-with-looting
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
# Sugarscape with Looting Dynamics - Model Description

## What It Is

This is a **NetLogo agent-based model** that extends the classic Sugarscape simulation to study economic inequality, resource extraction, and predatory behavior. Agents navigate a world with two resources (sugar and spice), and can choose between **productive strategies** (harvesting resources) or **exploitative strategies** (looting from others).

The model examines how inequality emerges when agents can either:
- **Produce**: Harvest resources from the environment
- **Loot**: Take resources from other agents based on strategic calculations

## How It Works

### Core Mechanics

**1. Environment Setup**
- Two resource types: **sugar** (yellow) and **spice** (red)
- Two landscape modes:
  - **Mountains ON** (`k?` switch): Resources concentrated in peaks (original Sugarscape)
  - **Mountains OFF**: Flat distribution - sugar on left, spice on right

**2. Agent Properties**
Each agent has:
- **Resources**: Sugar and spice holdings
- **Metabolism**: How much sugar/spice consumed per tick
- **Vision**: How far they can see (1-world size)
- **Speed**: How far they can move per tick
- **Wealth**: Calculated as Cobb-Douglas utility function
- **Looting parameters**:
  - `lambda` (λ): Time allocated to looting (0-1)
  - `omega` (ω): Defensive technology (0-0.4)
  - `theta` (θ): Looting efficiency (0-0.9, based on "naivety")
  - `delta` (δ): Threshold for role switching (0-0.6)

**3. Agent Decision-Making**

Each tick, agents:

1. **Calculate MRS** (Marginal Rate of Substitution): `(sugar/sugar-metabolism) / (spice/spice-metabolism)`
   - MRS > 1: Value spice more
   - MRS < 1: Value sugar more

2. **Evaluate Strategies**:
   - **Production payoff**: Based on their productivity (`A_hat`)
   - **Looting payoff**: Based on victim's wealth, inequality, and defensive capabilities

3. **Choose Role**:
   - If `(looting payoff - production payoff) < delta` → **Producer** (green)
   - Otherwise → **Looter** (red)

4. **Execute Strategy**:
   - **Producers**: Move to best patch, harvest all resources
   - **Looters**: Partially harvest `(1-λ)` from current patch, loot `λ` fraction from victim

**4. Looting Mechanism**

When looting:
- Looter identifies victim with highest `wealth × (1 - omega)`
- Looter takes: `available_resources × lambda` (where available = victim's resources × (1-omega))
- Victim retains: `omega × original_resources`
- If MRS>1, loot spice; if MRS<1, loot sugar

**5. Survival & Reproduction**
- Agents die if sugar ≤ 0 or spice ≤ 0
- Before dying, they reproduce (hatch 1 offspring with new random traits)
- Population remains relatively constant

**6. Inequality Tracking**
- **Gini coefficient**: Measures wealth inequality (0 = perfect equality, 1 = perfect inequality)
- **Lorenz curve**: Visual representation of wealth distribution

## How to Use

### Setup Controls

**Switches** (toggle ON/OFF):
- **`k?`**: Enables mountain topology (resource peaks) vs flatlands
- **`Ai?`**: Enables heterogeneous agent capabilities (vision, speed, metabolism vary)
- **`theta?`**: Enables variable looting efficiency (naivety-based)

**Sliders**:
- **`initial-population`**: Starting number of agents
- **`minimum/maximum-sugar-endowment`**: Initial sugar range for agents
- **`minimum/maximum-spice-endowment`**: Initial spice range for agents

### Running the Model

**1. Basic Production-Only Simulation**:
```
- Press "setup"
- Press "go" (runs standard Sugarscape)
```

**2. With Looting Dynamics**:
```
- Press "setup"
- Press "go-with-looting" (enables strategic role switching)
```

### Monitoring & Visualization

**Key Monitors**:
- **Gini Index**: Inequality level (0-1)
- **Count Looters**: Number of red (looter) agents
- **Percent Looters**: Percentage choosing exploitation
- **Inequality Measure**: Coefficient of variation of wealth
- **Mean A_hat**: Average productivity

**Visualization Commands** (call these to color agents):
- `color-agents-by-vision`: See vision differences
- `color-agents-by-metabolism`: See metabolic differences  
- `color-agents-by-speed`: See movement capability differences

**Reporting Function**:
- `monitor-looting-activity`: Prints detailed statistics about looter/producer split

### Experimental Configurations

**Configuration 1: Baseline Equality**
```
k? = OFF (flatlands)
Ai? = OFF (identical agents)
theta? = OFF (same looting tech)
```
*Expected*: Low inequality, few looters

**Configuration 2: Geographic Inequality**
```
k? = ON (mountains)
Ai? = OFF (identical agents)
theta? = OFF (same looting tech)
```
*Expected*: Moderate inequality from resource access

**Configuration 3: Capability Inequality**
```
k? = OFF or ON
Ai? = ON (heterogeneous agents)
theta? = ON (variable naivety)
```
*Expected*: High inequality, strategic looting emerges

### Interpretation

- **Green agents**: Producers (chose production as optimal strategy)
- **Red agents**: Looters (chose exploitation as optimal strategy)
- **Gini rising**: Inequality increasing
- **Looter % rising**: Predation becoming more attractive (often due to high inequality)
- **Population stability**: Should remain near initial population

### Key Insights to Observe

1. **Inequality feedback loop**: High inequality makes looting more attractive
2. **Defensive technology**: Higher `omega` protects producers
3. **Spatial patterns**: Looters may cluster near productive areas
4. **Role switching**: Agents dynamically change strategies based on conditions

This model is useful for studying institutional economics, predation vs production trade-offs, and the endogenous emergence of inequality in systems with both productive and extractive opportunities.
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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="300"/>
    <metric>count turtles</metric>
    <metric>avg_price</metric>
    <enumeratedValueSet variable="maximum-sugar-endowment">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wealth-reproduction">
      <value value="10"/>
      <value value="11"/>
      <value value="12"/>
      <value value="13"/>
      <value value="14"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum-spice-endowment">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Trade?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minimum-sugar-endowment">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="visualization">
      <value value="&quot;no-visualization&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maximum-spice-endowment">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-population">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pmut">
      <value value="0.05"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
1
@#$#@#$#@
