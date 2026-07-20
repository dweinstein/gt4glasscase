"
An ordered group of GcLayers for one model: an embeddings band, the transformer layers in ascending depth, then a head/final band. Built by GcTensorGroup>>layers. The Layers view answers 'how is tensor mass distributed across depth, and where do the non-layer bands sit?'. (Per-layer metric curves with a regularity band are DW-17.)
"
Class {
	#name : 'GcLayerGroup',
	#superclass : 'GcGroup',
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'gt - views' }
GcLayerGroup >> clickableLayerStripFor: aPoints [
	"A horizontal row of small clickable markers, one per plotted layer, that spawn the GcLayer into the inspector (the curve's drill-down affordance)."
	| strip |
	strip := BlElement new
		layout: BlLinearLayout horizontal;
		constraintsDo: [ :c | c horizontal matchParent. c vertical fitContent ];
		padding: (BlInsets all: 3);
		yourself.
	aPoints do: [ :p |
		| layer marker |
		layer := p at: #layer.
		marker := BlElement new
			background: (Color blue alpha: 0.6);
			border: (BlBorder paint: (Color gray alpha: 0.5) width: 0.5);
			margin: (BlInsets all: 1);
			size: 11 @ 11;
			addAptitude: (BrGlamorousWithExplicitTooltipAptitude text: layer label);
			yourself.
		marker addEventHandlerOn: BlClickEvent do: [ :evt | marker phlow spawnObject: layer ].
		strip addChild: marker ].
	^ strip
]

