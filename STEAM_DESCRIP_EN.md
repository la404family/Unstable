# STEAM_DESCRIP_EN.md
# Steam BBCode format — paste directly into the Workshop description
# No Markdown here: only BBCode works on Steam

---

[h1]OPERATION ROYAL ALLIANCE — Porto[/h1]
[i]Dynamic cooperative mission · 1 to 7 players · CUP · NO DLC required[/i]

[hr][/hr]

Porto, 2025. A backwater island. A fishing port turned smuggling hub, clandestine transit point and jihadist recruitment ground. The [b]Justice Movement (MJ)[/b] and the [b]Liberation Front (FL)[/b] are fighting over it. The Kingdom of Sahrani, under international pressure, deploys its [b]RACS Multinational Expeditionary Corps[/b] — Turkish, Arab, African and Indonesian volunteers — to clean up Porto. Without NATO. Without the Americans. This is a decisive test of the Kingdom's credibility.

[b]You are that expeditionary force. The mission depends on your decisions.[/b]

[hr][/hr]

[h2]🔁 DYNAMIC MISSION — 3 RANDOM SCENARIOS[/h2]

At the start of every game, the first reconnaissance meeting randomly draws a scenario. [b]The mission you play tonight will not be the one you play tomorrow.[/b]

[list]
[*][b]Scenario 1 — Cooperation:[/b] The local contact collaborates. Neutralise the militia leaders, recover the compromising documents, destroy the armed vehicles.
[*][b]Scenario 2 — Betrayal:[/b] The contact has been burned. Free the imprisoned RACS informant, then defuse both MJ bombs before Porto goes up in flames — [b]timer running[/b].
[*][b]Scenario 3 — Mutiny:[/b] Confrontation at the meeting point. If the squad leader survives: capture the financier. If he falls: free the informant under pressure.
[/list]

[b]5 main tasks · 3 branch points · 2 distinct narrative arcs.[/b] Every path leads to a player-initiated helicopter extraction — never automatic.

[hr][/hr]

[h2]🗺️ MISSION TREE[/h2]

[code]
  ┌─────────────────────────────────────┐
  │  MISSION START                      │
  └──────────────┬──────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────┐
  │  TASK 00 — Boarding                 │
  │  Reach the rendezvous point         │
  └──────────────┬──────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────┐
  │  TASK 01 — Rendezvous               │
  │  Scenario drawn randomly            │
  └──────┬───────────┬──────────────────┘
         │           │           │
    S1   │      S2   │      S3   │
  Coop-  │  Betrayal │   Mutiny  │
 eration │           │           │
         ▼           ▼      ┌────┴────────┐
  ┌───────────┐  ┌────────┐ │             │
  │ TASK 02A  │  │TASK 02B│ │ Leader alive│ Leader dead
  │ Neutralise│  │The Red │ ▼             ▼
  │ leaders   │  │Thread  │ ┌──────────┐  ┌────────┐
  │ Recover   │  │Free the│ │ TASK 02C │  │TASK 02B│
  │ documents │  │infor-  │ │The Middle│  │The Red │
  └─────┬─────┘  │mant    │ │man       │  │Thread  │
        │        └───┬────┘ │Capture   │  └───┬────┘
        │            │      │financier │      │
        │            │      └────┬─────┘      │
        ▼            ▼           ▼             ▼
  ┌───────────┐  ┌────────────────────┐  ┌────────────────────┐
  │ TASK 03A  │  │      TASK 03A      │  │      TASK 03B      │
  │ Armed     │  │    Armed           │  │ Operation Shield   │
  │ vehicles  │  │    vehicles        │  │ Defuse MJ bombs    │
  └─────┬─────┘  └────────┬───────────┘  └──────────┬─────────┘
        │                 │                          │
        └────────┬────────┘                          │
                 │                                   │
                 └──────────────┬────────────────────┘
                                ▼
                  ┌─────────────────────────────┐
                  │  HELICOPTER EXTRACTION      │
                  │  Initiated by the players   │
                  │  End of mission             │
                  └─────────────────────────────┘
[/code]

[hr][/hr]

[h2]⚙️ REAL-TIME TACTICAL COMMAND[/h2]

The squad leader has a full set of orders available through the [b]scroll menu[/b].

