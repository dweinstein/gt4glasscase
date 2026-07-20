"
A group of GcTensorRefs. Signature views: shape table, aggregate distribution, spectrum overlay, delta heatmap.
"
Class {
	#name : 'GcTensorGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'computing' }
GcTensorGroup >> aggregateHistogramBins: aCount [
	"An aCount-bin histogram merged from the cached per-tensor histograms of every sampled tensor (from cached stats only, never fetches). Empty when nothing is sampled."
	^ self mergeHistograms: (self sampledStatsTensors collect: [ :t | t cachedStats histogram ]) binCount: aCount
]

{ #category : 'converting' }
GcTensorGroup >> asTensorTree [
	"Build the tensor-name hierarchy (root GcTensorTreeNode) by splitting each tensor's dotted name."
	| root |
	root := GcTensorTreeNode named: '' path: ''.
	self items do: [ :aTensor |
		| node parts prefix |
		node := root.
		parts := aTensor name substrings: '.'.
		prefix := ''.
		parts doWithIndex: [ :seg :i |
			prefix := prefix isEmpty ifTrue: [ seg ] ifFalse: [ prefix, '.', seg ].
			i = parts size
				ifTrue: [ node addChild: (GcTensorTreeNode named: seg path: prefix tensor: aTensor) ]
				ifFalse: [ node := node childNamed: seg ifAbsentAddPath: prefix ] ] ].
	^ root
]

{ #category : 'grouping' }
GcTensorGroup >> byLayer [
	^ self partitionBy: [ :t | t layerIndex ]
]

{ #category : 'grouping' }
GcTensorGroup >> byModule [
	^ self partitionBy: [ :t | t module ]
]

{ #category : 'regularity' }
GcTensorGroup >> cohortKeyFor: aTensor [
	"The cohort a tensor belongs to for regularity: same module and role across every layer (e.g. all q_proj.weight)."
	| pn |
	pn := aTensor parsedName.
	^ (pn module ifNil: [ '?' ]) , ' | ' , (pn role ifNil: [ '?' ])
]

{ #category : 'regularity' }
GcTensorGroup >> defaultWarmModule [
	"The cheapest real (per-layer) cohort to sample: among sampleable transformer-layer tensors, the module whose tensors carry the least total bytes (typically a layernorm). nil if nothing is sampleable."
	| candidates totals |
	candidates := self items select: [ :t | t supportsSampling and: [ t layerIndex notNil ] ].
	candidates isEmpty ifTrue: [ ^ nil ].
	totals := Dictionary new.
	candidates do: [ :t |
		totals at: t module put: (t byteSize + (totals at: t module ifAbsent: [ 0 ])) ].
	^ (totals associations detectMin: [ :assoc | assoc value ]) key
]

{ #category : 'gt - views' }
GcTensorGroup >> emptyDistributionElement [
	"Placeholder shown when no tensor in the group has cached stats yet."
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
		padding: (BlInsets all: 10);
		addChild: (BrLabel new aptitude: BrGlamorousLabelAptitude; text: 'no sampled stats yet -- run the warm-up action'; yourself);
		yourself
]

{ #category : 'gt - views' }
GcTensorGroup >> gtAggregateDistributionFor: aView [
	"What is the pooled value distribution across this group's sampled tensors? A horizontal-bar histogram merged from the cached per-tensor histograms (from cached stats only), labelled with how many tensors contributed. Empty until a warm-up runs."
	<gtView>
	^ aView explicit
		title: 'Aggregate distribution';
		priority: 4;
		stencil: [ | bins sampled total |
			sampled := self sampledStatsTensors size.
			total := self size.
			bins := self aggregateHistogramBins: 40.
			bins isEmpty
				ifTrue: [ self emptyDistributionElement ]
				ifFalse: [ GcHistogramBin barChartElementFor: bins subtitle: 'distribution over ' , sampled printString , '/' , total printString , ' sampled tensors' ] ]
]

{ #category : 'views' }
GcTensorGroup >> gtByLayerFor: aView [
	"How does parameter mass vary with depth? Clicking a row opens that layer's tensor sub-group."
	<gtView>
	^ aView columnedList
		title: 'By layer';
		priority: 7;
		items: [ self layerSummaries ];
		column: 'Layer' text: [ :assoc | assoc key isNil ifTrue: [ '(non-layer)' ] ifFalse: [ assoc key printString ] ];
		column: 'Tensors' text: [ :assoc | assoc value size printString ];
		column: 'Params' text: [ :assoc | assoc value totalParams printString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'views' }
GcTensorGroup >> gtByModuleFor: aView [
	"How is parameter mass distributed across module types? Clicking a row opens that module's tensor sub-group."
	<gtView>
	^ aView columnedList
		title: 'By module';
		priority: 6;
		items: [ self moduleSummaries ];
		column: 'Module' text: [ :assoc | assoc key ];
		column: 'Tensors' text: [ :assoc | assoc value size printString ];
		column: 'Params' text: [ :assoc | assoc value totalParams printString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt search' }
GcTensorGroup >> gtSearchTensorsFor: aSearch [
	<gtSearch>
	^ aSearch list
		title: 'Tensors';
		priority: 10;
		items: [ self items ];
		itemName: [ :t | t name ];
		filterBySubstring
]

{ #category : 'gt - views' }
GcTensorGroup >> gtShapeTableFor: aView [
	"The workhorse tensor list: every tensor with its structural facts and its regularity z-score against its (module,role) cohort, ordered by |z| descending so anomalies surface first. Click a row to inspect the tensor."
	<gtView>
	^ aView columnedList
		title: 'Tensors';
		priority: 5;
		items: [ (self regularityScores values asSortedCollection: [ :a :b | a absZ > b absZ ]) asArray ];
		column: 'Name' text: [ :s | s tensor name ];
		column: 'Layer' text: [ :s | s tensor layerIndex ifNil: [ '—' ] ifNotNil: [ :i | i printString ] ];
		column: 'Module' text: [ :s | s tensor module ifNil: [ '—' ] ];
		column: 'Dtype' text: [ :s | s tensor dtype asString ];
		column: 'Shape' text: [ :s | s tensor shape ifNil: [ '—' ] ifNotNil: [ :sh | sh printString ] ];
		column: 'Params' text: [ :s | s tensor paramCount printString ];
		column: 'Bytes' text: [ :s | s tensor byteSize printString ];
		column: 'z' text: [ :s | s zDisplayString ];
		send: [ :s | s tensor ]
]

{ #category : 'gt - views' }
GcTensorGroup >> gtSkylineFor: aView [
	"Does this model's structure deviate from its own internal regularity? One row per depth (embeddings band, transformer layers by index, head/final band); each tensor is a box sized by sqrt(byte size) and coloured by the |z| of its metric within its (module,role) cohort. A normal transformer is boringly uniform, so anything hot or oddly sized breaks the texture at a glance. Click a box to inspect the tensor, a row to open the layer. Colour needs sampled values: use the warm-up action, otherwise everything reads grey (structural only)."
	<gtView>
	^ aView mondrian
		title: 'Skyline';
		priority: 3;
		painting: [ :m | self paintSkylineOn: m ]
]

{ #category : 'views' }
GcTensorGroup >> gtTreeFor: aView [
	"The tensor-name hierarchy (forwarded to the tree root)."
	<gtView>
	^ aView forward
		title: 'Tree';
		priority: 4;
		object: [ self asTensorTree ];
		view: #gtTreeFor:
]

{ #category : 'gt - actions' }
GcTensorGroup >> gtWarmSkylineActionFor: anAction [
	"Sample one bounded cohort so the skyline stops being all-grey, then refresh the view in place."
	<gtAction>
	^ anAction button
		tooltip: 'Sample the cheapest per-layer cohort''s stats over bounded HTTP Range fetches, then recolour the skyline';
		priority: 30;
		icon: BrGlamorousVectorIcons refresh;
		action: [ :aButton |
			[ self warmDefaultCohort.
			  aButton enqueueTask: (BlTaskAction new action: [ aButton phlow fireViewUpdateWish ]) ]
				asAsyncFuture awaitWithUserBackgroundPriority ]
]

{ #category : 'accessing' }
GcTensorGroup >> headline [
	"The salient number for a tensor group is its total parameter count."
	^ self totalParams printString , ' params'
]

{ #category : 'grouping' }
GcTensorGroup >> layerIndices [
	^ (((self collect: [ :t | t layerIndex ]) reject: [ :x | x isNil ]) asSet) asSortedCollection asArray
]

{ #category : 'views' }
GcTensorGroup >> layerSummaries [
	^ ((self groupedBy: [ :t | t layerIndex ]) associations
		asSortedCollection: [ :a :b | (a key ifNil: [ -1 ]) < (b key ifNil: [ -1 ]) ]) asArray
]

{ #category : 'accessing' }
GcTensorGroup >> layers [
	"This group's tensors organised into ordered per-depth GcLayers: an embeddings band (if any), the transformer layers in ascending index order, then a head/final band (if any). Each GcLayer carries a back-reference to this group so it can compute cohort regularity."
	| byIndex realLayers ordered nonLayer embeds heads |
	byIndex := self groupedBy: [ :t | t layerIndex ].
	realLayers := ((byIndex keys reject: [ :k | k isNil ]) asSortedCollection asArray)
		collect: [ :idx | GcLayer index: idx tensors: (byIndex at: idx) modelGroup: self ].
	nonLayer := byIndex at: nil ifAbsent: [ nil ].
	embeds := nonLayer isNil
		ifTrue: [ #() ]
		ifFalse: [ nonLayer items select: [ :t | t parsedName block = #embedding ] ].
	heads := nonLayer isNil
		ifTrue: [ #() ]
		ifFalse: [ nonLayer items reject: [ :t | t parsedName block = #embedding ] ].
	ordered := OrderedCollection new.
	embeds isEmpty ifFalse: [ ordered add: (GcLayer index: nil tensors: embeds modelGroup: self) ].
	ordered addAll: realLayers.
	heads isEmpty ifFalse: [ ordered add: (GcLayer index: nil tensors: heads modelGroup: self) ].
	^ GcLayerGroup withAll: ordered
]

{ #category : 'computing' }
GcTensorGroup >> mergeHistograms: aHistograms binCount: aCount [
	"Merge several per-tensor bin-lists into a single aCount-bin histogram over the pooled value range, re-binning each source bar into the merged bin that contains its midpoint. Total count is preserved. Returns an empty array when there is nothing to merge."
	| histos lo hi width bins |
	histos := aHistograms reject: [ :h | h isNil or: [ h isEmpty ] ].
	histos isEmpty ifTrue: [ ^ #() ].
	lo := (histos collect: [ :h | h first lowerBound ]) min.
	hi := (histos collect: [ :h | h last upperBound ]) max.
	hi = lo ifTrue: [ hi := lo + 1.0 ].
	width := (hi - lo) / aCount.
	bins := (1 to: aCount) collect: [ :i |
		GcHistogramBin lowerBound: lo + ((i - 1) * width) upperBound: lo + (i * width) count: 0 ].
	histos do: [ :h |
		h do: [ :srcBin |
			| idx target |
			idx := ((srcBin midpoint - lo) / width) floor + 1.
			idx := (idx max: 1) min: aCount.
			target := bins at: idx.
			target count: target count + srcBin count ] ].
	^ bins
]

{ #category : 'views' }
GcTensorGroup >> moduleSummaries [
	^ ((self groupedBy: [ :t | t module ifNil: [ '(none)' ] ]) associations
		asSortedCollection: [ :a :b | a key < b key ]) asArray
]

{ #category : 'gt - skyline' }
GcTensorGroup >> paintSkylineOn: aMondrian [
	"Vertical skyline: a caption, then one row per depth (embeddings band, layers by index, head/final band), with each layer's tensors nested as boxes coloured by regularity |z|."
	| scores rows |
	scores := self regularityScores.
	rows := self layers items.
	aMondrian nodes
		stencil: [ :caption |
			BlTextElement new
				text: caption asRopedText;
				padding: (BlInsets all: 4) ];
		with: { self skylineCaption }.
	aMondrian nodes
		stencil: [ :layer | self skylineRowElementFor: layer ];
		with: rows;
		forEach: [ :layer |
			aMondrian nodes
				stencil: [ :tensor | self skylineBoxFor: tensor score: (scores at: tensor ifAbsent: [ nil ]) ];
				with: layer tensors items ]
		in: #boxes.
	aMondrian layout vertical
]

{ #category : 'regularity' }
GcTensorGroup >> regularityScoreFor: aTensor [
	"This tensor's regularity score against its cohort, or nil if the tensor is not in this group."
	^ self regularityScores at: aTensor ifAbsent: [ nil ]
]

{ #category : 'regularity' }
GcTensorGroup >> regularityScores [
	"An IdentityDictionary tensor -> GcRegularityScore. For each (module, role) cohort, use the sampled-mean metric when EVERY member already has cached stats (never fetches), otherwise the structural paramCount metric; z is population-standardised within the cohort. Recomputed on demand so it reflects the current warm-up state."
	| scores byCohort |
	scores := IdentityDictionary new.
	byCohort := self groupedBy: [ :t | self cohortKeyFor: t ].
	byCohort valuesDo: [ :cohort |
		| members useValue metric values n mean std |
		members := cohort asArray.
		useValue := members allSatisfy: [ :t | t hasStats ].
		metric := useValue ifTrue: [ #mean ] ifFalse: [ #paramCount ].
		values := members collect: [ :t | useValue ifTrue: [ t cachedStats mean ] ifFalse: [ t paramCount ] ].
		n := values size.
		mean := n = 0 ifTrue: [ 0 ] ifFalse: [ (values inject: 0 into: [ :a :b | a + b ]) / n ].
		std := n = 0
			ifTrue: [ 0 ]
			ifFalse: [ ((values inject: 0 into: [ :a :b | a + ((b - mean) squared) ]) / n) sqrt ].
		members withIndexDo: [ :t :i |
			scores at: t put: (GcRegularityScore
				tensor: t
				metric: metric
				value: (values at: i)
				cohortMean: mean
				cohortStd: std
				cohortSize: n) ] ].
	^ scores
]

{ #category : 'accessing' }
GcTensorGroup >> sampledStatsTensors [
	"This group's tensors that already carry cached Tier-1 stats (never fetches)."
	^ self items select: [ :t | t hasStats ]
]

{ #category : 'gt - skyline' }
GcTensorGroup >> skylineBoxFor: aTensor score: aScore [
	| side color |
	side := (((aTensor byteSize + 1) sqrt / 22.0) max: 6.0) min: 46.0.
	color := aScore isNil ifTrue: [ Color lightGray ] ifFalse: [ aScore skylineColor ].
	^ BlElement new
		background: color;
		border: (BlBorder paint: (Color gray alpha: 0.5) width: 0.5);
		margin: (BlInsets all: 1);
		size: side @ side;
		yourself
]

{ #category : 'gt - skyline' }
GcTensorGroup >> skylineCaption [
	"An honest one-line statement of what the skyline colours mean, with the current sampling coverage."
	| scores total valueCount |
	scores := self regularityScores.
	total := scores size.
	valueCount := scores values count: [ :s | s isValueMetric and: [ s hasCohort ] ].
	^ 'Skyline -- colour = |z| of sampled mean within (module,role) cohort; ' , valueCount printString , '/' , total printString , ' value-sampled, rest grey (structural only). Box size proportional to sqrt(bytes).'
]

{ #category : 'gt - skyline' }
GcTensorGroup >> skylineRowElementFor: aLayer [
	| label boxes |
	label := BlTextElement new
		text: aLayer label asRopedText;
		padding: (BlInsets all: 3).
	boxes := BlElement new
		layout: BlLinearLayout horizontal;
		padding: (BlInsets all: 1);
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ].
	boxes graph beChildrenContainer: #boxes.
	^ BlElement new
		layout: BlLinearLayout horizontal;
		padding: (BlInsets all: 1);
		constraintsDo: [ :c | c horizontal fitContent. c vertical fitContent ];
		addChildren: { label. boxes };
		yourself
]

{ #category : 'analyzing' }
GcTensorGroup >> statistics [
	^ (Dictionary new)
		at: #tensorCount put: self size;
		at: #totalParams put: self totalParams;
		at: #totalBytes put: self totalBytes;
		at: #modules put: self byModule size;
		yourself
]

{ #category : 'aggregating' }
GcTensorGroup >> totalBytes [
	^ self inject: 0 into: [ :sum :t | sum + t byteSize ]
]

{ #category : 'aggregating' }
GcTensorGroup >> totalParams [
	^ self inject: 0 into: [ :sum :t | sum + t paramCount ]
]

{ #category : 'regularity' }
GcTensorGroup >> warmDefaultCohort [
	"Warm the cheapest per-layer cohort's stats so the skyline's value-metric colouring becomes real. Returns the number of tensors warmed."
	| m |
	m := self defaultWarmModule.
	^ m isNil ifTrue: [ 0 ] ifFalse: [ self warmStatsForModule: m ]
]

{ #category : 'regularity' }
GcTensorGroup >> warmStatsForModule: aModuleString [
	"Bounded warm-up: compute (fetch + decode) Tier-1 stats for every sampleable tensor whose module is aModuleString that is not already cached -- one cohort only (e.g. ~30 layernorm vectors), sequential. Returns the number warmed. Never warms everything."
	| count |
	count := 0.
	self items do: [ :t |
		(t module = aModuleString and: [ t supportsSampling and: [ t hasStats not ] ])
			ifTrue: [ t stats. count := count + 1 ] ].
	^ count
]
