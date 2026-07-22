"
Hermetic <gtExample> methods proving GcBlasBackend (Accelerate cblas_sgemm) numerically matches the GcTensorMath naive oracle on known-answer and random-differential cases, plus a <noTest> benchmark quantifying the real speedup and the float64->float32 conversion overhead at a GPT-2-prefill-shaped matmul. exampleSanity2x2 is deliberately the first real FFI call this backend ever makes in this image -- a tiny known-answer case that must be exact before anything larger is trusted.
"
Class {
	#name : 'GcBlasBackendExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase-Performance',
	#package : 'Gt4GlassCase',
	#tag : 'Performance'
}

{ #category : 'asserting' }
GcBlasBackendExamples >> assertTrue: aBoolean [
	aBoolean ifFalse: [ self error: 'assertion failed' ]
]

{ #category : 'asserting' }
GcBlasBackendExamples >> assertVector: actual matches: expected within: tol [
	actual size = expected size ifFalse: [ ^ self error: 'size mismatch: ', actual size printString, ' vs ', expected size printString ].
	1 to: expected size do: [ :i |
		((actual at: i) - (expected at: i)) abs <= tol
			ifFalse: [ ^ self error: 'element ', i printString, ' expected ', (expected at: i) printString, ' got ', (actual at: i) printString ] ]
]

{ #category : 'examples' }
GcBlasBackendExamples >> exampleBenchmark [
	<gtExample>
	<noTest>
	"GPT-2-prefill-shaped matmul (m=64, k=768, n=2304, e.g. a fused QKV projection) -- naive GcTensorMath i-k-j loop vs Accelerate cblas_sgemm via GcBlasBackend, reported through the existing GcKernelBenchmark head-to-head (single-call timings + the results-identical correctness gate, tol 1e-3 since BLAS computes in float32). Because a single BLAS call can be faster than millisecond timer resolution, THREE extra iterated measurements are taken separately (not part of the single-call gate) and folded into the labels so the object stays honest and self-explaining: (1) cost of converting one Float64Array to a float32 C buffer alone: convMs; (2) raw cblas_sgemm-only throughput over rawIterations calls on PRE-converted buffers (no conversion in the loop): rawGflops; (3) the full drop-in matmulA:rows:inner:b:cols: (conversion + sgemm + conversion-back) throughput over pathIterations calls: pathGflops -- the honest, uncached, repeated-call cost. Inspect the result: gtComparison and gtSummary; read operationLabel/optimizedLabel for the measured numbers."
	| m k n aData bData backend bench flops convMs aBuf bBuf cBuf rawIterations rawMs rawGflops pathIterations pathMs pathGflops opLabel optLabel |
	m := 64. k := 768. n := 2304.
	flops := 2 * m * k * n.
	aData := self randomFloat64: m * k seedMul: 2654435761 seedMod: 10007.
	bData := self randomFloat64: k * n seedMul: 40503 seedMod: 9973.
	backend := GcBlasBackend new.
	backend matmulA: aData rows: m inner: k b: bData cols: n.

	convMs := Time millisecondsToRun: [ backend doubleArrayToFloatBuffer: bData ].

	aBuf := backend doubleArrayToFloatBuffer: aData.
	bBuf := backend doubleArrayToFloatBuffer: bData.
	cBuf := FFIExternalArray externalNewType: 'float' size: m * n.
	rawIterations := 500.
	rawMs := Time millisecondsToRun: [
		1 to: rawIterations do: [ :i |
			backend sgemmOrder: 101 ta: 111 tb: 111 m: m n: n k: k alpha: 1.0 a: aBuf getHandle lda: k b: bBuf getHandle ldb: n beta: 0.0 c: cBuf getHandle ldc: n ] ].
	aBuf free. bBuf free. cBuf free.
	rawGflops := (flops * rawIterations) / (rawMs max: 1) / 1.0e6.

	pathIterations := 20.
	pathMs := Time millisecondsToRun: [
		1 to: pathIterations do: [ :i | backend matmulA: aData rows: m inner: k b: bData cols: n ] ].
	pathGflops := (flops * pathIterations) / (pathMs max: 1) / 1.0e6.

	opLabel := 'matmul ', m printString, 'x', k printString, 'x', n printString,
		' (', ((flops / 1.0e9) printShowingDecimalPlaces: 3), ' GFLOP) -- naive vs Accelerate BLAS sgemm'.
	optLabel := 'Accelerate cblas_sgemm | raw sgemm-only: ', (rawGflops printShowingDecimalPlaces: 1), ' GFLOP/s (', rawIterations printString, ' iters, ', rawMs printString, ' ms total) | full uncached matmulA path: ', (pathGflops printShowingDecimalPlaces: 1), ' GFLOP/s (', pathIterations printString, ' iters) | B float64->32 conversion alone: ', convMs printString, ' ms'.

	bench := (GcKernelBenchmark
		operation: opLabel
		naive: [ GcTensorMath matmulA: aData rows: m inner: k b: bData cols: n ]
		label: 'naive i-k-j (GcTensorMath matmulA:)'
		optimized: [ backend matmulA: aData rows: m inner: k b: bData cols: n ]
		label: 'Accelerate cblas_sgemm (single call)') run.
	self assertTrue: bench naiveMs notNil.
	self assertTrue: bench optimizedMs notNil.
	self assertTrue: (bench isIdenticalWithin: 1.0e-3).
	bench setOperation: opLabel naive: [ GcTensorMath matmulA: aData rows: m inner: k b: bData cols: n ] label: 'naive i-k-j (GcTensorMath matmulA:)' optimized: [ backend matmulA: aData rows: m inner: k b: bData cols: n ] label: optLabel.
	^ bench
]

{ #category : 'examples' }
GcBlasBackendExamples >> exampleDifferentialConv1D [
	<gtExample>
	"Differential test: GcBlasBackend mmulNoTransposeInput:inSize:weight:outSize:bias: (the weight-cached GPT-2 Conv1D path, m=1) vs the naive GcTensorMath mmulNoTransposeInput:inSize:weight:outSize:bias: oracle, both with and without bias. Returns a summary: case label -> max abs diff."
	| backend inSize outSize x w bias withBiasNaive withBiasBlas noBiasNaive noBiasBlas dWith dNoBias |
	backend := GcBlasBackend new.
	inSize := 768. outSize := 64.
	x := self randomFloat64: inSize seedMul: 2654435761 seedMod: 10007.
	w := self randomFloat64: inSize * outSize seedMul: 40503 seedMod: 9973.
	bias := self randomFloat64: outSize seedMul: 16777619 seedMod: 7919.
	withBiasNaive := GcTensorMath mmulNoTransposeInput: x inSize: inSize weight: w outSize: outSize bias: bias.
	withBiasBlas := backend mmulNoTransposeInput: x inSize: inSize weight: w outSize: outSize bias: bias.
	dWith := self maxAbsDiff: withBiasNaive vs: withBiasBlas.
	self assertTrue: dWith < 1.0e-3.
	noBiasNaive := GcTensorMath mmulNoTransposeInput: x inSize: inSize weight: w outSize: outSize bias: nil.
	noBiasBlas := backend mmulNoTransposeInput: x inSize: inSize weight: w outSize: outSize bias: nil.
	dNoBias := self maxAbsDiff: noBiasNaive vs: noBiasBlas.
	self assertTrue: dNoBias < 1.0e-3.
	^ OrderedCollection new
		add: 'with bias' -> dWith;
		add: 'no bias' -> dNoBias;
		yourself
]

{ #category : 'examples' }
GcBlasBackendExamples >> exampleDifferentialMatmul [
	<gtExample>
	"Differential test: GcBlasBackend matmulA:rows:inner:b:cols: (Accelerate cblas_sgemm, float32 compute) vs the naive GcTensorMath matmulA:rows:inner:b:cols: oracle (float64), across a few GPT-2-shaped sizes (small, single-row GPT-2-attention-head-sized, and a 4-row case). float32 vs float64 compute introduces small, bounded numeric drift -- asserted well under 1e-3 absolute, elementwise, for every size. Returns a summary: size string -> max abs diff."
	| backend sizes results |
	backend := GcBlasBackend new.
	sizes := { { 8. 16. 12 }. { 1. 768. 64 }. { 4. 64. 128 } }.
	results := OrderedCollection new.
	sizes do: [ :dims | | m k n a b naiveResult blasResult d |
		m := dims at: 1. k := dims at: 2. n := dims at: 3.
		a := self randomFloat64: m * k seedMul: 2654435761 seedMod: 10007.
		b := self randomFloat64: k * n seedMul: 40503 seedMod: 9973.
		naiveResult := GcTensorMath matmulA: a rows: m inner: k b: b cols: n.
		blasResult := backend matmulA: a rows: m inner: k b: b cols: n.
		d := self maxAbsDiff: naiveResult vs: blasResult.
		self assertTrue: d < 1.0e-3.
		results add: (m printString, 'x', k printString, 'x', n printString) -> d ].
	^ results
]

{ #category : 'examples' }
GcBlasBackendExamples >> exampleSanity2x2 [
	<gtExample>
	"THE first FFI call this backend ever makes -- a tiny known-answer 2x2 case that must be EXACT before anything larger is trusted. A=[[1,2,3],[4,5,6]] (2x3), B=[[7,8],[9,10],[11,12]] (3x2) -> C=[[58,64],[139,154]] (2x2), the same known-answer case as GcTensorMath's own matmulExample."
	| backend result |
	backend := GcBlasBackend new.
	result := backend matmulA: #(1.0 2.0 3.0 4.0 5.0 6.0) rows: 2 inner: 3 b: #(7.0 8.0 9.0 10.0 11.0 12.0) cols: 2.
	self assertVector: result matches: #(58.0 64.0 139.0 154.0) within: 1.0e-6.
	^ result
]

{ #category : 'asserting' }
GcBlasBackendExamples >> maxAbsDiff: aArray vs: bArray [
	"Maximum absolute elementwise difference between two same-sized numeric arrays."
	| m |
	aArray size = bArray size ifFalse: [ ^ self error: 'size mismatch: ', aArray size printString, ' vs ', bArray size printString ].
	m := 0.0.
	1 to: aArray size do: [ :i | | d | d := ((aArray at: i) - (bArray at: i)) abs. d > m ifTrue: [ m := d ] ].
	^ m
]

{ #category : 'private - random' }
GcBlasBackendExamples >> randomFloat64: n seedMul: mul seedMod: mod [
	"Deterministic pseudo-random Float64Array in [-0.5, 0.5), same seeded-hash style as GcGpt2MathExamples>>blockedMatmulBenchmarkExample -- reproducible without a real Random."
	| arr |
	arr := Float64Array new: n.
	1 to: n do: [ :i | arr at: i put: (((i * mul) \\ mod) / mod asFloat) - 0.5 ].
	^ arr
]
