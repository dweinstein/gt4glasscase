"
A first-class 2D affine slice of a model's high-dimensional hidden space (I1: never a bare array). A grid point (col i, row j) maps to the R^d vector `base + a*u + b*v`, where u,v are orthonormal directions in R^d, a,b range over [-extent, +extent] at `resolution` steps each, and `basisLabel` names how u,v were chosen (e.g. 'top-2 right singular vectors of W'). Provenance for every view that renders on this slice (I14). Owns only geometry: no router, no weights.
"
Class {
	#name : 'GcHiddenSlice',
	#superclass : 'Object',
	#instVars : [
		'u',
		'v',
		'base',
		'extent',
		'resolution',
		'basisLabel'
	],
	#category : 'Gt4GlassCase',
	#package : 'Gt4GlassCase'
}

{ #category : 'instance creation' }
GcHiddenSlice class >> u: aU v: aV base: aBase extent: aRadius resolution: anInteger basisLabel: aLabel [
	^ self new
		setU: aU v: aV base: aBase extent: aRadius resolution: anInteger basisLabel: aLabel;
		yourself
]

{ #category : 'geometry' }
GcHiddenSlice >> aAt: aColumnIndex [
	"The a-coordinate (first axis) for grid column aColumnIndex, 1..resolution, ranging -extent..+extent as floats (no whole-number tick bug)."
	resolution <= 1 ifTrue: [ ^ 0.0 ].
	^ extent * (2.0 * (aColumnIndex - 1) / (resolution - 1) - 1.0)
]

{ #category : 'geometry' }
GcHiddenSlice >> bAt: aRowIndex [
	"The b-coordinate (second axis) for grid row aRowIndex, 1..resolution, ranging +extent (top row) down to -extent (bottom row) as floats. Parenthesised: Smalltalk binary messages are left-to-right, so 1.0 - 2.0 * x needs the product grouped."
	resolution <= 1 ifTrue: [ ^ 0.0 ].
	^ extent * (1.0 - (2.0 * (aRowIndex - 1) / (resolution - 1)))
]

{ #category : 'accessing' }
GcHiddenSlice >> base [
	^ base
]

{ #category : 'accessing' }
GcHiddenSlice >> basisLabel [
	^ basisLabel
]

{ #category : 'accessing' }
GcHiddenSlice >> dimension [
	"The dimensionality d of the hidden space this slice lives in."
	^ u size
]

{ #category : 'accessing' }
GcHiddenSlice >> extent [
	^ extent
]

{ #category : 'accessing' }
GcHiddenSlice >> extentLabel [
	"Human label for the a,b range, e.g. '[-1.207, 1.207]'."
	^ '[-' , (extent printShowingDecimalPlaces: 3) , ', ' , (extent printShowingDecimalPlaces: 3) , ']'
]

{ #category : 'gt - views' }
GcHiddenSlice >> gtSliceFacetsFor: aView [
	"What 2D slice of hidden space is this, and how was its basis chosen?"
	<gtView>
	^ aView columnedList
		title: 'Slice';
		priority: 10;
		items: [ self sliceFacets ];
		column: 'Property' text: [ :assoc | assoc key ];
		column: 'Value' text: [ :assoc | assoc value displayString ];
		send: [ :assoc | assoc value ]
]

{ #category : 'geometry' }
GcHiddenSlice >> pointAtColumn: aColumnIndex row: aRowIndex [
	"The R^d hidden vector base + a*u + b*v at grid cell (column, row)."
	| a b point |
	a := self aAt: aColumnIndex.
	b := self bAt: aRowIndex.
	point := Array new: self dimension.
	1 to: self dimension do: [ :k |
		point at: k put: (base at: k) + (a * (u at: k)) + (b * (v at: k)) ].
	^ point
]

{ #category : 'printing' }
GcHiddenSlice >> printOn: aStream [
	aStream
		nextPutAll: 'GcHiddenSlice(';
		print: self dimension;
		nextPutAll: 'd, ';
		print: resolution;
		nextPutAll: 'x';
		print: resolution;
		nextPutAll: ' grid, ';
		nextPutAll: (basisLabel ifNil: [ 'unnamed basis' ]);
		nextPutAll: ')'
]

{ #category : 'accessing' }
GcHiddenSlice >> resolution [
	^ resolution
]

{ #category : 'initialization' }
GcHiddenSlice >> setU: aU v: aV base: aBase extent: aRadius resolution: anInteger basisLabel: aLabel [
	u := aU.
	v := aV.
	base := aBase.
	extent := aRadius.
	resolution := anInteger.
	basisLabel := aLabel
]

{ #category : 'gt - facets' }
GcHiddenSlice >> sliceFacets [
	^ OrderedCollection new
		add: 'Basis' -> (basisLabel ifNil: [ 'unnamed' ]);
		add: 'Dimension (d)' -> self dimension;
		add: 'Resolution' -> (resolution printString , ' x ' , resolution printString);
		add: 'Extent (R)' -> extent;
		add: 'a,b range' -> self extentLabel;
		yourself
]

{ #category : 'accessing' }
GcHiddenSlice >> u [
	^ u
]

{ #category : 'accessing' }
GcHiddenSlice >> v [
	^ v
]
