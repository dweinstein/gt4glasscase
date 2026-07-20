"
One tensor's regularity score: how far this tensor deviates from its own cohort (the same (module, role) across every layer, e.g. all q_proj.weight). z = (metricValue - cohortMean) / cohortStd, and 0 when cohortStd = 0. The metric is chosen per cohort with honest provenance (I14): #mean -- the sampled-value mean -- when every cohort member already has cached Tier-1 stats (never triggers a fetch), otherwise the structural #paramCount, which catches shape anomalies with zero I/O. hasCohort answers whether there was anything to compare against at all. skylineColor turns |z| into the model-skyline colour ramp (grey = no cohort or structural-only, calm -> hot as |z| grows).
"
Class {
	#name : 'GcRegularityScore',
	#superclass : 'Object',
	#instVars : [
		'tensor',
		'metric',
		'metricValue',
		'cohortMean',
		'cohortStd',
		'cohortSize',
		'z'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcRegularityScore class >> tensor: aTensor metric: aSymbol value: aNumber cohortMean: aMean cohortStd: aStd cohortSize: aCount [
	^ self new
		setTensor: aTensor metric: aSymbol value: aNumber cohortMean: aMean cohortStd: aStd cohortSize: aCount
]

{ #category : 'accessing' }
GcRegularityScore >> absZ [
	^ z abs
]

{ #category : 'accessing' }
GcRegularityScore >> cohortMean [
	^ cohortMean
]

{ #category : 'accessing' }
GcRegularityScore >> cohortSize [
	^ cohortSize
]

{ #category : 'accessing' }
GcRegularityScore >> cohortStd [
	^ cohortStd
]

{ #category : 'accessing' }
GcRegularityScore >> facets [
	^ {
		'Tensor' -> (tensor ifNil: [ nil ] ifNotNil: [ tensor name ]).
		'Metric' -> self metricLabel.
		'Metric value' -> metricValue.
		'Cohort size' -> cohortSize.
		'Cohort mean' -> cohortMean.
		'Cohort std' -> cohortStd.
		'z' -> self zDisplayString }
]

{ #category : 'gt - views' }
GcRegularityScore >> gtSummaryFor: aView [
	"How regular is this tensor compared to its (module, role) cohort?"
	<gtView>
	^ aView columnedList
		title: 'Regularity';
		priority: 1;
		items: [ self facets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'testing' }
GcRegularityScore >> hasCohort [
	"Was there anything to compare this tensor against? A cohort of one (a unique module/role) has no regularity signal."
	^ cohortSize >= 2
]

{ #category : 'testing' }
GcRegularityScore >> isStructuralMetric [
	^ metric = #paramCount
]

{ #category : 'testing' }
GcRegularityScore >> isValueMetric [
	"True when the score was computed from sampled values (cached stats), false when it fell back to structure."
	^ metric = #mean
]

{ #category : 'accessing' }
GcRegularityScore >> metric [
	^ metric
]

{ #category : 'printing' }
GcRegularityScore >> metricLabel [
	^ self isValueMetric
		ifTrue: [ 'mean (sampled)' ]
		ifFalse: [ 'paramCount (structural)' ]
]

{ #category : 'accessing' }
GcRegularityScore >> metricValue [
	^ metricValue
]

{ #category : 'rendering' }
GcRegularityScore >> neutralColor [
	"The colour for 'nothing to compare / values not sampled yet'."
	^ Color lightGray
]

{ #category : 'printing' }
GcRegularityScore >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(.
	aStream nextPutAll: (tensor ifNil: [ '?' ] ifNotNil: [ tensor name ]).
	aStream nextPutAll: ' z='.
	aStream nextPutAll: self zDisplayString.
	aStream nextPutAll: ' '.
	aStream nextPutAll: self metricLabel.
	aStream nextPut: $)
]

{ #category : 'rendering' }
GcRegularityScore >> rampColorForAbsZ: anAbsZ [
	"Calm teal at |z| = 0 ramping to hot red at |z| >= 2."
	| t |
	t := (anAbsZ / 2.0) min: 1.0.
	^ Color
		r: 0.30 + (0.55 * t)
		g: 0.60 - (0.44 * t)
		b: 0.62 - (0.46 * t)
]

{ #category : 'initialization' }
GcRegularityScore >> setTensor: aTensor metric: aSymbol value: aNumber cohortMean: aMean cohortStd: aStd cohortSize: aCount [
	tensor := aTensor.
	metric := aSymbol.
	metricValue := aNumber.
	cohortMean := aMean.
	cohortStd := aStd.
	cohortSize := aCount.
	z := (aStd isNil or: [ aStd = 0 ])
		ifTrue: [ 0 ]
		ifFalse: [ (aNumber - aMean) / aStd ]
]

{ #category : 'rendering' }
GcRegularityScore >> skylineColor [
	"Grey when there is nothing to say yet -- no cohort, or a structural-only score (values not sampled). Once a cohort's values are warmed, ramp calm -> hot with |z|."
	self hasCohort ifFalse: [ ^ self neutralColor ].
	self isValueMetric ifFalse: [ ^ self neutralColor ].
	^ self rampColorForAbsZ: self absZ
]

{ #category : 'accessing' }
GcRegularityScore >> tensor [
	^ tensor
]

{ #category : 'accessing' }
GcRegularityScore >> z [
	^ z
]

{ #category : 'printing' }
GcRegularityScore >> zDisplayString [
	"The z-score for a table cell: two decimals, or an em dash when there is no cohort to compare against."
	^ self hasCohort
		ifFalse: [ '—' ]
		ifTrue: [ z printShowingDecimalPlaces: 2 ]
]
