"
A multi-shard safetensors model presented as ONE thing the tensor views consume. Holds an ordered list of per-shard GcSafetensorsFiles; its `tensors` is the union of every shard's GcTensorRefs, and CRUCIALLY each GcTensorRef keeps its OWN shard file as its `file`, so per-tensor byte sampling (GcTensorRef>>sampleSlice / sliceFromElement:count:) routes each read to the correct shard's URL at that shard's byteDataOffset (I5 + correctness). Assembled from a safetensors index weight_map, whose UNIQUE VALUES are the authoritative shard list -- naming-agnostic (handles asymmetric padding, 0-based numbering, odd stems like model.safetensors-00001-of-.., unnumbered MTP extras, and the single-literal-file case). Never holds weights (I5).
"
Class {
	#name : 'GcShardedSafetensorsFile',
	#superclass : 'Object',
	#instVars : [
		'path',
		'shards',
		'metadata',
		'tensors'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'index' }
GcShardedSafetensorsFile class >> distinctShardNamesFrom: aWeightMap [
	"The unique shard file names named by a safetensors index weight_map, in stable sorted order. NEVER assumes a naming pattern, start index, padding, or that 'index exists => multiple files'. Sorting (rather than first-appearance) is used because JSON object key order is not preserved by the parser."
	^ aWeightMap values asSet asSortedCollection asArray
]

