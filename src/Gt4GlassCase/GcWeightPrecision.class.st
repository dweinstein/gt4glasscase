"
A weight-precision mode as a first-class value object (I1: nothing is a bare symbol). Represents how a GcGpt2Model's weights are simulated when decoded: #f32 (exact full precision, the baseline), #bf16 (round each element to bfloat16 = sign + 8 exponent + top 7 mantissa bits), or a symmetric round-to-nearest integer mode #int8 / #int4. Applying a precision to a weight tensor returns a NEW Float64Array whose values have been quantized then dequantized, simulating what the model would compute if its weights were stored at that precision. Integer modes quantize PER ROW (each leading-dimension row of a rank>=2 tensor gets its own scale = maxAbs(row)/(2^(bits-1)-1)); rank<=1 tensors (biases, LayerNorm gamma/beta) are left in full precision, matching real int quantization and the GcMoeRouter>>quantizedToBits: bias convention this generalizes. #f32 apply is the identity, so it reproduces the baseline logits exactly.
"
Class {
	#name : 'GcWeightPrecision',
	#superclass : 'Object',
	#instVars : [
		'symbol',
		'bits'
	],
	#category : 'Gt4GlassCase-Precision',
	#package : 'Gt4GlassCase',
	#tag : 'Precision'
}

