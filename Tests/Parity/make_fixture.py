"""Expected phonemes for the parity test, from Python misaki configured the way Paradee and Kokoro use it
(en.G2P(trf=False, british=False, espeak fallback, unk="")). Words misaki sent to espeak (rating 2) are listed per sentence,
since MisakiSwift's fallback is a BART network and is expected to differ there.
Needs misaki[en] + espeakng + huggingface_hub (FishTTS's .venv-paradee has them).
Run with a Python that has misaki[en] + espeakng: python make_fixture.py > parity.json"""
import glob, json, os, re

from huggingface_hub import hf_hub_download

from misaki import en, espeak

g2p = en.G2P(trf=False, british=False, fallback=espeak.EspeakFallback(british=False), unk="")
cases = []
here = os.path.dirname(os.path.abspath(__file__))
for path in sorted(glob.glob(os.path.join(here, "corpus", "*.txt"))):
    for sentence in re.split(r"(?<=[.!?…])\s+|\n+", open(path, encoding="utf-8").read().strip()):
        if not sentence.strip():
            continue
        ps, tokens = g2p(sentence)
        fallback = [{"text": t.text, "phonemes": t.phonemes} for t in tokens
                    if t.phonemes and 2 in (getattr(t, "rating", None), t._.rating)]
        cases.append({"source": os.path.basename(path), "text": sentence, "phonemes": ps, "fallback": fallback})
# Kokoro's phoneme vocabulary (Paradee shares it): characters outside it never reach the voice model.
vocab = json.load(open(hf_hub_download("sahilmahendrakar/Paradee-8M-v1.1", "config.json", revision="v1.1")))["vocab"]
print(json.dumps({"vocab": "".join(vocab), "cases": cases}, ensure_ascii=False, indent=1))
