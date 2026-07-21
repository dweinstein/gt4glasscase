"
Hermetic <gtExample> methods (NO network, NO GPT-2 file) proving the GcTensorMath kernel and the local-file safetensors loader on tiny synthetic data with hand-computed expected values. These are deterministic and belong in the automated test gate (plain <gtExample>, no <noTest>).
"
Class {
	#name : 'GcGpt2MathExamples',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'asserting' }
GcGpt2MathExamples >> assert: actual closeTo: expected within: tol [
	(actual - expected) abs <= tol
		ifFalse: [ self error: 'expected ', expected printString, ' but got ', actual printString ]
]

{ #category : 'asserting' }
GcGpt2MathExamples >> assertTrue: aBoolean [
	aBoolean ifFalse: [ self error: 'assertion failed' ]
]

{ #category : 'asserting' }
GcGpt2MathExamples >> assertVector: actual matches: expected within: tol [
	actual size = expected size ifFalse: [ ^ self error: 'size mismatch: ', actual size printString, ' vs ', expected size printString ].
	1 to: expected size do: [ :i |
		((actual at: i) - (expected at: i)) abs <= tol
			ifFalse: [ ^ self error: 'element ', i printString, ' expected ', (expected at: i) printString, ' got ', (actual at: i) printString ] ]
]

{ #category : 'examples - optimized kernels' }
GcGpt2MathExamples >> biasGeluFusedMatchesUnfusedExample [
	<gtExample>
	"The fused bias-add + gelu_new kernel equals the unfused composition geluNew: (biasAdd: x bias: bias) elementwise, within 1e-9 (in fact bit-identical), on a known input spanning negative, zero and positive values. Correctness gate for the operator-fusion optimization."
	| x bias fused unfused |
	x := Float64Array withAll: #(0.5 -1.0 2.0 3.0 -0.25 0.0).
	bias := Float64Array withAll: #(0.1 0.2 -0.3 0.05 1.0 -0.5).
	fused := GcTensorMath biasGeluFused: x bias: bias.
	unfused := GcTensorMath geluNew: (GcTensorMath biasAdd: x bias: bias).
	self assertVector: fused matches: unfused within: 1.0e-9.
	^ fused
]

{ #category : 'examples - optimized kernels' }
GcGpt2MathExamples >> blockedMatmulBenchmarkExample [
	<gtExample>
	"A GcKernelBenchmark comparing the naive vs blocked matmul on a deterministically-seeded 48x48x48 pair. Running it captures both timings (>= 0 ms) and -- the assertion that matters -- proves the results are IDENTICAL (maxDiff 0). The speedup is reported HONESTLY: in this interpreted VM cache tiling is typically a wash (or slightly slower), which is exactly the lesson the object teaches. Inspect the returned object: gtComparison + gtSummary."
	| m k n aRand bRand bench |
	m := 48. k := 48. n := 48.
	aRand := Float64Array new: m * k.
	1 to: m * k do: [ :i | aRand at: i put: (((i * 2654435761) \\ 10007) / 10007.0) - 0.5 ].
	bRand := Float64Array new: k * n.
	1 to: k * n do: [ :i | bRand at: i put: (((i * 40503) \\ 9973) / 9973.0) - 0.5 ].
	bench := (GcKernelBenchmark
		operation: 'matmul 48x48x48 (naive vs blocked)'
		naive: [ GcTensorMath matmulA: aRand rows: m inner: k b: bRand cols: n ]
		label: 'naive i-k-j (matmulA:)'
		optimized: [ GcTensorMath matmulBlockedA: aRand rows: m inner: k b: bRand cols: n blockSize: 16 ]
		label: 'blocked / tiled (bs=16)') run.
	self assertTrue: bench naiveMs notNil.
	self assertTrue: bench optimizedMs notNil.
	self assertTrue: bench isIdentical.
	self assertTrue: bench maxDiff = 0.0.
	^ bench
]

{ #category : 'examples - optimized kernels' }
GcGpt2MathExamples >> float32StorageRoundTripExample [
	<gtExample>
	"Storing a known Float64Array as a Float32Array (the #f32 weight-STORAGE optimization) then reading it back stays within Float32 relative epsilon (~1.2e-7) of the original -- the small, bounded precision cost of halving the weight footprint. Float32Array>>at: widens to a full double on read, so downstream math still runs in doubles."
	| f64 f32 eps |
	f64 := Float64Array withAll: #(1.5 2.25 3.1415926535 -7.0 0.1 123456.75).
	f32 := Float32Array withAll: f64.
	eps := 1.2e-7.
	self assertTrue: f32 size = f64 size.
	1 to: f64 size do: [ :i | | mag rel |
		mag := (f64 at: i) abs max: 1.0.
		rel := ((f32 at: i) - (f64 at: i)) abs / mag.
		self assertTrue: rel <= eps ].
	^ f32
]

{ #category : 'examples' }
GcGpt2MathExamples >> geluNewExample [
	<gtExample>
	"HF gelu_new: exact 0 at 0, known values at 1, 3, -1; elementwise agrees with the scalar."
	| g0 g1 g3 gNeg expNeg vec |
	g0 := GcTensorMath geluNewScalar: 0.0.
	g1 := GcTensorMath geluNewScalar: 1.0.
	g3 := GcTensorMath geluNewScalar: 3.0.
	gNeg := GcTensorMath geluNewScalar: -1.0.
	expNeg := -0.15880800939172324.
	self assertTrue: g0 = 0.0.
	self assert: g1 closeTo: 0.8411919906082768 within: 1.0e-9.
	self assert: g3 closeTo: 2.996362607918227 within: 1.0e-9.
	self assert: gNeg closeTo: expNeg within: 1.0e-9.
	vec := GcTensorMath geluNew: (Float64Array withAll: #(0.0 1.0 3.0 -1.0)).
	self assert: (vec at: 2) closeTo: g1 within: 1.0e-12.
	^ vec
]

{ #category : 'examples' }
GcGpt2MathExamples >> layerNormExample [
	<gtExample>
	"LayerNorm of #(1 2 3 4) with gamma=1, beta=0. Reference mean (2.5) and population variance (1.25) are hand-computed independently of the op; output mean is ~0."
	| x result mean var eps denom expected sum |
	x := #(1.0 2.0 3.0 4.0).
	result := GcTensorMath layerNorm: x gamma: #(1.0 1.0 1.0 1.0) beta: #(0.0 0.0 0.0 0.0).
	mean := 2.5.
	var := 1.25.
	eps := 1.0e-5.
	denom := (var + eps) sqrt.
	expected := x collect: [ :v | (v - mean) / denom ].
	self assertVector: result matches: expected within: 1.0e-9.
	sum := 0.0.
	result do: [ :v | sum := sum + v ].
	self assert: sum closeTo: 0.0 within: 1.0e-9.
	^ result
]

{ #category : 'examples' }
GcGpt2MathExamples >> linearHelpersExample [
	<gtExample>
	"Tied unembedding transpose, embedding row lookup, argmax, and elementwise add/mul on known inputs."
	| logits emb |
	logits := GcTensorMath unembedHidden: #(1.0 2.0) dim: 2 table: #(1.0 0.0 0.0 1.0 1.0 1.0) vocab: 3.
	self assertVector: logits matches: #(1.0 2.0 3.0) within: 1.0e-12.
	emb := GcTensorMath embeddingRowFrom: #(10.0 11.0 20.0 21.0 30.0 31.0) dim: 2 index: 2.
	self assertVector: emb matches: #(30.0 31.0) within: 1.0e-12.
	self assertTrue: (GcTensorMath argmax: #(0.1 0.5 0.2 0.9 0.3)) = 3.
	self assertVector: (GcTensorMath add: #(1.0 2.0 3.0) and: #(4.0 5.0 6.0)) matches: #(5.0 7.0 9.0) within: 1.0e-12.
	self assertVector: (GcTensorMath mul: #(1.0 2.0 3.0) and: #(4.0 5.0 6.0)) matches: #(4.0 10.0 18.0) within: 1.0e-12.
	self assertVector: (GcTensorMath biasAdd: #(1.0 2.0 3.0) bias: #(10.0 20.0 30.0)) matches: #(11.0 22.0 33.0) within: 1.0e-12.
	^ logits
]

{ #category : 'examples' }
GcGpt2MathExamples >> loaderRoundTripExample [
	<gtExample>
	"Build a tiny synthetic safetensors buffer in-image (8-byte LE header length + JSON header + 24 bytes of six known F32 values), then decode it two ways: via GcInMemoryBytesProvider and via GcLocalFileBytesProvider (temp file, seek-read). Both must decode the identical six floats with shape #(2 3). Returns the in-memory GcSafetensorsFile."
	| floats dataBytes headerString headerBytes headerLen lenPrefix fullBuffer memProvider memFile memTensor memFloats tempFile localProvider localFile hdrLenBytes hdrLen hdrBytes hdrString localTensor localFloats |
	floats := #(1.5 -2.25 0.5 3.75 -0.125 100.0).
	dataBytes := ByteArray new: 24.
	floats withIndexDo: [ :f :idx | | bits base |
		bits := f asIEEE32BitWord.
		base := (idx - 1) * 4.
		dataBytes at: base + 1 put: (bits bitAnd: 16rFF).
		dataBytes at: base + 2 put: ((bits bitShift: -8) bitAnd: 16rFF).
		dataBytes at: base + 3 put: ((bits bitShift: -16) bitAnd: 16rFF).
		dataBytes at: base + 4 put: ((bits bitShift: -24) bitAnd: 16rFF) ].
	headerString := '{"t":{"dtype":"F32","shape":[2,3],"data_offsets":[0,24]}}'.
	headerBytes := headerString utf8Encoded.
	headerLen := headerBytes size.
	lenPrefix := ByteArray new: 8.
	0 to: 7 do: [ :i | lenPrefix at: i + 1 put: ((headerLen bitShift: -8 * i) bitAnd: 16rFF) ].
	fullBuffer := lenPrefix , headerBytes , dataBytes.
	memProvider := GcInMemoryBytesProvider bytes: fullBuffer dataOffset: 8 + headerLen.
	memFile := GcSafetensorsFile new bytesProvider: memProvider; yourself.
	memFile parseHeaderString: headerString.
	memTensor := memFile tensors detect: [ :t | t name = 't' ].
	memFloats := memTensor asFloatArray.
	self assertTrue: memTensor dimensions asArray = #(2 3).
	self assertVector: memFloats matches: floats within: 1.0e-6.
	tempFile := FileLocator temp / ('gc-gpt2-loader-', UUID new asString36, '.safetensors').
	[ tempFile binaryWriteStreamDo: [ :s | s nextPutAll: fullBuffer ].
		localProvider := GcLocalFileBytesProvider forPath: tempFile.
		localFile := GcSafetensorsFile new bytesProvider: localProvider; yourself.
		hdrLenBytes := localProvider provideBytesFrom: 0 to: 7.
		hdrLen := 0.
		0 to: 7 do: [ :i | hdrLen := hdrLen + ((hdrLenBytes at: i + 1) bitShift: 8 * i) ].
		hdrBytes := localProvider provideBytesFrom: 8 to: 8 + hdrLen - 1.
		hdrString := hdrBytes utf8Decoded.
		localFile parseHeaderString: hdrString.
		localTensor := localFile tensors detect: [ :t | t name = 't' ].
		localFloats := localTensor asFloatArray ] ensure: [ tempFile ensureDelete ].
	self assertTrue: hdrLen = headerLen.
	self assertTrue: hdrString = headerString.
	self assertTrue: localFile byteDataOffset = (8 + headerLen).
	self assertVector: localFloats matches: floats within: 1.0e-6.
	self assertVector: localFloats matches: memFloats within: 1.0e-12.
	^ memFile
]

{ #category : 'examples - optimized kernels' }
GcGpt2MathExamples >> matmulBlockedMatchesNaiveExample [
	<gtExample>
	"The blocked/tiled matmul returns results IDENTICAL to the naive i-k-j matmul -- on a known small pair (product exactly #(58 64 139 154)) and on a larger deterministically-seeded pseudo-random pair (Math.random is unavailable, so each element is a fixed function of its index). The tiling preserves the per-output summation order, so it is bit-identical here (maxDiff 0), asserted within 1e-9. Dimensions 17x23x19 with blockSize 8 deliberately exercise RAGGED block boundaries. This is the correctness gate for the blocked-matmul optimization."
	| a b known blocked m k n aRand bRand naive blk maxDiff |
	a := Float64Array withAll: #(1.0 2.0 3.0 4.0 5.0 6.0).
	b := Float64Array withAll: #(7.0 8.0 9.0 10.0 11.0 12.0).
	known := GcTensorMath matmulA: a rows: 2 inner: 3 b: b cols: 2.
	blocked := GcTensorMath matmulBlockedA: a rows: 2 inner: 3 b: b cols: 2 blockSize: 2.
	self assertVector: known matches: #(58.0 64.0 139.0 154.0) within: 1.0e-12.
	self assertVector: blocked matches: known within: 1.0e-12.
	m := 17. k := 23. n := 19.
	aRand := Float64Array new: m * k.
	1 to: m * k do: [ :i | aRand at: i put: (((i * 2654435761) \\ 10007) / 10007.0) - 0.5 ].
	bRand := Float64Array new: k * n.
	1 to: k * n do: [ :i | bRand at: i put: (((i * 40503) \\ 9973) / 9973.0) - 0.5 ].
	naive := GcTensorMath matmulA: aRand rows: m inner: k b: bRand cols: n.
	blk := GcTensorMath matmulBlockedA: aRand rows: m inner: k b: bRand cols: n blockSize: 8.
	maxDiff := 0.0.
	1 to: naive size do: [ :i | | d | d := ((naive at: i) - (blk at: i)) abs. d > maxDiff ifTrue: [ maxDiff := d ] ].
	self assertTrue: maxDiff <= 1.0e-9.
	^ blk
]

{ #category : 'examples' }
GcGpt2MathExamples >> matmulExample [
	<gtExample>
	"C[2,2] = A[2,3] . B[3,2] with known integer-valued inputs -> #(58 64 139 154)."
	| result |
	result := GcTensorMath matmulA: #(1.0 2.0 3.0 4.0 5.0 6.0) rows: 2 inner: 3 b: #(7.0 8.0 9.0 10.0 11.0 12.0) cols: 2.
	self assertVector: result matches: #(58.0 64.0 139.0 154.0) within: 1.0e-12.
	^ result
]

{ #category : 'examples' }
GcGpt2MathExamples >> mmulNoTransposeExample [
	<gtExample>
	"GUARDS the GPT-2 Conv1D no-transpose convention. W stored [in=2, out=3] row-major, x=#(2 3). With bias -> #(24 39 54); without bias -> #(14 19 24). A transposed kernel would give different numbers."
	| withBias noBias |
	withBias := GcTensorMath mmulNoTransposeInput: #(2.0 3.0) inSize: 2 weight: #(1.0 2.0 3.0 4.0 5.0 6.0) outSize: 3 bias: #(10.0 20.0 30.0).
	self assertVector: withBias matches: #(24.0 39.0 54.0) within: 1.0e-12.
	noBias := GcTensorMath mmulNoTransposeInput: #(2.0 3.0) inSize: 2 weight: #(1.0 2.0 3.0 4.0 5.0 6.0) outSize: 3 bias: nil.
	self assertVector: noBias matches: #(14.0 19.0 24.0) within: 1.0e-12.
	^ withBias
]

{ #category : 'examples' }
GcGpt2MathExamples >> softmaxExample [
	<gtExample>
	"Numerically stable softmax of #(1 2 3): known distribution, sums to 1."
	| result expected sum |
	result := GcTensorMath softmax: #(1.0 2.0 3.0).
	expected := #(0.09003057317038046 0.24472847105479764 0.6652409557748218).
	self assertVector: result matches: expected within: 1.0e-9.
	sum := 0.0.
	result do: [ :v | sum := sum + v ].
	self assert: sum closeTo: 1.0 within: 1.0e-9.
	^ result
]
