"
A key/value cache for incremental (KV-cached) GPT-2 decoding. Per layer (0..numLayers-1) it holds two growing OrderedCollections of per-position Float64Arrays: the attention KEYS and VALUES already computed for every token seen so far (each a d-length slice of that token's c_attn output -- keys are the [d,2d) slice, values the [2d,3d) slice). During prefill the whole prompt's K/V are appended; during decode each new token appends exactly one K and one V per layer and then attends over the FULL accumulated K/V. This is the memory that makes decode O(seqLen) per step instead of O(seqLen^2): the cost of long context is literally the size of this object (see gtCacheGrowthFor: and memoryBytes).
"
Class {
	#name : 'GcKvCache',
	#superclass : 'Object',
	#instVars : [
		'numLayers',
		'keys',
		'values'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'adding' }
GcKvCache >> appendKey: aKeyVector value: aValueVector forLayer: layerIndex [
	"Append one position's key and value (each a d-length Float64Array) to the 0-based layerIndex."
	(keys at: layerIndex + 1) addLast: aKeyVector.
	(values at: layerIndex + 1) addLast: aValueVector
]

{ #category : 'gt - views' }
GcKvCache >> gtCacheGrowthFor: aView [
	<gtView>
	| total seqLen |
	seqLen := self seqLength.
	total := self memoryBytes.
	^ aView columnedList
		title: 'Cache growth';
		priority: 10;
		items: [ self layerSlices ];
		column: 'Layer' text: [ :slice | slice layerIndex printString ];
		column: 'Positions (K)' text: [ :slice | slice keys size printString ];
		column: 'Positions (V)' text: [ :slice | slice values size printString ];
		column: 'Bytes' text: [ :slice | slice memoryBytes printString ];
		column: 'KB' text: [ :slice | (slice memoryBytes / 1024.0) printShowingDecimalPlaces: 1 ];
		send: [ :slice | slice ]
]

{ #category : 'gt - views' }
GcKvCache >> gtSummaryFor: aView [
	<gtView>
	^ aView textEditor
		title: 'Summary';
		priority: 5;
		text: [ String streamContents: [ :s |
			s nextPutAll: 'KV cache'; cr.
			s nextPutAll: 'layers: '; print: (numLayers ifNil: [ 0 ]); cr.
			s nextPutAll: 'context length (positions): '; print: self seqLength; cr.
			s nextPutAll: 'total memory (bytes): '; print: self memoryBytes; cr.
			s nextPutAll: 'total memory (KB): '; nextPutAll: (self memoryBytes / 1024.0 printShowingDecimalPlaces: 1); cr.
			s nextPutAll: 'per new token this grows by ~'; print: (numLayers ifNil: [ 0 ]) * 2 * 768 * 8; nextPutAll: ' bytes (numLayers * 2 * d * 8).' ] ]
]

{ #category : 'accessing' }
GcKvCache >> keysForLayer: layerIndex [
	"The OrderedCollection of cached key vectors for the 0-based layerIndex, oldest position first."
	^ keys at: layerIndex + 1
]

{ #category : 'accessing' }
GcKvCache >> layerSlices [
	"A moldable GcKvLayerSlice per layer, wrapping that layer's cached key/value collections."
	| slices |
	numLayers isNil ifTrue: [ ^ #() ].
	slices := OrderedCollection new.
	0 to: numLayers - 1 do: [ :li |
		slices add: (GcKvLayerSlice new
			layerIndex: li;
			keys: (keys at: li + 1);
			values: (values at: li + 1);
			yourself) ].
	^ slices asArray
]

{ #category : 'accessing' }
GcKvCache >> memoryBytes [
	"Total bytes held by the cached key and value vectors (8 bytes per Float64 element), summed over all layers and positions. This is the memory price of the current context length."
	| total |
	total := 0.
	numLayers isNil ifTrue: [ ^ 0 ].
	0 to: numLayers - 1 do: [ :li |
		(keys at: li + 1) do: [ :k | total := total + (k size * 8) ].
		(values at: li + 1) do: [ :v | total := total + (v size * 8) ] ].
	^ total
]

{ #category : 'accessing' }
GcKvCache >> numLayers [
	^ numLayers
]

{ #category : 'initialization' }
GcKvCache >> numLayers: anInteger [
	"Size the cache for anInteger transformer layers, with empty key/value collections per layer. Returns self so `GcKvCache new numLayers: 12` yields the cache."
	numLayers := anInteger.
	keys := (1 to: anInteger) collect: [ :i | OrderedCollection new ].
	values := (1 to: anInteger) collect: [ :i | OrderedCollection new ].
	^ self
]

{ #category : 'operations' }
GcKvCache >> reset [
	"Empty every layer's key/value collections, keeping the layer count."
	numLayers ifNotNil: [ self numLayers: numLayers ]
]

{ #category : 'accessing' }
GcKvCache >> seqLength [
	"Number of token positions currently cached (identical across layers). Zero if unsized or empty."
	(numLayers isNil or: [ numLayers = 0 ]) ifTrue: [ ^ 0 ].
	^ (keys at: 1) size
]

{ #category : 'accessing' }
GcKvCache >> valuesForLayer: layerIndex [
	"The OrderedCollection of cached value vectors for the 0-based layerIndex, oldest position first."
	^ values at: layerIndex + 1
]
