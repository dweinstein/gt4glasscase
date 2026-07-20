"
A group of GcModelSource port instances (HF-agnostic: members may be ANY adapter -- HuggingFace, in-memory, ...). It makes several model sources COMPARABLE and answers domain questions across them: architecture facets (forwarding to GcArchitectureComparison), size & shape, where the parameter budget goes, which config knobs differ, and whether the checkpoints share a tensor-name vocabulary. Every comparison is a question-named <gtView> that reads ONLY already-cached metadata -- a render block NEVER performs network I/O (I5). Run 'Load metadata' (the <gtAction>) or send #loadMetadata once to fetch config.json + the safetensors header for each member; the views then compare what is cached and honestly show 'not loaded' for members without it. select:/reject: return GcModelSourceGroup and record their lineage (I3).
"
Class {
	#name : 'GcModelSourceGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'testing' }
GcModelSourceGroup >> anyLoadedConfig [
	^ self items anySatisfy: [ :aSource | aSource loadedConfig notNil ]
]

{ #category : 'testing' }
GcModelSourceGroup >> anyLoadedTensors [
	^ self items anySatisfy: [ :aSource | aSource loadedTensorGroup notNil ]
]

{ #category : 'comparing - architecture' }
GcModelSourceGroup >> architectureComparison [
	"A GcArchitectureComparison of the members' cached architectures (label -> architecture; nil for members not loaded). No network -- reads only cached configs."
	^ GcArchitectureComparison forAll: (self items collect: [ :aSource | aSource label -> aSource loadedArchitecture ])
]

{ #category : 'comparing - config' }
GcModelSourceGroup >> configDiffKeys [
	"The sorted raw config keys whose cached values differ across loaded members (empty when fewer than two configs are loaded to disagree)."
	| loaded |
	loaded := self items select: [ :aSource | aSource loadedConfig notNil ].
	loaded isEmpty ifTrue: [ ^ #() ].
	^ (self configKeyUnion asSortedCollection: [ :a :b | a < b ]) asArray
		select: [ :aKey | self configKeyDiffers: aKey among: loaded ]
]

{ #category : 'comparing - config' }
GcModelSourceGroup >> configDiffRows [
	"Rows for the config-diff view: a leading '(N identical keys)' summary, then one row per differing key. Each row is { keyText. per-member value strings. drill-in group }. Cached configs only."
	| loaded diffKeys rows |
	loaded := self items select: [ :aSource | aSource loadedConfig notNil ].
	loaded isEmpty ifTrue: [ ^ #() ].
	diffKeys := self configDiffKeys.
	rows := OrderedCollection new.
	rows add: { (self configKeyUnion size - diffKeys size) printString , ' identical keys'.
		(self items collect: [ :aSource | '' ]).
		self loadedSources }.
	diffKeys do: [ :aKey |
		rows add: { aKey.
			(self items collect: [ :aSource | self configValueDisplayOf: aSource at: aKey ]).
			self loadedSources } ].
	^ rows asArray
]

{ #category : 'comparing - size' }
GcModelSourceGroup >> configFacet: aBlock of: aSource [
	"Format a value read from aSource's cached architecture/config; 'not loaded' when no config is cached. No network."
	aSource loadedConfig ifNil: [ ^ 'not loaded' ].
	^ aBlock value ifNil: [ '—' ] ifNotNil: [ :v | v displayString ]
]

{ #category : 'comparing - config' }
GcModelSourceGroup >> configKeyDiffers: aKey among: loadedSourcesCollection [
	"True when the cached configs disagree on aKey (an absent key counts as a distinct value)."
	| absent values |
	absent := Object new.
	values := loadedSourcesCollection collect: [ :aSource |
		aSource loadedConfig rawJson at: aKey ifAbsent: [ absent ] ].
	^ values asSet size > 1
]

{ #category : 'comparing - config' }
GcModelSourceGroup >> configKeyUnion [
	"The set of all raw config keys across members whose config is cached."
	| keys |
	keys := Set new.
	self items do: [ :aSource |
		aSource loadedConfig ifNotNil: [ :aConfig | keys addAll: aConfig rawJson keys ] ].
	^ keys
]

{ #category : 'comparing - config' }
GcModelSourceGroup >> configValueDisplayOf: aSource at: aKey [
	| config |
	config := aSource loadedConfig.
	config ifNil: [ ^ 'not loaded' ].
	^ (config rawJson includesKey: aKey)
		ifTrue: [ (config rawJson at: aKey) displayString ]
		ifFalse: [ '—' ]
]

{ #category : 'views' }
GcModelSourceGroup >> gtArchitectureComparisonFor: aView [
	"How do these models' architectures line up, facet by facet? Forwards to GcArchitectureComparison over the CACHED configs only ('-' marks a member not loaded yet); differing facets are prefixed '<>'. No network."
	<gtView>
	self anyLoadedConfig ifFalse: [ ^ self placeholderView: aView title: 'Architecture' priority: 3 ].
	^ (self architectureComparison gtFacetGridFor: aView)
		title: 'Architecture';
		priority: 3;
		yourself
]

{ #category : 'views' }
GcModelSourceGroup >> gtConfigDiffFor: aView [
	"Which config knobs differ across these models? The union of raw config keys where cached values disagree, one column per model; identical keys collapse into a leading count. No network."
	<gtView>
	| list |
	self anyLoadedConfig ifFalse: [ ^ self placeholderView: aView title: 'Config diff' priority: 6 ].
	list := aView columnedList
		title: 'Config diff';
		priority: 6;
		items: [ self configDiffRows ];
		column: 'Key' text: [ :row | row first ];
		yourself.
	self items doWithIndex: [ :aSource :i |
		list column: aSource label text: [ :row | (row second) at: i ] ].
	list send: [ :row | row third ].
	^ list
]

{ #category : 'actions' }
GcModelSourceGroup >> gtLoadMetadataActionFor: anAction [
	"Fetch config.json + the safetensors header for each member over bounded HTTP, then refresh the views in place. The ONLY network path -- never invoked from a render block."
	<gtAction>
	^ anAction button
		label: 'Load metadata';
		tooltip: 'Fetch config.json + the safetensors header for each member, then refresh the comparison views';
		priority: 20;
		icon: BrGlamorousVectorIcons refresh;
		action: [ :aButton |
			[ self loadMetadata.
			  aButton enqueueTask: (BlTaskAction new action: [ aButton phlow fireViewUpdateWish ]) ]
				asAsyncFuture awaitWithUserBackgroundPriority ]
]

{ #category : 'views' }
GcModelSourceGroup >> gtModelsFor: aView [
	"Which models are in this group, and is each one's metadata loaded yet? Click a row to open the source."
	<gtView>
	^ aView columnedList
		title: 'Models';
		priority: 9;
		items: [ self items ];
		column: 'Model' text: [ :aSource | aSource label ];
		column: 'Type' text: [ :aSource | aSource loadedConfig ifNil: [ 'not loaded' ] ifNotNil: [ :aConfig | aConfig modelType ifNil: [ '—' ] ] ];
		column: 'Loaded' text: [ :aSource | aSource isMetadataLoaded ifTrue: [ 'yes' ] ifFalse: [ 'no' ] ];
		send: [ :aSource | aSource ]
]

{ #category : 'views' }
GcModelSourceGroup >> gtNamingSchemeFor: aView [
	"Do these checkpoints share a tensor-name vocabulary? Names shared by all loaded members, then each model's uniquely-named tensors, from cached headers. Click a row to open those tensors. No network."
	<gtView>
	self anyLoadedTensors ifFalse: [ ^ self placeholderView: aView title: 'Naming scheme' priority: 7 ].
	^ aView columnedList
		title: 'Naming scheme';
		priority: 7;
		items: [ self namingOverlapRows ];
		column: 'Scope' text: [ :row | row first ];
		column: 'Tensors' text: [ :row | (row second) printString ];
		send: [ :row | row third ]
]

{ #category : 'views' }
GcModelSourceGroup >> gtParamBudgetFor: aView [
	"Where does each model's parameter budget go -- attention vs MLP vs embeddings vs other? Percentages from cached tensor headers only. No network."
	<gtView>
	^ aView columnedList
		title: 'Param budget';
		priority: 5;
		items: [ self items ];
		column: 'Model' text: [ :aSource | aSource label ];
		column: 'Attention' text: [ :aSource | self paramShareText: #attention of: aSource ];
		column: 'MLP' text: [ :aSource | self paramShareText: #mlp of: aSource ];
		column: 'Embedding' text: [ :aSource | self paramShareText: #embedding of: aSource ];
		column: 'Other' text: [ :aSource | self paramShareOtherTextOf: aSource ];
		send: [ :aSource | aSource ]
]

{ #category : 'views' }
GcModelSourceGroup >> gtSizeAndShapeFor: aView [
	"How big is each model, and where does the budget go? One row per member from cached metadata; 'not loaded' where a member has none. No network."
	<gtView>
	^ aView columnedList
		title: 'Size & shape';
		priority: 4;
		items: [ self items ];
		column: 'Model' text: [ :aSource | aSource label ];
		column: 'Layers' text: [ :aSource | self configFacet: [ aSource loadedArchitecture numLayers ] of: aSource ];
		column: 'Hidden' text: [ :aSource | self configFacet: [ aSource loadedArchitecture hiddenSize ] of: aSource ];
		column: 'Heads' text: [ :aSource | self headsDisplayFor: aSource ];
		column: 'Vocab' text: [ :aSource | self configFacet: [ aSource loadedConfig vocabSize ] of: aSource ];
		column: 'Tensors' text: [ :aSource | self tensorFacet: [ aSource loadedTensorGroup size ] of: aSource ];
		column: 'Params' text: [ :aSource | self tensorFacet: [ aSource loadedTensorGroup totalParams ] of: aSource ];
		column: 'Bytes' text: [ :aSource | self tensorFacet: [ aSource loadedTensorGroup totalBytes ] of: aSource ];
		send: [ :aSource | aSource ]
]

{ #category : 'accessing' }
GcModelSourceGroup >> headline [
	^ self size printString , ' models (' , self loadedCount printString , ' loaded)'
]

{ #category : 'comparing - size' }
GcModelSourceGroup >> headsDisplayFor: aSource [
	"Attention-head summary: 'H/KV GQA' when grouped-query, else 'H MHA'. Cached config only."
	| arch h kv |
	aSource loadedConfig ifNil: [ ^ 'not loaded' ].
	arch := aSource loadedArchitecture.
	arch ifNil: [ ^ '—' ].
	h := arch numHeads.
	h ifNil: [ ^ '—' ].
	kv := arch kvHeads.
	(kv notNil and: [ kv < h ])
		ifTrue: [ ^ h printString , '/' , kv printString , ' GQA' ].
	^ h printString , ' MHA'
]

{ #category : 'loading' }
GcModelSourceGroup >> loadMetadata [
	"Fetch config.json + the safetensors header for EVERY member (bounded network). NOT called from a render block. Returns self."
	self items do: [ :aSource | aSource loadMetadata ].
	^ self
]

{ #category : 'accessing' }
GcModelSourceGroup >> loadedCount [
	^ self items count: [ :aSource | aSource isMetadataLoaded ]
]

{ #category : 'accessing' }
GcModelSourceGroup >> loadedSources [
	"A species-correct sub-group of the members whose metadata is cached -- safe to read from views. Lineage recorded (I3)."
	^ self withItems: (self items select: [ :aSource | aSource isMetadataLoaded ]) derivedBy: #loadedSources
]

{ #category : 'comparing - naming' }
GcModelSourceGroup >> namingOverlapRows [
	"Rows for the naming-scheme view: a shared-by-all summary then one per-model 'unique' row. Each row is { scopeText. tensorCount. drill-in GcTensorGroup }. Cached headers only."
	| loaded shared rows |
	loaded := self items select: [ :aSource | aSource loadedTensorGroup notNil ].
	loaded isEmpty ifTrue: [ ^ #() ].
	shared := self sharedTensorNames.
	rows := OrderedCollection new.
	rows add: { 'shared by all ' , loaded size printString , ' loaded'.
		shared size.
		(self tensorsNamed: shared in: loaded first) }.
	loaded do: [ :aSource | | unique |
		unique := self uniqueTensorNamesFor: aSource among: loaded.
		rows add: { aSource label , ' unique (of ' , aSource loadedTensorGroup size printString , ')'.
			unique size.
			(self tensorsNamed: unique in: aSource) } ].
	^ rows asArray
]

{ #category : 'comparing - budget' }
GcModelSourceGroup >> paramShareOf: aSource [
	"Dictionary of tensor-block -> fraction of total parameters, from cached tensor headers; nil if the source has no cached header or zero params. No network."
	| tg total counts fractions |
	tg := aSource loadedTensorGroup.
	tg ifNil: [ ^ nil ].
	total := tg totalParams.
	total = 0 ifTrue: [ ^ nil ].
	counts := Dictionary new.
	tg do: [ :t | | b |
		b := t parsedName block.
		counts at: b put: (counts at: b ifAbsent: [ 0 ]) + t paramCount ].
	fractions := Dictionary new.
	counts keysAndValuesDo: [ :k :v | fractions at: k put: v / total ].
	^ fractions
]

{ #category : 'comparing - budget' }
GcModelSourceGroup >> paramShareOtherTextOf: aSource [
	"Combined share of everything outside attention/MLP/embedding (norms and any other tensors)."
	| shares other |
	aSource loadedTensorGroup ifNil: [ ^ 'not loaded' ].
	shares := self paramShareOf: aSource.
	shares ifNil: [ ^ '—' ].
	other := shares keys inject: 0 into: [ :sum :k |
		(#(attention mlp embedding) includes: k) ifTrue: [ sum ] ifFalse: [ sum + (shares at: k) ] ].
	^ self percentText: other
]

{ #category : 'comparing - budget' }
GcModelSourceGroup >> paramShareText: aBlockKey of: aSource [
	| shares |
	aSource loadedTensorGroup ifNil: [ ^ 'not loaded' ].
	shares := self paramShareOf: aSource.
	shares ifNil: [ ^ '—' ].
	^ self percentText: (shares at: aBlockKey ifAbsent: [ 0 ])
]

{ #category : 'comparing - budget' }
GcModelSourceGroup >> percentText: aFraction [
	^ ((aFraction asFloat * 100) printShowingDecimalPlaces: 1) , '%'
]

{ #category : 'views - support' }
GcModelSourceGroup >> placeholderView: aView title: aTitle priority: anInteger [
	"A non-empty, error-free stand-in shown when no member has the metadata a comparison needs yet."
	^ aView columnedList
		title: aTitle;
		priority: anInteger;
		items: [ { 'No member metadata loaded yet -- run the ''Load metadata'' action.' } ];
		column: 'Status' text: [ :each | each ]
]

{ #category : 'comparing - naming' }
GcModelSourceGroup >> sharedTensorNames [
	"Tensor names present in EVERY loaded member's cached header (empty when none are loaded)."
	| loaded |
	loaded := self items select: [ :aSource | aSource loadedTensorGroup notNil ].
	loaded isEmpty ifTrue: [ ^ Set new ].
	^ loaded
		inject: (self tensorNameSetOf: loaded first)
		into: [ :acc :aSource | acc select: [ :n | (self tensorNameSetOf: aSource) includes: n ] ]
]

{ #category : 'accessing' }
GcModelSourceGroup >> statistics [
	"Item count plus how many members currently have cached metadata (safe to read from views)."
	^ Dictionary new
		at: #count put: self size;
		at: #loaded put: self loadedCount;
		yourself
]

{ #category : 'comparing - size' }
GcModelSourceGroup >> tensorFacet: aBlock of: aSource [
	"Format a value read from aSource's cached tensor header; 'not loaded' when no header is cached. No network."
	aSource loadedTensorGroup ifNil: [ ^ 'not loaded' ].
	^ aBlock value ifNil: [ '—' ] ifNotNil: [ :v | v displayString ]
]

{ #category : 'comparing - naming' }
GcModelSourceGroup >> tensorNameSetOf: aSource [
	"The set of tensor names in aSource's cached header (empty if not loaded). No network."
	^ aSource loadedTensorGroup
		ifNil: [ Set new ]
		ifNotNil: [ :tg | tg collect: [ :t | t name ] as: Set ]
]

{ #category : 'comparing - naming' }
GcModelSourceGroup >> tensorsNamed: aSetOfNames in: aSource [
	"A GcTensorGroup of aSource's cached tensors whose names are in aSetOfNames -- the naming view's drill-in target."
	| tg |
	tg := aSource loadedTensorGroup.
	tg ifNil: [ ^ GcTensorGroup new ].
	^ tg select: [ :t | aSetOfNames includes: t name ]
]

{ #category : 'comparing - naming' }
GcModelSourceGroup >> uniqueTensorNamesFor: aSource among: loadedSourcesCollection [
	"Names in aSource's cached header not present in any OTHER loaded member."
	| mine others |
	mine := self tensorNameSetOf: aSource.
	others := loadedSourcesCollection reject: [ :each | each == aSource ].
	^ mine reject: [ :n | others anySatisfy: [ :o | (self tensorNameSetOf: o) includes: n ] ]
]
