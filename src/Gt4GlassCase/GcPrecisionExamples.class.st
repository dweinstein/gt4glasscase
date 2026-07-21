"
Executable documentation + tests for the runnable low-precision inference engine (Glass Case Stage 2/3). The hermetic examples prove the quantization MATH independent of the model: symmetric per-row round-to-nearest int4/int8 and bf16 rounding on tiny hand-computed weights. The <noTest> precisionDifferentialExample is the headline end-to-end result: the SAME GPT-2-124M forward run at f32/bf16/int8/int4 on the in-context France prompt, comparing greedy tokens and logit divergence -- the precision differential made observable.
"
Class {
	#name : 'GcPrecisionExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase-Precision',
	#package : 'Gt4GlassCase',
	#tag : 'Precision'
}

{ #category : 'examples - hermetic' }
GcPrecisionExamples >> bf16RoundingExample [
	"bf16 rounding keeps sign + 8 exponent + top 7 mantissa bits. pi (f32 word 0x40490FDB) rounds to bf16 0x4049 = 3.140625 (reusing GcDtypeDecoder bf16FromU16:). Rounding is idempotent on exact bf16 values, and 0.0/1.0 are unchanged."
	<gtExample>
	| roundedPi exactBf16 |
	roundedPi := GcWeightPrecision bf16Round: Float pi.
	exactBf16 := GcDtypeDecoder bf16FromU16: 16r4049.
	self assert: roundedPi equals: 3.140625.
	self assert: roundedPi equals: exactBf16.
	self assert: (GcWeightPrecision bf16Round: exactBf16) equals: exactBf16.
	self assert: (GcWeightPrecision bf16Round: 1.0) equals: 1.0.
	self assert: (GcWeightPrecision bf16Round: 0.0) equals: 0.0.
	^ roundedPi
]

{ #category : 'examples - hermetic' }
GcPrecisionExamples >> f32IdentityExample [
	"#f32 apply is the exact identity -- it returns the SAME array, so the full-precision path reproduces the baseline logits bit-for-bit."
	<gtExample>
	| src out |
	src := Float64Array withAll: #(0.123 -4.5 7.89 0.0).
	out := GcWeightPrecision f32 apply: src dimensions: #(1 4).
	self assert: out == src.
	^ out
]

{ #category : 'examples - hermetic' }
GcPrecisionExamples >> int4QuantizationExample [
	"Symmetric round-to-nearest int4 of a hand-computed row. rowMaxAbs 1.0 -> scale 1/7; q = round(w*7) = (0, 4, -7, 6); dequant = q*scale = (0, 4/7, -1, 6/7). Proves the int4 quantization math independent of the model."
	<gtExample>
	| src dequant expected |
	src := Float64Array withAll: #(0.0 0.5 -1.0 0.9).
	dequant := GcWeightPrecision int4 apply: src dimensions: #(1 4).
	expected := { 0.0. 4 / 7. -1.0. 6 / 7 }.
	self assert: dequant size equals: 4.
	1 to: 4 do: [ :i |
		self assert: ((dequant at: i) - (expected at: i)) abs < 1e-9 ].
	^ dequant
]

{ #category : 'examples - hermetic' }
GcPrecisionExamples >> int8QuantizationExample [
	"Symmetric round-to-nearest int8 of the same row. scale = 1/127; q = round(w*127) = (0, 64, -127, 114); dequant = (0, 64/127, -1, 114/127)."
	<gtExample>
	| src dequant expected |
	src := Float64Array withAll: #(0.0 0.5 -1.0 0.9).
	dequant := GcWeightPrecision int8 apply: src dimensions: #(1 4).
	expected := { 0.0. 64 / 127. -1.0. 114 / 127 }.
	1 to: 4 do: [ :i |
		self assert: ((dequant at: i) - (expected at: i)) abs < 1e-9 ].
	^ dequant
]

{ #category : 'examples - hermetic' }
GcPrecisionExamples >> perRowQuantizationExample [
	"Two rows of very different magnitude prove PER-ROW scaling: row0 (1.0, -0.5) maxAbs 1.0 -> (1.0, -4/7); row1 (0.1, -0.2) maxAbs 0.2 -> scale 0.2/7 -> (0.8/7, -0.2). Whole-tensor int4 (single scale 1/7) would instead give row1 (1/7, -1/7) -- asserted NOT to happen."
	<gtExample>
	| src dequant expected |
	src := Float64Array withAll: #(1.0 -0.5 0.1 -0.2).
	dequant := GcWeightPrecision int4 apply: src dimensions: #(2 2).
	expected := { 1.0. -4 / 7. 0.8 / 7. -0.2 }.
	1 to: 4 do: [ :i |
		self assert: ((dequant at: i) - (expected at: i)) abs < 1e-9 ].
	self assert: ((dequant at: 3) - (1 / 7)) abs > 1e-3.
	^ dequant
]

{ #category : 'examples - end to end' }
GcPrecisionExamples >> precisionDifferentialExample [
	"THE headline result. Run the SAME GPT-2-124M forward at f32/bf16/int8/int4 on 'The capital of France is Paris. The capital of France is' and compare. Asserts the f32 greedy = 6342 (' Paris') as a baseline sanity check; the per-precision greedy tokens and logit divergence vs f32 are then reported by the comparison's views (the actual precision differential -- whether int4 still says ' Paris' or flips). Runs on a FRESH openDefault model so the shared default stays clean f32; weights are unloaded at the end. <noTest>: each precision is a cold ~500MB weight decode + re-quantize + forward (~1 minute each)."
	<gtExample>
	<noTest>
	| ids comparison baseline |
	ids := GcGpt2InferenceExamples new franceInContextPromptIds.
	comparison := GcPrecisionComparison promptIds: ids.
	comparison runWith: GcGpt2Model openDefault precisions: #(f32 bf16 int8 int4).
	baseline := comparison baselineResult.
	self assert: comparison results size equals: 4.
	self assert: baseline greedyId equals: 6342.
	self assert: baseline decoded equals: ' Paris'.
	self assert: baseline maxAbsLogitDivergence equals: 0.0.
	self assert: baseline flips not.
	^ comparison
]
