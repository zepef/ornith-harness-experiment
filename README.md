# Ornith Harness Experiment

Évaluation du modèle **`ornith:35b`** (Ollama, local) — annoncé « niveau Opus 4.7 » — en le mettant
dans un **harnais compile-test** piloté par Claude (Opus 4.8 dans Claude Code), avec un compilateur
comme juge. Tâche : émuler `printf()` en assembleur x86-64.

**Verdict empirique :** le harnais le fait passer de « n'assemble pas » → « compile » → structure
correcte, **mais il n'atteint jamais un `printf` juste**. Il corrige les fixes *mécaniques*
(`;`→`#`, poser un registre manquant) et **diverge sur les fixes *structurels*** (l'ABI varargs)
*même donnés mot pour mot*. « Niveau Opus 4.7 » = erreur de catégorie : Qwen-MoE 34,7B quantifié Q4,
sous **licence MIT** (≠ université MIT).

---

## Contenu

| Fichier | Description |
|---|---|
| `conversation.md` | Transcript de la session (critique printf → enquête Ornith → harnais → article). |
| `ornith-harness-medium.md` | Article Medium prêt à publier (EN, ~870 mots) : *« The Compiler Doesn't Lie ».* |
| **`harness/`** | Le code du harnais. |
| `harness/chat.py` | Driver : pousse les messages à l'API Ollama `/api/chat`, garde le contexte, journalise pensée/réponse. |
| `harness/prompt1.txt` | Le prompt de tâche (émuler printf, contraintes ABI + toolchain GAS). |
| `harness/ornith-dialogue.json` | Dialogue intégral Claude↔Ornith (tous les tours + feedbacks réinjectés). |
| `harness/ledger.txt` | Stats par itération (wall, tokens, longueur de pensée, code émis, issue). |
| **`reference-printf/`** | L'implémentation de référence **qui marche** (écrite par Claude). |
| `reference-printf/myprintf.s` | printf x86-64 (GAS, syntaxe Intel) : `%s %d %c %%`, INT_MIN, varargs spillés. |
| `reference-printf/test.c` | Test C + sortie attendue. |
| **`ornith-output/`** | La meilleure tentative d'Ornith + preuves. |
| `ornith-output/ornith-sol.s` | Dernière sortie d'Ornith (régression iter 5 : n'assemble pas). |
| `ornith-output/run_out.txt` | Sortie runtime erronée (valeurs d'args fausses). |
| `ornith-output/last_build_errors.txt` | Erreurs d'assemblage de la dernière itération. |
| **`critique-demo/`** | Démonstration que la « Correction B » d'une critique tierce ne tient pas. |
| `critique-demo/correctionB.s` | « Correction B » transcrite : ne s'assemble pas (`mov rdx, edx`). |
| `critique-demo/demoB.s`, `mainB.c` | Version réparée *a minima* → imprime du binaire au lieu de « 42 » (rax jamais chargé). |

---

## Reproduire

**Le harnais** (nécessite Ollama avec `ornith:35b` et `OLLAMA_HOST` pointant sur le serveur) :
```bash
cd harness
# seed conv.json avec prompt1.txt, puis :
python3 chat.py conv.json        # un tour ; réinjecter les erreurs et relancer
```
Note : `chat.py` lit le serveur depuis la variable d'environnement `OLLAMA_HOST`
(défaut `http://127.0.0.1:11434`). `ornith` est un modèle de raisonnement : prévoir un `num_predict`
élevé (≥48k) sinon il n'atteint jamais sa réponse (tout part en `thinking`).

**L'implémentation de référence** (qui marche) :
```bash
cd reference-printf
gcc -no-pie test.c myprintf.s -o t && ./t
```

**La « Correction B » cassée** :
```bash
cd critique-demo
gcc -c correctionB.s -o correctionB.o     # -> Error: operand type mismatch (mov rdx, edx)
gcc -no-pie mainB.c demoB.s -o demoB && ./demoB   # entrée 42 -> binaire poubelle
```
