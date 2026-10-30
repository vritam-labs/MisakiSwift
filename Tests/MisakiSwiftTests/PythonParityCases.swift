import Testing
@testable import MisakiSwift

/// One sentence per parity fix, with Python misaki 0.9.4's exact output (en.G2P(trf=False, british=False,
/// espeak fallback, unk="")). Each of these failed before its fix; ParityTests covers the broad corpus.
let pythonMisakiCases: [(text: String, phonemes: String)] = [
  ("We use self-attention here.", "wˌi jˈuz sˌɛlfətˈɛnʧən hˈɪɹ."),  // in-word hyphen is not a pause
  ("A state-of-the-art model.", "ɐ stˈAtʌvðiˈɑɹt mˈɑdᵊl."),  // multi-hyphen compound
  ("Results are on Section 23 of WSJ.", "ɹəzˈʌlts ɑɹ ˌɔn sˈɛkʃən twˈɛnti θɹˈi ʌv dˌʌbᵊljuˌɛsʤˈA."),  // 21-29 keep their twenty
  ("It cost 1,500,000 dollars.", "ˌɪt kˈɔst wˈʌn mˈɪljᵊn fˈIv hˈʌndɹəd θˈWzᵊnd dˈɑləɹz."),  // millions before thousands
  ("It took 3.5 days and 0.1 dropout.", "ˌɪt tˈʊk θɹˈi pYnt fˈIv dˈAz ænd zˈɪɹO pYnt wˈʌn dɹˈɑpˌWt."),  // decimals are numbers, not initialisms
  ("Transformer (big) model.", "tɹænsfˈɔɹməɹ (bˈɪɡ) mˈɑdᵊl."),  // parentheses are kept
  ("as in [29], it works.", "æz ɪn [twˈɛnti nˈIn), ɪt wˈɜɹks."),  // brackets map like spaCy
  ("She said \"hi\" and left.", "ʃˌi sˈɛd “hˈI” ænd lˈɛft."),  // straight quotes become curly
  ("John V. Smith spoke.", "ʤˈɑn vˈi smˈɪθ spˈOk."),  // single letter + period is one token
  ("less than i.", "lˈɛs ðən ˈI"),  // sentence-final single letter drops its period
  ("The 21st and 44th meetings.", "ðə twˈɛnti fˈɜɹst ænd fˈɔɹTi fˈɔɹθ mˈiTɪŋz."),  // ordinals
  ("The company raised $4.5 million at a $40 million valuation.", "ðə kˈʌmpᵊni ɹˈAzd fˈɔɹ pYnt fˈIv mˈɪljᵊn dˈɑləɹz æt ɐ fˈɔɹTi mˈɪljᵊn dˈɑləɹz vˌæljuˈAʃən."),  // currency after a decimal
  ("About 25% of the 1,200 people agreed.", "əbˈWt twˈɛnti fˈIv pəɹsˈɛnt ʌv ðə wˈʌn θˈWzᵊnd tˈu hˈʌndɹəd pˈipᵊl əɡɹˈid."),  // percent
  ("He paid £20 for the 3rd edition.", "hˌi pˈAd twˈɛnti pˈWndz fɔɹ ðə θˈɜɹd ədˈɪʃən."),  // ordinal spacing
  ("He was born in the '80s and grew up listening to his parents' records.", "hˌi wʌz bˈɔɹn ɪn ði ˈATiz ænd ɡɹˈu ˌʌp lˈɪsənɪŋ tə hɪz pˈɛɹᵊnts ɹˈɛkəɹdz."),  // apostrophes
  ("It dropped to -5 degrees.", "ˌɪt dɹˈɑpt tə mˈInəs fˈIv dəɡɹˈiz."),  // signed number
  ("We propose a new model in this paper.", "wˌi pɹəpˈOz ɐ nˈu mˈɑdᵊl ɪn ðɪs pˈApəɹ."),  // POS tags present (a, in)
]

@Test(arguments: pythonMisakiCases.map { $0.text })
func testMatchesPythonMisaki(_ text: String) {
  let g2p = EnglishG2P(british: false, unk: "")
  let expected = pythonMisakiCases.first { $0.text == text }!.phonemes
  #expect(g2p.phonemize(text: text).0 == expected)
}
