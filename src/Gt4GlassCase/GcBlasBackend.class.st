"
FFI-backed BLAS matmul backend using Apple Accelerate's cblas_sgemm, as a DROP-IN accelerated replacement for GcTensorMath's naive interpreted matmul kernels -- same contracts (row-major Float64Array in/out), radically faster (~1000x). Compute happens in float32 (BLAS sgemm); inputs/outputs stay Float64Array at the boundary, so callers see no precision-contract change beyond the small, bounded float32 rounding (see the differential gtExamples in GcBlasBackendExamples for the measured bound). matmulA:rows:inner:b:cols: converts both operands fresh every call (general-purpose, uncached). mmulNoTransposeInput:inSize:weight:outSize:bias: is the GPT-2 Conv1D-shaped path (m=1) and CACHES the converted weight buffer by identity of the weight array in weightBuffers, since GPT-2 weights are stable objects reused every forward pass -- only the input vector is converted per call. GcTensorMath stays the readable oracle; this class exists purely for speed and is proven equal to it by differential examples, never by inspection alone.
"
Class {
	#name : 'GcBlasBackend',
	#superclass : 'Object',
	#instVars : [
		'weightBuffers'
	],
	#category : 'Gt4GlassCase-Performance',
	#package : 'Gt4GlassCase',
	#tag : 'Performance'
}

