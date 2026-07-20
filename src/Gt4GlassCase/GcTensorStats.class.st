"
Cached numeric summary of a tensor, computed from a GcTensorSlice (a sampled or full decode of the tensor's values). Tier-1 (in-image) fields: mean, std, min, max, l2Norm, sparsity (zero fraction), nanCount, infCount and a ~40-bin GcHistogramBin histogram, alongside provenance -- sampleCount, totalCount and samplingStrategy (I14: every view answers 'n of N sampled'). healthLabel answers the auditor's question 'is anything numerically wrong?' (NaN / Inf first). Build with `GcTensorStats fromSlice:` or `fromValues:`. Tier-2 (SVD, spectra) is delegated to Python and would be cached in spectralEntropy et al.; it is out of scope here.
"
Class {
	#name : 'GcTensorStats',
	#superclass : 'Object',
	#instVars : [
		'tensorRef',
		'min',
		'max',
		'mean',
		'std',
		'sparsity',
		'spectralEntropy',
		'l2Norm',
		'nanCount',
		'infCount',
		'histogram',
		'sampleCount',
		'totalCount',
		'samplingStrategy',
		'slice'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcTensorStats class >> fromSlice: aSlice [
	^ self new computeFromSlice: aSlice
]

{ #category : 'instance creation' }
GcTensorStats class >> fromValues: aCollection [
	"Compute stats over a plain collection of Floats (wrapped in a synthetic full slice)."
	^ self fromSlice: (GcTensorSlice fromValues: aCollection)
]

{ #category : 'computing' }
GcTensorStats >> computeFromSlice: aSlice [
	"Tier-1 numerics over the slice's decoded Floats: moments and L2 over the finite values, NaN/Inf/zero counts over all, and a ~40-bin histogram."
	| vals finite n mySum sumSq |
	slice := aSlice.
	tensorRef := aSlice tensorRef.
	samplingStrategy := aSlice samplingStrategy.
	sampleCount := aSlice sampleCount.
	totalCount := aSlice totalCount.
	vals := aSlice values.
	nanCount := vals count: [ :v | v isNaN ].
	infCount := vals count: [ :v | v isInfinite ].
	sparsity := sampleCount = 0 ifTrue: [ 0 ] ifFalse: [ (vals count: [ :v | v = 0 ]) / sampleCount ].
	finite := vals select: [ :v | v isFinite ].
	n := finite size.
	n = 0 ifTrue: [
		min := nil. max := nil. mean := nil. std := nil. l2Norm := 0.0.
		histogram := OrderedCollection new.
		^ self ].
	min := finite inject: finite first into: [ :m :v | m min: v ].
	max := finite inject: finite first into: [ :m :v | m max: v ].
	mySum := finite inject: 0.0 into: [ :acc :v | acc + v ].
	mean := mySum / n.
	sumSq := finite inject: 0.0 into: [ :acc :v | acc + ((v - mean) * (v - mean)) ].
	std := (sumSq / n) sqrt.
	l2Norm := (finite inject: 0.0 into: [ :acc :v | acc + (v * v) ]) sqrt.
	self computeHistogramFrom: finite.
	^ self
]

{ #category : 'computing' }
GcTensorStats >> computeHistogramFrom: finiteValues [
	"Bin the finite values into ~40 equal-width buckets between min and max (single degenerate bin when all equal)."
	| binCount lo hi width bins idx |
	histogram := OrderedCollection new.
	finiteValues isEmpty ifTrue: [ ^ self ].
	lo := min.
	hi := max.
	lo = hi ifTrue: [
		histogram add: (GcHistogramBin lowerBound: lo upperBound: hi count: finiteValues size).
		^ self ].
	binCount := 40.
	width := (hi - lo) / binCount.
	bins := Array new: binCount withAll: 0.
	finiteValues do: [ :v |
		idx := ((v - lo) / width) floor + 1.
		idx < 1 ifTrue: [ idx := 1 ].
		idx > binCount ifTrue: [ idx := binCount ].
		bins at: idx put: (bins at: idx) + 1 ].
	1 to: binCount do: [ :i |
		histogram add: (GcHistogramBin
			lowerBound: lo + ((i - 1) * width)
			upperBound: lo + (i * width)
			count: (bins at: i)) ].
	^ self
]

{ #category : 'printing' }
GcTensorStats >> distributionSubtitle [
	| prov range |
	prov := slice
		ifNil: [ 'sampled ', sampleCount printString, ' of ', totalCount printString ]
		ifNotNil: [ :s | s provenanceLabel ].
	(min isNil or: [ max isNil ])
		ifTrue: [ range := '' ]
		ifFalse: [ range := '   range [', (min printShowingDecimalPlaces: 4), ', ', (max printShowingDecimalPlaces: 4), ']' ].
	^ prov, range
]

{ #category : 'accessing' }
GcTensorStats >> facets [
	"Health first: NaN / Inf / zero-fraction are what a security auditor looks for."
	^ {
		'Health' -> self healthLabel.
		'NaN count' -> nanCount.
		'Inf count' -> infCount.
		'Zero fraction' -> self zeroFraction.
		'Samples' -> sampleCount.
		'Total elements' -> totalCount.
		'Sampling' -> samplingStrategy.
		'Mean' -> mean.
		'Std' -> std.
		'Min' -> min.
		'Max' -> max.
		'L2 norm' -> l2Norm }
]

{ #category : 'gt - views' }
GcTensorStats >> gtFacetsFor: aView [
	"Is anything numerically wrong with this tensor?"
	<gtView>
	^ aView columnedList
		title: 'Statistics';
		priority: 1;
		items: [ self facets ];
		column: 'Metric' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value isNil ifTrue: [ '-' ] ifFalse: [ assoc value displayString ] ];
		send: [ :assoc | assoc value ]
]

{ #category : 'gt - views' }
GcTensorStats >> gtSampleValuesFor: aView [
	"The raw sampled values (forwarded to the slice)."
	<gtView>
	slice isNil ifTrue: [ ^ aView empty ].
	^ aView forward
		title: 'Sample values';
		priority: 4;
		object: [ slice ];
		view: #gtSampleValuesFor:
]

{ #category : 'gt - views' }
GcTensorStats >> gtValueDistributionFor: aView [
	"What values does this tensor hold? A horizontal-bar histogram of the sampled values, labelled with honest provenance."
	<gtView>
	(histogram isNil or: [ histogram isEmpty ]) ifTrue: [ ^ aView empty ].
	^ aView explicit
		title: 'Value distribution';
		priority: 3;
		stencil: [ | data maxCount widthScale barChart chartElement label |
			data := GtPlotterDataGroup new values: histogram.
			data := data labelled: [ :bin | bin midpoint printShowingDecimalPlaces: 4 ].
			data := data background: [ :bin | Color blue alpha: 0.5 ].
			maxCount := histogram inject: 1 into: [ :m :bin | m max: bin count ].
			widthScale := GtPlotterLinearScale new domainFrom: 0 to: maxCount.
			barChart := GtPlotterHorizontalBarChart new.
			barChart barLabelSpacing: 120.
			barChart barWidthScale: widthScale.
			barChart barWidthData: [ :bin | bin count ].
			barChart amountOfTicks: 4.
			barChart with: data.
			chartElement := barChart create.
			label := BrLabel new
				aptitude: BrGlamorousLabelAptitude;
				text: self distributionSubtitle;
				yourself.
			BlElement new
				layout: BlLinearLayout vertical;
				constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
				padding: (BlInsets all: 5);
				addChild: label;
				addChild: chartElement;
				yourself ]
]

{ #category : 'testing' }
GcTensorStats >> healthLabel [
	"A one-line answer to 'is anything numerically wrong?'."
	(nanCount notNil and: [ nanCount > 0 ]) ifTrue: [ ^ 'NaN present (', nanCount printString, ')' ].
	(infCount notNil and: [ infCount > 0 ]) ifTrue: [ ^ 'Inf present (', infCount printString, ')' ].
	^ 'finite'
]

{ #category : 'accessing' }
GcTensorStats >> histogram [
	^ histogram
]

{ #category : 'accessing' }
GcTensorStats >> infCount [
	^ infCount
]

{ #category : 'accessing' }
GcTensorStats >> l2Norm [
	^ l2Norm
]

{ #category : 'accessing' }
GcTensorStats >> max [
	^ max
]

{ #category : 'accessing' }
GcTensorStats >> mean [
	^ mean
]

{ #category : 'accessing' }
GcTensorStats >> min [
	^ min
]

{ #category : 'accessing' }
GcTensorStats >> nanCount [
	^ nanCount
]

{ #category : 'printing' }
GcTensorStats >> printOn: aStream [
	aStream nextPutAll: 'GcTensorStats('.
	mean ifNotNil: [ :m | aStream nextPutAll: 'mean='; print: m; nextPutAll: ' ' ].
	aStream nextPutAll: self healthLabel; nextPut: $)
]

{ #category : 'accessing' }
GcTensorStats >> sampleCount [
	^ sampleCount
]

{ #category : 'accessing' }
GcTensorStats >> samplingStrategy [
	^ samplingStrategy
]

{ #category : 'accessing' }
GcTensorStats >> slice [
	^ slice
]

{ #category : 'accessing' }
GcTensorStats >> sparsity [
	^ sparsity
]

{ #category : 'accessing' }
GcTensorStats >> std [
	^ std
]

{ #category : 'accessing' }
GcTensorStats >> tensorRef [
	^ tensorRef
]

{ #category : 'accessing' }
GcTensorStats >> totalCount [
	^ totalCount
]

{ #category : 'accessing' }
GcTensorStats >> zeroFraction [
	^ sparsity ifNil: [ 0 ] ifNotNil: [ :s | s asFloat ]
]