{ #category : 'gt - views' }
GcLayerGroup >> curveElementForPoints: aPoints valueTitle: aTitle subtitle: aSubtitle [
	"Compose a per-layer curve: an honest subtitle, a line chart of the metric across depth with a mean +/- 1 sigma reference band drawn in the same frame (V4), and a row of clickable layer markers that spawn the GcLayer. Empty points -> a labelled placeholder. Y ticks adapt to magnitude (3 decimals for small sampled values, whole numbers for large param counts); X ticks are whole depth ordinals."
	| values mean std xMax allData colors chartData chart chartElement subtitleLabel strip |
	aPoints isEmpty ifTrue: [ ^ self emptyCurveElementWithMessage: aSubtitle ].
	values := aPoints collect: [ :p | p at: #value ].
	mean := (values inject: 0.0 into: [ :a :b | a + b ]) / values size.
	std := ((values inject: 0.0 into: [ :a :b | a + ((b - mean) squared) ]) / values size) sqrt.
	xMax := (aPoints collect: [ :p | p at: #position ]) inject: 1 into: [ :m :p | m max: p ].
	allData := OrderedCollection new.
	aPoints do: [ :p |
		allData add: (Dictionary new at: #x put: (p at: #position); at: #y put: (p at: #value); at: #series put: 'metric'; yourself) ].
	{ 'mean + 1sd' -> (mean + std). 'mean' -> mean. 'mean - 1sd' -> (mean - std) } do: [ :assoc |
		{ 1. xMax } do: [ :xx |
			allData add: (Dictionary new at: #x put: xx; at: #y put: assoc value; at: #series put: assoc key; yourself) ] ].
	colors := Dictionary new
		at: 'metric' put: (Color blue);
		at: 'mean' put: (Color gray);
		at: 'mean + 1sd' put: (Color gray alpha: 0.4);
		at: 'mean - 1sd' put: (Color gray alpha: 0.4);
		yourself.
	chartData := (GtPlotterDataGroup new values: allData)
		groupedBy: [ :p | p at: #series ] labelled: [ :s | s ] colored: [ :s | colors at: s ].
	chart := GtPlotterLineChart new
		with: chartData;
		valueX: [ :p | p at: #x ];
		scaleX: GtPlotterLinearScale new;
		labelFormatX: [ :v | (v printShowingDecimalPlaces: 0) asRopedText foreground: Color darkGray ];
		titleX: 'Layer (depth ordinal)';
		ticksX: (xMax min: 12);
		valueY: [ :p | p at: #y ];
		scaleY: GtPlotterLinearScale new;
		labelFormatY: [ :v | ((v abs < 100 and: [ v ~= 0 ]) ifTrue: [ v printShowingDecimalPlaces: 3 ] ifFalse: [ v printShowingDecimalPlaces: 0 ]) asRopedText foreground: Color darkGray ];
		titleY: aTitle.
	chartElement := chart create.
	chartElement constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ].
	subtitleLabel := BrLabel new aptitude: BrGlamorousLabelAptitude; text: aSubtitle; yourself.
	strip := self clickableLayerStripFor: aPoints.
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
		padding: (BlInsets all: 5);
		addChild: subtitleLabel;
		addChild: chartElement;
		addChild: strip;
		yourself
]

{ #category : 'gt - views' }
GcLayerGroup >> emptyCurveElementWithMessage: aString [
	"A labelled placeholder element for a curve with no data."
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
		padding: (BlInsets all: 10);
		addChild: (BrLabel new aptitude: BrGlamorousLabelAptitude; text: aString; yourself);
		yourself
]

{ #category : 'gt - views' }
GcLayerGroup >> gtLayersFor: aView [
	"How much tensor mass lives at each depth? Bands (embeddings, head/final) sit at the ends; click a row to open that layer."
	<gtView>
	^ aView columnedList
		title: 'Layers';
		priority: 5;
		items: [ self items ];
		column: 'Layer' text: [ :layer | layer label ];
		column: 'Tensors' text: [ :layer | layer tensors size printString ];
		column: 'Params' text: [ :layer | layer totalParams printString ];
		send: [ :layer | layer ]
]

{ #category : 'gt - views' }
GcLayerGroup >> gtPerLayerStructuralCurveFor: aView [
	"Is any layer structurally unusual? Total parameters per layer across depth, with a mean +/- 1 sigma reference band (V4); click a marker to open that layer. Always available -- structural, no sampling needed."
	<gtView>
	^ aView explicit
		title: 'Structural curve';
		priority: 6;
		stencil: [
			self
				curveElementForPoints: (self perLayerCurvePoints: [ :layer | layer totalParams ])
				valueTitle: 'Total params'
				subtitle: 'total params per layer over ' , self items size printString , ' layers (structural, no sampling)' ]
]

{ #category : 'gt - views' }
GcLayerGroup >> gtPerLayerValueCurveFor: aView [
	"Do sampled values drift across depth? Per-layer mean of the sampled tensor means, over ONLY the tensors with cached Tier-1 stats (never fetches), with a mean +/- 1 sigma band (V4). Honest subtitle names the coverage; empty until a warm-up runs."
	<gtView>
	^ aView explicit
		title: 'Value drift';
		priority: 7;
		stencil: [ | points sampled total |
			sampled := self sampledTensorCount.
			total := self tensorCount.
			points := self perLayerCurvePoints: [ :layer | self sampledMeanForLayer: layer ].
			points isEmpty
				ifTrue: [ self emptyCurveElementWithMessage: 'no sampled stats yet -- run the warm-up action on the tensor group' ]
				ifFalse: [ self
					curveElementForPoints: points
					valueTitle: 'Mean of sampled tensor means'
					subtitle: 'value curve from ' , sampled printString , '/' , total printString , ' sampled tensors, ' , points size printString , ' layers measured' ] ]
]

{ #category : 'accessing' }
GcLayerGroup >> perLayerCurvePoints: aValueBlock [
	"One record per layer that has a value under aValueBlock: the 1-based depth ordinal (position over all ordered layers), the layer itself, and the numeric value. Layers whose value is nil (e.g. no sampled tensors) are omitted, so the series honestly shows only measured depths."
	| points |
	points := OrderedCollection new.
	self items doWithIndex: [ :layer :i |
		| v |
		v := aValueBlock value: layer.
		v ifNotNil: [
			points add: (Dictionary new
				at: #position put: i;
				at: #layer put: layer;
				at: #value put: v asFloat;
				yourself) ] ].
	^ points
]

{ #category : 'accessing' }
GcLayerGroup >> sampledMeanForLayer: aLayer [
	"The mean of the sampled means of this layer's tensors that already carry cached Tier-1 stats, or nil when none are sampled. Never fetches (reads cachedStats only)."
	| withStats |
	withStats := aLayer tensors items select: [ :t | t hasStats ].
	withStats isEmpty ifTrue: [ ^ nil ].
	^ (withStats inject: 0.0 into: [ :acc :t | acc + t cachedStats mean ]) / withStats size
]

{ #category : 'accessing' }
GcLayerGroup >> sampledTensorCount [
	"Number of tensors across all layers that already carry cached Tier-1 stats (never fetches)."
	^ self items inject: 0 into: [ :sum :layer | sum + (layer tensors items count: [ :t | t hasStats ]) ]
]

{ #category : 'accessing' }
GcLayerGroup >> tensorCount [
	"Total number of tensors across all layers."
	^ self items inject: 0 into: [ :sum :layer | sum + layer tensors size ]
]
