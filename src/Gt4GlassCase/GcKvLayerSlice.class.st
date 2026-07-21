"
One layer's slice of a GcKvCache: the accumulated attention keys and values (each an OrderedCollection of d-length Float64Arrays, one per cached token position) for a single transformer layer. A moldable, inspectable row of the cache-growth view -- gtVectorsFor: lists the per-position key/value vectors so you can drill from 'how big is layer N' down to the actual cached vectors.
"
Class {
	#name : 'GcKvLayerSlice',
	#superclass : 'Object',
	#instVars : [
		'layerIndex',
		'keys',
		'values'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'gt - views' }
GcKvLayerSlice >> gtVectorsFor: aView [
	<gtView>
	^ aView columnedList
		title: 'Cached vectors';
		priority: 10;
		items: [ (1 to: self seqLength) asArray ];
		column: 'Position' text: [ :pos | pos printString ];
		column: 'Key L2' text: [ :pos | ((keys at: pos) inject: 0.0 into: [ :acc :e | acc + (e * e) ]) sqrt printShowingDecimalPlaces: 4 ];
		column: 'Value L2' text: [ :pos | ((values at: pos) inject: 0.0 into: [ :acc :e | acc + (e * e) ]) sqrt printShowingDecimalPlaces: 4 ];
		column: 'Dim' text: [ :pos | (keys at: pos) size printString ];
		send: [ :pos | keys at: pos ]
]

{ #category : 'accessing' }
GcKvLayerSlice >> keys [
	^ keys
]

{ #category : 'accessing' }
GcKvLayerSlice >> keys: aCollection [
	keys := aCollection
]

{ #category : 'accessing' }
GcKvLayerSlice >> layerIndex [
	^ layerIndex
]

{ #category : 'accessing' }
GcKvLayerSlice >> layerIndex: anInteger [
	layerIndex := anInteger
]

{ #category : 'accessing' }
GcKvLayerSlice >> memoryBytes [
	"Bytes held by this layer's cached key and value vectors (8 bytes per Float64 element)."
	| total |
	total := 0.
	keys do: [ :k | total := total + (k size * 8) ].
	values do: [ :v | total := total + (v size * 8) ].
	^ total
]

{ #category : 'printing' }
GcKvLayerSlice >> printOn: aStream [
	super printOn: aStream.
	aStream nextPutAll: '(layer '; print: layerIndex; nextPutAll: ', '; print: self seqLength; nextPutAll: ' positions)'
]

{ #category : 'accessing' }
GcKvLayerSlice >> seqLength [
	"Number of cached positions in this layer."
	^ keys size
]

{ #category : 'accessing' }
GcKvLayerSlice >> values [
	^ values
]

{ #category : 'accessing' }
GcKvLayerSlice >> values: aCollection [
	values := aCollection
]
