"
Decodes raw little-endian safetensors tensor bytes into Floats for exactly the dtypes the numeric views need: bf16, f16, f32. It exists so decoding lives in ONE inspectable, testable place instead of being smeared across the tensor model. Class-side primitives (bf16FromU16:/f16FromU16:/f32FromU32:) do the IEEE-754 bit math (including f16 subnormals, Inf and NaN); an instance carries a dtype and decodes a whole byte buffer. Not a general tensor library -- only the three float dtypes are supported.
"
Class {
	#name : 'GcDtypeDecoder',
	#superclass : 'Object',
	#instVars : [
		'dtype'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'decoding - primitives' }
GcDtypeDecoder class >> bf16FromU16: aU16 [
	"BF16 is simply the high 16 bits of an IEEE-754 fp32; widen and reinterpret."
	^ Float fromIEEE32Bit: (aU16 bitShift: 16)
]

{ #category : 'decoding - primitives' }
GcDtypeDecoder class >> f16FromU16: aU16 [
	"Decode an IEEE-754 half (1 sign, 5 exponent, 10 mantissa bits), handling subnormals, Inf and NaN explicitly."
	| sign exp frac magnitude |
	sign := (aU16 bitShift: -15) bitAnd: 1.
	exp := (aU16 bitShift: -10) bitAnd: 16r1F.
	frac := aU16 bitAnd: 16r3FF.
	exp = 16r1F ifTrue: [
		^ frac = 0
			ifTrue: [ sign = 1 ifTrue: [ Float negativeInfinity ] ifFalse: [ Float infinity ] ]
			ifFalse: [ Float nan ] ].
	exp = 0
		ifTrue: [ magnitude := (frac / 1024) * (2 raisedTo: -14) ]
		ifFalse: [ magnitude := (1 + (frac / 1024)) * (2 raisedTo: exp - 15) ].
	magnitude := magnitude asFloat.
	^ sign = 1 ifTrue: [ magnitude negated ] ifFalse: [ magnitude ]
]

{ #category : 'decoding - primitives' }
GcDtypeDecoder class >> f32FromU32: aU32 [
	^ Float fromIEEE32Bit: aU32
]

{ #category : 'instance creation' }
GcDtypeDecoder class >> forDtype: aSymbol [
	^ self new dtype: aSymbol; yourself
]

{ #category : 'accessing' }
GcDtypeDecoder class >> supportedDtypes [
	^ #(#bf16 #f16 #f32)
]

{ #category : 'accessing' }
GcDtypeDecoder >> bytesPerElement [
	dtype = #f32 ifTrue: [ ^ 4 ].
	(dtype = #bf16 or: [ dtype = #f16 ]) ifTrue: [ ^ 2 ].
	self error: 'Unsupported dtype for decoding: ', dtype printString
]

{ #category : 'decoding' }
GcDtypeDecoder >> decodeBytes: aByteArray [
	"Decode a whole little-endian byte buffer into an Array of Floats (whole elements only; a trailing partial element is ignored)."
	| width n |
	width := self bytesPerElement.
	n := aByteArray size // width.
	^ (0 to: n - 1) collect: [ :i | self decodeElementAt: i in: aByteArray ]
]

{ #category : 'decoding' }
GcDtypeDecoder >> decodeElementAt: anElementIndex in: aByteArray [
	"Decode the 0-based element at anElementIndex from a little-endian byte buffer."
	| width base |
	width := self bytesPerElement.
	base := (anElementIndex * width) + 1.
	dtype = #f32 ifTrue: [ ^ self class f32FromU32: (self u32At: base in: aByteArray) ].
	dtype = #bf16 ifTrue: [ ^ self class bf16FromU16: (self u16At: base in: aByteArray) ].
	dtype = #f16 ifTrue: [ ^ self class f16FromU16: (self u16At: base in: aByteArray) ].
	self error: 'Unsupported dtype for decoding: ', dtype printString
]

{ #category : 'accessing' }
GcDtypeDecoder >> dtype [
	^ dtype
]

{ #category : 'accessing' }
GcDtypeDecoder >> dtype: aSymbol [
	dtype := aSymbol
]

{ #category : 'explaining' }
GcDtypeDecoder >> explanationFacets [
	| facets |
	facets := OrderedCollection new.
	facets add: 'Dtype' -> dtype.
	facets add: 'Byte order' -> 'little-endian'.
	facets add: 'Supported' -> self isSupported.
	self isSupported ifTrue: [
		facets add: 'Bytes per element' -> self bytesPerElement.
		facets add: 'Decodes 1.0 from bits' -> self oneSampleHex.
		facets add: 'Decoded value' -> self oneSampleValue ].
	^ facets asArray
]

{ #category : 'gt - views' }
GcDtypeDecoder >> gtWorkedExampleFor: aView [
	"How does this decoder turn bytes into a Float?"
	<gtView>
	^ aView columnedList
		title: 'Decoding';
		priority: 1;
		items: [ self explanationFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value isNil ifTrue: [ '-' ] ifFalse: [ assoc value displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'testing' }
GcDtypeDecoder >> isSupported [
	^ self class supportedDtypes includes: dtype
]

{ #category : 'explaining' }
GcDtypeDecoder >> oneSampleHex [
	dtype = #f32 ifTrue: [ ^ '16r3F800000' ].
	dtype = #bf16 ifTrue: [ ^ '16r3F80' ].
	dtype = #f16 ifTrue: [ ^ '16r3C00' ].
	^ nil
]

{ #category : 'explaining' }
GcDtypeDecoder >> oneSampleValue [
	"The Float this decoder produces from the canonical bits for 1.0 -- a live proof it works."
	dtype = #f32 ifTrue: [ ^ self class f32FromU32: 16r3F800000 ].
	dtype = #bf16 ifTrue: [ ^ self class bf16FromU16: 16r3F80 ].
	dtype = #f16 ifTrue: [ ^ self class f16FromU16: 16r3C00 ].
	^ nil
]

{ #category : 'printing' }
GcDtypeDecoder >> printOn: aStream [
	aStream nextPutAll: 'GcDtypeDecoder('; nextPutAll: (dtype ifNil: [ '?' ]) asString; nextPut: $)
]

{ #category : 'decoding' }
GcDtypeDecoder >> u16At: anIndex in: aByteArray [
	"Little-endian unsigned 16-bit at 1-based byte index."
	^ (aByteArray at: anIndex) + ((aByteArray at: anIndex + 1) * 256)
]

{ #category : 'decoding' }
GcDtypeDecoder >> u32At: anIndex in: aByteArray [
	"Little-endian unsigned 32-bit at 1-based byte index."
	^ (aByteArray at: anIndex)
		+ ((aByteArray at: anIndex + 1) bitShift: 8)
		+ ((aByteArray at: anIndex + 2) bitShift: 16)
		+ ((aByteArray at: anIndex + 3) bitShift: 24)
]
