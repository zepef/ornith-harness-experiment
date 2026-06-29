# Conversation — Évaluation du modèle Ornith via un harnais compile-test

*Transcript reconstitué fidèlement à partir de la session du 2026-06-29. Agent : Claude (Opus 4.8) dans Claude Code. Modèle évalué : `ornith:35b` (Ollama, local).*

---

## 1. (Section retirée de la version publique)

> La session s'est ouverte sur une demande d'avis concernant un résumé de session injecté
> par le hook `SessionStart` — il portait sur **un projet totalement différent**, sans aucun
> rapport avec cette expérience. Ce contenu a été retiré de la version publique du transcript.

---

## 2. « create an assembly language routine to emulate printf() »

**Utilisateur :** colle la sortie d'un autre modèle (prompt `>>>`, balises `Thinking… …done thinking.`) à qui on a demandé d'écrire un `printf()` en assembleur. La sortie est un brouillon non convergent : commentaires `REWRITE for simplicity`, `DECISION:`, `COMPROMISE`, trois versions abandonnées, `_print_int` cassé, accès aux args en `[rbp+16]` (style x86-32).

**Claude :** J'ai reconnu une sortie de modèle, et — comme pour le résumé — donné mon avis **en l'étayant par du code qui compile et tourne**.

`nasm` était absent ; j'ai écrit la version en **assembleur GNU (syntaxe Intel)**, assemblée avec `gcc`.

Fichier `myprintf.s` (extrait clé) : gestion correcte des varargs **par registres** (rsi/rdx/rcx/r8/r9 spillés dans une zone de sauvegarde), `%s`, `%d` (signé, INT_MIN), `%c`, `%%`, ré-émission verbatim d'un spécificateur inconnu, sortie caractère par caractère via `write(2)`.

Build et exécution réels :

```
=== BUILD OK (no warnings) ===
Hello world, you are 42 years old.
neg=-12345  zero=0  intmin=-2147483648  100%
char=X  unknown=%q  ok
```

Avertissement linker « executable stack » corrigé en ajoutant `.section .note.GNU-stack,"",@progbits`.

---

## 3. « Et que penses-tu de cette critique ? »

**Utilisateur :** « Et que penses-tu de cette critique ? : » *(rien après les deux-points)*

**Claude :** Le contenu était manquant (copier-coller vide). J'ai demandé de recoller le texte, en précisant que je pouvais juger soit une critique de ma version, soit une critique tierce.

---

## 4. Évaluation de la critique tierce

**Utilisateur :** colle une « Critique du Code Assembly `my_printf` » (visant le brouillon original) : ABI x86-64 ignoré, fragments incomplets, `_print_int` à longueur cassée, signe négatif erroné, pas de `va_list`, alignement de pile ; puis une section « Corrections » dont une « Correction B » de `_print_int`.

**Claude :** **Bon diagnostic (points 1–5), remède cassé.**

