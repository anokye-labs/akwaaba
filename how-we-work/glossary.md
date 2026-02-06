# Glossary: Akan Terms & Concepts

At Anokye Labs, we draw from Akan culture to name our systems and describe how we work together.

## Terms

### Akwaaba (ah-KWAH-bah)
**Meaning:** Welcome

**In our system:** The reference implementation repository. Akwaaba is where new contributors (human and AI) come to learn how we work. It contains the governance model, agent instructions, and documentation.

**Repository:** [anokye-labs/akwaaba](https://github.com/anokye-labs/akwaaba)

---

### Ananse (ah-NAHN-seh)
**Meaning:** Spider — the clever trickster figure in Akan folklore who owns all stories

**In our system:** The agentic runtime engine. Like the spider at the center of a web, Ananse connects all the pieces and enables dynamic, intelligent behavior.

---

### Asafo (ah-SAH-fo)
**Meaning:** Warrior company — traditional military organizations of the Akan people

**In our system:** The team — both human contributors and AI agents working together. The asafo moves as a unit, each member with a role, coordinated by the Okyerema.

---

### Adwoma (ah-DWOH-mah)
**Meaning:** Work, labor

**In our system:** The actual work being done — issues, tasks, code changes, documentation. When we say "coordinating adwoma," we mean organizing and tracking all the work that needs to happen.

---

### Okyeame (oh-CHEH-ah-meh)
**Meaning:** Spokesperson, the chief's linguist — the person who speaks on behalf of the chief and interprets messages

**In our system:** The client applications that connect users to the Ananse runtime. The Okyeame translates between human intent and machine action, using voice-first input and adaptive card output.

**Repository:** [anokye-labs/okyeame](https://github.com/anokye-labs/okyeame)

---

### Okyerema (oh-CHEH-reh-mah)
**Meaning:** Talking drummer — the musician who communicates messages, calls the community to action, and keeps the rhythm during ceremonies and battles

**In our system:** The project orchestration skill. The Okyerema keeps agents in rhythm — coordinating adwoma through the asafo. When the Okyerema beats the drum, the asafo knows what to do and when to do it.

**Skill:** [.github/skills/okyerema/](../.github/skills/okyerema/SKILL.md)

---

## How They Fit Together

```
┌─────────────────────────────────────────────────┐
│                    Akwaaba                       │
│              (Welcome / Reference)               │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │              Okyerema                     │   │
│  │         (Talking Drummer)                 │   │
│  │   Orchestrates the asafo's adwoma         │   │
│  │   via GitHub Issues & Projects            │   │
│  └──────────────────────────────────────────┘    │
│                                                  │
│           ┌─────────┐  ┌─────────┐               │
│           │  Asafo  │  │  Asafo  │               │
│           │ (Agent) │  │ (Human) │               │
│           └────┬────┘  └────┬────┘               │
│                │            │                    │
│                └─────┬──────┘                    │
│                      ▼                           │
│              ┌───────────────┐                   │
│              │    Ananse     │                   │
│              │  (Runtime)    │                   │
│              └───────┬───────┘                   │
│                      ▼                           │
│              ┌───────────────┐                   │
│              │   Okyeame     │                   │
│              │  (Client UI)  │                   │
│              └───────────────┘                   │
└─────────────────────────────────────────────────┘
```

The **Okyerema** keeps the **asafo** in rhythm as they do **adwoma**. The **Ananse** runtime powers the intelligence. The **Okyeame** speaks to the world. And **Akwaaba** welcomes everyone in.

---

## Why Akan?

Anokye Labs draws from Akan cultural concepts because they map beautifully to how we think about AI-assisted software development:

- The **talking drummer** doesn't do the work — it coordinates and communicates
- The **asafo** is stronger as a unit than any individual warrior
- The **spider's web** connects everything intelligently
- The **spokesperson** translates between different worlds

These aren't just names — they're design principles.

---

*[← Back to Our Way](./our-way.md) | [← Back to How We Work](../how-we-work.md)*