{ #category : 'accessing' }
GcWeightPrecision class >> all [
	"The four modes in increasing aggressiveness, f32 baseline first."
	^ { self f32. self bf16. self int8. self int4 }
]

{ #category : 'accessing' }
GcWeightPrecision class >> allSymbols [
	^ #(f32 bf16 int8 int4)
]

{ #category : 'instance creation' }
GcWeightPrecision class >> bf16 [
	"bfloat16: sign + 8 exponent + top 7 mantissa bits (the high 16 bits of an fp32)."
	^ self symbol: #bf16
]

{ #category : 'converting' }
GcWeightPrecision class >> bf16Round: aFloat [
	"Round an f64/f32 to bf16 precision (sign + 8 exponent bits + top 7 mantissa bits), round-to-nearest-even, reusing GcDtypeDecoder>>bf16FromU16:. bf16 is the high 16 bits of the fp32 word; add the rounding bias then keep the high half and widen back."
	| word bias u16 |
	aFloat isFinite ifFalse: [ ^ aFloat ].
	word := aFloat asIEEE32BitWord.
	bias := 16r7FFF + ((word bitShift: -16) bitAnd: 1).
	u16 := ((word + bias) bitShift: -16) bitAnd: 16rFFFF.
	^ GcDtypeDecoder bf16FromU16: u16
]

{ #category : 'instance creation' }
GcWeightPrecision class >> default [
	^ self f32
]

{ #category : 'instance creation' }
GcWeightPrecision class >> f32 [
	"Full precision -- the exact baseline. apply: is the identity."
	^ self symbol: #f32
]

{ #category : 'instance creation' }
GcWeightPrecision class >> fromSymbol: aSymbolOrPrecision [
	"Accept either a bare symbol (#f32/#bf16/#int8/#int4) or an already-built GcWeightPrecision, so callers can pass whichever they have."
	(aSymbolOrPrecision isKindOf: self) ifTrue: [ ^ aSymbolOrPrecision ].
	^ self symbol: aSymbolOrPrecision
]

{ #category : 'instance creation' }
GcWeightPrecision class >> int4 [
	"Symmetric per-row round-to-nearest int4 -- the most aggressive mode."
	^ self symbol: #int4
]

{ #category : 'instance creation' }
GcWeightPrecision class >> int8 [
	"Symmetric per-row round-to-nearest int8."
	^ self symbol: #int8
]

{ #category : 'instance creation' }
GcWeightPrecision class >> symbol: aSymbol [
	^ self new setSymbol: aSymbol
]

{ #category : 'comparing' }
GcWeightPrecision >> = anObject [
	^ self class = anObject class and: [ symbol = anObject symbol ]
]

{ #category : 'applying' }
GcWeightPrecision >> apply: aFloat64Array dimensions: dims [
	"Return a NEW Float64Array of aFloat64Array quantized-then-dequantized at this precision (dims is the tensor's raw dimensions array, needed for per-row integer scaling). #f32 is the identity so the baseline is reproduced exactly."
	symbol = #f32 ifTrue: [ ^ aFloat64Array ].
	self isBf16 ifTrue: [ ^ self bf16RoundAll: aFloat64Array ].
	self isInteger ifTrue: [ ^ self intQuantize: aFloat64Array dimensions: dims ].
	^ aFloat64Array
]

{ #category : 'applying' }
GcWeightPrecision >> bf16RoundAll: aArray [
	"Round every element to bf16 precision into a NEW Float64Array."
	| n out |
	n := aArray size.
	out := Float64Array new: n.
	1 to: n do: [ :i | out at: i put: (self class bf16Round: (aArray at: i)) ].
	^ out
]

{ #category : 'accessing' }
GcWeightPrecision >> bits [
	"Integer bit width for #int8/#int4, or nil for #f32/#bf16."
	^ bits
]

{ #category : 'gt - views' }
GcWeightPrecision >> gtOverviewFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Overview';
		priority: 10;
		items: [ {
			'Mode' -> self label.
			'Bits' -> (bits ifNil: [ self isBf16 ifTrue: [ '16 (bf16)' ] ifFalse: [ '32 (f32)' ] ] ifNotNil: [ bits ]).
			'Full precision?' -> self isFullPrecision.
			'Integer RTN?' -> self isInteger.
			'Per-row scale?' -> self isInteger } ];
		column: 'Field' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value asString ];
		send: [ :assoc | self ]
]

{ #category : 'comparing' }
GcWeightPrecision >> hash [
	^ symbol hash
]

{ #category : 'applying' }
GcWeightPrecision >> intQuantize: aArray dimensions: dims [
	"Symmetric per-row round-to-nearest quantize->dequantize to `bits` bits. Generalizes GcMoeRouter>>quantizedToBits: to a flat row-major Float64Array: each leading-dimension row (innerSize contiguous elements) gets scale = maxAbs(row) / (2^(bits-1)-1), q = clamp(round(w/scale)), w' = q*scale. Rank<=1 tensors (biases, LayerNorm gamma/beta) are left in FULL precision -- matching real int quantization and the router's full-precision bias."
	| n cols rows levels negLevels out |
	dims size < 2 ifTrue: [ ^ aArray ].
	n := aArray size.
	levels := (2 raisedTo: bits - 1) - 1.
	negLevels := levels negated.
	cols := dims allButFirst inject: 1 into: [ :p :d | p * d ].
	rows := n // cols.
	out := Float64Array new: n.
	0 to: rows - 1 do: [ :r |
		| base maxAbs scale |
		base := r * cols.
		maxAbs := 0.0.
		1 to: cols do: [ :c |
			| v |
			v := (aArray at: base + c) abs.
			v > maxAbs ifTrue: [ maxAbs := v ] ].
		scale := maxAbs = 0.0 ifTrue: [ 1.0 ] ifFalse: [ maxAbs / levels ].
		1 to: cols do: [ :c |
			| q |
			q := ((aArray at: base + c) / scale) rounded.
			q := (q max: negLevels) min: levels.
			out at: base + c put: q * scale ] ].
	^ out
]

{ #category : 'testing' }
GcWeightPrecision >> isBf16 [
	^ symbol = #bf16
]

{ #category : 'testing' }
GcWeightPrecision >> isFullPrecision [
	^ symbol = #f32
]

{ #category : 'testing' }
GcWeightPrecision >> isInteger [
	"True for the symmetric-int modes (#int8/#int4)."
	^ bits notNil
]

{ #category : 'accessing' }
GcWeightPrecision >> label [
	^ symbol asString
]

{ #category : 'printing' }
GcWeightPrecision >> printOn: aStream [
	aStream nextPutAll: 'precision '; nextPutAll: self label
]

{ #category : 'initialization' }
GcWeightPrecision >> setSymbol: aSymbol [
	symbol := aSymbol.
	bits := aSymbol = #int8
		ifTrue: [ 8 ]
		ifFalse: [ aSymbol = #int4 ifTrue: [ 4 ] ifFalse: [ nil ] ]
]

{ #category : 'accessing' }
GcWeightPrecision >> symbol [
	^ symbol
]
