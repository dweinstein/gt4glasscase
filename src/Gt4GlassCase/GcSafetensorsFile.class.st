"
One safetensors shard. Lazy header parse: 8-byte little-endian length + JSON header (tensor name -> dtype/shape/offsets), then the raw buffer. Holds refs, never the bytes (I5).
"
Class {
	#name : 'GcSafetensorsFile',
	#superclass : 'Object',
	#instVars : [
		'path',
		'header',
		'tensors',
		'byteDataOffset',
		'bytesProvider'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'parsing' }
GcSafetensorsFile >> buildTensors [
	tensors := OrderedCollection new.
	header keysAndValuesDo: [ :tensorName :info |
		tensorName = '__metadata__' ifFalse: [
			| offsets ref |
			offsets := info at: 'data_offsets'.
			ref := GcTensorRef
				name: tensorName
				dtype: (info at: 'dtype') asLowercase asSymbol
				shape: (info at: 'shape') asArray.
			ref beginOffset: (offsets at: 1).
			ref endOffset: (offsets at: 2).
			ref file: self.
			tensors add: ref ] ]
]

{ #category : 'accessing' }
GcSafetensorsFile >> byteDataOffset [
	"Absolute offset (8 + header length) where tensor data begins. Lazily obtained from the bytes provider when not set directly (hermetic tests set it via byteDataOffset:)."
	^ byteDataOffset ifNil: [
		byteDataOffset := bytesProvider ifNotNil: [ :p | p provideByteDataOffset ] ]
]

{ #category : 'accessing' }
GcSafetensorsFile >> byteDataOffset: anInteger [
	byteDataOffset := anInteger
]

{ #category : 'slack space' }
GcSafetensorsFile >> byteSegments [
	| segments startOf |
	startOf := [ :segment |
		(segment isKindOf: GcSlackRange)
			ifTrue: [ segment start ]
			ifFalse: [ segment beginOffset ] ].
	segments := OrderedCollection new.
	segments addAll: self sortedTensorExtents.
	segments addAll: self slackRanges.
	^ (segments asSortedCollection: [ :a :b | (startOf value: a) <= (startOf value: b) ]) asArray
]

{ #category : 'bytes port' }
GcSafetensorsFile >> bytesFrom: startAbs to: endAbs [
	"Absolute, inclusive byte range from the wired provider. The core never knows the transport."
	bytesProvider isNil ifTrue: [ ^ self error: 'No bytes provider wired on this safetensors file' ].
	^ bytesProvider provideBytesFrom: startAbs to: endAbs
]

{ #category : 'bytes port' }
GcSafetensorsFile >> bytesProvider [
	^ bytesProvider
]

{ #category : 'bytes port' }
GcSafetensorsFile >> bytesProvider: anObject [
	"An adapter-supplied object answering provideBytesFrom:to: and provideByteDataOffset. Keeps the core transport-free (hexagonal)."
	bytesProvider := anObject
]

{ #category : 'accessing' }
GcSafetensorsFile >> fileName [
	"The bare file name (last path segment) -- provenance for a tensor's owning shard (I14)."
	^ path
		ifNil: [ '?' ]
		ifNotNil: [
			(path includes: $/)
				ifTrue: [ path copyAfterLast: $/ ]
				ifFalse: [ path ] ]
]

{ #category : 'gt - search' }
GcSafetensorsFile >> gtSearchTensorsFor: aSearch [
	"Find a tensor by name substring straight from the file inspector (e.g. type q_proj)."
	<gtSearch>
	^ aSearch list
		title: 'Tensors';
		priority: 10;
		items: [ self tensors ];
		itemName: [ :t | t name ];
		filterBySubstring
]

{ #category : 'gt views' }
GcSafetensorsFile >> gtShardsFor: aView [
	"A single-file model is one shard. (GcShardedSafetensorsFile overrides with the real per-shard breakdown.)"
	<gtView>
	^ aView columnedList
		title: 'Shards';
		priority: 6;
		items: [ self shards ];
		column: 'Shard' text: [ :shard | shard fileName ];
		column: 'Tensors' text: [ :shard | shard tensorCount ];
		column: 'Bytes' text: [ :shard | shard totalTensorBytes ];
		send: [ :shard | shard ]
]

{ #category : 'views' }
GcSafetensorsFile >> gtSkylineFor: aView [
	"The model skyline (forwarded to the tensor group)."
	<gtView>
	^ aView forward
		title: 'Skyline';
		priority: 3;
		object: [ self tensorGroup ];
		view: #gtSkylineFor:
]

{ #category : 'views' }
GcSafetensorsFile >> gtSlackMapFor: aView [
	<gtView>
	"Are there byte ranges in this shard claimed by no tensor - gaps, overlaps, or trailing slack? Wrapped rows read like a defragmenter byte map: blue = tensor, red = gap, dark purple = overlap."
	^ aView mondrian
		title: 'Slack map';
		priority: 8;
		painting: [ :m |
			| totalSpan extents |
			extents := self sortedTensorExtents.
			totalSpan := extents isEmpty
				ifTrue: [ 1 ]
				ifFalse: [ extents last endOffset max: 1 ].
			m nodes
				stencil: [ :segment |
					| width color |
					width := ((segment byteSize / totalSpan) * 900) rounded max: 2.
					color := (segment isKindOf: GcSlackRange)
						ifTrue: [
							segment kind = #gap
								ifTrue: [ Color r: 0.85 g: 0.25 b: 0.2 ]
								ifFalse: [ Color r: 0.5 g: 0.15 b: 0.5 ] ]
						ifFalse: [ Color r: 0.55 g: 0.65 b: 0.8 ].
					BlElement new
						background: color;
						size: width @ 22;
						yourself ];
				with: self byteSegments.
			m layout grid ]
]

{ #category : 'gt views' }
GcSafetensorsFile >> gtSlackRangesFor: aView [
	<gtView>
	"Are there byte ranges in this shard claimed by no tensor - gaps, overlaps, or trailing slack? Exact byte offsets and sizes for each unclaimed range."
	^ aView columnedList
		title: 'Slack ranges';
		priority: 9;
		items: [
			self slackRanges isEmpty
				ifTrue: [
					{ {'no unclaimed bytes'.
						'all ' , self tensorCount printString , ' tensors tile the data area exactly'.
						self} } ]
				ifFalse: [
					self slackRanges collect: [ :range |
						{range kind asString. range printString. range} ] ] ];
		column: 'Status' text: [ :row | row at: 1 ];
		column: 'Detail' text: [ :row | row at: 2 ];
		send: [ :row | row at: 3 ]
]

{ #category : 'views' }
GcSafetensorsFile >> gtSummaryFor: aView [
	"What does this safetensors file contain, overall? Clicking 'Tensors' navigates into the tensor group."
	<gtView>
	^ aView columnedList
		title: 'Summary';
		priority: 1;
		items: [ self summaryFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | (v isCollection and: [ v isString not ]) ifTrue: [ v printString ] ifFalse: [ v displayString ] ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'views' }
GcSafetensorsFile >> gtTensorsFor: aView [
	"The tensors themselves, as a shape table (composed from the tensor group)."
	<gtView>
	^ aView forward
		title: 'Tensors';
		priority: 2;
		object: [ self tensorGroup ];
		view: #gtShapeTableFor:
]

{ #category : 'views' }
GcSafetensorsFile >> gtTreeFor: aView [
	"The tensor-name hierarchy (HuggingFace-style file tree)."
	<gtView>
	^ aView forward
		title: 'Tree';
		priority: 2;
		object: [ self tensorTree ];
		view: #gtTreeFor:
]

{ #category : 'gt - actions' }
GcSafetensorsFile >> gtWarmSkylineActionFor: anAction [
	"Sample one bounded cohort so the forwarded skyline stops being all-grey, then refresh the view in place."
	<gtAction>
	^ anAction button
		tooltip: 'Sample the cheapest per-layer cohort''s stats over bounded HTTP Range fetches, then recolour the skyline';
		priority: 30;
		icon: BrGlamorousVectorIcons refresh;
		action: [ :aButton |
			[ self tensorGroup warmDefaultCohort.
			  aButton enqueueTask: (BlTaskAction new action: [ aButton phlow fireViewUpdateWish ]) ]
				asAsyncFuture awaitWithUserBackgroundPriority ]
]

{ #category : 'bytes port' }
GcSafetensorsFile >> hasBytesProvider [
	^ bytesProvider notNil
]

{ #category : 'accessing' }
GcSafetensorsFile >> header [
	^ header
]

{ #category : 'parsing' }
GcSafetensorsFile >> parseHeaderDictionary: aDictionary [
	"Build GcTensorRefs from an already-parsed safetensors header (a plain Dictionary of name -> {dtype, shape, data_offsets}). Generic: no coupling to any transport."
	header := aDictionary.
	self buildTensors.
	^ self
]

{ #category : 'parsing' }
GcSafetensorsFile >> parseHeaderString: aJsonString [
	^ self parseHeaderDictionary: (STONJSON fromString: aJsonString)
]

{ #category : 'accessing' }
GcSafetensorsFile >> path [
	^ path
]

{ #category : 'accessing' }
GcSafetensorsFile >> path: aPathObject [
	path := aPathObject
]

{ #category : 'printing' }
GcSafetensorsFile >> printOn: aStream [
	| src |
	src := self sourcePath.
	aStream nextPutAll: 'GcSafetensorsFile('.
	aStream nextPutAll: (src ifNil: [ '?' ] ifNotNil: [ :p | p asFileReference basename ]).
	aStream nextPutAll: ', '.
	aStream print: self tensorCount.
	aStream nextPutAll: ' tensors)'
]

{ #category : 'accessing' }
GcSafetensorsFile >> shards [
	"A single-file model is one shard: itself. Lets the 'Shards' view be uniform across single-file and sharded models."
	^ { self }
]

{ #category : 'slack space' }
GcSafetensorsFile >> slackRanges [
	"Walks tensor extents in offset order accumulating gaps and overlaps. Trailing slack after the last tensor is not computable from metadata alone - the total file size is unknown here - so it is not reported."
	| cursor result |
	cursor := 0.
	result := OrderedCollection new.
	self sortedTensorExtents do: [ :tensor |
		tensor beginOffset > cursor
			ifTrue: [ result add: (GcSlackRange kind: #gap start: cursor end: tensor beginOffset) ].
		tensor beginOffset < cursor
			ifTrue: [ result add: (GcSlackRange kind: #overlap start: tensor beginOffset end: (cursor min: tensor endOffset)) ].
		cursor := cursor max: tensor endOffset ].
	^ result
]

{ #category : 'slack space' }
GcSafetensorsFile >> sortedTensorExtents [
	^ (((tensors ifNil: [ #() ]) select: [ :each | each beginOffset notNil and: [ each endOffset notNil ] ])
		asSortedCollection: [ :a :b | a beginOffset <= b beginOffset ]) asArray
]

{ #category : 'accessing' }
GcSafetensorsFile >> sourcePath [
	"The file's identifying path: the explicitly-set path if any, else derived from the bytes provider (single source of truth). May be a FileReference, a String, or nil (e.g. an in-memory provider)."
	^ path ifNil: [ (bytesProvider notNil and: [ bytesProvider respondsTo: #path ])
		ifTrue: [ bytesProvider path ]
		ifFalse: [ nil ] ]
]

{ #category : 'views' }
GcSafetensorsFile >> summaryFacets [
	| group |
	group := self tensorGroup.
	^ {
		'Path' -> path.
		'Tensors' -> group.
		'Total params' -> group totalParams.
		'Total bytes' -> group totalBytes.
		'Layers' -> group layerIndices size.
		'Modules' -> group byModule size.
		'Dtypes' -> ((self tensors collect: [ :t | t dtype ]) asSet asSortedCollection asArray) }
]

{ #category : 'querying' }
GcSafetensorsFile >> tensorCount [
	^ self tensors size
]

{ #category : 'converting' }
GcSafetensorsFile >> tensorGroup [
	"A GcTensorGroup wrapping every tensor in this file -- ready for partitionBy:, statistics, etc."
	^ GcTensorGroup withAll: self tensors
]

{ #category : 'converting' }
GcSafetensorsFile >> tensorTree [
	^ self tensorGroup asTensorTree
]

{ #category : 'accessing' }
GcSafetensorsFile >> tensors [
	^ tensors ifNil: [ tensors := OrderedCollection new ]
]

{ #category : 'querying' }
GcSafetensorsFile >> totalTensorBytes [
	^ self tensors inject: 0 into: [ :sum :t | sum + t byteSize ]
]
