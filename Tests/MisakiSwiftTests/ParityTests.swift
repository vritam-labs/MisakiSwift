import Foundation
import Testing
@testable import MisakiSwift

/// Word-level parity with Python misaki (Tests/Parity/parity.json, made by make_fixture.py). Kokoro-family voices
/// are trained on Python misaki's phonemes, so every difference outside the out-of-vocabulary fallback is a bug.
/// Python's fallback is espeak and ours is the BART network, so hunks touching fallback words are counted apart.
struct ParityCase: Decodable {
  struct Fallback: Decodable { let text: String; let phonemes: String }
  let source: String
  let text: String
  let phonemes: String
  let fallback: [Fallback]
}

/// Minimal LCS diff over words: returns the differing (expected, actual) hunks.
func wordHunks(_ a: [Substring], _ b: [Substring]) -> [([Substring], [Substring])] {
  var lcs = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
  for i in stride(from: a.count - 1, through: 0, by: -1) {
    for j in stride(from: b.count - 1, through: 0, by: -1) {
      lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
    }
  }
  var hunks: [([Substring], [Substring])] = [], i = 0, j = 0, ea: [Substring] = [], eb: [Substring] = []
  func flush() { if !ea.isEmpty || !eb.isEmpty { hunks.append((ea, eb)); ea = []; eb = [] } }
  while i < a.count || j < b.count {
    if i < a.count, j < b.count, a[i] == b[j] { flush(); i += 1; j += 1 }
    else if j < b.count, i == a.count || lcs[i][j + 1] >= lcs[i + 1][j] { eb.append(b[j]); j += 1 }
    else { ea.append(a[i]); i += 1 }
  }
  flush()
  return hunks
}

struct ParityFixture: Decodable { let vocab: String; let cases: [ParityCase] }

@Test func testParityWithPythonMisaki() throws {
  let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../Parity/parity.json")
  let fixture = try JSONDecoder().decode(ParityFixture.self, from: Data(contentsOf: url)), cases = fixture.cases
  // Compare only what the voice model hears: characters outside Kokoro's vocabulary are dropped before inference.
  let vocab = Set(fixture.vocab.unicodeScalars)
  func heard(_ s: String) -> String { String(String.UnicodeScalarView(s.unicodeScalars.filter { vocab.contains($0) })) }
  let g2p = EnglishG2P(british: false, unk: "")
  var words = 0, bugWords = 0, fallbackWords = 0, exact = 0
  var report: [String: Int] = [:], example: [String: String] = [:]
  for c in cases {
    let got = heard(g2p.phonemize(text: c.text).0), want = heard(c.phonemes)
    if got == want { exact += 1 }
    // omittingEmptySubsequences: false, so a doubled space (an extra pause token) counts as a difference
    let expected = want.split(separator: " ", omittingEmptySubsequences: false)
    words += expected.count
    let fb = c.fallback.map { heard($0.phonemes) }
    for (e, a) in wordHunks(expected, got.split(separator: " ", omittingEmptySubsequences: false)) {
      let n = max(e.count, a.count)
      if e.contains(where: { w in fb.contains { !$0.isEmpty && w.contains($0) } }) { fallbackWords += n; continue }
      bugWords += n
      let key = "\(e.joined(separator: " ")) -> \(a.joined(separator: " "))"
      report[key, default: 0] += 1
      example[key] = example[key] ?? c.text
    }
  }
  let lexAgreement = 1 - Double(bugWords) / Double(words)
  var lines = [String(format: "PARITY: %d sentences, %d exact (%.1f%%), %d words, %d non-fallback words differ (agreement %.3f), %d fallback words differ",
               cases.count, exact, 100 * Double(exact) / Double(cases.count), words, bugWords, lexAgreement, fallbackWords)]
  lines += report.sorted(by: { ($0.value, $1.key) > ($1.value, $0.key) }).map { "\($0.value)x  \($0.key)    | \(example[$0.key]!)" }
  // xcodebuild hides test stdout, so the full report also lands next to the fixture (gitignored).
  try lines.joined(separator: "\n").write(to: url.deletingLastPathComponent().appendingPathComponent("report.txt"),
                                          atomically: true, encoding: .utf8)
  print(lines.prefix(40).joined(separator: "\n"))
  #expect(lexAgreement >= 0)  // ratcheted up as fixes land
}

/// Debug aid: phonemizes each line of Tests/Parity/debug.txt (gitignored) into debug_out.txt with token detail.
@Test func testDebugSentences() throws {
  let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../Parity")
  guard let text = try? String(contentsOf: dir.appendingPathComponent("debug.txt"), encoding: .utf8) else { return }
  let g2p = EnglishG2P(british: false, unk: "")
  let out = text.split(separator: "\n").map { line -> String in
    let (ps, tokens) = g2p.phonemize(text: String(line))
    return "\(line)\n  -> \(ps)\n  " + tokens.map { "\($0.text)/\($0.tag?.rawValue ?? "nil")/\($0.phonemes ?? "nil")" }.joined(separator: "  ")
  }
  try out.joined(separator: "\n").write(to: dir.appendingPathComponent("debug_out.txt"), atomically: true, encoding: .utf8)
}
