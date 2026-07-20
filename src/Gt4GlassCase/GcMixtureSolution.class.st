"
SCAFFOLD (DW-18, Tier-2 boundary object): the RESULT of a data-mixture inference -- a dictionary of per-category proportions (category-name -> fraction in [0,1]), a scalar residual (the misfit of the recovered mixture; 0 = perfect, larger = worse), and a provenance label naming who produced it (planted/synthetic here; the Python oracle in production). The residual is shown PROMINENTLY (a bad fit must be visible) so a poor reconstruction can never masquerade as a confident answer. Renderable from planted/synthetic numbers; the actual LP that fills it is delegated to gc-harness (DW-18 Tier-2), mirroring DW-12's Tier-1/Tier-2 split.
"
Class {
	#name : 'GcMixtureSolution',
	#superclass : 'Object',
	#instVars : [
		'proportions',
		'residual',
		'provenance'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcMixtureSolution class >> proportions: aDict residual: aNumber provenance: aString [
	^ self new setProportions: aDict residual: aNumber provenance: aString
]

{ #category : 'gt views' }
GcMixtureSolution >> gtProportionsFor: aView [
	<gtView>
	"The per-category proportions as a table, largest first, with the residual in the title."
	^ aView columnedList
		title: 'Proportions';
		priority: 2;
		items: [ self sortedProportions ];
		column: 'Category' text: [ :assoc | assoc key ];
		column: 'Proportion' text: [ :assoc | assoc value asFloat printShowingDecimalPlaces: 4 ];
		send: [ :assoc | assoc key ]
]

{ #category : 'gt views' }
GcMixtureSolution >> gtSolutionFor: aView [
	<gtView>
	"The inferred mixture: per-category proportions as bars, with the residual (misfit) shown PROMINENTLY -- a bad fit must be visible."
	^ aView explicit
		title: 'Mixture solution';
		priority: 1;
		stencil: [ self solutionElement ]
]

{ #category : 'accessing' }
GcMixtureSolution >> gtSolutionSubtitle [
	^ 'RESIDUAL (misfit): ' , self residualString , ' -- ' , (self isGoodFit ifTrue: [ 'good fit (< 0.05)' ] ifFalse: [ 'POOR FIT (>= 0.05): reconstruction does not explain the merge order' ]) , '  |  provenance: ' , (provenance ifNil: [ 'unknown' ])
]

{ #category : 'testing' }
GcMixtureSolution >> isGoodFit [
	"A fit is good when the residual (misfit) is below the documented 0.05 threshold."
	^ residual notNil and: [ residual < 0.05 ]
]

{ #category : 'printing' }
GcMixtureSolution >> printOn: aStream [
	aStream nextPutAll: 'mixture solution (residual '; nextPutAll: self residualString; nextPutAll: (self isGoodFit ifTrue: [ ', good fit)' ] ifFalse: [ ', POOR FIT)' ])
]

{ #category : 'accessing' }
GcMixtureSolution >> proportions [
	^ proportions
]

{ #category : 'accessing' }
GcMixtureSolution >> provenance [
	^ provenance
]

{ #category : 'accessing' }
GcMixtureSolution >> residual [
	^ residual
]

{ #category : 'accessing' }
GcMixtureSolution >> residualString [
	^ residual isNil ifTrue: [ 'n/a' ] ifFalse: [ residual asFloat printShowingDecimalPlaces: 3 ]
]

{ #category : 'initialization' }
GcMixtureSolution >> setProportions: aDict residual: aNumber provenance: aString [
	proportions := aDict.
	residual := aNumber.
	provenance := aString
]

{ #category : 'gt views' }
GcMixtureSolution >> solutionElement [
	"Per-category proportions as horizontal bars, under a prominent residual banner (red = poor fit). Renderable from planted numbers."
	| banner |
	banner := BrLabel new
		aptitude: BrGlamorousLabelAptitude;
		text: (self gtSolutionSubtitle asRopedText
			foreground: (self isGoodFit ifTrue: [ Color green darker ] ifFalse: [ Color red ]));
		yourself.
	(proportions isNil or: [ proportions isEmpty ]) ifTrue: [
		^ BlElement new
			layout: BlLinearLayout vertical;
			constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
			padding: (BlInsets all: 8);
			addChild: banner;
			yourself ].
	^ [ | data maxV widthScale barChart chartElement |
		data := GtPlotterDataGroup new values: self sortedProportions.
		data := data labelled: [ :assoc | assoc key , '  ' , (assoc value asFloat printShowingDecimalPlaces: 3) ].
		data := data background: [ :assoc | Color blue alpha: 0.5 ].
		maxV := self sortedProportions inject: 0.0001 into: [ :m :assoc | m max: assoc value asFloat ].
		widthScale := GtPlotterLinearScale new domainFrom: 0 to: maxV.
		barChart := GtPlotterHorizontalBarChart new.
		barChart barLabelSpacing: 160.
		barChart barWidthScale: widthScale.
		barChart barWidthData: [ :assoc | assoc value asFloat ].
		barChart amountOfTicks: 4.
		barChart with: data.
		chartElement := barChart create.
		BlElement new
			layout: BlLinearLayout vertical;
			constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
			padding: (BlInsets all: 8);
			addChild: banner;
			addChild: chartElement;
			yourself ] value
]

{ #category : 'accessing' }
GcMixtureSolution >> sortedProportions [
	"Category -> proportion associations, largest first."
	proportions ifNil: [ ^ #() ].
	^ (proportions associations asSortedCollection: [ :a :b | a value >= b value ]) asArray
]
