"
Stateless GPT-2 tensor-op kernel: class-side numeric primitives operating on row-major Float64Array vectors/matrices with EXPLICIT shapes (this image has no FloatArray global; Float64Array is the full-precision typed float array). Ops: matmul (i-k-j, reusable row buffer, no inner-loop allocation), mmulNoTranspose (HF Conv1D linear -- W stored [in,out], NO transpose), tied-unembedding transpose, biasAdd, elementwise add/mul, geluNew (HF gelu_new tanh approximation; tanh synthesized from exp), softmax (max-subtracted), layerNorm (population variance, eps 1e-5, affine), embedding row lookup, argmax. Boring and reusable on purpose.
"
Class {
	#name : 'GcTensorMath',
	#superclass : 'Object',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'elementwise' }
GcTensorMath class >> add: a and: b [
	"Elementwise sum of two equal-length vectors."
	| y |
	y := Float64Array new: a size.
	1 to: a size do: [ :i | y at: i put: (a at: i) + (b at: i) ].
	^ y
]

{ #category : 'lookup' }
GcTensorMath class >> argmax: x [
	"0-based index of the maximum element (ready as a token id). Ties resolve to the first maximum."
	| bestIdx bestVal |
	bestIdx := 0.
	bestVal := x at: 1.
	2 to: x size do: [ :i | (x at: i) > bestVal ifTrue: [ bestVal := x at: i. bestIdx := i - 1 ] ].
	^ bestIdx
]

{ #category : 'elementwise' }
GcTensorMath class >> biasAdd: x bias: bias [
	"Elementwise x + bias (same length)."
	| y |
	y := Float64Array new: x size.
	1 to: x size do: [ :i | y at: i put: (x at: i) + (bias at: i) ].
	^ y
]

{ #category : 'kernels - optimized' }
GcTensorMath class >> biasGeluFused: x bias: bias [
	"FUSED bias-add + HF gelu_new in a SINGLE pass over x, with NO intermediate array: result[i] = geluNewScalar(x[i] + bias[i]). Numerically IDENTICAL to the unfused composition geluNew: (biasAdd: x bias: bias) -- same scalar applied to the same sum -- but avoids materializing and re-scanning the bias-added intermediate (the operator-fusion win the GPT-2 MLP Conv1D->bias->gelu path benefits from)."
	| y |
	y := Float64Array new: x size.
	1 to: x size do: [ :i | y at: i put: (self geluNewScalar: (x at: i) + (bias at: i)) ].
	^ y
]

{ #category : 'lookup' }
GcTensorMath class >> embeddingRowFrom: table dim: d index: rowIndex [
	"Row rowIndex (0-based) of a [vocab, d] row-major embedding table as a d-length Float64Array."
	| y base |
	y := Float64Array new: d.
	base := rowIndex * d.
	1 to: d do: [ :i | y at: i put: (table at: base + i) ].
	^ y
]

{ #category : 'activations' }
GcTensorMath class >> geluNew: aVector [
	"Elementwise HF gelu_new over a Float64Array."
	| y |
	y := Float64Array new: aVector size.
	1 to: aVector size do: [ :i | y at: i put: (self geluNewScalar: (aVector at: i)) ].
	^ y
]

{ #category : 'activations' }
GcTensorMath class >> geluNewScalar: x [
	"HF gelu_new tanh approximation for a scalar: 0.5*x*(1 + tanh( sqrt(2/pi) * (x + 0.044715*x^3) )). Fully parenthesized for Smalltalk precedence."
	| c inner |
	c := 0.7978845608028654.
	inner := c * (x + (0.044715 * x * x * x)).
	^ 0.5 * x * (1.0 + (self tanhOf: inner))
]

{ #category : 'normalization' }
GcTensorMath class >> layerNorm: x gamma: gamma beta: beta [
	"LayerNorm with the GPT-2 default eps of 1e-5."
	^ self layerNorm: x gamma: gamma beta: beta eps: 1.0e-5
]

{ #category : 'normalization' }
GcTensorMath class >> layerNorm: x gamma: gamma beta: beta eps: eps [
	"Per-vector LayerNorm: mean, POPULATION variance, normalize with eps, then affine y = gamma * normalized + beta."
	| n mean var inv y d |
	n := x size.
	mean := 0.0.
	1 to: n do: [ :i | mean := mean + (x at: i) ].
	mean := mean / n.
	var := 0.0.
	1 to: n do: [ :i | d := (x at: i) - mean. var := var + (d * d) ].
	var := var / n.
	inv := 1.0 / (var + eps) sqrt.
	y := Float64Array new: n.
	1 to: n do: [ :i | y at: i put: ((((x at: i) - mean) * inv) * (gamma at: i)) + (beta at: i) ].
	^ y
]

{ #category : 'linear' }
GcTensorMath class >> matmulA: a rows: m inner: k b: b cols: n [
	"C[m,n] = A[m,k] . B[k,n], all row-major Float64Array. i-k-j accumulation into a reusable row buffer; no allocation in the inner loop."
	| c rowBuf aBase bBase cBase aip |
	c := Float64Array new: m * n.
	rowBuf := Float64Array new: n.
	1 to: m do: [ :i |
		1 to: n do: [ :j | rowBuf at: j put: 0.0 ].
		aBase := (i - 1) * k.
		1 to: k do: [ :p |
			aip := a at: aBase + p.
			bBase := (p - 1) * n.
			1 to: n do: [ :j | rowBuf at: j put: (rowBuf at: j) + (aip * (b at: bBase + j)) ] ].
		cBase := (i - 1) * n.
		1 to: n do: [ :j | c at: cBase + j put: (rowBuf at: j) ] ].
	^ c
]

{ #category : 'kernels - optimized' }
GcTensorMath class >> matmulBlockedA: a rows: m inner: k b: b cols: n blockSize: bs [
	"BLOCKED (cache-tiled) C[m,n] = A[m,k] . B[k,n], row-major Float64Array. Same i-k-j accumulation as matmulA:... but iterated over bs-sized tiles of the (i,k,j) index space so an A/B tile loaded into cache is reused across the block; the accumulator IS c (Float64Array new: is 0.0-filled) -- NO inner-loop allocation. For any fixed output C[i,j] the p-contributions are still added in ascending p order (each k-tile is a contiguous ascending range processed to completion before the next), so the summation order -- and thus the result -- is numerically IDENTICAL to matmulA:. The reason BLAS exists: reuse a loaded block. In an interpreted VM the extra tiling overhead may cancel the cache win -- measure it with GcKernelBenchmark."
	| c iEnd pEnd jEnd aBase bBase cBase aip |
	c := Float64Array new: m * n.
	1 to: m by: bs do: [ :ii |
		iEnd := (ii + bs - 1) min: m.
		1 to: k by: bs do: [ :kk |
			pEnd := (kk + bs - 1) min: k.
			1 to: n by: bs do: [ :jj |
				jEnd := (jj + bs - 1) min: n.
				ii to: iEnd do: [ :i |
					aBase := (i - 1) * k.
					cBase := (i - 1) * n.
					kk to: pEnd do: [ :p |
						aip := a at: aBase + p.
						bBase := (p - 1) * n.
						jj to: jEnd do: [ :j |
							c at: cBase + j put: (c at: cBase + j) + (aip * (b at: bBase + j)) ] ] ] ] ] ].
	^ c
]

{ #category : 'linear' }
GcTensorMath class >> mmulNoTransposeInput: x inSize: inSize weight: w outSize: outSize bias: bias [
	"GPT-2 Conv1D linear -- THE no-transpose convention. x has inSize elements; W is stored [inSize, outSize] ROW-MAJOR (HF Conv1D weight layout); y[j] = ( sum over i of x[i] * W[i*outSize + j] ) + bias[j]. NO transpose. bias may be nil."
	| y wBase xi |
	y := Float64Array new: outSize.
	bias ifNotNil: [ 1 to: outSize do: [ :j | y at: j put: (bias at: j) ] ].
	1 to: inSize do: [ :i |
		xi := x at: i.
		wBase := (i - 1) * outSize.
		1 to: outSize do: [ :j | y at: j put: (y at: j) + (xi * (w at: wBase + j)) ] ].
	^ y
]

{ #category : 'elementwise' }
GcTensorMath class >> mul: a and: b [
	"Elementwise product of two equal-length vectors."
	| y |
	y := Float64Array new: a size.
	1 to: a size do: [ :i | y at: i put: (a at: i) * (b at: i) ].
	^ y
]

{ #category : 'activations' }
GcTensorMath class >> softmax: x [
	"Numerically stable softmax over the whole vector: subtract the max, exp, normalize."
	| y max sum |
	max := x at: 1.
	2 to: x size do: [ :i | (x at: i) > max ifTrue: [ max := x at: i ] ].
	y := Float64Array new: x size.
	sum := 0.0.
	1 to: x size do: [ :i | | e | e := ((x at: i) - max) exp. y at: i put: e. sum := sum + e ].
	1 to: x size do: [ :i | y at: i put: (y at: i) / sum ].
	^ y
]

{ #category : 'private' }
GcTensorMath class >> tanhOf: x [
	"tanh synthesized from exp (Float has no #tanh here); stable form, no overflow for large |x|."
	| t |
	x < 0.0 ifTrue: [ ^ (self tanhOf: x negated) negated ].
	t := (2.0 * x) negated exp.
	^ (1.0 - t) / (1.0 + t)
]

{ #category : 'linear' }
GcTensorMath class >> unembedHidden: h dim: d table: table vocab: vocab [
	"Tied unembedding (transposed): logits[v] = sum over dd of h[dd] * table[v*d + dd], where table is stored [vocab, d] row-major (the tied embedding weights). Cost vocab*d."
	| logits base acc |
	logits := Float64Array new: vocab.
	1 to: vocab do: [ :v |
		base := (v - 1) * d.
		acc := 0.0.
		1 to: d do: [ :dd | acc := acc + ((h at: dd) * (table at: base + dd)) ].
		logits at: v put: acc ].
	^ logits
]
