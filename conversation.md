# Conversation — Evaluating the Ornith model with a compile-test harness

*Transcript faithfully reconstructed from the 2026-06-29 session. Agent: Claude (Opus 4.8) in Claude Code. Model under test: `ornith:35b` (Ollama, local).*

---

## 1. (Section removed from the public version)

> The session opened with a request for feedback on a session summary injected by the
> `SessionStart` hook — it concerned **a completely different project**, unrelated to this
> experiment. That content has been removed from the public version of the transcript.

---

## 2. "create an assembly language routine to emulate printf()"

**User:** pastes the output of another model (prompt `>>>`, `Thinking… …done thinking.` markers) that was asked to write a `printf()` in assembly. The output is a non-converging draft: comments like `REWRITE for simplicity`, `DECISION:`, `COMPROMISE`, three abandoned versions, a broken `_print_int`, args accessed via `[rbp+16]` (x86-32 style).

**Claude:** I recognized a model's output and — as with the summary — gave my opinion **backed by code that compiles and runs**.

`nasm` wasn't available, so I wrote the version in **GNU assembler (Intel syntax)**, assembled with `gcc`.

`myprintf.s` (key points): correct varargs handling **via registers** (rsi/rdx/rcx/r8/r9 spilled into a save area), `%s`, `%d` (signed, INT_MIN), `%c`, `%%`, verbatim re-emission of an unknown specifier, character-by-character output via `write(2)`.

Real build and run:

```
=== BUILD OK (no warnings) ===
Hello world, you are 42 years old.
neg=-12345  zero=0  intmin=-2147483648  100%
char=X  unknown=%q  ok
```

The "executable stack" linker warning was fixed by adding `.section .note.GNU-stack,"",@progbits`.

---

## 3. "And what do you think of this critique?"

**User:** "And what do you think of this critique? :" *(nothing after the colon)*

**Claude:** The content was missing (empty paste). I asked for the text, noting I could judge either a critique of my version or a third-party critique.

---

## 4. Evaluating the third-party critique

**User:** pastes a "Critique of the `my_printf` Assembly Code" (targeting the original draft): x86-64 ABI ignored, incomplete fragments, broken length math in `_print_int`, wrong negative-sign handling, no `va_list`, stack alignment; plus a "Corrections" section including a "Correction B" for `_print_int`.

**Claude:** **Good diagnosis (points 1–5), broken remedy.**

- **Point 6 is factually wrong:** "x86-64 requires the stack 16-byte aligned before `syscall`." No — 16-byte alignment is required for function **`call`s** (and SSE), **not** for the `syscall` instruction.
- **"Correction B" tested faithfully:**
  - Doesn't assemble: `mov rdx, edx` → `operand type mismatch`.
  - Once repaired (the single assembler fix), on input **42** it prints **binary garbage**:

```
input=42  →  52:9773 �j�  @  ...
```

  Because `div rbx` divides `rdx:rax`, but **`rax` is never loaded from `rdi`** (the value 42 lives in `rdi`); and `rdx`/`edx` is used both as a "length counter" and as the division remainder — `div` writes the remainder into `rdx`, so the two clobber each other. The cherry: `sub rsp,32` … `pop rbp` without `add rsp,32` → **the very stack bug it criticizes in the original code**.

**Verdict:** competent at pointing, incompetent at repairing. *Critique theater*: authoritative tone, real diagnosis, non-functional remedy.

---

## 5. "This model is ORINTH by MIT, Opus-4.7-level — I doubt it"

