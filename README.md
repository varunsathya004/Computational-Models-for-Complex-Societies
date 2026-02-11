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