[list]
[*][b]Rules of Engagement (RoE):[/b] 4 instant modes — Infiltration (total silence, crouched movement) · Vigilance (defensive) · Assault (free fire, active cover) · Charge (sprint on objective)
[*][b]Squad healing:[/b] Wounded AI treat themselves as soon as enemy contact is broken, in staggered sequence.
[*][b]Smart rally:[/b] Semi-circular formation behind the leader, automatic pathfinding unblock (3 attempts), safety timeout.
[*][b]Building sweep:[/b] The squad clears structures within 50 m then reforms within 3 minutes.
[/list]

[hr][/hr]

[h2]🚁 HELICOPTER SUPPORT — CH-47F RACS[/h2]

One Chinook. One centralised dispatcher with a priority system — a critical mission task can interrupt an ongoing delivery.

[list]
[*][b]Ammo resupply:[/b] Crate dropped on site. AI units resupply in pairs with a looting animation — up to 8 magazines reloaded per unit. The leader manages his own inventory.
[*][b]Vehicle delivery:[/b] Sling-load. [b]Single use[/b] per mission.
[*][b]CAS air support:[/b] Close air support strike. 5-minute cooldown.
[*][b]Reinforcements:[/b] RACS squad paradropped.
[*][b]Extraction:[/b] The helicopter only lifts off when your team is ready. In certain tasks it is [b]exclusively reserved for an NPC[/b] — any player who boards is ejected.
[/list]

[hr][/hr]

[h2]🛸 DRONE SURVEILLANCE — MQ-9 REAPER[/h2]

[list]
[*]Circular loiter 15 minutes · altitude 180 m · radius 450 m
[*]Real-time enemy (red) and friendly (blue) map markers
[*]Detection range: 1,000 m
[*]One active drone at a time. Enemy ground units ignore it.
[/list]

[hr][/hr]

[h2]💀 DEATH AND GAME CONTINUITY[/h2]

Your character goes down? [b]You don't disappear.[/b] You automatically take control of a living AI in your squad — full control transfer, Event Handlers included. Command automatically reassigns to the next living human player. If all AI are out of action, spectator mode activates. Only the [b]simultaneous death of every human player[/b] triggers a defeat — and even then, a safety delay gives the last control transfers time to complete. If a single player is still alive, he can call reinforcements and other players can retake control of their AI units.

[hr][/hr]

[h2]💣 OPERATION SHIELD — TASK 03B[/h2]

[b]High-risk mission.[/b] The MJ has planted two explosive devices across Porto.

[list]
[*][b]Live countdown[/b] displayed in your HUD (top right) — 25 to 45 minutes. Turns red under 5 minutes.
[*]Defusing: hold action for 10 seconds within 3 metres of the bomb.
[*]8 to 12 MJ guards per site, organised in two active patrols.
[*][b]Infiltrated civilian traitors[/b]: undetectable at range, they automatically arm themselves if you approach within 15 metres.
[*]Failure: explosions, guards go assault, survival sub-task activated. Hold on until extraction.
[/list]

[hr][/hr]

[h2]🪪 PROCEDURAL IMMERSION[/h2]

[list]
[*][b]Random identities:[/b] unique name, face and voice for every player at every session.
[*][b]Randomised gear:[/b] uniform, vest, helmet, backpack — no two soldiers look the same from one mission to the next.
[*][b]Dynamic civilians:[/b] fishermen, passers-by and residents moving through Porto. Avoid civilian casualties.
[*][b]Soundscape:[/b] procedural calls to prayer, harbour ambient sounds.
[*][b]Random weather:[/b] different conditions every time you launch.
[/list]

[hr][/hr]

[h2]📋 TECHNICAL INFO[/h2]

[list]
[*][b]Mode:[/b] Singleplayer / Hosted cooperative / Dedicated server
[*][b]Players:[/b] 1 to 4
[*][b]DLC required:[/b] [b]None[/b]
[*][b]Required mods:[/b] CUP Terrains Core · CUP Terrains Maps · CUP Units · CUP Weapons · CUP Vehicles
[*][b]Map:[/b] Porto (CUP Terrains)
[*][b]Player faction:[/b] RACS — Independent side
[*][b]Estimated duration:[/b] 60 to 120 minutes depending on scenario
[/list]

[hr][/hr]
[i]— RACS Multinational Command · 2026[/i]