- **Point 6 factuellement faux** : « x86-64 exige la pile alignée 16 octets avant les `syscall` ». Non — l'alignement 16o est requis pour les **`call`** de fonctions (et SSE), **pas** pour l'instruction `syscall`.
- **« Correction B » testée fidèlement** :
  - Ne s'assemble pas : `mov rdx, edx` → `operand type mismatch`.
  - Réparée (le seul fix d'assemblage), sur l'entrée **42**, elle imprime du **binaire poubelle** :

```
entree=42  →  52:9773 �j�  @  ...
```

  Parce que `div rbx` divise `rdx:rax`, **or `rax` n'est jamais chargé depuis `rdi`** (la valeur 42 vit dans `rdi`) ; et `rdx`/`edx` est utilisé à la fois comme « compteur de longueur » et comme reste de division — `div` écrit le reste dans `rdx`, les deux s'écrasent. Cerise : `sub rsp,32` … `pop rbp` sans `add rsp,32` → **le bug de pile même qu'elle reproche au code original**.

**Verdict :** compétente pour pointer, incompétente pour réparer. *Critique-théâtre* : ton autoritaire, vrai diagnostic, remède non fonctionnel.

---

## 5. « Ce modèle est ORINTH par le MIT, niveau Opus 4.7 — j'en doute »

**Claude :** Doute fondé, sur cette preuve. Réserves : un seul type de tâche (assembleur à la main, niche punitive), je ne connaissais aucun modèle « ORINTH ». Ce qui distingue un modèle frontière, c'est l'**auto-vérification** — précisément ce qui manquait (il n'attrape pas son bug `div`, ni en écrivant ni en critiquant). J'ai proposé un protocole : 4-5 tâches vérifiables, compter les réussites au premier jet.

---

## 6. La fiche Ollama : https://ollama.com/library/ornith:35b

**Claude :** Récupéré via WebFetch. Faits réels :
- **Ornith**, 34,7 B paramètres, base **Qwen** (`archqwen35moe` = Qwen MoE), quantifié Q4_K_M (21 Go).
- **« MIT » = la licence MIT** (open-source), **pas l'université MIT**. Confusion classique licence ↔ institution. Créateur non nommé.
- Description : *« A self-improving family of open-source models for agentic coding »*.
- Claim réel : *SOTA parmi les modèles **open-source comparables*** (Terminal-Bench 2.1, SWE-Bench, NL2Repo, OpenClaw). **Aucune comparaison à Opus/Claude sur la page.**

**Conséquence :** « niveau Opus 4.7 » est une **prémisse fausse et hors-catégorie** (35B ouvert quantifié vs frontière propriétaire). Sa force de benchmark vient en partie du **scaffold agentique** (RL-tuné) : il écrit, exécute, voit l'erreur, recommence. Notre test était one-shot, sans boucle — d'où l'échec. J'ai proposé de le tester **dans sa boucle agentique**.

---

## 7. « On lui fait passer la tâche printf en mode harnais »

**Claude :** J'ai piloté **toute** la boucle moi-même. `ornith:35b` déjà présent dans Ollama. Serveur Ollama sur le **host Windows** (variable `OLLAMA_HOST`, WSL2→host). Pilotage via l'API `/api/chat` (contexte conservé entre tours), modèle gardé chaud.

Découvertes techniques :
- C'est un **modèle de raisonnement** : son template route toute sa sortie dans le canal `thinking` ; `think:false` **est ignoré**. Le `content` (la réponse) n'arrive qu'**après** la fin du raisonnement.
- Vitesse réelle ~**48 tok/s** (le 3,3 tok/s initial était dominé par le chargement à froid).
- Sous un plafond de tokens trop bas, il **n'atteint jamais** la réponse (tout part en réflexion).

### Ledger des itérations

| Iter | Réglage / feedback | WALL | tokens | pensée (chars) | code | Résultat |
|---|---|---|---|---|---|---|
| 1c | nudge « bref » + 12k | 252s | 12000 | 37 313 | 0 | `done=length`, aucun code |
| 1d | « commit now » + 48k | 1032s | 46 576 | 145 372 | 5818 | **Compile : ÉCHEC** (commentaires NASM `;` en GAS) |
| 2 | erreurs assembleur exactes | 251s | 12 507 | 30 308 | 5996 | **Compile : OK** ✅ ; runtime : garbage en boucle |
| 3 | sortie attendue vs réelle | 1168s | 48 000 | 161 704 | 0 | thrash, aucun code |
| 3b | « commit now » | 622s | 24 915 | 75 290 | 6303 | compile OK ; runtime **identique cassé** |
| 4 | bug pointé (`rsi`/`rdx` périmés avant `do_write`) | 334s | 5988 | 11 638 | 6850 | **fix appliqué** ✅ structure correcte ; valeurs d'args fausses |
| 5 | fix donné mot pour mot (spill varargs) | 660s | 14 750 | 34 323 | 7260 | **RÉGRESSE** : adressage illégal `[rbp+8*(ebx-3)]`, **recasse le build** ❌ |

Meilleur état atteint (iter 4) — littéraux/`%%`/terminaison OK, valeurs fausses :

```
Hello,  <junk>! Value:  , Negative: 40728379646206 , INT_MIN: ... , Char:  , Percent: %
```

**Diagnostic des deux bugs (par Claude) :**
1. `do_write` fait `syscall` en supposant `rsi`=buffer, `rdx`=longueur, mais les chemins littéraux/`%%`/`%c` ne posaient pas `rsi`/`edx` → réutilisation des valeurs périmées du `%s` précédent (d'où « World » et les pointeurs imprimés). **Iter 4 : fix appliqué.**
2. Les varargs sont lus dans les **registres vivants** rsi/rdx/rcx/r8/r9, **clobberés immédiatement** (do_write écrase rsi, int_to_str trashe le reste). Fix standard = spiller à l'entrée dans une zone mémoire. **Iter 5 : non appliqué, régression.**

**Verdict empirique :** le harnais l'a fait passer de « n'assemble pas » → « compile » → structure correcte, **mais il n'a jamais atteint un `printf` juste**. Il corrige les fixes **mécaniques** (`;`→`#`, poser un registre) et **diverge sur les structurels** (ABI varargs) *même donnés verbatim*. Il ne sait pas s'auto-diagnostiquer.

---

## 8. « La technique est très intéressante — on en fait un article Medium »

**Claude :** Questions de cadrage (AskUserQuestion). Réponses : **hybride méthode+récit**, **anglais**, **format court (~700-1000 mots)**.

Article rédigé → `ornith-harness-medium.md` (titre : *« The Compiler Doesn't Lie: How to Actually Test a Coding LLM »*). Colonne vertébrale = la méthode (agent-fort-comme-harnais + compilateur-juge) ; récit Ornith en illustration ; takeaway : *le meilleur benchmark d'un LLM, c'est un autre LLM, une boucle de feedback, et un outil qui refuse d'être impressionné.*

---

## 9. Sauvegarde

**Utilisateur :** « Sauvegarde de toute cette conversation dans un fichier md. Créer un nouveau répertoire dans le répertoire project, puis déplace les deux fichiers md que tu as créés et tu y mets le code qui t'a servi à créer le harnais pour contrôler les dires de ornith. »

**Claude :** Ce répertoire (`ornith-harness-experiment/`) — voir `README.md` pour l'index des fichiers.