**Claude:** The doubt is well-founded, on this evidence. Caveats: a single task type (hand-written assembly, a punishing niche), and I knew of no model called "ORINTH." What distinguishes a frontier model is **self-verification** — precisely what was missing here (it doesn't catch its own `div` bug, neither while writing nor while critiquing). I proposed a protocol: 4–5 verifiable tasks, count first-pass successes.

---

## 6. The Ollama page: https://ollama.com/library/ornith:35b

**Claude:** Fetched via WebFetch. The actual facts:
- **Ornith**, 34.7B parameters, base **Qwen** (`archqwen35moe` = Qwen MoE), quantized Q4_K_M (21 GB).
- **"MIT" = the MIT license** (open-source), **not MIT the university**. Classic license↔institution confusion. Creator not named.
- Description: *"A self-improving family of open-source models for agentic coding."*
- Real claim: *SOTA among **comparable open-source models*** (Terminal-Bench 2.1, SWE-Bench, NL2Repo, OpenClaw). **No comparison to Opus/Claude on the page.**

**Consequence:** "Opus-4.7-level" is a **false, out-of-category premise** (open quantized 35B vs proprietary frontier). Its benchmark strength comes partly from the **agentic scaffold** (RL-tuned): it writes, runs, sees the error, retries. Our first test was one-shot, no loop — hence the failure. I proposed testing it **inside its agentic loop**.

---

## 7. "Let's run the printf task in harness mode"

**Claude:** I drove the **entire** loop myself. `ornith:35b` already present in Ollama. The Ollama server runs on the **Windows host** (`OLLAMA_HOST`, WSL2→host). Driven via the `/api/chat` endpoint (context preserved across turns), model kept warm.

Technical findings:
- It's a **reasoning model**: its template routes all output into the `thinking` channel; `think:false` **is ignored**. The `content` (the answer) only appears **after** reasoning finishes.
- Real speed ~**48 tok/s** (the initial 3.3 tok/s was dominated by cold load).
- Under too small a token cap it **never reaches** the answer (everything goes to thinking).

### Iteration ledger

| Iter | Setting / feedback | WALL | tokens | thinking (chars) | code | Result |
|---|---|---|---|---|---|---|
| 1c | "be brief" nudge + 12k | 252s | 12000 | 37,313 | 0 | `done=length`, no code |
| 1d | "commit now" + 48k | 1032s | 46,576 | 145,372 | 5818 | **Compile: FAIL** (NASM `;` comments in GAS) |
| 2 | exact assembler errors | 251s | 12,507 | 30,308 | 5996 | **Compile: OK** ✅; runtime: looping garbage |
| 3 | expected vs actual output | 1168s | 48,000 | 161,704 | 0 | thrash, no code |
| 3b | "commit now" | 622s | 24,915 | 75,290 | 6303 | compiles; runtime **identically broken** |
| 4 | bug pinpointed (`rsi`/`rdx` stale before `do_write`) | 334s | 5988 | 11,638 | 6850 | **fix applied** ✅ correct structure; arg values wrong |
| 5 | fix given verbatim (spill varargs) | 660s | 14,750 | 34,323 | 7260 | **REGRESSES**: illegal addressing `[rbp+8*(ebx-3)]`, **breaks the build** ❌ |

Best state reached (iter 4) — literals/`%%`/termination correct, values wrong:

```
Hello,  <junk>! Value:  , Negative: 40728379646206 , INT_MIN: ... , Char:  , Percent: %
```

**Diagnosis of both bugs (by Claude):**
1. `do_write` does the `syscall` assuming `rsi`=buffer, `rdx`=length, but the literal/`%%`/`%c` paths didn't set `rsi`/`edx` → reuse of the stale values from the previous `%s` (hence "World" and printed pointers). **Iter 4: fix applied.**
2. The varargs are read from the **live registers** rsi/rdx/rcx/r8/r9, **clobbered immediately** (do_write overwrites rsi, int_to_str trashes the rest). The standard fix is to spill them into a memory area at entry. **Iter 5: not applied, regression.**

**Empirical verdict:** the harness moved it from "won't assemble" → "compiles" → correct structure, **but it never reached a correct `printf`**. It fixes **mechanical** problems (`;`→`#`, set a register) and **diverges on structural ones** (the varargs ABI) *even when given them verbatim*. It cannot self-diagnose.

---

## 8. "The technique is fascinating — let's make a Medium article"

**Claude:** Framing questions (AskUserQuestion). Answers: **hybrid method+narrative**, **English**, **short format (~700-1000 words)**.

Article written → `ornith-harness-medium.md` (title: *"The Compiler Doesn't Lie: How to Actually Test a Coding LLM"*). Backbone = the method (strong-agent-as-harness + compiler-as-judge); the Ornith story as illustration; takeaway: *the most honest LLM benchmark might just be another LLM, a feedback loop, and a tool that refuses to be impressed.*

---

## 9. Saving + publishing

**User:** asked to save the whole conversation to markdown, create a new directory under `projects`, move the two `.md` files there, and add the harness code. Then: create a public GitHub repository.

**Claude:** Created `ornith-harness-experiment/` (see `README.md` for the file index). Before publishing publicly, scanned for sensitive content, removed an unrelated client-project section (the original section 1), genericized an internal IP, then created and pushed the public repo.
