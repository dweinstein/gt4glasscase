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
