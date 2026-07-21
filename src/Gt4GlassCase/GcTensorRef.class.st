"
A reference to one tensor: name, dtype, shape, byte offsets, owning file. NEVER holds bytes (I5) -- browsing a 671B model must work on a laptop.
"
Class {
	#name : 'GcTensorRef',
	#superclass : 'Object',
	#instVars : [
		'name',
		'dtype',
		'shape',
		'beginOffset',
		'endOffset',
		'file',
		'stats'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTensorRef class >> name: aName dtype: aDtype shape: aShape [
	^ self new
		name: aName;
		dtype: aDtype;
		shape: aShape;
		yourself
]

{ #category : 'sampling' }
GcTensorRef class >> sampleElementCap [
	"Max elements decoded for an in-image sample: 65536 keeps the ranged fetch <= 256 KB even at f32 (I5/I7)."
	^ 65536
]

{ #category : 'decoding' }
GcTensorRef >> asFloatArray [
	"The WHOLE tensor decoded to a row-major Float64Array (this image has no FloatArray; Float64Array is the full-precision typed float array). One ranged read + decode of every element. GPT-2 is F32, decoded losslessly into doubles."
	^ Float64Array withAll: (self sliceFromElement: 0 count: self elementCount) values
]

{ #category : 'accessing' }
GcTensorRef >> beginOffset [
	^ beginOffset
]

{ #category : 'accessing' }
GcTensorRef >> beginOffset: anInteger [
	beginOffset := anInteger
]

{ #category : 'querying' }
GcTensorRef >> byteSize [
	^ (beginOffset notNil and: [ endOffset notNil ])
		ifTrue: [ endOffset - beginOffset ]
		ifFalse: [ 0 ]
]

{ #category : 'accessing' }
GcTensorRef >> cachedStats [
	"The cached Tier-1 stats, or nil if not computed yet. Never fetches (unlike #stats)."
	^ stats
]

{ #category : 'views' }
GcTensorRef >> detailFacets [
	| pn |
	pn := self parsedName.
	^ {
		'Name' -> name.
		'Dtype' -> dtype.
		'Shape' -> shape.
		'Params' -> self paramCount.
		'Bytes' -> self byteSize.
		'Byte range' -> (beginOffset ifNil: [ nil ] ifNotNil: [ :b | b printString, ' .. ', endOffset printString ]).
		'Layer' -> pn layerIndex.
		'Block' -> pn block.
		'Module' -> pn module.
		'Role' -> pn role.
		'Expert' -> pn expertIndex.
		'Parsed name' -> pn }
]

{ #category : 'accessing' }
GcTensorRef >> dimensions [
	"The raw dimensions array (convenience)."
	^ shape ifNil: [ #() ] ifNotNil: [ :s | (s isKindOf: GcTensorShape) ifTrue: [ s dimensions ] ifFalse: [ s ] ]
]

{ #category : 'accessing' }
GcTensorRef >> dtype [
	^ dtype
]

{ #category : 'accessing' }
GcTensorRef >> dtype: aSymbol [
	dtype := aSymbol
]

{ #category : 'numerics' }
GcTensorRef >> dtypeByteWidth [
	"Bytes per element for the tensor's dtype (safetensors names, lowercased)."
	^ (Dictionary new)
		at: #f64 put: 8; at: #i64 put: 8; at: #u64 put: 8;
		at: #f32 put: 4; at: #i32 put: 4; at: #u32 put: 4;
		at: #f16 put: 2; at: #bf16 put: 2; at: #i16 put: 2; at: #u16 put: 2;
		at: #f8_e4m3 put: 1; at: #f8_e5m2 put: 1; at: #i8 put: 1; at: #u8 put: 1; at: #bool put: 1;
		at: dtype ifAbsent: [ nil ]
]

{ #category : 'numerics' }
GcTensorRef >> elementCount [
	"Number of elements = product of the shape dimensions (1 for a scalar)."
	shape isNil ifTrue: [ ^ 1 ].
	(shape isKindOf: GcTensorShape) ifTrue: [ ^ shape elementCount ].
	^ shape isEmpty ifTrue: [ 1 ] ifFalse: [ shape inject: 1 into: [ :product :dim | product * dim ] ]
]

{ #category : 'accessing' }
GcTensorRef >> endOffset [
	^ endOffset
]

{ #category : 'accessing' }
GcTensorRef >> endOffset: anInteger [
	endOffset := anInteger
]

{ #category : 'accessing' }
GcTensorRef >> file [
	^ file
]

{ #category : 'accessing' }
GcTensorRef >> file: aFile [
	file := aFile
]

{ #category : 'views' }
GcTensorRef >> gtDetailsFor: aView [
	"What is this tensor and where does it live in the model?"
	<gtView>
	^ aView columnedList
		title: 'Tensor';
		priority: 1;
		items: [ self detailFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | (v isCollection and: [ v isString not ]) ifTrue: [ v printString ] ifFalse: [ v displayString ] ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt - views' }
GcTensorRef >> gtSampleValuesFor: aView [
	"The first decoded values of a sampled slice of this tensor."
	<gtView>
	self supportsSampling ifFalse: [ ^ aView empty ].
	^ aView forward
		title: 'Sample values';
		priority: 5;
		object: [ self stats ];
		view: #gtSampleValuesFor:
]

{ #category : 'gt - views' }
GcTensorRef >> gtValueDistributionFor: aView [
	"What values does this tensor hold? (samples and decodes on demand, then delegates to the statistics)"
	<gtView>
	self supportsSampling ifFalse: [ ^ aView empty ].
	^ aView forward
		title: 'Value distribution';
		priority: 4;
		object: [ self stats ];
		view: #gtValueDistributionFor:
]

{ #category : 'testing' }
GcTensorRef >> hasStats [
	"Are Tier-1 stats already computed and cached? Answers WITHOUT triggering a fetch (unlike #stats), so regularity views can read value stats only where they are free."
	^ stats notNil
]

{ #category : 'sampling' }
GcTensorRef >> innerSize [
	"Elements per leading-dimension row: the product of all dimensions except the first (the contiguous inner block of a row-major tensor). For a 2-D vocab x hidden embedding this is the hidden size."
	| dims |
	dims := self dimensions.
	dims size <= 1 ifTrue: [ ^ self elementCount ].
	^ dims allButFirst inject: 1 into: [ :p :d | p * d ]
]

{ #category : 'sampling' }
GcTensorRef >> isFullySampled [
	^ self paramCount <= self class sampleElementCap
]

{ #category : 'testing' }
GcTensorRef >> isRouterTensor [
	"True if this looks like a MoE top-k gating router weight: module 'gate' or 'router', role 'weight', rank-2 (experts x hidden) with more than one expert, and not a per-expert tensor. Matches Qwen/DeepSeek/OLMoE (mlp.gate.weight) and Mixtral (block_sparse_moe.gate.weight); excludes shared_expert_gate (single row) and dense mlp.gate_proj."
	| parsed dims |
	parsed := self parsedName.
	((parsed module = 'gate') or: [ parsed module = 'router' ]) ifFalse: [ ^ false ].
	parsed role = 'weight' ifFalse: [ ^ false ].
	parsed isExpert ifTrue: [ ^ false ].
	dims := self dimensions.
	^ dims size = 2 and: [ dims first > 1 ]
]

{ #category : 'querying' }
GcTensorRef >> layerIndex [
	^ self parsedName layerIndex
]

{ #category : 'querying' }
GcTensorRef >> module [
	^ self parsedName module
]

{ #category : 'accessing' }
GcTensorRef >> name [
	^ name
]

{ #category : 'accessing' }
GcTensorRef >> name: aString [
	name := aString
]

{ #category : 'numerics' }
GcTensorRef >> paramCount [
	^ self elementCount
]

{ #category : 'querying' }
GcTensorRef >> parsedName [
	^ GcTensorName from: name
]

{ #category : 'printing' }
GcTensorRef >> printOn: aStream [
	aStream nextPutAll: 'GcTensorRef('.
	aStream nextPutAll: (name ifNil: [ '?' ]).
	aStream nextPut: $)
]

{ #category : 'sampling' }
GcTensorRef >> rowBandSliceFrom: startRow count: nRows [
	"Fetch+decode a contiguous band of nRows rows starting at startRow (0-based) as ONE flat GcTensorSlice -- a single ranged read for the whole band. Callers reshape into rows of innerSize."
	| inner |
	inner := self innerSize.
	^ self sliceFromElement: startRow * inner count: nRows * inner
]

{ #category : 'sampling' }
GcTensorRef >> rowSliceAt: aRowIndex [
	"Fetch+decode row aRowIndex (0-based) of this row-major tensor as a GcTensorSlice -- one ranged read of innerSize elements."
	| inner |
	inner := self innerSize.
	^ self sliceFromElement: aRowIndex * inner count: inner
]

{ #category : 'sampling' }
GcTensorRef >> sampleElementCount [
	^ self paramCount min: self class sampleElementCap
]

{ #category : 'sampling' }
GcTensorRef >> sampleSlice [
	"Fetch (via the file's bytes port) and decode a leading contiguous span of this tensor's values -- the whole tensor when small, otherwise a capped sample. Absolute range = file dataOffset + this tensor's relative begin offset."
	| width count absStart absEnd bytes decoder decoded |
	self supportsSampling ifFalse: [ ^ self error: 'Sampling not supported for dtype ', dtype printString ].
	file ifNil: [ ^ self error: 'Tensor has no owning file' ].
	width := self dtypeByteWidth.
	count := self sampleElementCount.
	absStart := file byteDataOffset + beginOffset.
	absEnd := absStart + (count * width) - 1.
	bytes := file bytesFrom: absStart to: absEnd.
	decoder := GcDtypeDecoder forDtype: dtype.
	decoded := decoder decodeBytes: bytes.
	^ GcTensorSlice tensorRef: self elementStart: 0 values: decoded isFull: self isFullySampled
]

{ #category : 'sampling' }
GcTensorRef >> sampleStats [
	^ self stats
]

{ #category : 'accessing' }
GcTensorRef >> shape [
	^ shape
]

{ #category : 'accessing' }
GcTensorRef >> shape: aShapeOrArray [
	"Store the shape as a first-class GcTensorShape, wrapping a raw dimensions array if needed."
	shape := aShapeOrArray isNil
		ifTrue: [ nil ]
		ifFalse: [ (aShapeOrArray isKindOf: GcTensorShape)
			ifTrue: [ aShapeOrArray ]
			ifFalse: [ GcTensorShape fromArray: aShapeOrArray ] ]
]

{ #category : 'sampling' }
GcTensorRef >> sliceFromElement: startElement count: aCount [
	"Fetch (via the file's bytes port) and decode a contiguous element range [startElement, startElement+aCount) of this tensor -- e.g. one embedding row, since rows of a 2-D row-major safetensors tensor are contiguous. ONE ranged read. Absolute range = file dataOffset + this tensor's begin offset + startElement*byteWidth."
	| width absStart absEnd bytes decoder decoded full |
	self supportsSampling ifFalse: [ ^ self error: 'Sampling not supported for dtype ', dtype printString ].
	file ifNil: [ ^ self error: 'Tensor has no owning file' ].
	(startElement >= 0 and: [ aCount > 0 and: [ startElement + aCount <= self elementCount ] ])
		ifFalse: [ ^ self error: 'Element range out of bounds' ].
	width := self dtypeByteWidth.
	absStart := file byteDataOffset + beginOffset + (startElement * width).
	absEnd := absStart + (aCount * width) - 1.
	bytes := file bytesFrom: absStart to: absEnd.
	decoder := GcDtypeDecoder forDtype: dtype.
	decoded := decoder decodeBytes: bytes.
	full := startElement = 0 and: [ aCount = self elementCount ].
	^ GcTensorSlice tensorRef: self elementStart: startElement values: decoded isFull: full
]

{ #category : 'sampling' }
GcTensorRef >> stats [
	"Lazily computed, cached Tier-1 numeric summary of a sampled slice of this tensor."
	^ stats ifNil: [ stats := self sampleSlice stats ]
]

{ #category : 'sampling' }
GcTensorRef >> supportsSampling [
	^ GcDtypeDecoder supportedDtypes includes: dtype
]