{ #category : 'instance creation' }
GcShardedSafetensorsFile class >> fromWeightMap: aWeightMap metadata: aMetadataOrNil path: aPath shardBuilder: aBlock [
	"Assemble a sharded union from a safetensors index weight_map (tensorName -> shardFile). The authoritative shard list is the UNIQUE VALUES of the weight_map, in stable sorted order -- naming-agnostic (asymmetric padding, 0-based, odd stems, MTP extras, single-literal-file). aBlock maps each distinct shard file name to a GcSafetensorsFile (over HTTP in the adapter, in-memory in tests)."
	| shardNames shards |
	shardNames := self distinctShardNamesFrom: aWeightMap.
	shards := shardNames collect: [ :fileName | aBlock value: fileName ].
	^ self path: aPath shards: shards metadata: aMetadataOrNil
]

{ #category : 'instance creation' }
GcShardedSafetensorsFile class >> path: aPath shards: aShardCollection metadata: aMetadataOrNil [
	^ self new setPath: aPath shards: aShardCollection metadata: aMetadataOrNil
]

{ #category : 'index' }
GcShardedSafetensorsFile class >> signalNoSafetensorsForRepository: aRepoId filesPresent: aFileNameCollection [
	"Neither model.safetensors nor model.safetensors.index.json exists. Raise a clear domain error that names the safetensors-ish files actually present, or states the repo has no safetensors weights."
	| safetensorsish |
	safetensorsish := (aFileNameCollection select: [ :each | each endsWith: '.safetensors' ]) asSortedCollection asArray.
	safetensorsish isEmpty ifTrue: [
		^ Error signal: 'No safetensors weights for ' , aRepoId , ' (no model.safetensors and no model.safetensors.index.json -- repo is likely GGUF/pytorch-only)' ].
	^ Error signal: 'No model.safetensors and no model.safetensors.index.json for ' , aRepoId , '; safetensors-ish files present but not a recognised entry point: ' , (', ' join: safetensorsish)
]

{ #category : 'gt search' }
GcShardedSafetensorsFile >> gtSearchTensorsFor: aSearch [
	"Find a tensor by name substring straight from the union inspector (searches across all shards)."
	<gtSearch>
	^ aSearch list
		title: 'Tensors';
		priority: 10;
		items: [ self tensors ];
		itemName: [ :t | t name ];
		filterBySubstring
]

{ #category : 'gt views' }
GcShardedSafetensorsFile >> gtShardsFor: aView [
	"One row per physical shard file. Each tensor of the model lives in exactly one of these, and its byte reads route to that shard's URL/offset. Click a row to open the shard's own GcSafetensorsFile (its tensors, tree, skyline)."
	<gtView>
	^ aView columnedList
		title: 'Shards';
		priority: 2;
		items: [ self shards ];
		column: 'Shard' text: [ :shard | shard fileName ];
		column: 'Tensors' text: [ :shard | shard tensorCount ];
		column: 'Bytes' text: [ :shard | shard totalTensorBytes ];
		column: 'Dtypes' text: [ :shard | ', ' join: ((shard tensors collect: [ :t | t dtype asString ]) asSet asSortedCollection asArray) ];
		send: [ :shard | shard ]
]

{ #category : 'gt views' }
GcShardedSafetensorsFile >> gtSkylineFor: aView [
	"The model skyline over the whole sharded union (forwarded to the tensor group)."
	<gtView>
	^ aView forward
		title: 'Skyline';
		priority: 5;
		object: [ self tensorGroup ];
		view: #gtSkylineFor:
]

{ #category : 'gt views' }
GcShardedSafetensorsFile >> gtSummaryFor: aView [
	"What does this sharded model contain, overall? Clicking a value navigates into it (Tensors -> the group)."
	<gtView>
	^ aView columnedList
		title: 'Summary';
		priority: 1;
		items: [ self summaryFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value ifNil: [ '-' ] ifNotNil: [ :v | (v isCollection and: [ v isString not ]) ifTrue: [ v printString ] ifFalse: [ v displayString ] ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt views' }
GcShardedSafetensorsFile >> gtTensorsFor: aView [
	"Every tensor across all shards, as a shape table (composed from the union tensor group)."
	<gtView>
	^ aView forward
		title: 'Tensors';
		priority: 3;
		object: [ self tensorGroup ];
		view: #gtShapeTableFor:
]

{ #category : 'gt views' }
GcShardedSafetensorsFile >> gtTreeFor: aView [
	"The tensor-name hierarchy across all shards (HuggingFace-style file tree)."
	<gtView>
	^ aView forward
		title: 'Tree';
		priority: 4;
		object: [ self tensorTree ];
		view: #gtTreeFor:
]

{ #category : 'accessing' }
GcShardedSafetensorsFile >> metadata [
	"The parsed `metadata` section of the safetensors index (e.g. total_size), or nil."
	^ metadata
]

{ #category : 'accessing' }
GcShardedSafetensorsFile >> path [
	^ path
]

{ #category : 'printing' }
GcShardedSafetensorsFile >> printOn: aStream [
	aStream nextPutAll: 'GcShardedSafetensorsFile('.
	aStream nextPutAll: (path ifNil: [ '?' ]).
	aStream nextPutAll: ', '.
	aStream print: self shardCount.
	aStream nextPutAll: ' shards, '.
	aStream print: self tensorCount.
	aStream nextPutAll: ' tensors)'
]

{ #category : 'initialization' }
GcShardedSafetensorsFile >> setPath: aPath shards: aShardCollection metadata: aMetadataOrNil [
	path := aPath.
	shards := aShardCollection asOrderedCollection.
	metadata := aMetadataOrNil
]

{ #category : 'accessing' }
GcShardedSafetensorsFile >> shardCount [
	^ self shards size
]

{ #category : 'accessing' }
GcShardedSafetensorsFile >> shards [
	^ shards ifNil: [ shards := OrderedCollection new ]
]

{ #category : 'accessing' }
GcShardedSafetensorsFile >> summaryFacets [
	| group |
	group := self tensorGroup.
	^ {
		'Path' -> path.
		'Shards' -> self shardCount.
		'Tensors' -> group.
		'Total params' -> group totalParams.
		'Total bytes' -> group totalBytes.
		'Index total_size' -> (metadata ifNil: [ nil ] ifNotNil: [ :m | m at: 'total_size' ifAbsent: [ nil ] ]).
		'Layers' -> group layerIndices size.
		'Modules' -> group byModule size.
		'Dtypes' -> ((self tensors collect: [ :t | t dtype ]) asSet asSortedCollection asArray) }
]

{ #category : 'accessing' }
GcShardedSafetensorsFile >> tensorCount [
	^ self tensors size
]

{ #category : 'querying' }
GcShardedSafetensorsFile >> tensorGroup [
	"A GcTensorGroup wrapping every tensor across all shards -- ready for partitionBy:, statistics, skyline, etc. Plug-compatible with GcSafetensorsFile>>tensorGroup."
	^ GcTensorGroup withAll: self tensors
]

{ #category : 'querying' }
GcShardedSafetensorsFile >> tensorTree [
	^ self tensorGroup asTensorTree
]

{ #category : 'accessing' }
GcShardedSafetensorsFile >> tensors [
	"The union of every shard's GcTensorRefs. Each ref keeps its OWN shard file as its `file`, so per-tensor byte sampling routes to the correct shard (byteDataOffset + provider)."
	^ tensors ifNil: [
		tensors := OrderedCollection new.
		self shards do: [ :aShard | tensors addAll: aShard tensors ].
		tensors ]
]

{ #category : 'accessing' }
GcShardedSafetensorsFile >> totalTensorBytes [
	^ self tensors inject: 0 into: [ :sum :t | sum + t byteSize ]
]
