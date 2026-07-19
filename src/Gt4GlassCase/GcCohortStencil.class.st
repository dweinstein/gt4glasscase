"
A pluggable miniature renderer for cohort small-multiples grids. Holds a metricBlock (child group -> number) used by the default cell, a labelBlock (child group -> string), and an optional cellBlock (child group + shared-axis context -> BlElement) so richer miniatures (histograms, spectra, occupancy plots) can drop in as cell renderers without redesign. Shared axes and the cohort IQR band are computed once from the outer group and passed to every cell, so all cells are directly comparable and a cohort that breaks the texture of its siblings stands out.
"
Class {
	#name : 'GcCohortStencil',
	#superclass : 'Object',
	#instVars : [
		'labelBlock',
		'metricBlock',
		'cellBlock',
		'cellWidth',
		'cellHeight'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcCohortStencil class >> default [
	^ self new
]

{ #category : 'accessing' }
GcCohortStencil >> cellBlock [
	^ cellBlock
]

{ #category : 'accessing' }
GcCohortStencil >> cellBlock: aBlock [
	cellBlock := aBlock
]

{ #category : 'accessing' }
GcCohortStencil >> cellHeight [
	^ cellHeight ifNil: [ cellHeight := 64 ]
]

{ #category : 'accessing' }
GcCohortStencil >> cellHeight: aNumber [
	cellHeight := aNumber
]

{ #category : 'accessing' }
GcCohortStencil >> cellWidth [
	^ cellWidth ifNil: [ cellWidth := 100 ]
]

{ #category : 'accessing' }
GcCohortStencil >> cellWidth: aNumber [
	cellWidth := aNumber
]

{ #category : 'rendering' }
GcCohortStencil >> contextFor: anOuterGroup [
	| metrics sorted n max q1 median q3 |
	metrics := anOuterGroup items collect: [ :each | (self metricBlock value: each) asFloat ].
	metrics isEmpty ifTrue: [
		^ Dictionary new
			at: #metrics put: metrics;
			at: #max put: 1.0;
			at: #q1 put: 0.0;
			at: #median put: 0.0;
			at: #q3 put: 0.0;
			yourself ].
	sorted := metrics asSortedCollection asArray.
	n := sorted size.
	max := sorted last max: 1.0.
	q1 := sorted at: ((n * 1 // 4) max: 1).
	median := sorted at: ((n * 2 // 4) max: 1).
	q3 := sorted at: ((n * 3 // 4) max: 1).
	^ Dictionary new
		at: #metrics put: metrics;
		at: #max put: max;
		at: #q1 put: q1;
		at: #median put: median;
		at: #q3 put: q3;
		yourself
]

{ #category : 'rendering' }
GcCohortStencil >> elementFor: aChildGroup context: aDictionary [
	| container max usableHeight usableWidth labelHeight metric barHeight barWidth q1 q3 bandTop bandHeight band bar label |
	self cellBlock notNil ifTrue: [ ^ self cellBlock value: aChildGroup value: aDictionary ].
	max := (aDictionary at: #max ifAbsent: [ 1.0 ]) max: 1.0.
	labelHeight := 14.
	usableHeight := self cellHeight - labelHeight.
	usableWidth := self cellWidth.
	q1 := aDictionary at: #q1 ifAbsent: [ 0.0 ].
	q3 := aDictionary at: #q3 ifAbsent: [ 0.0 ].
	metric := (self metricBlock value: aChildGroup) asFloat.
	container := BlElement new
		size: self cellWidth @ self cellHeight;
		background: Color white;
		border: (BlBorder paint: Color veryLightGray width: 1);
		margin: (BlInsets all: 2);
		yourself.
	bandTop := usableHeight - (q3 / max * usableHeight).
	bandHeight := ((q3 - q1) / max * usableHeight) max: 1.
	band := BlElement new
		size: usableWidth @ bandHeight;
		background: Color veryLightGray;
		yourself.
	band relocate: 0 @ bandTop.
	container addChild: band.
	barHeight := metric / max * usableHeight.
	barWidth := self cellWidth / 3.
	bar := BlElement new
		size: barWidth @ barHeight;
		background: (Color r: 0.35 g: 0.5 b: 0.75);
		yourself.
	bar relocate: ((self cellWidth - barWidth) / 2) @ (usableHeight - barHeight).
	container addChild: bar.
	label := BlTextElement new text: (self labelBlock value: aChildGroup) asRopedText.
	label relocate: 2 @ usableHeight.
	container addChild: label.
	^ container
]

{ #category : 'accessing' }
GcCohortStencil >> labelBlock [
	^ labelBlock ifNil: [ labelBlock := [ :g |
		| s |
		s := g printString.
		s size > 18
			ifTrue: [ s copyFrom: 1 to: 18 ]
			ifFalse: [ s ] ] ]
]

{ #category : 'accessing' }
GcCohortStencil >> labelBlock: aBlock [
	labelBlock := aBlock
]

{ #category : 'accessing' }
GcCohortStencil >> metricBlock [
	^ metricBlock ifNil: [ metricBlock := [ :g | g size ] ]
]

{ #category : 'accessing' }
GcCohortStencil >> metricBlock: aBlock [
	metricBlock := aBlock
]