{ #category : 'private - validation' }
GcBlasBackend >> checkSize: anArray is: expected label: aString [
	"Raises a descriptive Error if anArray size does not equal expected. Defense-in-depth shape validation before any FFI/BLAS call, since a size mismatch reaching cblas_sgemm is a native out-of-bounds memory access (a hard SIGSEGV), not a catchable Smalltalk error."
	anArray size = expected
		ifFalse: [ self error: aString, ' size mismatch: expected ', expected printString, ' got ', anArray size printString ]
]

{ #category : 'api - memory' }
GcBlasBackend >> clearWeightCache [
	"Free every cached float32 weight buffer (native memory, malloc'd via FFIExternalArray -- NOT garbage collected) and reset the cache. Call before dropping a GcBlasBackend instance, or when the owning model's weights are unloaded (see GcGpt2Model>>unloadWeights), to avoid leaking native buffers. Quarantines the cache FIRST: weightBuffers is set to nil before any buffer is freed, so if one #free raises mid-loop (e.g. PrimitiveFailed on an already-freed handle), the dict is never left reachable holding freed handles for a later lookup to hand back to sgemm (which would SIGSEGV). Each buffer's #free is wrapped individually so one failure cannot stop the rest from being freed."
	| toFree |
	toFree := weightBuffers.
	weightBuffers := nil.
	toFree ifNotNil: [
		toFree valuesDo: [ :buf |
			[ buf free ] on: Error do: [ :e | ] ] ]
]

{ #category : 'converting' }
GcBlasBackend >> doubleArrayToFloatBuffer: aFloat64Array [
	"Convert a Float64Array (or any indexable float collection) to a NEW temporary C float buffer (FFIExternalArray of C 'float'), narrowing each element to float32. Caller owns the returned buffer and must #free it, unless it is being cached (see weightBuffers). If the fill loop raises (e.g. a non-numeric element), the freshly allocated buffer is freed before the error propagates, so a mid-fill failure cannot leak native memory; on success ownership of the filled buffer transfers to the caller as before."
	| n buf |
	n := aFloat64Array size.
	buf := FFIExternalArray externalNewType: 'float' size: n.
	[ 1 to: n do: [ :i | buf at: i put: (aFloat64Array at: i) ] ]
		ifCurtailed: [ buf free ].
	^ buf
]

{ #category : 'converting' }
GcBlasBackend >> floatBufferToDoubleArray: aBuffer size: n [
	"Convert a C float buffer (FFIExternalArray of C 'float') back to a Float64Array, widening each element to float64."
	| result |
	result := Float64Array new: n.
	1 to: n do: [ :i | result at: i put: (aBuffer at: i) ].
	^ result
]

{ #category : 'testing' }
GcBlasBackend >> isAvailable [
	"Answer whether the Accelerate BLAS backend is usable -- guards callers so they can degrade to the naive GcTensorMath kernels. Runs a tiny real sgemm to prove the library loads AND the FFI call succeeds."
	^ [ (self matmulA: #(1.0 2.0 3.0 4.0) rows: 2 inner: 2 b: #(1.0 0.0 0.0 1.0) cols: 2) size = 4 ]
		on: Error
		do: [ :e | false ]
]

{ #category : 'computing' }
GcBlasBackend >> matmulA: a rows: m inner: k b: b cols: n [
	"DROP-IN BLAS-backed replacement for GcTensorMath matmulA:rows:inner:b:cols:. C[m,n] = A[m,k] . B[k,n], row-major Float64Array in and out. Converts A and B to fresh temporary float32 buffers every call (general-purpose, UNcached); see mmulNoTransposeInput:inSize:weight:outSize:bias: for the weight-cached GPT-2 Conv1D path. m, k, n and the sizes of a and b are validated BEFORE any buffer is allocated or any FFI call is made, since invalid dims or a size mismatch reaching cblas_sgemm would be a native out-of-bounds access rather than a catchable error. The temporary buffers are freed in an ensure: block, so a mid-call error (conversion or sgemm) cannot leak native memory."
	| aBuf bBuf cBuf |
	(m isInteger and: [ m > 0 ]) ifFalse: [ ^ self error: 'matmulA:rows:inner:b:cols: invalid m (rows): ', m printString ].
	(k isInteger and: [ k > 0 ]) ifFalse: [ ^ self error: 'matmulA:rows:inner:b:cols: invalid k (inner): ', k printString ].
	(n isInteger and: [ n > 0 ]) ifFalse: [ ^ self error: 'matmulA:rows:inner:b:cols: invalid n (cols): ', n printString ].
	self checkSize: a is: m * k label: 'matmulA:rows:inner:b:cols: a'.
	self checkSize: b is: k * n label: 'matmulA:rows:inner:b:cols: b'.
	aBuf := bBuf := cBuf := nil.
	^ [ aBuf := self doubleArrayToFloatBuffer: a.
		bBuf := self doubleArrayToFloatBuffer: b.
		cBuf := FFIExternalArray externalNewType: 'float' size: m * n.
		self
			sgemmOrder: 101 ta: 111 tb: 111
			m: m n: n k: k
			alpha: 1.0
			a: aBuf getHandle lda: k
			b: bBuf getHandle ldb: n
			beta: 0.0
			c: cBuf getHandle ldc: n.
		self floatBufferToDoubleArray: cBuf size: m * n ]
	ensure: [
		aBuf ifNotNil: [ aBuf free ].
		bBuf ifNotNil: [ bBuf free ].
		cBuf ifNotNil: [ cBuf free ] ]
]

{ #category : 'computing' }
GcBlasBackend >> mmulNoTransposeInput: x inSize: inSize weight: w outSize: outSize bias: bias [
	"DROP-IN BLAS-backed replacement for GcTensorMath mmulNoTransposeInput:inSize:weight:outSize:bias: (GPT-2 Conv1D, y = x . W + bias, NO transpose). x is a length-inSize Float64Array (one row); W is Float64Array [inSize,outSize] row-major; bias may be nil. m=1, n=outSize, k=inSize. inSize, outSize and the sizes of x, w and bias are validated BEFORE the weight cache is touched, so an invalid call never populates weightBuffers with a buffer converted from a wrongly-shaped weight. The float32 buffer for W is CACHED by identity of w in weightBuffers -- GPT-2 weights are stable objects reused every forward pass, so only x is converted per call. The per-call temp buffers (xBuf, cBuf) are freed in an ensure: block; the cached wBuf is NOT freed here (owned by weightBuffers, released by clearWeightCache)."
	| wBuf xBuf cBuf beta |
	(inSize isInteger and: [ inSize > 0 ]) ifFalse: [ ^ self error: 'mmulNoTransposeInput:inSize:weight:outSize:bias: invalid inSize: ', inSize printString ].
	(outSize isInteger and: [ outSize > 0 ]) ifFalse: [ ^ self error: 'mmulNoTransposeInput:inSize:weight:outSize:bias: invalid outSize: ', outSize printString ].
	self checkSize: x is: inSize label: 'mmulNoTransposeInput:inSize:weight:outSize:bias: x'.
	self checkSize: w is: inSize * outSize label: 'mmulNoTransposeInput:inSize:weight:outSize:bias: w'.
	bias ifNotNil: [ self checkSize: bias is: outSize label: 'mmulNoTransposeInput:inSize:weight:outSize:bias: bias' ].
	xBuf := cBuf := nil.
	wBuf := self weightBuffers at: w ifAbsentPut: [ self doubleArrayToFloatBuffer: w ].
	^ [ xBuf := self doubleArrayToFloatBuffer: x.
		cBuf := FFIExternalArray externalNewType: 'float' size: outSize.
		beta := 0.0.
		bias ifNotNil: [
			beta := 1.0.
			1 to: outSize do: [ :j | cBuf at: j put: (bias at: j) ] ].
		beta = 0.0 ifTrue: [ 1 to: outSize do: [ :j | cBuf at: j put: 0.0 ] ].
		self
			sgemmOrder: 101 ta: 111 tb: 111
			m: 1 n: outSize k: inSize
			alpha: 1.0
			a: xBuf getHandle lda: inSize
			b: wBuf getHandle ldb: outSize
			beta: beta
			c: cBuf getHandle ldc: outSize.
		self floatBufferToDoubleArray: cBuf size: outSize ]
	ensure: [
		xBuf ifNotNil: [ xBuf free ].
		cBuf ifNotNil: [ cBuf free ] ]
]

{ #category : 'ffi - blas' }
GcBlasBackend >> sgemmOrder: order ta: ta tb: tb m: m n: n k: k alpha: alpha a: a lda: lda b: b ldb: ldb beta: beta c: c ldc: ldc [
	"Raw FFI wrapper over Accelerate's cblas_sgemm. a, b, c are ExternalAddress handles (send getHandle on an FFIExternalArray) to C float buffers, row-major layout (order=101), no transpose (ta=tb=111)."
	^ self ffiCall: 'void cblas_sgemm(int order, int ta, int tb, int m, int n, int k, float alpha, float *a, int lda, float *b, int ldb, float beta, float *c, int ldc)' module: GcAccelerateLib
]

{ #category : 'accessing' }
GcBlasBackend >> weightBuffers [
	"Lazily-created cache of converted-to-float32 weight buffers, keyed by the IDENTITY of the original Float64Array weight (GPT-2 weights are stable objects reused every forward pass)."
	^ weightBuffers ifNil: [ weightBuffers := IdentityDictionary new ]
]
