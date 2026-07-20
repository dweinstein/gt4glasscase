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
