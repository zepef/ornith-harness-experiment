# The Compiler Doesn't Lie: How to Actually Test a Coding LLM

*A local 35B model was billed as "Opus-4.7-level." So I put it in a harness and let the compiler be the judge.*

---

A friend pointed me at **Ornith**, an open-source coding model you can pull from Ollama, with a claim attached: *roughly on par with Claude Opus 4.7.* He didn't believe it. Neither did I. But "I don't believe it" isn't an argument — so we built one.

The result is a small, reusable technique that I now reach for whenever someone waves a benchmark at me: **wrap the model in a feedback loop, and make a compiler the referee.**

## The technique

The setup has three roles:

- **The candidate** — the model under test (Ornith 35B, running locally on Ollama).
- **The harness** — a *stronger* agent (Claude) that hands over a task, compiles whatever comes back, and feeds the exact errors back in. Deterministic. No vibes.
- **The judge** — `gcc` and the program's own output. Either it assembles and prints the right bytes, or it doesn't.

This matters because benchmarks blur two very different abilities into one score: **generating** plausible code, and **self-correcting** when reality pushes back. A harness pries them apart. And the judge is incorruptible — a critique can *sound* expert and still not compile. (It happened earlier in this same investigation: a polished, confident critique of some assembly proposed "fixes" that didn't even assemble. We only knew because we tried.)

## The task

Emulate C's `printf` in x86-64 assembly — `%s`, `%d`, `%c`, `%%` — following the System V ABI. It's a deliberately cruel choice: assembly is nothing *but* invariants (register clobbering, operand sizes, the varargs calling convention) and the toolchain checks every one of them mercilessly. No room to bluff.

## What happened, round by round

**Round 0 — it couldn't stop talking.** Ornith is a reasoning model, and left alone it reasoned itself into a wall: 12,000 tokens of internal monologue, *zero* lines of code. I watched it re-litigate how to store a single byte — `mov [rsi], al`? `mov byte ptr`? — over and over ("Ugh… wait, I clobbered ecx… let me just try"). Only after an explicit *"commit now, I'll compile it for you"* did it finally emit code — **after 17 minutes and ~46,000 tokens, 89% of them thinking.**

**Round 1 — won't assemble.** The first real attempt used NASM-style `;` comments in a GNU-assembler context, where `;` is a statement separator. Every comment became a phantom instruction. Dozens of errors.

**Round 2 — the loop works.** I pasted the exact assembler errors back. It fixed the comment syntax, added the `ptr` size keywords, and **it built.** Real progress, driven entirely by feedback.

**Round 3 — the loop stalls.** The program ran but printed looping garbage. I fed back *expected vs. actual*. Ornith thrashed: **161,000 characters of thinking, no fix.** Forced to commit, it re-emitted byte-identical broken code.

**Round 4 — it can take a precise fix.** I stopped describing symptoms and pointed at the line: *your `do_write` syscall reads `rsi`/`rdx`, but your literal-character path never sets them, so it reuses stale values from the previous `%s`.* This it could do. The structural bug vanished — clean single line, correct literals, working `%%`:

```
Hello,  <junk>! Value:  , Negative: 40728379646206 , ... , Percent: %
```

Structure perfect. Argument *values* still wrong.

**Round 5 — it regresses.** The remaining bug was architectural: it read varargs from *live* registers that get clobbered immediately; the fix is to spill them to a stack save area at entry. I handed it the exact code to paste. It ignored it, invented an illegal addressing mode (`[rbp+8*(ebx-3)]`), and **turned a building program back into a broken one.**

We never reached a fully correct `printf`.

## The verdict

Here's what the harness made visible that no leaderboard could:

> Ornith converges on **mechanical** fixes (swap `;` for `#`, set a missing register) and diverges on **structural** ones (the varargs ABI) — even when handed the solution verbatim. It cannot self-diagnose; it needed a stronger agent to localize every bug, and it still regressed on the hard one.

That's not an insult — it's a *category*. Ornith is a quantized 34.7B Qwen MoE under the **MIT license** (which, note, is a software license, not the university). For an open model you can run on one GPU, holding the ABI in its head at all is impressive. But "Opus-4.7-level" was never the claim on the label — the label says *SOTA among comparable open-source models*, with no frontier comparison at all. The parity story was marketing folklore, and one afternoon with a compiler dissolved it.

## The takeaway

If you want to know what a model can really do, don't read the benchmark number. Build the loop:

1. Give it a task with an **objective oracle** (it compiles and runs, or it doesn't).
2. Feed back **exact** tool output, nothing softened.
3. Watch *where* it stops improving.

The gap between "passes the eval" and "ships correct code" is precisely the gap between the mechanical fix and the structural one — and a harness with a compiler at the bottom is the cheapest way to see it.

The whole experiment, by the way, was run by one agent driving another on a laptop. That's the fun part: the most honest LLM benchmark might just be **another LLM, a feedback loop, and a tool that refuses to be impressed.**
