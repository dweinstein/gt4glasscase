"
One bar of a value-distribution histogram: the half-open interval [lowerBound, upperBound) and the number of sampled values that fell inside it. A first-class object (I1: nothing is a bare array) so the distribution view can send a bin and answer 'what is in this bucket?'.
"
Class {
	#name : 'GcHistogramBin',
	#superclass : 'Object',
	#instVars : [
		'lowerBound',
		'upperBound',
		'count'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'gt - views' }
GcHistogramBin class >> barChartElementFor: aBins subtitle: aSubtitle [
	"A labelled horizontal-bar histogram element for a collection of GcHistogramBins -- the shared distribution visual (bar width = bin count, label = bin midpoint)."
	| data maxCount widthScale barChart chartElement label |
	data := GtPlotterDataGroup new values: aBins.
	data := data labelled: [ :bin | bin midpoint printShowingDecimalPlaces: 2 ].
	data := data background: [ :bin | Color blue alpha: 0.5 ].
	maxCount := aBins inject: 1 into: [ :m :bin | m max: bin count ].
	widthScale := GtPlotterLinearScale new domainFrom: 0 to: maxCount.
	barChart := GtPlotterHorizontalBarChart new.
	barChart barLabelSpacing: 120.
	barChart barWidthScale: widthScale.
	barChart barWidthData: [ :bin | bin count ].
	barChart amountOfTicks: 4.
	barChart with: data.
	chartElement := barChart create.
	label := BrLabel new aptitude: BrGlamorousLabelAptitude; text: aSubtitle; yourself.
	^ BlElement new
		layout: BlLinearLayout vertical;
		constraintsDo: [ :c | c horizontal matchParent. c vertical matchParent ];
		padding: (BlInsets all: 5);
		addChild: label;
		addChild: chartElement;
		yourself
]

{ #category : 'instance creation' }
GcHistogramBin class >> lowerBound: aLow upperBound: aHigh count: anInteger [
	^ self new
		lowerBound: aLow;
		upperBound: aHigh;
		count: anInteger;
		yourself
]

{ #category : 'accessing' }
GcHistogramBin >> count [
	^ count
]

{ #category : 'accessing' }
GcHistogramBin >> count: anInteger [
	count := anInteger
]

{ #category : 'accessing' }
GcHistogramBin >> facets [
	^ {
		'Lower bound' -> lowerBound.
		'Upper bound' -> upperBound.
		'Midpoint' -> self midpoint.
		'Count' -> count }
]

{ #category : 'gt - views' }
GcHistogramBin >> gtDetailsFor: aView [
	"How many values fell in this bucket, and what is its range?"
	<gtView>
	^ aView columnedList
		title: 'Bin';
		priority: 1;
		items: [ self facets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'accessing' }
GcHistogramBin >> lowerBound [
	^ lowerBound
]

{ #category : 'accessing' }
GcHistogramBin >> lowerBound: aNumber [
	lowerBound := aNumber
]

{ #category : 'accessing' }
GcHistogramBin >> midpoint [
	^ (lowerBound + upperBound) / 2
]

{ #category : 'printing' }
GcHistogramBin >> printOn: aStream [
	aStream
		nextPut: $[;
		print: lowerBound;
		nextPutAll: ', ';
		print: upperBound;
		nextPutAll: '): ';
		print: count
]

{ #category : 'accessing' }
GcHistogramBin >> upperBound [
	^ upperBound
]

{ #category : 'accessing' }
GcHistogramBin >> upperBound: aNumber [
	upperBound := aNumber
]

{ #category : 'accessing' }
GcHistogramBin >> width [
	^ upperBound - lowerBound
]
